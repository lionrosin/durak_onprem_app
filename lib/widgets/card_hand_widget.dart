import 'package:flutter/material.dart';
import '../models/card.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Hand of cards displayed grouped by suit color (red/black),
/// with fan layout, staggered entry animations, and tap interaction.
class CardHandWidget extends StatefulWidget {
  final List<PlayingCard> cards;
  final Set<PlayingCard> playableCards;
  final PlayingCard? selectedCard;
  final ValueChanged<PlayingCard>? onCardTap;
  final bool enabled;
  final Suit? trumpSuit;

  const CardHandWidget({
    super.key,
    required this.cards,
    this.playableCards = const {},
    this.selectedCard,
    this.onCardTap,
    this.enabled = true,
    this.trumpSuit,
  });

  @override
  State<CardHandWidget> createState() => _CardHandWidgetState();
}

class _CardHandWidgetState extends State<CardHandWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Group and sort cards: trumps last, within each group sort by rank.
  List<_CardGroup> _groupCards() {
    final trumpSuit = widget.trumpSuit;
    final groups = <_CardGroup>[];

    // Separate into suit groups
    final bySuit = <Suit, List<PlayingCard>>{};
    for (final card in widget.cards) {
      bySuit.putIfAbsent(card.suit, () => []).add(card);
    }

    // Sort each suit group by rank
    for (final entry in bySuit.entries) {
      entry.value.sort((a, b) => a.rank.value.compareTo(b.rank.value));
    }

    // Order groups: non-trump first (alternating red/black for visual variety),
    // then trump suit last
    final suitOrder = <Suit>[];
    final nonTrumps = Suit.values.where((s) => s != trumpSuit).toList();
    // Sort non-trumps: alternate red/black
    final reds = nonTrumps.where((s) => s.isRed).toList();
    final blacks = nonTrumps.where((s) => !s.isRed).toList();
    while (reds.isNotEmpty || blacks.isNotEmpty) {
      if (blacks.isNotEmpty) suitOrder.add(blacks.removeAt(0));
      if (reds.isNotEmpty) suitOrder.add(reds.removeAt(0));
    }
    if (trumpSuit != null) suitOrder.add(trumpSuit);

    for (final suit in suitOrder) {
      if (bySuit.containsKey(suit) && bySuit[suit]!.isNotEmpty) {
        groups.add(_CardGroup(
          suit: suit,
          cards: bySuit[suit]!,
          isTrump: suit == trumpSuit,
        ));
      }
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return SizedBox(
        height: PlayingCardWidget.normalHeight + 40,
        child: Center(
          child: Text(
            'No cards',
            style: TextStyle(
              color: AppTheme.textSecondary.withAlpha(120),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final groups = _groupCards();

    return SizedBox(
      height: PlayingCardWidget.normalHeight + 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suit group labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: groups.map((g) => _buildGroupLabel(g)).toList(),
            ),
          ),
          const SizedBox(height: 4),
          // Cards
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildGroupedHand(groups, constraints.maxWidth);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(_CardGroup group) {
    final color = group.suit.isRed ? AppTheme.suitRed : AppTheme.textPrimary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: group.isTrump
            ? AppTheme.gold.withAlpha(25)
            : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: group.isTrump
            ? Border.all(color: AppTheme.gold.withAlpha(60), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            group.suit.symbol,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '${group.cards.length}',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (group.isTrump) ...[
            const SizedBox(width: 2),
            Icon(Icons.star, color: AppTheme.gold, size: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupedHand(List<_CardGroup> groups, double maxWidth) {
    // Flatten cards with group info for layout
    final allCards = <_LayoutCard>[];
    int globalIndex = 0;
    for (int g = 0; g < groups.length; g++) {
      for (int i = 0; i < groups[g].cards.length; i++) {
        allCards.add(_LayoutCard(
          card: groups[g].cards[i],
          groupIndex: g,
          isFirstInGroup: i == 0 && g > 0,
          globalIndex: globalIndex++,
        ));
      }
    }

    final cardCount = allCards.length;
    final cardWidth = PlayingCardWidget.normalWidth;
    final groupGap = 12.0; // Extra gap between suit groups
    final groupCount = groups.length;

    // Calculate overlap
    final totalGaps = (groupCount - 1) * groupGap;
    final availableWidth = maxWidth - 40 - totalGaps; // padding
    final totalCardWidth = cardWidth * cardCount;
    final overlap = totalCardWidth > availableWidth
        ? (totalCardWidth - availableWidth) / (cardCount - 1).clamp(1, 100)
        : 0.0;
    final effectiveCardWidth = cardWidth - overlap;

    // Calculate total hand width
    double handWidth = 0;
    for (final lc in allCards) {
      handWidth += effectiveCardWidth;
      if (lc.isFirstInGroup) handWidth += groupGap;
    }
    handWidth = handWidth - effectiveCardWidth + cardWidth; // last card full width
    final startX = (maxWidth - handWidth) / 2;

    // Fan angle
    final maxAngle = (cardCount > 1) ? 0.03 : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(cardCount, (index) {
        final lc = allCards[index];
        final card = lc.card;
        final isPlayable = widget.playableCards.contains(card);
        final isSelected = widget.selectedCard == card;

        // Calculate x position with group gaps
        double xPos = startX;
        for (int i = 0; i < index; i++) {
          xPos += effectiveCardWidth;
          if (allCards[i + 1 < allCards.length ? i + 1 : i].isFirstInGroup &&
              i + 1 == index) {
            // This is handled below
          }
        }
        // Recalculate properly
        xPos = startX;
        for (int i = 0; i < index; i++) {
          xPos += effectiveCardWidth;
        }
        // Add group gaps
        int gapsBefore = 0;
        for (int i = 0; i <= index; i++) {
          if (allCards[i].isFirstInGroup) gapsBefore++;
        }
        xPos += gapsBefore * groupGap;

        // Fan arc
        final center = (cardCount - 1) / 2;
        final normalizedPos =
            cardCount > 1 ? (index - center) / center : 0.0;
        final angle = normalizedPos * maxAngle;
        final yOffset = (normalizedPos * normalizedPos) * 8;

        return Positioned(
          left: xPos,
          bottom: yOffset + (isSelected ? 12 : 0),
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.bottomCenter,
            child: PlayingCardWidget(
              card: card,
              isPlayable: widget.enabled && isPlayable,
              isSelected: isSelected,
              animateEntry: true,
              entryDelay: index * 50,
              onTap: widget.enabled && isPlayable
                  ? () => widget.onCardTap?.call(card)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _CardGroup {
  final Suit suit;
  final List<PlayingCard> cards;
  final bool isTrump;

  _CardGroup({
    required this.suit,
    required this.cards,
    this.isTrump = false,
  });
}

class _LayoutCard {
  final PlayingCard card;
  final int groupIndex;
  final bool isFirstInGroup;
  final int globalIndex;

  _LayoutCard({
    required this.card,
    required this.groupIndex,
    required this.isFirstInGroup,
    required this.globalIndex,
  });
}
