import '../models/card.dart';
import '../models/game_state.dart';
import '../models/deck.dart';
import '../models/player.dart';

/// Result of processing a game action.
class ActionResult {
  final GameState state;
  final String? error;
  final bool success;

  const ActionResult.success(this.state)
      : error = null,
        success = true;

  const ActionResult.failure(this.state, this.error) : success = false;
}

/// Pure game logic — no side effects, fully testable.
/// All methods take a GameState and return a new GameState or validation result.
class GameEngine {
  const GameEngine();

  // ── Initialization ──────────────────────────────────────────────

  /// Create a new game with the given players.
  GameState createGame({
    required String gameId,
    required List<Player> players,
    GameVariant variant = GameVariant.classic,
    int? seed,
  }) {
    assert(players.length >= minPlayers && players.length <= maxPlayers);

    final deck = Deck.shuffled(seed: seed);
    final trumpSuit = deck.trumpSuit!;

    final state = GameState(
      gameId: gameId,
      players: players,
      deck: deck,
      trumpSuit: trumpSuit,
      variant: variant,
      phase: GamePhase.dealing,
    );

    return state;
  }

  /// Deal initial hands (6 cards each) and determine first attacker.
  GameState dealInitialHands(GameState state) {
    final newState = state.copyWith();

    // Deal 6 cards to each player
    for (final player in newState.players) {
      final cards = newState.deck.drawMultiple(handSize);
      player.addCards(cards);
      player.sortHand(newState.trumpSuit);
    }

    // First attacker is the player with the lowest trump card
    final firstAttacker = _findFirstAttacker(newState);
    final firstDefender =
        _nextActivePlayerIndex(newState, firstAttacker);

    return newState.copyWith(
      attackerIndex: firstAttacker,
      defenderIndex: firstDefender,
      phase: GamePhase.attacking,
    );
  }

  /// Find the player with the lowest trump card (first attacker).
  int _findFirstAttacker(GameState state) {
    int lowestTrumpPlayer = 0;
    int lowestTrumpValue = 999;

    for (int i = 0; i < state.players.length; i++) {
      for (final card in state.players[i].hand) {
        if (card.suit == state.trumpSuit &&
            card.rank.value < lowestTrumpValue) {
          lowestTrumpValue = card.rank.value;
          lowestTrumpPlayer = i;
        }
      }
    }

    return lowestTrumpPlayer;
  }

  // ── Action Processing ───────────────────────────────────────────

  /// Process any game action. Returns the new state or an error.
  ActionResult processAction(GameState state, GameAction action) {
    // Validate it's an active player
    final playerIndex = state.players.indexWhere((p) => p.id == action.playerId);
    if (playerIndex == -1) {
      return ActionResult.failure(state, 'Player not found');
    }

    return switch (action) {
      AttackAction a => _processAttack(state, a, playerIndex),
      DefendAction a => _processDefend(state, a, playerIndex),
      PickUpAction a => _processPickUp(state, a, playerIndex),
      PassAction a => _processPass(state, a, playerIndex),
      TransferAction a => _processTransfer(state, a, playerIndex),
    };
  }

  // ── Attack ──────────────────────────────────────────────────────

  ActionResult _processAttack(
      GameState state, AttackAction action, int playerIndex) {
    // Validate phase
    if (state.phase != GamePhase.attacking) {
      return ActionResult.failure(state, 'Not in attacking phase');
    }

    // Validate player is an attacker (main attacker or helper)
    if (!_canPlayerAttack(state, playerIndex)) {
      return ActionResult.failure(state, 'You cannot attack now');
    }

    // Validate the player has this card
    final player = state.players[playerIndex];
    if (!player.hand.contains(action.card)) {
      return ActionResult.failure(state, 'Card not in hand');
    }

    // Validate the card can be played (rank must match table or table empty)
    if (!canAttackWith(state, action.card)) {
      return ActionResult.failure(
          state, 'Card rank must match a card already on the table');
    }

    // Validate max attacks not exceeded
    if (state.tablePairs.length >= state.maxAttackCards) {
      return ActionResult.failure(state, 'Maximum attacks reached');
    }

    // Apply the attack
    final newState = state.copyWith();
    newState.players[playerIndex].removeCard(action.card);
    newState.tablePairs.add(TablePair(attackCard: action.card));
    newState.phase = GamePhase.defending;
    newState.passedPlayers.clear(); // New card played, reset passes
    newState.sequenceNumber++;

    // Check if max attacks reached — if so, no more cards can be added,
    // so we don't need to auto-pass here (defender still needs to respond).

    return ActionResult.success(newState);
  }

  /// Whether a card can be used to attack given the current table state.
  bool canAttackWith(GameState state, PlayingCard card) {
    // First attack — any card is valid
    if (state.tablePairs.isEmpty) return true;

    // Subsequent attacks — rank must match any card on the table
    return state.tableRanks.contains(card.rank);
  }

