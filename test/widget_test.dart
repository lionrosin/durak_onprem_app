import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/models/card.dart';
import 'package:durak_onprem_app/models/deck.dart';
import 'package:durak_onprem_app/models/game_state.dart';
import 'package:durak_onprem_app/models/player.dart';
import 'package:durak_onprem_app/engine/game_engine.dart';

void main() {
  group('PlayingCard', () {
    test('card can beat lower card of same suit', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      const lower = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      expect(card.canBeat(lower, Suit.spades), isTrue);
    });

    test('card cannot beat higher card of same suit', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      const higher = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      expect(card.canBeat(higher, Suit.spades), isFalse);
    });

    test('trump card beats non-trump card', () {
      const trump = PlayingCard(suit: Suit.spades, rank: Rank.six);
      const nonTrump = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(trump.canBeat(nonTrump, Suit.spades), isTrue);
    });

    test('non-trump cannot beat different suit non-trump', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      const other = PlayingCard(suit: Suit.clubs, rank: Rank.six);
      expect(card.canBeat(other, Suit.spades), isFalse);
    });
  });

  group('Deck', () {
    test('creates 36 cards', () {
      final deck = Deck.shuffled(seed: 42);
      expect(deck.remaining, equals(36));
      expect(deck.trumpCard, isNotNull);
      expect(deck.trumpSuit, isNotNull);
    });

    test('draw reduces count', () {
      final deck = Deck.shuffled(seed: 42);
      deck.draw();
      expect(deck.remaining, equals(35));
    });

    test('drawMultiple returns correct count', () {
      final deck = Deck.shuffled(seed: 42);
      final cards = deck.drawMultiple(6);
      expect(cards.length, equals(6));
      expect(deck.remaining, equals(30));
    });
  });

  group('GameEngine', () {
    const engine = GameEngine();

    GameState createTestGame({GameVariant variant = GameVariant.classic}) {
      final players = [
        Player(id: 'p1', name: 'Alice', isHost: true),
        Player(id: 'p2', name: 'Bob'),
      ];
      final state = engine.createGame(
        gameId: 'test',
        players: players,
        variant: variant,
        seed: 42,
      );
      return engine.dealInitialHands(state);
    }

    test('creates and deals game correctly', () {
      final state = createTestGame();
      expect(state.phase, equals(GamePhase.attacking));
      expect(state.players[0].cardCount, equals(6));
      expect(state.players[1].cardCount, equals(6));
      expect(state.deck.remaining, equals(24)); // 36 - 12
    });

    test('attacker can play first card (any card)', () {
      final state = createTestGame();
      final attacker = state.players[state.attackerIndex];
      final card = attacker.hand.first;
      final result = engine.processAction(
        state,
        AttackAction(playerId: attacker.id, card: card),
      );
      expect(result.success, isTrue);
      expect(result.state.tablePairs.length, equals(1));
      expect(result.state.phase, equals(GamePhase.defending));
    });

    test('defender cannot attack', () {
      final state = createTestGame();
      final defender = state.players[state.defenderIndex];
      final card = defender.hand.first;
      final result = engine.processAction(
        state,
        AttackAction(playerId: defender.id, card: card),
      );
      expect(result.success, isFalse);
    });

    test('defender can pick up', () {
      var state = createTestGame();
      final attacker = state.players[state.attackerIndex];
      final defender = state.players[state.defenderIndex];
      final attackCard = attacker.hand.first;

      // Attack first
      final attackResult = engine.processAction(
        state,
        AttackAction(playerId: attacker.id, card: attackCard),
      );
      state = attackResult.state;

      // Defender picks up
      final pickupResult = engine.processAction(
        state,
        PickUpAction(playerId: defender.id),
      );
      expect(pickupResult.success, isTrue);
      expect(pickupResult.state.tablePairs, isEmpty);
    });

    test('serialization roundtrip', () {
      final state = createTestGame();
      final json = state.toJson();
      final restored = GameState.fromJson(json);
      expect(restored.gameId, equals(state.gameId));
      expect(restored.players.length, equals(state.players.length));
      expect(restored.trumpSuit, equals(state.trumpSuit));
      expect(restored.phase, equals(state.phase));
    });
  });
}
