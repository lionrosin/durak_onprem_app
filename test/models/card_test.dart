import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';

void main() {
  group('Suit', () {
    test('has 4 values', () {
      expect(Suit.values.length, equals(4));
    });

    test('isRed correctly identifies red suits', () {
      expect(Suit.hearts.isRed, isTrue);
      expect(Suit.diamonds.isRed, isTrue);
      expect(Suit.clubs.isRed, isFalse);
      expect(Suit.spades.isRed, isFalse);
    });

    test('has correct symbols', () {
      expect(Suit.hearts.symbol, equals('♥'));
      expect(Suit.diamonds.symbol, equals('♦'));
      expect(Suit.clubs.symbol, equals('♣'));
      expect(Suit.spades.symbol, equals('♠'));
    });

    test('has correct display names', () {
      expect(Suit.hearts.displayName, equals('Hearts'));
      expect(Suit.diamonds.displayName, equals('Diamonds'));
      expect(Suit.clubs.displayName, equals('Clubs'));
      expect(Suit.spades.displayName, equals('Spades'));
    });

    test('fromJson round-trip for all values', () {
      for (final suit in Suit.values) {
        final json = suit.toJson();
        final restored = Suit.fromJson(json);
        expect(restored, equals(suit));
      }
    });

    test('fromJson throws on invalid value', () {
      expect(() => Suit.fromJson('invalid'), throwsStateError);
    });
  });

  group('Rank', () {
    test('has 9 values (6 through Ace)', () {
      expect(Rank.values.length, equals(9));
    });

    test('values are ordered correctly', () {
      expect(Rank.six.value, equals(6));
      expect(Rank.seven.value, equals(7));
      expect(Rank.eight.value, equals(8));
      expect(Rank.nine.value, equals(9));
      expect(Rank.ten.value, equals(10));
      expect(Rank.jack.value, equals(11));
      expect(Rank.queen.value, equals(12));
      expect(Rank.king.value, equals(13));
      expect(Rank.ace.value, equals(14));
    });

    test('comparison operators work correctly', () {
      expect(Rank.ace > Rank.king, isTrue);
      expect(Rank.six < Rank.seven, isTrue);
      expect(Rank.queen >= Rank.queen, isTrue);
      expect(Rank.jack <= Rank.king, isTrue);
      expect(Rank.six > Rank.ace, isFalse);
    });

    test('has correct symbols', () {
      expect(Rank.six.symbol, equals('6'));
      expect(Rank.jack.symbol, equals('J'));
      expect(Rank.queen.symbol, equals('Q'));
      expect(Rank.king.symbol, equals('K'));
      expect(Rank.ace.symbol, equals('A'));
    });

    test('fromJson round-trip for all values', () {
      for (final rank in Rank.values) {
        final json = rank.toJson();
        final restored = Rank.fromJson(json);
        expect(restored, equals(rank));
      }
    });

    test('fromJson throws on invalid value', () {
      expect(() => Rank.fromJson('invalid'), throwsStateError);
    });
  });

  group('PlayingCard', () {
    test('canBeat - same suit, higher rank', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      const lower = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      expect(card.canBeat(lower, Suit.spades), isTrue);
    });

    test('canBeat - same suit, lower rank fails', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      const higher = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      expect(card.canBeat(higher, Suit.spades), isFalse);
    });

    test('canBeat - same suit, equal rank fails', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      const same = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      expect(card.canBeat(same, Suit.spades), isFalse);
    });

    test('canBeat - trump beats non-trump regardless of rank', () {
      const trump = PlayingCard(suit: Suit.spades, rank: Rank.six);
      const nonTrump = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(trump.canBeat(nonTrump, Suit.spades), isTrue);
    });

    test('canBeat - non-trump cannot beat different suit', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      const other = PlayingCard(suit: Suit.clubs, rank: Rank.six);
      expect(card.canBeat(other, Suit.spades), isFalse);
    });

    test('canBeat - trump vs trump, higher wins', () {
      const higherTrump = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const lowerTrump = PlayingCard(suit: Suit.spades, rank: Rank.six);
      expect(higherTrump.canBeat(lowerTrump, Suit.spades), isTrue);
      expect(lowerTrump.canBeat(higherTrump, Suit.spades), isFalse);
    });

    test('canBeat - non-trump cannot beat trump', () {
      const nonTrump = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      const trump = PlayingCard(suit: Suit.spades, rank: Rank.six);
      expect(nonTrump.canBeat(trump, Suit.spades), isFalse);
    });

    test('effectiveValue - non-trump card', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      expect(card.effectiveValue(Suit.spades), equals(13));
    });

    test('effectiveValue - trump card gets +100 bonus', () {
      const card = PlayingCard(suit: Suit.spades, rank: Rank.six);
      expect(card.effectiveValue(Suit.spades), equals(106));
    });

    test('toJson/fromJson round-trip', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.queen);
      final json = card.toJson();
      final restored = PlayingCard.fromJson(json);
      expect(restored, equals(card));
      expect(restored.suit, equals(Suit.hearts));
      expect(restored.rank, equals(Rank.queen));
    });

    test('equality - same suit and rank are equal', () {
      const a = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      const b = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality - different cards are not equal', () {
      const a = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      const b = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      const c = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });

    test('toString produces readable format', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(card.toString(), equals('A♥'));
    });

    test('toJson produces correct map', () {
      const card = PlayingCard(suit: Suit.clubs, rank: Rank.seven);
      final json = card.toJson();
      expect(json['suit'], equals('clubs'));
      expect(json['rank'], equals('seven'));
    });
  });
}
