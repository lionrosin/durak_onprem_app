import 'card.dart';
import 'deck.dart';
import 'player.dart';

/// Game variant selection.
enum GameVariant {
  classic,
  transfer, // Perevodnoy Durak
}

const int maxPlayers = 4;
const int minPlayers = 2;
const int handSize = 6;

/// The current phase of the game.
enum GamePhase {
  /// Waiting for players to join.
  lobby,

  /// Cards are being dealt.
  dealing,

  /// Attacker is choosing cards to play.
  attacking,

  /// Defender is responding to attacks.
  defending,

  /// Players are drawing cards to refill hands.
  drawing,

  /// The game is over.
  gameOver,
}

/// A pair of attack and defense cards on the table.
class TablePair {
  final PlayingCard attackCard;
  PlayingCard? defenseCard;

  TablePair({required this.attackCard, this.defenseCard});

  bool get isDefended => defenseCard != null;

  Map<String, dynamic> toJson() => {
        'attackCard': attackCard.toJson(),
        'defenseCard': defenseCard?.toJson(),
      };

  factory TablePair.fromJson(Map<String, dynamic> json) => TablePair(
        attackCard:
            PlayingCard.fromJson(json['attackCard'] as Map<String, dynamic>),
        defenseCard: json['defenseCard'] != null
            ? PlayingCard.fromJson(
                json['defenseCard'] as Map<String, dynamic>)
            : null,
      );
}

/// Complete game state — serializable for network sync.
class GameState {
  final String gameId;
  final List<Player> players;
  final Deck deck;
  final Suit trumpSuit;
  final List<TablePair> tablePairs;
  final List<PlayingCard> discardPile;
  GamePhase phase;
  int attackerIndex;
  int defenderIndex;
  final GameVariant variant;

  /// Indices of players who have passed (cannot add more attacks).
  final Set<int> passedPlayers;

  /// Index of the player who is the "durak" (loser). -1 if game not over.
  int durakIndex;

  /// Players who have finished (emptied their hands after deck is empty).
  final Set<int> finishedPlayers;

  /// Sequence number for network ordering.
  int sequenceNumber;

  GameState({
    required this.gameId,
    required this.players,
    required this.deck,
    required this.trumpSuit,
    List<TablePair>? tablePairs,
    List<PlayingCard>? discardPile,
    this.phase = GamePhase.lobby,
    this.attackerIndex = 0,
    this.defenderIndex = 1,
    this.variant = GameVariant.classic,
    Set<int>? passedPlayers,
    this.durakIndex = -1,
    Set<int>? finishedPlayers,
    this.sequenceNumber = 0,
  })  : tablePairs = tablePairs ?? [],
        discardPile = discardPile ?? [],
        passedPlayers = passedPlayers ?? {},
        finishedPlayers = finishedPlayers ?? {};

  /// The current attacker.
  Player get attacker => players[attackerIndex];

  /// The current defender.
  Player get defender => players[defenderIndex];

  /// Number of active (non-finished) players.
  int get activePlayers =>
      players.length - finishedPlayers.length;

  /// Whether all attack cards on the table have been defended.
  bool get allDefended => tablePairs.every((p) => p.isDefended);

  /// Whether there are any cards on the table.
  bool get hasTableCards => tablePairs.isNotEmpty;

  /// All ranks currently on the table (for validating additional attacks).
  Set<Rank> get tableRanks {
    final ranks = <Rank>{};
    for (final pair in tablePairs) {
      ranks.add(pair.attackCard.rank);
      if (pair.defenseCard != null) {
        ranks.add(pair.defenseCard!.rank);
      }
    }
    return ranks;
  }

  /// Maximum number of attack cards allowed (6 or defender's hand size).
  int get maxAttackCards {
    final defenderCards = defender.cardCount;
    return defenderCards < 6 ? defenderCards : 6;
  }

  /// All cards currently on the table (flat list).
  List<PlayingCard> get allTableCards {
    final cards = <PlayingCard>[];
    for (final pair in tablePairs) {
      cards.add(pair.attackCard);
      if (pair.defenseCard != null) {
        cards.add(pair.defenseCard!);
      }
    }
    return cards;
  }

