import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';
import 'package:durak_onprem_app/models/player.dart';

void main() {
  group('Player construction', () {
    test('default values', () {
      final player = Player(id: 'p1', name: 'Alice');
      expect(player.id, equals('p1'));
      expect(player.name, equals('Alice'));
      expect(player.hand, isEmpty);
      expect(player.isHost, isFalse);
      expect(player.connectionStatus, equals(ConnectionStatus.connected));
    });

    test('with initial hand', () {
      const cards = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ];
      final player = Player(id: 'p1', name: 'Alice', hand: cards);
      expect(player.cardCount, equals(2));
    });

    test('host flag', () {
      final player = Player(id: 'p1', name: 'Host', isHost: true);
      expect(player.isHost, isTrue);
    });
  });

  group('Player card operations', () {
    test('addCard increases hand size', () {
      final player = Player(id: 'p1', name: 'Alice');
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      player.addCard(card);
      expect(player.cardCount, equals(1));
      expect(player.hand.contains(card), isTrue);
    });

    test('addCards adds multiple cards', () {
      final player = Player(id: 'p1', name: 'Alice');
      const cards = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
        PlayingCard(suit: Suit.clubs, rank: Rank.queen),
      ];
      player.addCards(cards);
      expect(player.cardCount, equals(3));
    });

    test('removeCard removes existing card', () {
      final player = Player(id: 'p1', name: 'Alice');
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      player.addCard(card);
      final removed = player.removeCard(card);
      expect(removed, isTrue);
      expect(player.cardCount, equals(0));
    });

    test('removeCard returns false for non-existing card', () {
      final player = Player(id: 'p1', name: 'Alice');
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      final removed = player.removeCard(card);
      expect(removed, isFalse);
    });

    test('hasEmptyHand is true when hand is empty', () {
      final player = Player(id: 'p1', name: 'Alice');
      expect(player.hasEmptyHand, isTrue);
    });

    test('hasEmptyHand is false when hand has cards', () {
      final player = Player(id: 'p1', name: 'Alice');
      player.addCard(const PlayingCard(suit: Suit.hearts, rank: Rank.ace));
      expect(player.hasEmptyHand, isFalse);
    });
  });

  group('Player sortHand', () {
    test('sorts non-trump cards by effective value', () {
      final player = Player(id: 'p1', name: 'Alice');
      player.addCards(const [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.hearts, rank: Rank.six),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ]);
      player.sortHand(Suit.spades); // Hearts are not trump
      expect(player.hand[0].rank, equals(Rank.six));
      expect(player.hand[1].rank, equals(Rank.king));
      expect(player.hand[2].rank, equals(Rank.ace));
    });

    test('sorts trump cards after non-trump', () {
      final player = Player(id: 'p1', name: 'Alice');
      player.addCards(const [
        PlayingCard(suit: Suit.spades, rank: Rank.six), // Trump
        PlayingCard(suit: Suit.hearts, rank: Rank.ace), // Non-trump
      ]);
      player.sortHand(Suit.spades);
      expect(player.hand[0].suit, equals(Suit.hearts)); // Non-trump first
      expect(player.hand[1].suit, equals(Suit.spades)); // Trump last
    });
  });

  group('Player copyWith', () {
    test('produces independent copy', () {
      final player = Player(id: 'p1', name: 'Alice');
      player.addCard(const PlayingCard(suit: Suit.hearts, rank: Rank.ace));

      final copy = player.copyWith();
      copy.addCard(const PlayingCard(suit: Suit.spades, rank: Rank.king));

      expect(player.cardCount, equals(1));
      expect(copy.cardCount, equals(2));
    });

    test('overrides specified fields', () {
      final player = Player(id: 'p1', name: 'Alice', isHost: false);
      final copy = player.copyWith(name: 'Bob', isHost: true);
      expect(copy.name, equals('Bob'));
      expect(copy.isHost, isTrue);
      expect(copy.id, equals('p1')); // Unchanged
    });
  });

  group('Player serialization', () {
    test('toJson/fromJson round-trip', () {
      final player = Player(id: 'p1', name: 'Alice', isHost: true);
      player.addCards(const [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ]);

      final json = player.toJson();
      final restored = Player.fromJson(json);

      expect(restored.id, equals('p1'));
      expect(restored.name, equals('Alice'));
      expect(restored.isHost, isTrue);
      expect(restored.cardCount, equals(2));
      expect(restored.hand[0], equals(player.hand[0]));
    });

    test('toPublicJson hides hand contents', () {
      final player = Player(id: 'p1', name: 'Alice');
      player.addCards(const [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ]);

      final json = player.toPublicJson();
      expect(json['id'], equals('p1'));
      expect(json['name'], equals('Alice'));
      expect(json['cardCount'], equals(2));
      expect(json.containsKey('hand'), isFalse);
    });

    test('fromJson with missing hand creates empty hand', () {
      final json = {
        'id': 'p1',
        'name': 'Alice',
        'isHost': false,
      };
      final player = Player.fromJson(json);
      expect(player.hand, isEmpty);
    });

    test('fromJson with missing connectionStatus defaults to connected', () {
      final json = {
        'id': 'p1',
        'name': 'Alice',
      };
      final player = Player.fromJson(json);
      expect(player.connectionStatus, equals(ConnectionStatus.connected));
    });
  });

  group('Player equality', () {
    test('players with same ID are equal', () {
      final a = Player(id: 'p1', name: 'Alice');
      final b = Player(id: 'p1', name: 'Bob');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('players with different IDs are not equal', () {
      final a = Player(id: 'p1', name: 'Alice');
      final b = Player(id: 'p2', name: 'Alice');
      expect(a, isNot(equals(b)));
    });
  });

  group('Player toString', () {
    test('produces readable format', () {
      final player = Player(id: 'p1', name: 'Alice');
      player.addCards(const [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      ]);
      expect(player.toString(), equals('Player(Alice, 1 cards)'));
    });
  });

  group('ConnectionStatus', () {
    test('has 3 values', () {
      expect(ConnectionStatus.values.length, equals(3));
      expect(ConnectionStatus.values,
          contains(ConnectionStatus.connected));
      expect(ConnectionStatus.values,
          contains(ConnectionStatus.disconnected));
      expect(ConnectionStatus.values,
          contains(ConnectionStatus.reconnecting));
    });
  });
}
