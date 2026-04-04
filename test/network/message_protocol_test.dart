import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';
import 'package:durak_onprem_app/models/game_state.dart';
import 'package:durak_onprem_app/models/player.dart';
import 'package:durak_onprem_app/models/deck.dart';
import 'package:durak_onprem_app/network/message_protocol.dart';

void main() {
  group('NetworkMessage factory constructors', () {
    test('stateUpdate creates correct message', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
        sequenceNumber: 5,
      );
      final msg = NetworkMessage.stateUpdate(
        state: state,
        senderId: 'p1',
      );
      expect(msg.type, equals(MessageType.stateUpdate));
      expect(msg.senderId, equals('p1'));
      expect(msg.sequenceNumber, equals(5));
      expect(msg.payload, isNotNull);
    });

    test('playerAction creates correct message', () {
      const action = AttackAction(
        playerId: 'p1',
        card: PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      );
      final msg = NetworkMessage.playerAction(
        action: action,
        senderId: 'p1',
      );
      expect(msg.type, equals(MessageType.playerAction));
      expect(msg.senderId, equals('p1'));
      expect(msg.sequenceNumber, equals(0));
    });

    test('gameStart creates correct message', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
      );
      final msg = NetworkMessage.gameStart(
        initialState: state,
        senderId: 'p1',
      );
      expect(msg.type, equals(MessageType.gameStart));
    });

    test('lobbyUpdate creates correct message', () {
      final players = [
        Player(id: 'p1', name: 'Alice').toPublicJson(),
        Player(id: 'p2', name: 'Bob').toPublicJson(),
      ];
      final msg = NetworkMessage.lobbyUpdate(
        players: players,
        senderId: 'p1',
      );
      expect(msg.type, equals(MessageType.lobbyUpdate));
      expect(msg.payload['players'], isA<List>());
      expect((msg.payload['players'] as List).length, equals(2));
    });

    test('ping creates correct message', () {
      final msg = NetworkMessage.ping(senderId: 'p1');
      expect(msg.type, equals(MessageType.ping));
      expect(msg.payload['timestamp'], isNotNull);
      expect(msg.sequenceNumber, equals(0));
    });

    test('pong creates correct message', () {
      final msg = NetworkMessage.pong(senderId: 'p1');
      expect(msg.type, equals(MessageType.pong));
      expect(msg.payload['timestamp'], isNotNull);
    });

    test('playerLeft via direct construction', () {
      final msg = NetworkMessage(
        type: MessageType.playerLeft,
        payload: {'playerId': 'p2'},
        sequenceNumber: 0,
        senderId: 'p1',
      );
      expect(msg.type, equals(MessageType.playerLeft));
      expect(msg.payload['playerId'], equals('p2'));
    });
  });

  group('NetworkMessage serialization', () {
    test('stateUpdate round-trip', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
        sequenceNumber: 3,
      );
      final msg = NetworkMessage.stateUpdate(state: state, senderId: 'p1');
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);

      expect(restored.type, equals(MessageType.stateUpdate));
      expect(restored.senderId, equals('p1'));
      expect(restored.sequenceNumber, equals(3));
      expect(restored.payload, isNotNull);
    });

    test('playerAction round-trip', () {
      const action = DefendAction(
        playerId: 'p2',
        attackCard: PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: PlayingCard(suit: Suit.hearts, rank: Rank.king),
      );
      final msg = NetworkMessage.playerAction(action: action, senderId: 'p2');
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);

      expect(restored.type, equals(MessageType.playerAction));
      expect(restored.senderId, equals('p2'));
      final restoredAction = GameAction.fromJson(restored.payload);
      expect(restoredAction, isA<DefendAction>());
    });

    test('gameStart round-trip', () {
      final state = GameState(
        gameId: 'game-start',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.spades,
      );
      final msg = NetworkMessage.gameStart(initialState: state, senderId: 'p1');
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);

      expect(restored.type, equals(MessageType.gameStart));
      final restoredState = GameState.fromJson(restored.payload);
      expect(restoredState.gameId, equals('game-start'));
    });

    test('ping/pong round-trip', () {
      final ping = NetworkMessage.ping(senderId: 'p1');
      final serialized = ping.serialize();
      final restored = NetworkMessage.deserialize(serialized);
      expect(restored.type, equals(MessageType.ping));
      expect(restored.senderId, equals('p1'));
    });

    test('lobbyUpdate round-trip', () {
      final players = [
        {'id': 'p1', 'name': 'Alice', 'cardCount': 0},
        {'id': 'p2', 'name': 'Bob', 'cardCount': 0},
      ];
      final msg = NetworkMessage.lobbyUpdate(players: players, senderId: 'p1');
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);

      expect(restored.type, equals(MessageType.lobbyUpdate));
      expect(restored.payload['players'], isA<List>());
      expect((restored.payload['players'] as List).length, equals(2));
    });

    test('playerLeft round-trip', () {
      final msg = NetworkMessage(
        type: MessageType.playerLeft,
        payload: {'playerId': 'p3'},
        sequenceNumber: 0,
        senderId: 'p1',
      );
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);

      expect(restored.type, equals(MessageType.playerLeft));
      expect(restored.payload['playerId'], equals('p3'));
    });
  });

  group('NetworkMessage edge cases', () {
    test('deserialize handles empty payload gracefully', () {
      final msg = NetworkMessage(
        type: MessageType.ping,
        senderId: 'p1',
        payload: {},
        sequenceNumber: 0,
      );
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);
      expect(restored.type, equals(MessageType.ping));
    });

    test('deserialize with invalid JSON throws', () {
      expect(
        () => NetworkMessage.deserialize('not valid json{'),
        throwsA(anything),
      );
    });

    test('serialize produces valid JSON string', () {
      final msg = NetworkMessage.ping(senderId: 'p1');
      final serialized = msg.serialize();
      expect(serialized, isA<String>());
      expect(serialized.isNotEmpty, isTrue);
    });

    test('sequenceNumber defaults to 0 on deserialize when missing', () {
      // Manually construct JSON without 'seq'
      final msg = NetworkMessage(
        type: MessageType.ping,
        payload: {},
        sequenceNumber: 0,
        senderId: 'p1',
      );
      final serialized = msg.serialize();
      final restored = NetworkMessage.deserialize(serialized);
      expect(restored.sequenceNumber, equals(0));
    });
  });

  group('MessageType', () {
    test('has all expected values', () {
      expect(MessageType.values, containsAll([
        MessageType.stateUpdate,
        MessageType.playerAction,
        MessageType.gameStart,
        MessageType.lobbyUpdate,
        MessageType.playerLeft,
        MessageType.ping,
        MessageType.pong,
      ]));
    });

    test('has exactly 7 values', () {
      expect(MessageType.values.length, equals(7));
    });
  });
}
