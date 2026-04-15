import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'game_engine.dart';

/// Describes how a round ended — for UI animation purposes.
enum RoundEndType {
  /// Successful defense — cards go to discard pile (bita).
  defenseBita,
  /// Defender picked up — cards go to defender's hand.
  defenderPickUp,
}

/// Event emitted when a round ends, carrying the cards for animation.
class RoundEndEvent {
  final RoundEndType type;
  final List<TablePair> tablePairs;
  final int defenderIndex;
  final String defenderName;

  const RoundEndEvent({
    required this.type,
    required this.tablePairs,
    required this.defenderIndex,
    required this.defenderName,
  });
}

/// Orchestrates game flow, bridging UI, game logic, and network.
/// This is the primary state holder — UI listens to this via ChangeNotifier.
class GameManager extends ChangeNotifier {
  final GameEngine _engine = const GameEngine();
  GameState? _state;
  String? _localPlayerId;
  String? _errorMessage;

  /// The latest round-end event (consumed by the UI for animation).
  RoundEndEvent? _lastRoundEnd;
  RoundEndEvent? get lastRoundEnd => _lastRoundEnd;

  /// Clear the round-end event after the UI has consumed it.
  void clearRoundEnd() {
    _lastRoundEnd = null;
  }

  /// Current game state (null if no game active).
  GameState? get state => _state;

  /// The local player's ID.
  String? get localPlayerId => _localPlayerId;

  /// Last error message (cleared on next action).
  String? get errorMessage => _errorMessage;

  /// Whether a game is in progress.
  bool get isGameActive =>
      _state != null && _state!.phase != GamePhase.gameOver;

  /// The local player object.
  Player? get localPlayer {
    if (_state == null || _localPlayerId == null) return null;
    return _state!.players.firstWhere(
      (p) => p.id == _localPlayerId,
      orElse: () => _state!.players.first,
    );
  }

