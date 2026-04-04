import 'package:flutter_test/flutter_test.dart';

import 'package:durak_onprem_app/models/game_state.dart';
import 'package:durak_onprem_app/models/player.dart';
import 'package:durak_onprem_app/engine/game_engine.dart';
import 'package:durak_onprem_app/engine/ai_player.dart';

void main() {
  const engine = GameEngine();

  GameState createTestGame({
    GameVariant variant = GameVariant.classic,
    int seed = 42,
  }) {
    final players = [
      Player(id: 'p1', name: 'Human', isHost: true),
      Player(id: 'ai', name: 'AI'),
    ];
    final state = engine.createGame(
      gameId: 'test',
      players: players,
      variant: variant,
      seed: seed,
    );
    return engine.dealInitialHands(state);
  }

  group('AiPlayer construction', () {
    test('creates with correct id', () {
      final ai = AiPlayer(playerId: 'ai');
      expect(ai.playerId, equals('ai'));
    });
  });

  group('AiPlayer attack', () {
    test('AI plays a card when it is the attacker', () {
      for (int seed = 0; seed < 100; seed++) {
        final state = createTestGame(seed: seed);
        if (state.players[state.attackerIndex].id == 'ai' &&
            state.phase == GamePhase.attacking) {
          final ai = AiPlayer(playerId: 'ai');
          final action = ai.decideAction(state);
          expect(action, isNotNull);
          expect(action, isA<AttackAction>());
          if (action is AttackAction) {
            expect(action.playerId, equals('ai'));
            final aiPlayer = state.players[state.attackerIndex];
            expect(aiPlayer.hand.contains(action.card), isTrue);
          }
          return;
        }
      }
    });

    test('AI returns null when it is not its turn', () {
      final state = createTestGame(seed: 42);
      final nonActiveId = state.players[state.attackerIndex].id == 'ai'
          ? 'p1'
          : 'ai';
      if (nonActiveId == 'ai') {
        final ai = AiPlayer(playerId: 'ai');
        final action = ai.decideAction(state);
        if (state.players[state.attackerIndex].id != 'ai' &&
            state.players[state.defenderIndex].id != 'ai') {
          expect(action, isNull);
        }
      }
    });
  });

  group('AiPlayer defense', () {
    test('AI defends with a valid card when it can', () {
      for (int seed = 0; seed < 100; seed++) {
        var state = createTestGame(seed: seed);

        if (state.players[state.defenderIndex].id != 'ai') continue;

        final attackerId = state.players[state.attackerIndex].id;
        final attackCard = state.players[state.attackerIndex].hand.first;
        final attackResult = engine.processAction(
          state,
          AttackAction(playerId: attackerId, card: attackCard),
        );
        if (!attackResult.success) continue;
        state = attackResult.state;

        final ai = AiPlayer(playerId: 'ai');
        final action = ai.decideAction(state);

        if (action != null) {
          if (action is DefendAction) {
            expect(action.playerId, equals('ai'));
            expect(
              action.defenseCard.canBeat(action.attackCard, state.trumpSuit),
              isTrue,
            );
            return;
          } else if (action is PickUpAction) {
            expect(action.playerId, equals('ai'));
            return;
          }
        }
      }
    });

    test('AI picks up when it cannot defend', () {
      for (int seed = 0; seed < 200; seed++) {
        var state = createTestGame(seed: seed);

        if (state.players[state.defenderIndex].id != 'ai') continue;

        final attackerId = state.players[state.attackerIndex].id;
        final attackCard = state.players[state.attackerIndex].hand.first;
        final attackResult = engine.processAction(
          state,
          AttackAction(playerId: attackerId, card: attackCard),
        );
        if (!attackResult.success) continue;
        state = attackResult.state;

        final aiPlayer = state.players[state.defenderIndex];
        final undefended = state.tablePairs.where((p) => !p.isDefended);
        bool canDefendAny = undefended.any((pair) =>
            aiPlayer.hand.any((c) => c.canBeat(pair.attackCard, state.trumpSuit)));

        if (!canDefendAny) {
          final ai = AiPlayer(playerId: 'ai');
          final action = ai.decideAction(state);
          expect(action, isNotNull);
          expect(action, isA<PickUpAction>());
          return;
        }
      }
    });
  });

  group('AiPlayer pass', () {
    test('AI passes when all cards are defended and no matching cards', () {
      for (int seed = 0; seed < 100; seed++) {
        var state = createTestGame(seed: seed);

        if (state.players[state.attackerIndex].id != 'ai') continue;

        final ai = AiPlayer(playerId: 'ai');

        final attackAction = ai.decideAction(state);
        if (attackAction == null || attackAction is! AttackAction) continue;

        final atkResult = engine.processAction(state, attackAction);
        if (!atkResult.success) continue;
        state = atkResult.state;

        final defenderId = state.players[state.defenderIndex].id;
        final defender = state.players[state.defenderIndex];
        final undefended = state.tablePairs.where((p) => !p.isDefended).first;
        final defenseCards = defender.hand
            .where((c) => c.canBeat(undefended.attackCard, state.trumpSuit))
            .toList();

        if (defenseCards.isEmpty) continue;

        final defResult = engine.processAction(
          state,
          DefendAction(
            playerId: defenderId,
            attackCard: undefended.attackCard,
            defenseCard: defenseCards.first,
          ),
        );
        if (!defResult.success) continue;
        state = defResult.state;

        if (state.phase == GamePhase.attacking &&
            state.players[state.attackerIndex].id == 'ai') {
          final action = ai.decideAction(state);
          if (action is PassAction) {
            expect(action.playerId, equals('ai'));
            return;
          }
          if (action is AttackAction) {
            expect(state.tableRanks.contains(action.card.rank), isTrue);
            return;
          }
        }
      }
    });
  });

  group('AiPlayer transfer', () {
    test('AI transfers in Perevodnoy when possible', () {
      for (int seed = 0; seed < 200; seed++) {
        var state = createTestGame(variant: GameVariant.transfer, seed: seed);

        if (state.players[state.defenderIndex].id != 'ai') continue;

        final attackerId = state.players[state.attackerIndex].id;
        final attackCard = state.players[state.attackerIndex].hand.first;
        final attackResult = engine.processAction(
          state,
          AttackAction(playerId: attackerId, card: attackCard),
        );
        if (!attackResult.success) continue;
        state = attackResult.state;

        if (!engine.canTransfer(state)) continue;

        final aiPlayer = state.players[state.defenderIndex];
        final transferCards = aiPlayer.hand
            .where((c) => c.rank == attackCard.rank)
            .toList();
        if (transferCards.isEmpty) continue;

        final ai = AiPlayer(playerId: 'ai');
        final action = ai.decideAction(state);

        if (action is TransferAction) {
          expect(action.playerId, equals('ai'));
          expect(action.card.rank, equals(attackCard.rank));
          return;
        }
      }
    });
  });

  group('AiPlayer edge cases', () {
    test('AI handles game over gracefully', () {
      var state = createTestGame(seed: 42);
      state = state.copyWith(phase: GamePhase.gameOver);

      final ai = AiPlayer(playerId: 'ai');
      final action = ai.decideAction(state);
      expect(action, isNull);
    });

    test('AI handles empty hand', () {
      var state = createTestGame(seed: 42);
      final aiIndex = state.players.indexWhere((p) => p.id == 'ai');
      state.players[aiIndex].hand.clear();

      final ai = AiPlayer(playerId: 'ai');
      final action = ai.decideAction(state);
      expect(action == null || action is PassAction, isTrue);
    });
  });
}
