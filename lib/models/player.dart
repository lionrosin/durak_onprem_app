import 'card.dart';

enum ConnectionStatus {
  connected,
  disconnected,
  reconnecting,
}

class Player {
  final String id;
  final String name;
  final List<PlayingCard> hand;
  final bool isHost;
  ConnectionStatus connectionStatus;

  Player({
    required this.id,
    required this.name,
    List<PlayingCard>? hand,
    this.isHost = false,
    this.connectionStatus = ConnectionStatus.connected,
  }) : hand = hand ?? [];

  /// Number of cards in hand.
  int get cardCount => hand.length;

  /// Whether this player has no cards left.
  bool get hasEmptyHand => hand.isEmpty;

  /// Add a card to this player's hand.
  void addCard(PlayingCard card) {
    hand.add(card);
  }

  /// Add multiple cards to this player's hand.
  void addCards(List<PlayingCard> cards) {
    hand.addAll(cards);
  }

  /// Remove a card from this player's hand. Returns true if found and removed.
  bool removeCard(PlayingCard card) {
    return hand.remove(card);
  }

  /// Sort hand by suit then rank, with trumps at the end.
  void sortHand(Suit trumpSuit) {
    hand.sort((a, b) {
      final aValue = a.effectiveValue(trumpSuit);
      final bValue = b.effectiveValue(trumpSuit);
      if (aValue != bValue) return aValue.compareTo(bValue);
      return a.suit.index.compareTo(b.suit.index);
    });
  }

  /// Create a copy of this player (for state snapshots).
  Player copyWith({
    String? id,
    String? name,
    List<PlayingCard>? hand,
    bool? isHost,
    ConnectionStatus? connectionStatus,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? List.from(this.hand),
      isHost: isHost ?? this.isHost,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hand': hand.map((c) => c.toJson()).toList(),
        'isHost': isHost,
        'connectionStatus': connectionStatus.name,
      };

  /// Serialize for network but hide hand contents (for opponents).
  Map<String, dynamic> toPublicJson() => {
        'id': id,
        'name': name,
        'cardCount': cardCount,
        'isHost': isHost,
        'connectionStatus': connectionStatus.name,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        hand: (json['hand'] as List?)
                ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        isHost: json['isHost'] as bool? ?? false,
        connectionStatus: ConnectionStatus.values.firstWhere(
          (s) => s.name == (json['connectionStatus'] as String?),
          orElse: () => ConnectionStatus.connected,
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Player && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Player($name, ${hand.length} cards)';
}
