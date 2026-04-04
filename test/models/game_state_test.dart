import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';
import 'package:durak_onprem_app/models/deck.dart';
import 'package:durak_onprem_app/models/game_state.dart';
import 'package:durak_onprem_app/models/player.dart';

void main() {
  group('GameState construction', () {
    test('default values', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
      );
      expect(state.phase, equals(GamePhase.lobby));
      expect(state.attackerIndex, equals(0));
      expect(state.defenderIndex, equals(1));
      expect(state.variant, equals(GameVariant.classic));
      expect(state.tablePairs, isEmpty);
      expect(state.discardPile, isEmpty);
      expect(state.passedPlayers, isEmpty);
      expect(state.finishedPlayers, isEmpty);
      expect(state.durakIndex, equals(-1));
      expect(state.sequenceNumber, equals(0));
    });
  });

  group('GameState getters', () {
    late GameState state;

    setUp(() {
      state = GameState(
        gameId: 'test',
        players: [
          Player(id: 'p1', name: 'Alice'),
          Player(id: 'p2', name: 'Bob'),
          Player(id: 'p3', name: 'Charlie'),
        ],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
        attackerIndex: 0,
        defenderIndex: 1,
      );
    });

    test('attacker returns correct player', () {
      expect(state.attacker.id, equals('p1'));
    });

    test('defender returns correct player', () {
      expect(state.defender.id, equals('p2'));
    });

    test('activePlayers count excludes finished', () {
      expect(state.activePlayers, equals(3));
      state.finishedPlayers.add(0);
      expect(state.activePlayers, equals(2));
    });

    test('allDefended when no table cards', () {
      expect(state.allDefended, isTrue);
    });

    test('allDefended with defended pairs', () {
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: const PlayingCard(suit: Suit.hearts, rank: Rank.seven),
      ));
      expect(state.allDefended, isTrue);
    });

    test('allDefended is false with undefended pair', () {
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
      ));
      expect(state.allDefended, isFalse);
    });

    test('hasTableCards', () {
      expect(state.hasTableCards, isFalse);
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
      ));
      expect(state.hasTableCards, isTrue);
    });

    test('tableRanks collects all ranks on table', () {
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: const PlayingCard(suit: Suit.spades, rank: Rank.king),
      ));
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.clubs, rank: Rank.six),
      ));
      expect(state.tableRanks, containsAll([Rank.six, Rank.king]));
      expect(state.tableRanks.length, equals(2)); // six is deduplicated
    });

    test('maxAttackCards capped at 6', () {
      state.players[1].addCards(List.generate(
        10,
        (i) => PlayingCard(
          suit: Suit.values[i % 4],
          rank: Rank.values[i % 9],
        ),
      ));
      expect(state.maxAttackCards, equals(6));
    });

    test('maxAttackCards limited by defender hand size', () {
      state.players[1].addCards(const [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ]);
      expect(state.maxAttackCards, equals(2));
    });

    test('allTableCards returns flat list', () {
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: const PlayingCard(suit: Suit.hearts, rank: Rank.seven),
      ));
      state.tablePairs.add(TablePair(
        attackCard: const PlayingCard(suit: Suit.clubs, rank: Rank.six),
      ));
      expect(state.allTableCards.length, equals(3));
    });
  });

  group('GameState copyWith', () {
    test('produces independent copy', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
        phase: GamePhase.attacking,
      );

      final copy = state.copyWith(phase: GamePhase.defending);
      expect(copy.phase, equals(GamePhase.defending));
      expect(state.phase, equals(GamePhase.attacking)); // Unchanged
    });

    test('deep copies players list', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
      );
      state.players[0].addCard(
        const PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      );

      final copy = state.copyWith();
      copy.players[0].addCard(
        const PlayingCard(suit: Suit.spades, rank: Rank.king),
      );

      expect(state.players[0].cardCount, equals(1));
      expect(copy.players[0].cardCount, equals(2));
    });

    test('deep copies passedPlayers set', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
        passedPlayers: {0},
      );

      final copy = state.copyWith();
      copy.passedPlayers.add(1);

      expect(state.passedPlayers.length, equals(1));
      expect(copy.passedPlayers.length, equals(2));
    });
  });

  group('GameState serialization', () {
    test('toJson/fromJson round-trip', () {
      final state = GameState(
        gameId: 'game-123',
        players: [
          Player(id: 'p1', name: 'Alice', isHost: true),
          Player(id: 'p2', name: 'Bob'),
        ],
        deck: Deck.shuffled(seed: 42),
        trumpSuit: Suit.spades,
        phase: GamePhase.attacking,
        attackerIndex: 0,
        defenderIndex: 1,
        variant: GameVariant.transfer,
        passedPlayers: {0},
        durakIndex: -1,
        finishedPlayers: {},
        sequenceNumber: 5,
      );

      final json = state.toJson();
      final restored = GameState.fromJson(json);

      expect(restored.gameId, equals('game-123'));
      expect(restored.players.length, equals(2));
      expect(restored.players[0].name, equals('Alice'));
      expect(restored.trumpSuit, equals(Suit.spades));
      expect(restored.phase, equals(GamePhase.attacking));
      expect(restored.attackerIndex, equals(0));
      expect(restored.defenderIndex, equals(1));
      expect(restored.variant, equals(GameVariant.transfer));
      expect(restored.passedPlayers, contains(0));
      expect(restored.durakIndex, equals(-1));
      expect(restored.sequenceNumber, equals(5));
    });

    test('fromJson with missing variant defaults to classic', () {
      final state = GameState(
        gameId: 'test',
        players: [Player(id: 'p1', name: 'A'), Player(id: 'p2', name: 'B')],
        deck: Deck.shuffled(seed: 1),
        trumpSuit: Suit.hearts,
      );
      final json = state.toJson();
      json.remove('variant');
      final restored = GameState.fromJson(json);
      expect(restored.variant, equals(GameVariant.classic));
    });
  });

  group('TablePair', () {
    test('isDefended when defenseCard is set', () {
      final pair = TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: const PlayingCard(suit: Suit.hearts, rank: Rank.seven),
      );
      expect(pair.isDefended, isTrue);
    });

    test('not defended when defenseCard is null', () {
      final pair = TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
      );
      expect(pair.isDefended, isFalse);
    });

    test('toJson/fromJson round-trip without defense', () {
      final pair = TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
      );
      final json = pair.toJson();
      final restored = TablePair.fromJson(json);
      expect(restored.attackCard, equals(pair.attackCard));
      expect(restored.defenseCard, isNull);
    });

    test('toJson/fromJson round-trip with defense', () {
      final pair = TablePair(
        attackCard: const PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: const PlayingCard(suit: Suit.hearts, rank: Rank.seven),
      );
      final json = pair.toJson();
      final restored = TablePair.fromJson(json);
      expect(restored.attackCard, equals(pair.attackCard));
      expect(restored.defenseCard, equals(pair.defenseCard));
    });
  });

  group('GameAction serialization', () {
    test('AttackAction round-trip', () {
      const action = AttackAction(
        playerId: 'p1',
        card: PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      );
      final json = action.toJson();
      final restored = GameAction.fromJson(json);
      expect(restored, isA<AttackAction>());
      final attack = restored as AttackAction;
      expect(attack.playerId, equals('p1'));
      expect(attack.card.rank, equals(Rank.ace));
    });

    test('DefendAction round-trip', () {
      const action = DefendAction(
        playerId: 'p1',
        attackCard: PlayingCard(suit: Suit.hearts, rank: Rank.six),
        defenseCard: PlayingCard(suit: Suit.hearts, rank: Rank.king),
      );
      final json = action.toJson();
      final restored = GameAction.fromJson(json);
      expect(restored, isA<DefendAction>());
      final defend = restored as DefendAction;
      expect(defend.attackCard.rank, equals(Rank.six));
      expect(defend.defenseCard.rank, equals(Rank.king));
    });

    test('PickUpAction round-trip', () {
      const action = PickUpAction(playerId: 'p1');
      final json = action.toJson();
      final restored = GameAction.fromJson(json);
      expect(restored, isA<PickUpAction>());
      expect(restored.playerId, equals('p1'));
    });

    test('PassAction round-trip', () {
      const action = PassAction(playerId: 'p1');
      final json = action.toJson();
      final restored = GameAction.fromJson(json);
      expect(restored, isA<PassAction>());
      expect(restored.playerId, equals('p1'));
    });

    test('TransferAction round-trip', () {
      const action = TransferAction(
        playerId: 'p1',
        card: PlayingCard(suit: Suit.clubs, rank: Rank.seven),
      );
      final json = action.toJson();
      final restored = GameAction.fromJson(json);
      expect(restored, isA<TransferAction>());
      final transfer = restored as TransferAction;
      expect(transfer.card.rank, equals(Rank.seven));
    });

    test('fromJson throws on unknown type', () {
      expect(
        () => GameAction.fromJson({'type': 'unknown', 'playerId': 'p1'}),
        throwsArgumentError,
      );
    });
  });

  group('GamePhase', () {
    test('has all expected values', () {
      expect(GamePhase.values, containsAll([
        GamePhase.lobby,
        GamePhase.dealing,
        GamePhase.attacking,
        GamePhase.defending,
        GamePhase.drawing,
        GamePhase.gameOver,
      ]));
    });
  });

  group('GameVariant', () {
    test('has classic and transfer', () {
      expect(GameVariant.values, containsAll([
        GameVariant.classic,
        GameVariant.transfer,
      ]));
    });
  });

  group('Constants', () {
    test('maxPlayers is 4', () {
      expect(maxPlayers, equals(4));
    });

    test('minPlayers is 2', () {
      expect(minPlayers, equals(2));
    });

    test('handSize is 6', () {
      expect(handSize, equals(6));
    });
  });
}
