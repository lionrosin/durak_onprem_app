import 'package:flutter_test/flutter_test.dart';

import 'package:durak_onprem_app/models/game_state.dart';
import 'package:durak_onprem_app/models/player.dart';
import 'package:durak_onprem_app/engine/game_engine.dart';
import 'package:durak_onprem_app/engine/game_manager.dart';

void main() {
  const engine = GameEngine();

  GameManager createManager() {
    return GameManager();
  }

  List<Player> createPlayers() {
    return [
      Player(id: 'p1', name: 'Alice', isHost: true),
      Player(id: 'p2', name: 'Bob'),
    ];
  }

  void setupGame(GameManager manager) {
    manager.createGame(
      gameId: 'test',
      localPlayerId: 'p1',
      localPlayerName: 'Alice',
      players: createPlayers(),
    );
    manager.startGame();
  }

  group('GameManager lifecycle', () {
    test('initial state is null', () {
      final manager = createManager();
      expect(manager.state, isNull);
      manager.dispose();
    });

    test('createGame sets state', () {
      final manager = createManager();
      manager.createGame(
        gameId: 'test',
        localPlayerId: 'p1',
        localPlayerName: 'Alice',
        players: createPlayers(),
      );
      expect(manager.state, isNotNull);
      expect(manager.state!.phase, equals(GamePhase.dealing));
      manager.dispose();
    });

    test('startGame deals hands and sets attacking phase', () {
      final manager = createManager();
      setupGame(manager);
      expect(manager.state!.phase, equals(GamePhase.attacking));
      for (final p in manager.state!.players) {
        expect(p.cardCount, equals(6));
      }
      manager.dispose();
    });

    test('resetGame clears state', () {
      final manager = createManager();
      setupGame(manager);
      manager.resetGame();
      expect(manager.state, isNull);
      manager.dispose();
    });
  });

  group('GameManager actions', () {
    late GameManager manager;

    setUp(() {
      manager = createManager();
      setupGame(manager);
    });

    tearDown(() {
      manager.dispose();
    });

    test('attack via GameManager works', () {
      final state = manager.state!;
      if (state.attackerIndex == 0) {
        // p1 is attacker
        final card = state.players[0].hand.first;
        final result = manager.attack(card);
        expect(result, isTrue);
        expect(manager.state!.tablePairs.length, equals(1));
      }
    });
  });

  group('GameManager queries', () {
    late GameManager manager;

    setUp(() {
      manager = createManager();
      setupGame(manager);
    });

    tearDown(() {
      manager.dispose();
    });

    test('isMyTurn correct for attacker', () {
      final state = manager.state!;
      if (state.attackerIndex == 0) {
        expect(manager.isMyTurn, isTrue);
      } else {
        expect(manager.isMyTurn, isFalse);
      }
    });

    test('playableCards is non-empty when it is our turn', () {
      if (manager.isMyTurn) {
        expect(manager.playableCards, isNotEmpty);
      }
    });

    test('isAttacker/isDefender mutually exclusive for same player', () {
      expect(manager.isAttacker && manager.isDefender, isFalse);
    });

    test('localPlayer returns p1', () {
      expect(manager.localPlayer, isNotNull);
      expect(manager.localPlayer!.id, equals('p1'));
    });

    test('localPlayerId is set', () {
      expect(manager.localPlayerId, equals('p1'));
    });

    test('isGameActive is true after start', () {
      expect(manager.isGameActive, isTrue);
    });

    test('errorMessage is null initially', () {
      expect(manager.errorMessage, isNull);
    });
  });

  group('GameManager change notification', () {
    test('notifyListeners called on attack', () {
      final manager = createManager();
      setupGame(manager);

      int notifications = 0;
      manager.addListener(() => notifications++);

      final state = manager.state!;
      if (state.attackerIndex == 0) {
        final card = state.players[0].hand.first;
        manager.attack(card);
        expect(notifications, greaterThan(0));
      }

      manager.dispose();
    });
  });

  group('GameManager callbacks', () {
    test('onActionToSend called when local player acts', () {
      final manager = createManager();
      GameAction? sentAction;
      manager.onActionToSend = (action) {
        sentAction = action;
      };

      setupGame(manager);

      final state = manager.state!;
      if (state.attackerIndex == 0) {
        final card = state.players[0].hand.first;
        manager.attack(card);
        expect(sentAction, isNotNull);
        expect(sentAction, isA<AttackAction>());
      }

      manager.dispose();
    });

    test('onStateBroadcast called when action succeeds', () {
      final manager = createManager();
      GameState? broadcastState;
      manager.onStateBroadcast = (state) {
        broadcastState = state;
      };

      setupGame(manager);

      final state = manager.state!;
      if (state.attackerIndex == 0) {
        final card = state.players[0].hand.first;
        manager.attack(card);
        expect(broadcastState, isNotNull);
      }

      manager.dispose();
    });
  });

  group('GameManager processRemoteAction', () {
    test('processes valid remote action', () {
      final manager = createManager();
      setupGame(manager);

      final state = manager.state!;
      final attackerId = state.players[state.attackerIndex].id;
      final card = state.players[state.attackerIndex].hand.first;

      final result = manager.processRemoteAction(
        AttackAction(playerId: attackerId, card: card),
      );
      expect(result, isTrue);
      expect(manager.state!.tablePairs.length, equals(1));

      manager.dispose();
    });

    test('rejects invalid remote action', () {
      final manager = createManager();
      setupGame(manager);

      final state = manager.state!;
      final defenderId = state.players[state.defenderIndex].id;
      final card = state.players[state.defenderIndex].hand.first;

      // Defender trying to attack
      final result = manager.processRemoteAction(
        AttackAction(playerId: defenderId, card: card),
      );
      expect(result, isFalse);

      manager.dispose();
    });
  });

  group('GameManager applyNetworkState', () {
    test('replaces local state with network state', () {
      final manager = createManager();
      setupGame(manager);

      // Create a different state to simulate network update
      final networkState = engine.createGame(
        gameId: 'network-test',
        players: createPlayers(),
      );

      manager.applyNetworkState(engine.dealInitialHands(networkState));
      expect(manager.state!.gameId, equals('network-test'));

      manager.dispose();
    });
  });

  group('GameManager setLocalPlayerId', () {
    test('updates local player id', () {
      final manager = createManager();
      manager.setLocalPlayerId('p2');
      expect(manager.localPlayerId, equals('p2'));
      manager.dispose();
    });
  });
}