  /// Create a deep copy of the game state.
  GameState copyWith({
    String? gameId,
    List<Player>? players,
    Deck? deck,
    Suit? trumpSuit,
    List<TablePair>? tablePairs,
    List<PlayingCard>? discardPile,
    GamePhase? phase,
    int? attackerIndex,
    int? defenderIndex,
    GameVariant? variant,
    Set<int>? passedPlayers,
    int? durakIndex,
    Set<int>? finishedPlayers,
    int? sequenceNumber,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      players:
          players ?? this.players.map((p) => p.copyWith()).toList(),
      deck: deck ?? this.deck,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      tablePairs: tablePairs ?? List.from(this.tablePairs),
      discardPile: discardPile ?? List.from(this.discardPile),
      phase: phase ?? this.phase,
      attackerIndex: attackerIndex ?? this.attackerIndex,
      defenderIndex: defenderIndex ?? this.defenderIndex,
      variant: variant ?? this.variant,
      passedPlayers: passedPlayers ?? Set.from(this.passedPlayers),
      durakIndex: durakIndex ?? this.durakIndex,
      finishedPlayers:
          finishedPlayers ?? Set.from(this.finishedPlayers),
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'players': players.map((p) => p.toJson()).toList(),
        'deck': deck.toJson(),
        'trumpSuit': trumpSuit.toJson(),
        'tablePairs': tablePairs.map((p) => p.toJson()).toList(),
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
        'phase': phase.name,
        'attackerIndex': attackerIndex,
        'defenderIndex': defenderIndex,
        'variant': variant.name,
        'passedPlayers': passedPlayers.toList(),
        'durakIndex': durakIndex,
        'finishedPlayers': finishedPlayers.toList(),
        'sequenceNumber': sequenceNumber,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: json['gameId'] as String,
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      deck: Deck.fromJson(json['deck'] as Map<String, dynamic>),
      trumpSuit: Suit.fromJson(json['trumpSuit'] as String),
      tablePairs: (json['tablePairs'] as List)
          .map((p) => TablePair.fromJson(p as Map<String, dynamic>))
          .toList(),
      discardPile: (json['discardPile'] as List)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      phase: GamePhase.values.firstWhere((p) => p.name == json['phase']),
      attackerIndex: json['attackerIndex'] as int,
      defenderIndex: json['defenderIndex'] as int,
      variant: GameVariant.values.firstWhere(
        (v) => v.name == (json['variant'] as String?),
        orElse: () => GameVariant.classic,
      ),
      passedPlayers:
          (json['passedPlayers'] as List).map((e) => e as int).toSet(),
      durakIndex: json['durakIndex'] as int,
      finishedPlayers:
          (json['finishedPlayers'] as List).map((e) => e as int).toSet(),
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
    );
  }
}

/// Actions a player can take.
sealed class GameAction {
  final String playerId;
  const GameAction({required this.playerId});

  Map<String, dynamic> toJson();

  factory GameAction.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'attack' => AttackAction.fromJson(json),
      'defend' => DefendAction.fromJson(json),
      'pickUp' => PickUpAction.fromJson(json),
      'pass' => PassAction.fromJson(json),
      'transfer' => TransferAction.fromJson(json),
      _ => throw ArgumentError('Unknown action type: $type'),
    };
  }
}

/// Play an attack card onto the table.
class AttackAction extends GameAction {
  final PlayingCard card;
  const AttackAction({required super.playerId, required this.card});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'attack',
        'playerId': playerId,
        'card': card.toJson(),
      };

  factory AttackAction.fromJson(Map<String, dynamic> json) => AttackAction(
        playerId: json['playerId'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
      );
}

/// Defend against an attack card.
class DefendAction extends GameAction {
  final PlayingCard attackCard;
  final PlayingCard defenseCard;
  const DefendAction({
    required super.playerId,
    required this.attackCard,
    required this.defenseCard,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'defend',
        'playerId': playerId,
        'attackCard': attackCard.toJson(),
        'defenseCard': defenseCard.toJson(),
      };

  factory DefendAction.fromJson(Map<String, dynamic> json) => DefendAction(
        playerId: json['playerId'] as String,
        attackCard:
            PlayingCard.fromJson(json['attackCard'] as Map<String, dynamic>),
        defenseCard:
            PlayingCard.fromJson(json['defenseCard'] as Map<String, dynamic>),
      );
}

/// Defender picks up all table cards (gives up defending).
class PickUpAction extends GameAction {
  const PickUpAction({required super.playerId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pickUp',
        'playerId': playerId,
      };

  factory PickUpAction.fromJson(Map<String, dynamic> json) => PickUpAction(
        playerId: json['playerId'] as String,
      );
}

/// Attacker/other player passes (done adding attacks).
class PassAction extends GameAction {
  const PassAction({required super.playerId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pass',
        'playerId': playerId,
      };

  factory PassAction.fromJson(Map<String, dynamic> json) => PassAction(
        playerId: json['playerId'] as String,
      );
}

/// Transfer the attack to the next player (Perevodnoy variant only).
/// Defender plays a card of the same rank as the attack card,
/// passing the defense obligation to the next player.
class TransferAction extends GameAction {
  final PlayingCard card;
  const TransferAction({required super.playerId, required this.card});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'transfer',
        'playerId': playerId,
        'card': card.toJson(),
      };

  factory TransferAction.fromJson(Map<String, dynamic> json) => TransferAction(
        playerId: json['playerId'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
      );
}
