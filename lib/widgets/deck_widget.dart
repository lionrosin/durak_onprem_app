import 'package:flutter/material.dart';
import '../models/card.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Draw pile with trump card shown beneath and remaining count.
class DeckWidget extends StatelessWidget {
  final int remainingCards;
  final PlayingCard? trumpCard;
  final Suit? trumpSuit;

  const DeckWidget({
    super.key,
    required this.remainingCards,
    this.trumpCard,
    this.trumpSuit,
  });

  @override
  Widget build(BuildContext context) {
    if (remainingCards == 0 && trumpCard == null) {
      return _buildEmptyDeck();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trump suit badge
        if (trumpSuit != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trump ',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  trumpSuit!.symbol,
                  style: TextStyle(
                    color: trumpSuit!.isRed
                        ? AppTheme.suitRed
                        : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        // Deck stack
        SizedBox(
          width: PlayingCardWidget.normalWidth + 20,
          height: PlayingCardWidget.normalHeight + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Trump card (rotated 90°, shown underneath)
              if (trumpCard != null && remainingCards > 1)
                Positioned(
                  left: 8,
                  top: 4,
                  child: Transform.rotate(
                    angle: 1.5708, // 90 degrees
                    child: PlayingCardWidget(
                      card: trumpCard!,
                      isFaceUp: true,
                      isSmall: true,
                    ),
                  ),
                ),

              // Stacked card backs (visual depth)
              if (remainingCards > 2)
                Positioned(
                  left: 4,
                  top: 2,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: Suit.spades, rank: Rank.ace),
                    isFaceUp: false,
                  ),
                ),
              if (remainingCards > 1)
                Positioned(
                  left: 2,
                  top: 1,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: Suit.spades, rank: Rank.ace),
                    isFaceUp: false,
                  ),
                ),
              if (remainingCards > 0)
                PlayingCardWidget(
                  card: const PlayingCard(suit: Suit.spades, rank: Rank.ace),
                  isFaceUp: false,
                ),
            ],
          ),
        ),

        // Remaining count
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$remainingCards',
              style: const TextStyle(
                color: AppTheme.textGold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDeck() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trumpSuit != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withAlpha(40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trump ',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withAlpha(150),
                    fontSize: 11,
                  ),
                ),
                Text(
                  trumpSuit!.symbol,
                  style: TextStyle(
                    color: trumpSuit!.isRed
                        ? AppTheme.suitRed.withAlpha(150)
                        : AppTheme.textPrimary.withAlpha(150),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: PlayingCardWidget.normalWidth,
          height: PlayingCardWidget.normalHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.textSecondary.withAlpha(30),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_outline,
              color: AppTheme.textSecondary,
              size: 28,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Empty',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
