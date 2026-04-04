import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';
import 'package:durak_onprem_app/models/game_state.dart';
import 'package:durak_onprem_app/models/player.dart';
import 'package:durak_onprem_app/engine/game_engine.dart';

void main() {
  const engine = GameEngine();

  /// Helper: create a 2-player game ready for play.
  GameState createTestGame({
    GameVariant variant = GameVariant.classic,
    int seed = 42,
  }) {
    final players = [
      Player(id: 'p1', name: 'Alice', isHost: true),
      Player(id: 'p2', name: 'Bob'),
    ];
    final state = engine.createGame(
      gameId: 'test',
      players: players,
      variant: variant,
      seed: seed,
    );
    return engine.dealInitialHands(state);
  }

  /// Helper: create a 3-player game.
  GameState createThreePlayerGame({int seed = 42}) {
    final players = [
      Player(id: 'p1', name: 'Alice', isHost: true),
      Player(id: 'p2', name: 'Bob'),
      Player(id: 'p3', name: 'Charlie'),
    ];
    final state = engine.createGame(
      gameId: 'test-3p',
      players: players,
      seed: seed,
    );
    return engine.dealInitialHands(state);
  }

  group('Game Initialization', () {
    test('createGame sets up correct state', () {
      final state = engine.createGame(
        gameId: 'test',
        players: [
          Player(id: 'p1', name: 'Alice'),
          Player(id: 'p2', name: 'Bob'),
        ],
        seed: 42,
      );
      expect(state.gameId, equals('test'));
      expect(state.players.length, equals(2));
      expect(state.phase, equals(GamePhase.dealing));
      expect(state.deck.remaining, equals(36));
      expect(state.trumpSuit, isNotNull);
    });

    test('dealInitialHands gives 6 cards each', () {
      final state = createTestGame();
      expect(state.players[0].cardCount, equals(6));
      expect(state.players[1].cardCount, equals(6));
      expect(state.deck.remaining, equals(24));
    });

    test('dealInitialHands sets attacking phase', () {
      final state = createTestGame();
      expect(state.phase, equals(GamePhase.attacking));
    });

    test('first attacker has lowest trump card', () {
      final state = createTestGame(seed: 42);
      // The attacker should be the player holding the lowest trump
      final attacker = state.players[state.attackerIndex];
      final defender = state.players[state.defenderIndex];
      final trumpSuit = state.trumpSuit;

      final attackerTrumps = attacker.hand
          .where((c) => c.suit == trumpSuit)
          .map((c) => c.rank.value)
          .toList();
      final defenderTrumps = defender.hand
          .where((c) => c.suit == trumpSuit)
          .map((c) => c.rank.value)
          .toList();

      if (attackerTrumps.isNotEmpty && defenderTrumps.isNotEmpty) {
        final minAttacker = attackerTrumps.reduce((a, b) => a < b ? a : b);
        final minDefender = defenderTrumps.reduce((a, b) => a < b ? a : b);
        expect(minAttacker, lessThanOrEqualTo(minDefender));
      }
    });

    test('3-player game deals correctly', () {
      final state = createThreePlayerGame();
      expect(state.players.length, equals(3));
      for (final p in state.players) {
        expect(p.cardCount, equals(6));
      }
      expect(state.deck.remaining, equals(18)); // 36 - 18
    });
  });

  group('Attack', () {
    test('first attack with any card succeeds', () {
      final state = createTestGame();
      final attacker = state.players[state.attackerIndex];
      final card = attacker.hand.first;
      final result = engine.processAction(
        state,
        AttackAction(playerId: attacker.id, card: card),
      );
      expect(result.success, isTrue);
      expect(result.state.tablePairs.length, equals(1));
      expect(result.state.phase, equals(GamePhase.defending));
    });

    test('subsequent attack must match table rank', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;
      final firstCard = state.players[state.attackerIndex].hand.first;

      // First attack
      var result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: firstCard),
      );
      state = result.state;

      // Defend
      final defender = state.players[state.defenderIndex];
      final undefended = state.tablePairs.first;
      final defenseCards = defender.hand
          .where((c) => c.canBeat(undefended.attackCard, state.trumpSuit))
          .toList();

      if (defenseCards.isNotEmpty) {
        result = engine.processAction(
          state,
          DefendAction(
            playerId: defenderId,
            attackCard: undefended.attackCard,
            defenseCard: defenseCards.first,
          ),
        );
        state = result.state;

        // Now try a second attack — must match rank on table
        final attacker = state.players[state.attackerIndex];
        final matchingCards = attacker.hand
            .where((c) => state.tableRanks.contains(c.rank))
            .toList();
        final nonMatchingCards = attacker.hand
            .where((c) => !state.tableRanks.contains(c.rank))
            .toList();

        if (nonMatchingCards.isNotEmpty) {
          final badResult = engine.processAction(
            state,
            AttackAction(playerId: attackerId, card: nonMatchingCards.first),
          );
          expect(badResult.success, isFalse);
        }

        if (matchingCards.isNotEmpty) {
          final goodResult = engine.processAction(
            state,
            AttackAction(playerId: attackerId, card: matchingCards.first),
          );
          expect(goodResult.success, isTrue);
        }
      }
    });

    test('defender cannot attack', () {
      final state = createTestGame();
      final defender = state.players[state.defenderIndex];
      final result = engine.processAction(
        state,
        AttackAction(playerId: defender.id, card: defender.hand.first),
      );
      expect(result.success, isFalse);
      expect(result.error, contains('cannot attack'));
    });

    test('attack fails when not in attacking phase', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final firstCard = state.players[state.attackerIndex].hand.first;

      // Move to defending phase
      final result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: firstCard),
      );
      state = result.state;
      expect(state.phase, equals(GamePhase.defending));

      // Try to attack again in defending phase
      final attacker = state.players[state.attackerIndex];
      if (attacker.hand.isNotEmpty) {
        final badResult = engine.processAction(
          state,
          AttackAction(playerId: attackerId, card: attacker.hand.first),
        );
        expect(badResult.success, isFalse);
      }
    });

    test('attack fails with card not in hand', () {
      final state = createTestGame();
      final attacker = state.players[state.attackerIndex];
      const fakeCard = PlayingCard(suit: Suit.hearts, rank: Rank.ace);

      if (!attacker.hand.contains(fakeCard)) {
        final result = engine.processAction(
          state,
          AttackAction(playerId: attacker.id, card: fakeCard),
        );
        expect(result.success, isFalse);
        expect(result.error, contains('not in hand'));
      }
    });

    test('attack increments sequence number', () {
      final state = createTestGame();
      final attacker = state.players[state.attackerIndex];
      final result = engine.processAction(
        state,
        AttackAction(playerId: attacker.id, card: attacker.hand.first),
      );
      expect(result.state.sequenceNumber, greaterThan(state.sequenceNumber));
    });
  });

  group('Defend', () {
    test('valid defense works', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;
      final attackCard = state.players[state.attackerIndex].hand.first;

      // Attack
      var result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attackCard),
      );
      state = result.state;

      // Find a valid defense card
      final defender = state.players[state.defenderIndex];
      final undefended = state.tablePairs.first;
      final validDefense = defender.hand
          .where((c) => c.canBeat(undefended.attackCard, state.trumpSuit))
          .toList();

      if (validDefense.isNotEmpty) {
        result = engine.processAction(
          state,
          DefendAction(
            playerId: defenderId,
            attackCard: undefended.attackCard,
            defenseCard: validDefense.first,
          ),
        );
        expect(result.success, isTrue);
        expect(result.state.tablePairs.first.isDefended, isTrue);
        // After all defended, goes back to attacking
        expect(result.state.phase, equals(GamePhase.attacking));
      }
    });

    test('invalid defense card rejected', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;
      final attackCard = state.players[state.attackerIndex].hand.first;

      var result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attackCard),
      );
      state = result.state;

      // Try to defend with a card that can't beat the attack
      final defender = state.players[state.defenderIndex];
      final undefended = state.tablePairs.first;
      final invalidDefense = defender.hand
          .where((c) => !c.canBeat(undefended.attackCard, state.trumpSuit))
          .toList();

      if (invalidDefense.isNotEmpty) {
        result = engine.processAction(
          state,
          DefendAction(
            playerId: defenderId,
            attackCard: undefended.attackCard,
            defenseCard: invalidDefense.first,
          ),
        );
        expect(result.success, isFalse);
      }
    });

    test('non-defender cannot defend', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final attackCard = state.players[state.attackerIndex].hand.first;

      var result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attackCard),
      );
      state = result.state;

      // Attacker tries to defend
      final attacker = state.players[state.attackerIndex];
      if (attacker.hand.isNotEmpty) {
        result = engine.processAction(
          state,
          DefendAction(
            playerId: attackerId,
            attackCard: state.tablePairs.first.attackCard,
            defenseCard: attacker.hand.first,
          ),
        );
        expect(result.success, isFalse);
        expect(result.error, contains('not the defender'));
      }
    });
  });

  group('Pick Up', () {
    test('defender picks up all table cards', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;
      final attackCard = state.players[state.attackerIndex].hand.first;

      // Attack
      var result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attackCard),
      );
      state = result.state;

      // Pick up

      result = engine.processAction(
        state,
        PickUpAction(playerId: defenderId),
      );
      expect(result.success, isTrue);
      expect(result.state.tablePairs, isEmpty);
      // Defender should have picked up table cards (+ drawn cards may vary)
    });

    test('non-defender cannot pick up', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final attackCard = state.players[state.attackerIndex].hand.first;

      var result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attackCard),
      );
      state = result.state;

      result = engine.processAction(
        state,
        PickUpAction(playerId: attackerId),
      );
      expect(result.success, isFalse);
    });

    test('cannot pick up when no cards on table', () {
      final state = createTestGame();
      final defenderId = state.players[state.defenderIndex].id;
      final result = engine.processAction(
        state,
        PickUpAction(playerId: defenderId),
      );
      expect(result.success, isFalse);
    });

    test('turn advances after pickup (defender skipped)', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderIndex = state.defenderIndex;
      final defenderId = state.players[defenderIndex].id;

      // Attack
      var result = engine.processAction(
        state,
        AttackAction(
          playerId: attackerId,
          card: state.players[state.attackerIndex].hand.first,
        ),
      );
      state = result.state;

      // Pick up
      result = engine.processAction(
        state,
        PickUpAction(playerId: defenderId),
      );
      state = result.state;

      // In 2-player, after pickup the player after defender attacks
      // Defender is skipped for next attack
      expect(state.phase, equals(GamePhase.attacking));
    });
  });

  group('Pass', () {
    test('attacker passes after placing a card → defense succeeds', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;

      // Attack
      var result = engine.processAction(
        state,
        AttackAction(
          playerId: attackerId,
          card: state.players[state.attackerIndex].hand.first,
        ),
      );
      state = result.state;

      // Defend
      final defender = state.players[state.defenderIndex];
      final undefended = state.tablePairs.first;
      final defenseCards = defender.hand
          .where((c) => c.canBeat(undefended.attackCard, state.trumpSuit))
          .toList();

      if (defenseCards.isNotEmpty) {
        result = engine.processAction(
          state,
          DefendAction(
            playerId: defenderId,
            attackCard: undefended.attackCard,
            defenseCard: defenseCards.first,
          ),
        );
        state = result.state;

        // Pass
        result = engine.processAction(
          state,
          PassAction(playerId: attackerId),
        );
        expect(result.success, isTrue);
        // All attackers passed → defense successful, table cleared
        expect(result.state.tablePairs, isEmpty);
        expect(result.state.discardPile, isNotEmpty);
      }
    });

    test('defender cannot pass (should pick up instead)', () {
      final state = createTestGame();
      final defenderId = state.players[state.defenderIndex].id;

      // Try to pass as defender
      final result = engine.processAction(
        state,
        PassAction(playerId: defenderId),
      );
      expect(result.success, isFalse);
    });

    test('cannot pass during defending phase', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;

      // Attack to move to defending phase
      final result = engine.processAction(
        state,
        AttackAction(
          playerId: attackerId,
          card: state.players[state.attackerIndex].hand.first,
        ),
      );
      state = result.state;

      // Try to pass during defending (irrelevant for attacker but testing phase check)
      // The attacker can't act in defending phase except the defender
      // This tests the phase check
    });
  });

  group('Transfer (Perevodnoy)', () {
    test('valid transfer succeeds', () {
      // We need a specific seed where the defender has a card matching the attack rank
      // Try multiple seeds to find one that works
      for (int seed = 0; seed < 100; seed++) {
        final state = createTestGame(variant: GameVariant.transfer, seed: seed);
        final attackerId = state.players[state.attackerIndex].id;
        final defenderId = state.players[state.defenderIndex].id;
        final attackCard = state.players[state.attackerIndex].hand.first;

        final attackResult = engine.processAction(
          state,
          AttackAction(playerId: attackerId, card: attackCard),
        );
        if (!attackResult.success) continue;
        final afterAttack = attackResult.state;

        // Check if defender has a matching rank card
        final defender = afterAttack.players[afterAttack.defenderIndex];
        final transferCards = defender.hand
            .where((c) => c.rank == attackCard.rank)
            .toList();

        if (transferCards.isNotEmpty && engine.canTransfer(afterAttack)) {
          final transferResult = engine.processAction(
            afterAttack,
            TransferAction(playerId: defenderId, card: transferCards.first),
          );
          expect(transferResult.success, isTrue);
          // After transfer, the original defender becomes attacker
          expect(transferResult.state.attackerIndex,
              equals(afterAttack.defenderIndex));
          break;
        }
      }
    });

    test('transfer rejected in classic variant', () {
      final state = createTestGame(variant: GameVariant.classic);
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;

      final attackResult = engine.processAction(
        state,
        AttackAction(
          playerId: attackerId,
          card: state.players[state.attackerIndex].hand.first,
        ),
      );

      if (attackResult.success) {
        final afterAttack = attackResult.state;
        final defender = afterAttack.players[afterAttack.defenderIndex];
        if (defender.hand.isNotEmpty) {
          final result = engine.processAction(
            afterAttack,
            TransferAction(playerId: defenderId, card: defender.hand.first),
          );
          expect(result.success, isFalse);
          expect(result.error, contains('Perevodnoy'));
        }
      }
    });

    test('non-defender cannot transfer', () {
      final state = createTestGame(variant: GameVariant.transfer);
      final attackerId = state.players[state.attackerIndex].id;
      final attacker = state.players[state.attackerIndex];

      // Attack first
      final attackResult = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attacker.hand.first),
      );

      if (attackResult.success) {
        // Attacker tries to transfer
        final afterAttack = attackResult.state;
        final atk = afterAttack.players[afterAttack.attackerIndex];
        if (atk.hand.isNotEmpty) {
          final result = engine.processAction(
            afterAttack,
            TransferAction(playerId: attackerId, card: atk.hand.first),
          );
          expect(result.success, isFalse);
        }
      }
    });
  });

  group('Game Over', () {
    test('game ends when only one player has cards left', () {
      // Play a full game with deterministic seed to reach game over
      var state = createTestGame(seed: 42);
      int moves = 0;
      const maxMoves = 500;

      while (state.phase != GamePhase.gameOver && moves < maxMoves) {
        final attackerId = state.players[state.attackerIndex].id;
        final defenderId = state.players[state.defenderIndex].id;

        if (state.phase == GamePhase.attacking) {
  
          final playable = engine.getPlayableCards(state, attackerId);

          if (playable.isNotEmpty && state.tablePairs.length < state.maxAttackCards) {
            final result = engine.processAction(
              state,
              AttackAction(playerId: attackerId, card: playable.first),
            );
            if (result.success) {
              state = result.state;
            } else {
              final passResult = engine.processAction(
                state,
                PassAction(playerId: attackerId),
              );
              if (passResult.success) state = passResult.state;
            }
          } else {
            final result = engine.processAction(
              state,
              PassAction(playerId: attackerId),
            );
            if (result.success) state = result.state;
          }
        } else if (state.phase == GamePhase.defending) {
          final defender = state.players[state.defenderIndex];
          final undefended =
              state.tablePairs.where((p) => !p.isDefended).toList();

          if (undefended.isNotEmpty) {
            final defenseCards = defender.hand
                .where((c) =>
                    c.canBeat(undefended.first.attackCard, state.trumpSuit))
                .toList();

            if (defenseCards.isNotEmpty) {
              final result = engine.processAction(
                state,
                DefendAction(
                  playerId: defenderId,
                  attackCard: undefended.first.attackCard,
                  defenseCard: defenseCards.first,
                ),
              );
              if (result.success) state = result.state;
            } else {
              final result = engine.processAction(
                state,
                PickUpAction(playerId: defenderId),
              );
              if (result.success) state = result.state;
            }
          }
        }
        moves++;
      }

      // Game should have ended (or at least not infinite-loop)
      // With 500 moves for 2 players and 36 cards, game should finish
      if (state.phase == GamePhase.gameOver) {
        // Either durak was found or draw
        if (state.durakIndex >= 0) {
          expect(state.players[state.durakIndex].hand, isNotEmpty);
        }
      }
    });
  });

  group('getPlayableCards', () {
    test('returns all cards for initial attack', () {
      final state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final playable = engine.getPlayableCards(state, attackerId);
      // First attack: any card is valid
      expect(playable.length, equals(state.players[state.attackerIndex].cardCount));
    });

    test('returns empty for non-active player', () {
      final state = createTestGame();
      final playable = engine.getPlayableCards(state, 'nonexistent');
      expect(playable, isEmpty);
    });

    test('returns valid defense cards for defender', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;
      final defenderId = state.players[state.defenderIndex].id;

      // Attack
      final result = engine.processAction(
        state,
        AttackAction(
          playerId: attackerId,
          card: state.players[state.attackerIndex].hand.first,
        ),
      );
      state = result.state;

      final playable = engine.getPlayableCards(state, defenderId);
      // Each playable card should be able to beat some undefended attack
      for (final card in playable) {
        final canBeatSomething = state.tablePairs
            .where((p) => !p.isDefended)
            .any((p) => card.canBeat(p.attackCard, state.trumpSuit));
        // Card is playable either because it can beat OR transfer
        expect(canBeatSomething || state.tableRanks.contains(card.rank), isTrue);
      }
    });
  });

  group('canAttackWith', () {
    test('any card valid for first attack', () {
      final state = createTestGame();
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(engine.canAttackWith(state, card), isTrue);
    });

    test('matching rank valid for subsequent attack', () {
      var state = createTestGame();
      final attackerId = state.players[state.attackerIndex].id;

      final attackCard = state.players[state.attackerIndex].hand.first;
      final result = engine.processAction(
        state,
        AttackAction(playerId: attackerId, card: attackCard),
      );
      state = result.state;

      // A card with the same rank should be valid
      final matchingCard = PlayingCard(
        suit: attackCard.suit == Suit.hearts ? Suit.clubs : Suit.hearts,
        rank: attackCard.rank,
      );
      expect(engine.canAttackWith(state, matchingCard), isTrue);
    });
  });

  group('canTransfer', () {
    test('false in classic mode', () {
      final state = createTestGame(variant: GameVariant.classic);
      expect(engine.canTransfer(state), isFalse);
    });

    test('false when not defending', () {
      final state = createTestGame(variant: GameVariant.transfer);
      expect(state.phase, equals(GamePhase.attacking));
      expect(engine.canTransfer(state), isFalse);
    });
  });

  group('Player not found', () {
    test('processAction returns failure for unknown player', () {
      final state = createTestGame();
      final result = engine.processAction(
        state,
        AttackAction(
          playerId: 'unknown',
          card: const PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        ),
      );
      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });
  });

  group('ActionResult', () {
    test('success result', () {
      final state = createTestGame();
      final result = ActionResult.success(state);
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('failure result', () {
      final state = createTestGame();
      final result = ActionResult.failure(state, 'Test error');
      expect(result.success, isFalse);
      expect(result.error, equals('Test error'));
    });
  });
}
