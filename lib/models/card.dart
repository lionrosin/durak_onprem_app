// Playing card model for Durak card game.
// Uses a 36-card deck (ranks 6 through Ace).

enum Suit {
  hearts('♥', 'Hearts'),
  diamonds('♦', 'Diamonds'),
  clubs('♣', 'Clubs'),
  spades('♠', 'Spades');

  final String symbol;
  final String displayName;
  const Suit(this.symbol, this.displayName);

  bool get isRed => this == hearts || this == diamonds;

  factory Suit.fromJson(String json) => Suit.values.firstWhere((s) => s.name == json);
  String toJson() => name;
}

enum Rank {
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  final int value;
  final String symbol;
  const Rank(this.value, this.symbol);

  bool operator >(Rank other) => value > other.value;
  bool operator <(Rank other) => value < other.value;
  bool operator >=(Rank other) => value >= other.value;
  bool operator <=(Rank other) => value <= other.value;

  factory Rank.fromJson(String json) => Rank.values.firstWhere((r) => r.name == json);
  String toJson() => name;
}

class PlayingCard {
  final Suit suit;
  final Rank rank;

  const PlayingCard({required this.suit, required this.rank});

  /// Whether this card can beat [other] given [trumpSuit].
  /// Rules:
  /// - Same suit: must have higher rank
  /// - Trump beats non-trump
  /// - Trump vs trump: higher rank wins
  bool canBeat(PlayingCard other, Suit trumpSuit) {
    if (suit == other.suit) {
      return rank > other.rank;
    }
    if (suit == trumpSuit && other.suit != trumpSuit) {
      return true;
    }
    return false;
  }

  /// Effective value for sorting: trumps get +100 bonus
  int effectiveValue(Suit trumpSuit) {
    return rank.value + (suit == trumpSuit ? 100 : 0);
  }

  Map<String, dynamic> toJson() => {
        'suit': suit.toJson(),
        'rank': rank.toJson(),
      };

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
        suit: Suit.fromJson(json['suit'] as String),
        rank: Rank.fromJson(json['rank'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  @override
  String toString() => '${rank.symbol}${suit.symbol}';
}