  /// Whether it's the local player's turn to act.
  bool get isMyTurn {
    if (_state == null || _localPlayerId == null) return false;
    final myIndex =
        _state!.players.indexWhere((p) => p.id == _localPlayerId);
    if (myIndex == -1) return false;

    // Defender turn
    if (myIndex == _state!.defenderIndex) {
      // Defender can play if there are undefended cards
      if (_state!.tablePairs.any((p) => !p.isDefended)) return true;
      // Defender can transfer if it's the transfer variant and conditions met
      if (canTransfer) return true;
      // Otherwise, they wait for attackers to add cards
      return false;
    }

    // Attacker turn
    if (_state!.phase == GamePhase.attacking) {
      if (myIndex == _state!.attackerIndex) return true;
      if (!_state!.finishedPlayers.contains(myIndex) &&
          _state!.tablePairs.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  /// Whether the local player is the defender.
  bool get isDefender {
    if (_state == null || _localPlayerId == null) return false;
    final myIndex =
        _state!.players.indexWhere((p) => p.id == _localPlayerId);
    return myIndex == _state!.defenderIndex;
  }

  /// Whether the local player is the attacker.
  bool get isAttacker {
    if (_state == null || _localPlayerId == null) return false;
    final myIndex =
        _state!.players.indexWhere((p) => p.id == _localPlayerId);
    return myIndex == _state!.attackerIndex;
  }

  /// Cards the local player can currently play.
  List<PlayingCard> get playableCards {
    if (_state == null || _localPlayerId == null) return [];
    return _engine.getPlayableCards(_state!, _localPlayerId!);
  }

  /// Whether transfer is available for the local player.
  bool get canTransfer {
    if (_state == null) return false;
    if (!isDefender) return false;
    return _engine.canTransfer(_state!);
  }

  // ── Game Lifecycle ──────────────────────────────────────────────

  /// Create a new game as host.
  void createGame({
    required String gameId,
    required String localPlayerId,
    required String localPlayerName,
    required List<Player> players,
    GameVariant variant = GameVariant.classic,
  }) {
    _localPlayerId = localPlayerId;
    _errorMessage = null;

    _state = _engine.createGame(
      gameId: gameId,
      players: players,
      variant: variant,
    );

    notifyListeners();
  }

  /// Start the game (deal cards).
  void startGame() {
    if (_state == null) return;
    _state = _engine.dealInitialHands(_state!);
    _errorMessage = null;
    notifyListeners();
  }

  /// Apply a received game state from network (client mode).
  void applyNetworkState(GameState newState) {
    // Detect round end for animation: old state had table cards, new doesn't.
    if (_state != null &&
        _state!.hasTableCards &&
        newState.tablePairs.isEmpty) {
      // Reliable detection: if the discard pile grew, the table cards went
      // there (bita / successful defense). If it didn't grow, the defender
      // picked them up (pickup doesn't add to discard).
      final isBita =
          newState.discardPile.length > _state!.discardPile.length;

      _lastRoundEnd = RoundEndEvent(
        type: isBita ? RoundEndType.defenseBita : RoundEndType.defenderPickUp,
        tablePairs: _state!.tablePairs
            .map((p) => TablePair(
                  attackCard: p.attackCard,
                  defenseCard: p.defenseCard,
                ))
            .toList(),
        defenderIndex: _state!.defenderIndex,
        defenderName: _state!.players[_state!.defenderIndex].name,
      );
    }

    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  /// Set the local player ID (used when joining as client).
  void setLocalPlayerId(String id) {
    _localPlayerId = id;
  }

  // ── Player Actions ──────────────────────────────────────────────

  /// Play an attack card.
  bool attack(PlayingCard card) {
    return _processAction(
      AttackAction(playerId: _localPlayerId!, card: card),
    );
  }

  /// Defend against an attack card.
  bool defend(PlayingCard attackCard, PlayingCard defenseCard) {
    return _processAction(
      DefendAction(
        playerId: _localPlayerId!,
        attackCard: attackCard,
        defenseCard: defenseCard,
      ),
    );
  }

  /// Pick up all table cards (give up defending).
  bool pickUp() {
    return _processAction(
      PickUpAction(playerId: _localPlayerId!),
    );
  }

  /// Pass (done adding attacks).
  bool pass() {
    return _processAction(
      PassAction(playerId: _localPlayerId!),
    );
  }

  /// Transfer attack to next player (Perevodnoy only).
  bool transfer(PlayingCard card) {
    return _processAction(
      TransferAction(playerId: _localPlayerId!, card: card),
    );
  }

  /// Process an action from a remote player (host only).
  bool processRemoteAction(GameAction action) {
    return _processAction(action);
  }

  bool _processAction(GameAction action) {
    if (_state == null) {
      _errorMessage = 'No active game';
      notifyListeners();
      return false;
    }

    // Snapshot the table before processing — used to detect round end.
    final hadTableCards = _state!.hasTableCards;
    final previousTablePairs = hadTableCards
        ? _state!.tablePairs
            .map((p) => TablePair(
                  attackCard: p.attackCard,
                  defenseCard: p.defenseCard,
                ))
            .toList()
        : <TablePair>[];
    final previousDefenderIndex = _state!.defenderIndex;
    final previousDefenderName = _state!.players[previousDefenderIndex].name;
    final isPickUpAction = action is PickUpAction;

    final result = _engine.processAction(_state!, action);
    if (result.success) {
      _state = result.state;
      _errorMessage = null;

      // Auto-pass: if we're in the attacking phase and no attacker
      // has any playable cards, automatically pass for all of them.
      if (_state != null &&
          _state!.phase == GamePhase.attacking &&
          _state!.hasTableCards &&
          _engine.shouldAutoPassAttackers(_state!)) {
        // Auto-pass all eligible attackers
        for (int i = 0; i < _state!.players.length; i++) {
          if (i == _state!.defenderIndex) continue;
          if (_state!.finishedPlayers.contains(i)) continue;
          if (_state!.passedPlayers.contains(i)) continue;
          final passResult = _engine.processAction(
            _state!,
            PassAction(playerId: _state!.players[i].id),
          );
          if (passResult.success) {
            _state = passResult.state;
          }
        }
      }

      // Detect round end: table had cards but is now empty.
      if (hadTableCards &&
          previousTablePairs.isNotEmpty &&
          !_state!.hasTableCards) {
        _lastRoundEnd = RoundEndEvent(
          type: isPickUpAction
              ? RoundEndType.defenderPickUp
              : RoundEndType.defenseBita,
          tablePairs: previousTablePairs,
          defenderIndex: previousDefenderIndex,
          defenderName: previousDefenderName,
        );
      }

      // Notify network layer
      onActionToSend?.call(action);
      onStateBroadcast?.call(_state!);
    } else {
      _errorMessage = result.error;
    }

    notifyListeners();
    return result.success;
  }

  // ── Callbacks for network events ────────────────────────────────

  /// Called when the game action should be sent over network.
  /// Set this from the network layer.
  Function(GameAction action)? onActionToSend;

  /// Called when full state update should be broadcast (host only).
  Function(GameState state)? onStateBroadcast;

  // ── Cleanup ─────────────────────────────────────────────────────

  void resetGame() {
    _state = null;
    _localPlayerId = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    resetGame();
    super.dispose();
  }
}
