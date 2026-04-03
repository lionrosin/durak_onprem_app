import 'dart:math';
import 'card.dart';

/// A 36-card Durak deck (6 through Ace, all four suits).
class Deck {
  final List<PlayingCard> _cards;
  PlayingCard? _trumpCard;

  Deck._(this._cards, this._trumpCard);

  /// Create a fresh, shuffled 36-card deck with a trump card revealed.
  factory Deck.shuffled({int? seed}) {
    final cards = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        cards.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    final random = seed != null ? Random(seed) : Random();
    cards.shuffle(random);

    // The bottom card determines the trump suit and is placed face-up
    // under the deck. It will be the last card drawn.
    final trumpCard = cards.first;
    // Move trump card to the bottom (index 0 = bottom)
    // Cards are drawn from the end (top of deck)
    return Deck._(cards, trumpCard);
  }

  /// Create a deck from existing state (for network sync).
  factory Deck.fromState({
    required List<PlayingCard> cards,
    PlayingCard? trumpCard,
  }) {
    return Deck._(List.from(cards), trumpCard);
  }

  /// The trump card (bottom of deck, face up).
  PlayingCard? get trumpCard => _trumpCard;

  /// The trump suit for this game.
  Suit? get trumpSuit => _trumpCard?.suit;

  /// Number of cards remaining.
  int get remaining => _cards.length;

  /// Whether the deck is empty.
  bool get isEmpty => _cards.isEmpty;

  /// Whether the deck is not empty.
  bool get isNotEmpty => _cards.isNotEmpty;

  /// Draw a card from the top of the deck.
  /// Returns null if the deck is empty.
  PlayingCard? draw() {
    if (_cards.isEmpty) return null;
    final card = _cards.removeLast();
    // If we just drew the trump card (last card), clear it
    if (_cards.isEmpty) {
      _trumpCard = null;
    }
    return card;
  }

  /// Draw multiple cards from the top of the deck.
  List<PlayingCard> drawMultiple(int count) {
    final drawn = <PlayingCard>[];
    for (int i = 0; i < count && _cards.isNotEmpty; i++) {
      drawn.add(draw()!);
    }
    return drawn;
  }

  Map<String, dynamic> toJson() => {
        'cards': _cards.map((c) => c.toJson()).toList(),
        'trumpCard': _trumpCard?.toJson(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List)
        .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
        .toList();
    final trumpCard = json['trumpCard'] != null
        ? PlayingCard.fromJson(json['trumpCard'] as Map<String, dynamic>)
        : null;
    return Deck._(cards, trumpCard);
  }
}