  /// Whether a player is allowed to attack right now.
  bool _canPlayerAttack(GameState state, int playerIndex) {
    // Main attacker can always attack
    if (playerIndex == state.attackerIndex) return true;

    // Other non-defender, non-finished players can help attack
    // (only after the first attack card is played)
    if (playerIndex == state.defenderIndex) return false;
    if (state.finishedPlayers.contains(playerIndex)) return false;
    if (state.tablePairs.isEmpty) return false; // Only main attacker starts

    return true;
  }

  // ── Defend ──────────────────────────────────────────────────────

  ActionResult _processDefend(
      GameState state, DefendAction action, int playerIndex) {
    if (state.phase != GamePhase.defending) {
      return ActionResult.failure(state, 'Not in defending phase');
    }

    if (playerIndex != state.defenderIndex) {
      return ActionResult.failure(state, 'You are not the defender');
    }

    final player = state.players[playerIndex];
    if (!player.hand.contains(action.defenseCard)) {
      return ActionResult.failure(state, 'Defense card not in hand');
    }

    // Find the undefended attack card
    final pairIndex = state.tablePairs.indexWhere(
        (p) => p.attackCard == action.attackCard && !p.isDefended);
    if (pairIndex == -1) {
      return ActionResult.failure(state, 'Attack card not found on table');
    }

    // Validate the defense
    if (!action.defenseCard.canBeat(action.attackCard, state.trumpSuit)) {
      return ActionResult.failure(state, 'Card cannot beat the attack card');
    }

    // Apply the defense
    final newState = state.copyWith();
    newState.players[playerIndex].removeCard(action.defenseCard);
    newState.tablePairs[pairIndex].defenseCard = action.defenseCard;
    newState.sequenceNumber++;

    // If all pairs defended, switch back to attacking phase
    // (attacker may add more cards or pass)
    if (newState.allDefended) {
      newState.phase = GamePhase.attacking;

      // Auto-continue: if no attacker can play any cards, end the round
      if (_allAttackersHaveNoPlayableCards(newState)) {
        // Successful defense! Discard table cards.
        newState.discardPile.addAll(newState.allTableCards);
        newState.tablePairs.clear();
        newState.passedPlayers.clear();

        // Draw cards
        _drawCards(newState);

        // Defender becomes the next attacker
        _advanceTurnAfterDefense(newState);
        _checkGameOver(newState);
      }
    }

    return ActionResult.success(newState);
  }

  // ── Pick Up ─────────────────────────────────────────────────────

  ActionResult _processPickUp(
      GameState state, PickUpAction action, int playerIndex) {
    if (playerIndex != state.defenderIndex) {
      return ActionResult.failure(state, 'You are not the defender');
    }

    if (!state.hasTableCards) {
      return ActionResult.failure(state, 'No cards to pick up');
    }

    final newState = state.copyWith();
    final defender = newState.players[playerIndex];

    // Defender picks up all cards from the table
    defender.addCards(newState.allTableCards);
    defender.sortHand(newState.trumpSuit);
    newState.tablePairs.clear();
    newState.passedPlayers.clear();
    newState.sequenceNumber++;

    // After pickup: draw cards, then skip defender for next attack
    _drawCards(newState);
    _advanceTurnAfterPickUp(newState);
    _checkGameOver(newState);

    return ActionResult.success(newState);
  }

  // ── Pass ────────────────────────────────────────────────────────

  ActionResult _processPass(
      GameState state, PassAction action, int playerIndex) {
    if (state.phase != GamePhase.attacking) {
      return ActionResult.failure(state, 'Can only pass during attack phase');
    }

    if (playerIndex == state.defenderIndex) {
      return ActionResult.failure(state, 'Defender cannot pass (use pick up)');
    }

    if (!_canPlayerAttack(state, playerIndex)) {
      return ActionResult.failure(state, 'You cannot pass right now');
    }

    final newState = state.copyWith();
    newState.passedPlayers.add(playerIndex);
    newState.sequenceNumber++;

    // Check if all eligible attackers have passed
    if (_allAttackersPassed(newState)) {
      // Successful defense! Discard table cards.
      newState.discardPile.addAll(newState.allTableCards);
      newState.tablePairs.clear();
      newState.passedPlayers.clear();

      // Draw cards
      _drawCards(newState);

      // Defender becomes the next attacker
      _advanceTurnAfterDefense(newState);
      _checkGameOver(newState);
    }

    return ActionResult.success(newState);
  }

  // ── Transfer (Perevodnoy) ───────────────────────────────────────

