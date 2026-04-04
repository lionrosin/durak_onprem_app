import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';
import 'package:durak_onprem_app/models/deck.dart';

void main() {
  group('Deck.shuffled', () {
    test('creates 36 cards', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.remaining, equals(36));
    });

    test('has a trump card', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.trumpCard, isNotNull);
      expect(deck.trumpSuit, isNotNull);
    });

    test('trump suit matches trump card', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.trumpSuit, equals(deck.trumpCard!.suit));
    });

    test('contains all 36 unique cards', () {
      final deck = Deck.shuffled(seed: 42);
      final drawn = <PlayingCard>[];
      while (deck.isNotEmpty) {
        drawn.add(deck.draw()!);
      }
      expect(drawn.length, equals(36));
      expect(drawn.toSet().length, equals(36));
    });

    test('deterministic with same seed', () {
      final deck1 = Deck.shuffled(seed: 123);
      final deck2 = Deck.shuffled(seed: 123);
      final cards1 = deck1.drawMultiple(36);
      final cards2 = deck2.drawMultiple(36);
      for (int i = 0; i < 36; i++) {
        expect(cards1[i], equals(cards2[i]));
      }
    });

    test('different seeds produce different orders', () {
      final deck1 = Deck.shuffled(seed: 1);
      final deck2 = Deck.shuffled(seed: 2);
      final cards1 = deck1.drawMultiple(36);
      final cards2 = deck2.drawMultiple(36);
      // Very unlikely all 36 match with different seeds
      int matches = 0;
      for (int i = 0; i < 36; i++) {
        if (cards1[i] == cards2[i]) matches++;
      }
      expect(matches, lessThan(36));
    });
  });

  group('Deck.draw', () {
    test('reduces remaining count by 1', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.remaining, equals(36));
      deck.draw();
      expect(deck.remaining, equals(35));
    });

    test('returns non-null while cards remain', () {
      final deck = Deck.shuffled(seed: 42);
      for (int i = 0; i < 36; i++) {
        expect(deck.draw(), isNotNull);
      }
    });

    test('returns null when empty', () {
      final deck = Deck.shuffled(seed: 42);
      deck.drawMultiple(36);
      expect(deck.draw(), isNull);
    });

    test('clears trump card when last card drawn', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.trumpCard, isNotNull);
      deck.drawMultiple(35);
      expect(deck.trumpCard, isNotNull);
      deck.draw(); // Last card
      expect(deck.trumpCard, isNull);
    });
  });

  group('Deck.drawMultiple', () {
    test('returns correct number of cards', () {
      final deck = Deck.shuffled(seed: 42);
      final cards = deck.drawMultiple(6);
      expect(cards.length, equals(6));
      expect(deck.remaining, equals(30));
    });

    test('returns fewer cards when not enough remain', () {
      final deck = Deck.shuffled(seed: 42);
      deck.drawMultiple(34);
      final cards = deck.drawMultiple(5); // Only 2 remain
      expect(cards.length, equals(2));
      expect(deck.remaining, equals(0));
    });

    test('returns empty list from empty deck', () {
      final deck = Deck.shuffled(seed: 42);
      deck.drawMultiple(36);
      final cards = deck.drawMultiple(3);
      expect(cards, isEmpty);
    });
  });

  group('Deck.isEmpty/isNotEmpty', () {
    test('new deck is not empty', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.isEmpty, isFalse);
      expect(deck.isNotEmpty, isTrue);
    });

    test('empty deck reports empty', () {
      final deck = Deck.shuffled(seed: 42);
      deck.drawMultiple(36);
      expect(deck.isEmpty, isTrue);
      expect(deck.isNotEmpty, isFalse);
    });
  });

  group('Deck serialization', () {
    test('toJson/fromJson round-trip', () {
      final deck = Deck.shuffled(seed: 42);
      // Draw some cards to make state non-trivial
      deck.drawMultiple(5);
      final json = deck.toJson();
      final restored = Deck.fromJson(json);

      expect(restored.remaining, equals(deck.remaining));
      expect(restored.trumpCard, equals(deck.trumpCard));
      expect(restored.trumpSuit, equals(deck.trumpSuit));
    });

    test('toJson/fromJson preserves card order', () {
      final deck = Deck.shuffled(seed: 42);
      deck.drawMultiple(3);
      final json = deck.toJson();
      final restored = Deck.fromJson(json);

      // Draw remaining from both and compare
      final originalCards = <PlayingCard>[];
      final restoredCards = <PlayingCard>[];
      while (deck.isNotEmpty) {
        originalCards.add(deck.draw()!);
      }
      while (restored.isNotEmpty) {
        restoredCards.add(restored.draw()!);
      }
      expect(restoredCards.length, equals(originalCards.length));
      for (int i = 0; i < originalCards.length; i++) {
        expect(restoredCards[i], equals(originalCards[i]));
      }
    });

    test('toJson/fromJson with empty deck', () {
      final deck = Deck.shuffled(seed: 42);
      deck.drawMultiple(36);
      final json = deck.toJson();
      final restored = Deck.fromJson(json);
      expect(restored.remaining, equals(0));
      expect(restored.trumpCard, isNull);
    });
  });

  group('Deck.fromState', () {
    test('creates deck from existing cards', () {
      const cards = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.king),
      ];
      const trump = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      final deck = Deck.fromState(cards: cards, trumpCard: trump);

      expect(deck.remaining, equals(2));
      expect(deck.trumpCard, equals(trump));
      expect(deck.trumpSuit, equals(Suit.hearts));
    });

    test('creates deck with null trump', () {
      const cards = [
        PlayingCard(suit: Suit.clubs, rank: Rank.six),
      ];
      final deck = Deck.fromState(cards: cards);
      expect(deck.remaining, equals(1));
      expect(deck.trumpCard, isNull);
      expect(deck.trumpSuit, isNull);
    });
  });
}
