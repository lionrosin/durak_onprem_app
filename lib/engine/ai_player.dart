import 'dart:math';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'game_engine.dart';

/// Simple AI player for single-player 1v1 testing.
/// Strategy: play the lowest valid card, prefer non-trumps, defend when possible.
class AiPlayer {
  final GameEngine _engine = const GameEngine();
  final Random _random = Random();
  final String playerId;

  AiPlayer({required this.playerId});

  /// Determine the AI's next action given the current game state.
  /// Returns null if the AI can't act (not their turn).
  GameAction? decideAction(GameState state) {
    final playerIndex = state.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return null;

    final player = state.players[playerIndex];
    final isAttacker = playerIndex == state.attackerIndex;
    final isDefender = playerIndex == state.defenderIndex;

    if (state.phase == GamePhase.attacking && isAttacker) {
      return _decideAttack(state, player);
    }

    if (state.phase == GamePhase.attacking && !isDefender) {
      return _decideHelperAttack(state, player);
    }

    if (state.phase == GamePhase.defending && isDefender) {
      return _decideDefense(state, player);
    }

    return null;
  }

  /// Decide which card to attack with.
  GameAction _decideAttack(GameState state, Player player) {
    final playable = _engine.getPlayableCards(state, playerId);
    if (playable.isEmpty || (state.hasTableCards && _random.nextDouble() < 0.3)) {
      // Sometimes pass if cards are already on the table
      return PassAction(playerId: playerId);
    }

    // Sort by effective value — play lowest non-trump first
    final sorted = _sortByStrength(playable, state.trumpSuit);
    return AttackAction(playerId: playerId, card: sorted.first);
  }

  /// Decide whether to help attack.
  GameAction _decideHelperAttack(GameState state, Player player) {
    // Helpers are less aggressive
    if (_random.nextDouble() < 0.6) {
      return PassAction(playerId: playerId);
    }

    final playable = _engine.getPlayableCards(state, playerId);
    if (playable.isEmpty) {
      return PassAction(playerId: playerId);
    }

    final sorted = _sortByStrength(playable, state.trumpSuit);
    return AttackAction(playerId: playerId, card: sorted.first);
  }

  /// Decide how to defend.
  GameAction _decideDefense(GameState state, Player player) {
    // Try to defend each undefended pair
    final undefended = state.tablePairs.where((p) => !p.isDefended).toList();
    if (undefended.isEmpty) return PassAction(playerId: playerId);

    // Check if we can defend the first undefended card
    final target = undefended.first;
    final defenseOptions = player.hand
        .where((c) => c.canBeat(target.attackCard, state.trumpSuit))
        .toList();

    if (defenseOptions.isEmpty) {
      // Check if transfer is available
      if (state.variant == GameVariant.transfer &&
          _engine.canTransfer(state)) {
        final attackRanks =
            state.tablePairs.map((p) => p.attackCard.rank).toSet();
        final transferCards =
            player.hand.where((c) => attackRanks.contains(c.rank)).toList();
        if (transferCards.isNotEmpty) {
          final sorted = _sortByStrength(transferCards, state.trumpSuit);
          return TransferAction(playerId: playerId, card: sorted.first);
        }
      }

      // Can't defend — pick up
      return PickUpAction(playerId: playerId);
    }

    // Defend with the weakest possible card
    final sorted = _sortByStrength(defenseOptions, state.trumpSuit);
    return DefendAction(
      playerId: playerId,
      attackCard: target.attackCard,
      defenseCard: sorted.first,
    );
  }

  /// Sort cards by strength (weakest first). Non-trumps before trumps.
  List<PlayingCard> _sortByStrength(List<PlayingCard> cards, Suit trumpSuit) {
    final sorted = List<PlayingCard>.from(cards);
    sorted.sort((a, b) =>
        a.effectiveValue(trumpSuit).compareTo(b.effectiveValue(trumpSuit)));
    return sorted;
  }
}