  ActionResult _processTransfer(
      GameState state, TransferAction action, int playerIndex) {
    if (state.variant != GameVariant.transfer) {
      return ActionResult.failure(
          state, 'Transfer is only available in Perevodnoy mode');
    }

    if (playerIndex != state.defenderIndex) {
      return ActionResult.failure(state, 'Only the defender can transfer');
    }

    // Can only transfer if NO cards have been defended yet
    if (state.tablePairs.any((p) => p.isDefended)) {
      return ActionResult.failure(
          state, 'Cannot transfer after defending a card');
    }

    final player = state.players[playerIndex];
    if (!player.hand.contains(action.card)) {
      return ActionResult.failure(state, 'Card not in hand');
    }

    // The transfer card must match the rank of the attack card(s)
    final attackRanks =
        state.tablePairs.map((p) => p.attackCard.rank).toSet();
    if (!attackRanks.contains(action.card.rank)) {
      return ActionResult.failure(
          state, 'Transfer card must match the rank of attack cards');
    }

    // Determine the next defender after transfer
    final nextDefender =
        _nextActivePlayerIndex(state, state.defenderIndex);

    // Validate the next defender has enough cards for all the attacks
    final nextDefenderCards = state.players[nextDefender].cardCount;
    final totalAttacks = state.tablePairs.length + 1; // +1 for the transfer card
    if (nextDefenderCards < totalAttacks) {
      return ActionResult.failure(
          state, 'Next player doesn\'t have enough cards to defend');
    }

    final newState = state.copyWith();
    newState.players[playerIndex].removeCard(action.card);
    newState.tablePairs.add(TablePair(attackCard: action.card));

    // Current defender becomes the "attacker" (they transferred),
    // the next player becomes the new defender.
    // In 2-player: the original attacker becomes the new defender.
    newState.attackerIndex = state.defenderIndex;
    newState.defenderIndex = nextDefender;
    newState.phase = GamePhase.defending;
    newState.passedPlayers.clear();
    newState.sequenceNumber++;

    return ActionResult.success(newState);
  }

  // ── Turn Advancement ────────────────────────────────────────────

  /// Advance turn after successful defense (defender becomes attacker).
  void _advanceTurnAfterDefense(GameState state) {
    final newAttacker = state.defenderIndex;
    final newDefender = _nextActivePlayerIndex(state, newAttacker);

    state.attackerIndex = newAttacker;
    state.defenderIndex = newDefender;
    state.phase = GamePhase.attacking;
  }

  /// Advance turn after pick-up (defender is skipped).
  void _advanceTurnAfterPickUp(GameState state) {
    // The player after the defender becomes the attacker
    final newAttacker =
        _nextActivePlayerIndex(state, state.defenderIndex);
    final newDefender = _nextActivePlayerIndex(state, newAttacker);

    state.attackerIndex = newAttacker;
    state.defenderIndex = newDefender;
    state.phase = GamePhase.attacking;
  }

  /// Get the next active player index (skipping finished players).
  int _nextActivePlayerIndex(GameState state, int currentIndex) {
    int next = (currentIndex + 1) % state.players.length;
    int safety = 0;
    while (state.finishedPlayers.contains(next) &&
        safety < state.players.length) {
      next = (next + 1) % state.players.length;
      safety++;
    }
    return next;
  }

  // ── Drawing Cards ───────────────────────────────────────────────

  /// Draw cards so each player has 6. Attacker draws first, defender last.
  void _drawCards(GameState state) {
    if (state.deck.isEmpty) return;

    // Build draw order: attacker first, then others, defender last
    final drawOrder = <int>[];
    drawOrder.add(state.attackerIndex);

    for (int i = 0; i < state.players.length; i++) {
      if (i != state.attackerIndex &&
          i != state.defenderIndex &&
          !state.finishedPlayers.contains(i)) {
        drawOrder.add(i);
      }
    }
    drawOrder.add(state.defenderIndex);

    for (final idx in drawOrder) {
      final player = state.players[idx];
      while (player.cardCount < handSize && state.deck.isNotEmpty) {
        final card = state.deck.draw();
        if (card != null) player.addCard(card);
      }
      player.sortHand(state.trumpSuit);
    }

    // After drawing, check if any player is now finished
    // (deck is empty and hand is empty)
    if (state.deck.isEmpty) {
      for (int i = 0; i < state.players.length; i++) {
        if (state.players[i].hasEmptyHand &&
            !state.finishedPlayers.contains(i)) {
          state.finishedPlayers.add(i);
        }
      }
    }
  }

  // ── Game Over Check ─────────────────────────────────────────────

  /// Check if the game is over.
  void _checkGameOver(GameState state) {
    if (state.deck.isNotEmpty) return; // Game continues while deck has cards

    // Mark any players with empty hands as finished
    for (int i = 0; i < state.players.length; i++) {
      if (state.players[i].hasEmptyHand &&
          !state.finishedPlayers.contains(i)) {
        state.finishedPlayers.add(i);
      }
    }

    // Count players still holding cards
    final remainingPlayers = <int>[];
    for (int i = 0; i < state.players.length; i++) {
      if (!state.finishedPlayers.contains(i)) {
        remainingPlayers.add(i);
      }
    }

    if (remainingPlayers.length <= 1) {
      state.phase = GamePhase.gameOver;
      if (remainingPlayers.length == 1) {
        state.durakIndex = remainingPlayers.first;
      }
      // If 0 remaining, it's a draw (everyone shed their cards)
    }

    // Also check if attacker/defender are finished and need reassignment
    if (state.phase != GamePhase.gameOver) {
      if (state.finishedPlayers.contains(state.attackerIndex)) {
        state.attackerIndex =
            _nextActivePlayerIndex(state, state.attackerIndex);
        state.defenderIndex =
            _nextActivePlayerIndex(state, state.attackerIndex);
      }
      if (state.finishedPlayers.contains(state.defenderIndex)) {
        state.defenderIndex =
            _nextActivePlayerIndex(state, state.attackerIndex);
      }
    }
  }

  // ── Queries ─────────────────────────────────────────────────────

  bool _allAttackersPassed(GameState state) {
    for (int i = 0; i < state.players.length; i++) {
      if (i == state.defenderIndex) continue;
      if (state.finishedPlayers.contains(i)) continue;
      if (!state.passedPlayers.contains(i)) return false;
    }
    return true;
  }

  /// Check if no attacker (main or helpers) has any playable cards to add.
  /// Used for auto-continuing when attackers can't contribute more cards.
  bool _allAttackersHaveNoPlayableCards(GameState state) {
    if (state.phase != GamePhase.attacking) return false;
    if (!state.hasTableCards) return false; // First attack must be manual
    if (state.tablePairs.length >= state.maxAttackCards) return true;

    for (int i = 0; i < state.players.length; i++) {
      if (i == state.defenderIndex) continue;
      if (state.finishedPlayers.contains(i)) continue;
      // Check if this player has any card whose rank matches the table
      final player = state.players[i];
      final hasPlayable = player.hand.any((c) => canAttackWith(state, c));
      if (hasPlayable) return false;
    }
    return true;
  }

  /// Public version for use by GameManager to check after state changes.
  bool shouldAutoPassAttackers(GameState state) {
    return _allAttackersHaveNoPlayableCards(state);
  }

  /// Get all valid cards a player can play right now.
  List<PlayingCard> getPlayableCards(GameState state, String playerId) {
    final playerIndex =
        state.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return [];

    final player = state.players[playerIndex];

    if (state.phase == GamePhase.attacking &&
        _canPlayerAttack(state, playerIndex)) {
      // Can play any card whose rank matches the table, or any card if first
      return player.hand.where((c) => canAttackWith(state, c)).toList();
    }

    if (state.phase == GamePhase.defending &&
        playerIndex == state.defenderIndex) {
      final playable = <PlayingCard>[];

      // Cards that can beat undefended attacks
      for (final pair in state.tablePairs) {
        if (!pair.isDefended) {
          for (final card in player.hand) {
            if (card.canBeat(pair.attackCard, state.trumpSuit)) {
              playable.add(card);
            }
          }
        }
      }

      // In Perevodnoy: cards that can transfer (matching rank, no defenses yet)
      if (state.variant == GameVariant.transfer &&
          !state.tablePairs.any((p) => p.isDefended)) {
        final attackRanks =
            state.tablePairs.map((p) => p.attackCard.rank).toSet();
        for (final card in player.hand) {
          if (attackRanks.contains(card.rank) && !playable.contains(card)) {
            playable.add(card);
          }
        }
      }

      return playable.toSet().toList(); // Deduplicate
    }

    return [];
  }

  /// Whether the defender can transfer in the current state.
  bool canTransfer(GameState state) {
    if (state.variant != GameVariant.transfer) return false;
    if (state.phase != GamePhase.defending) return false;
    if (state.tablePairs.any((p) => p.isDefended)) return false;

    // Check that defender has a card matching an attack rank
    final defender = state.players[state.defenderIndex];
    final attackRanks =
        state.tablePairs.map((p) => p.attackCard.rank).toSet();
    final hasTransferCard =
        defender.hand.any((c) => attackRanks.contains(c.rank));
    if (!hasTransferCard) return false;

    // Check next defender has enough cards
    final nextDefender =
        _nextActivePlayerIndex(state, state.defenderIndex);
    final totalAttacks = state.tablePairs.length + 1;
    if (state.players[nextDefender].cardCount < totalAttacks) return false;

    return true;
  }
}
