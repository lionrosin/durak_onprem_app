import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine/game_manager.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Full-screen overlay that animates cards flying away when a round ends.
///
/// Timeline (bita):
///   0ms       — dim overlay fades in, label scales up with bounce
///   0–1200ms  — label is fully visible, glowing
///   800ms     — cards begin flying toward top-left (staggered)
///   1200ms    — label starts fading out
///   1800ms    — everything gone, onComplete fires
///
/// Timeline (pickup):
///   Same structure, cards fly downward, amber palette.
class RoundEndOverlay extends StatefulWidget {
  final RoundEndEvent event;
  final VoidCallback onComplete;

  const RoundEndOverlay({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<RoundEndOverlay> createState() => _RoundEndOverlayState();
}

class _RoundEndOverlayState extends State<RoundEndOverlay>
    with TickerProviderStateMixin {
  // Master timeline drives everything.
  late AnimationController _master;

  // Label animations (entrance + hold + exit).
  late Animation<double> _labelScale;
  late Animation<double> _labelOpacity;
  late Animation<double> _labelGlow;

  // Dim overlay.
  late Animation<double> _dimOpacity;

  // Card flight (starts partway through master).
  late Animation<double> _cardProgress;

  final List<_CardAnimData> _cardAnims = [];

  static const _totalDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();

    _master = AnimationController(vsync: this, duration: _totalDuration);

    // Dim overlay: fade in quickly, hold, fade out at the end.
    _dimOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _master, curve: Curves.easeOut));

    // Label scale: bounce in (0–15%), hold (15–65%), shrink out (65–85%).
    _labelScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.15), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _master, curve: Curves.easeOut));

    // Label opacity: appears quickly, holds, fades with scale.
    _labelOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 57),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _master, curve: Curves.easeOut));

    // Label glow pulsing — pulses while visible.
    _labelGlow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _master, curve: Curves.linear));

    // Card flight progress: starts at 45% of master, ends at 95%.
    _cardProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.45, 0.95, curve: Curves.easeInQuad),
      ),
    );

    // Build per-card data.
    final pairs = widget.event.tablePairs;
    int idx = 0;
    for (final pair in pairs) {
      _cardAnims.add(_CardAnimData(card: pair.attackCard, index: idx++));
      if (pair.defenseCard != null) {
        _cardAnims.add(_CardAnimData(card: pair.defenseCard!, index: idx++));
      }
    }

    _master.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isBita = widget.event.type == RoundEndType.defenseBita;

    final accentColor = isBita ? AppTheme.success : AppTheme.warning;

    // Fly targets.
    final targetDx = isBita ? -size.width * 0.35 : 0.0;
    final targetDy = isBita ? -size.height * 0.35 : size.height * 0.40;

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _master,
          builder: (context, _) {
            return Stack(
              children: [
                // ─── Dim overlay ──────────────────────────────────
                Container(
                  color: Colors.black
                      .withAlpha((_dimOpacity.value * 100).toInt()),
                ),

                // ─── Radial glow behind the label ─────────────────
                if (_labelOpacity.value > 0.01)
                  Center(
                    child: Container(
                      width: 300 * _labelScale.value,
                      height: 300 * _labelScale.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withAlpha(
                                (_labelGlow.value * 40).toInt()),
                            accentColor.withAlpha(
                                (_labelGlow.value * 15).toInt()),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                // ─── Label badge ──────────────────────────────────
                if (_labelOpacity.value > 0.01)
                  Center(
                    child: Transform.scale(
                      scale: _labelScale.value,
                      child: Opacity(
                        opacity: _labelOpacity.value.clamp(0.0, 1.0),
                        child: _buildLabel(isBita, accentColor, widget.event.defenderName),
                      ),
                    ),
                  ),

                // ─── Sparkle particles ────────────────────────────
                if (_labelOpacity.value > 0.1)
                  ..._buildSparkles(accentColor, size),

                // ─── Flying cards ─────────────────────────────────
                ..._cardAnims.map((anim) => _FlyingCard(
                      playingCard: anim.card,
                      cardIndex: anim.index,
                      totalCards: _cardAnims.length,
                      targetDx: targetDx,
                      targetDy: targetDy,
                      isBita: isBita,
                      progress: _cardProgress.value,
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(bool isBita, Color accentColor, String defenderName) {
    final glowIntensity = _labelGlow.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withAlpha((glowIntensity * 180).toInt()),
          width: 2,
        ),
        boxShadow: [
          // Inner glow
          BoxShadow(
            color: accentColor.withAlpha((glowIntensity * 80).toInt()),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          // Outer glow
          BoxShadow(
            color: accentColor.withAlpha((glowIntensity * 40).toInt()),
            blurRadius: 60,
            spreadRadius: 8,
          ),
          // Shadow
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Icon(
            isBita ? Icons.check_circle_rounded : Icons.back_hand_rounded,
            color: accentColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          // Main text
          Text(
            isBita ? 'БИТА' : 'ЗАБРАЛ',
            style: TextStyle(
              color: accentColor,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              shadows: [
                Shadow(
                  color: accentColor.withAlpha((glowIntensity * 200).toInt()),
                  blurRadius: 20,
                ),
                Shadow(
                  color: accentColor.withAlpha((glowIntensity * 120).toInt()),
                  blurRadius: 40,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            isBita ? '$defenderName defended!' : '$defenderName picks up',
            style: TextStyle(
              color: AppTheme.textSecondary.withAlpha(180),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Small sparkle/particle dots that drift outward from center.
  List<Widget> _buildSparkles(Color color, Size screenSize) {
    final sparkles = <Widget>[];
    const count = 12;
    for (int i = 0; i < count; i++) {
      final rng = math.Random(i * 17 + 3);
      final angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.5;
      final distance = 60.0 + rng.nextDouble() * 120.0;
      final sparkleSize = 3.0 + rng.nextDouble() * 4.0;

      // Sparkles drift outward as the label is visible.
      final t = _labelOpacity.value;
      final dx = math.cos(angle) * distance * t;
      final dy = math.sin(angle) * distance * t;
      final opacity = (t * (1.0 - t) * 4.0).clamp(0.0, 1.0); // peak at t=0.5

      sparkles.add(
        Center(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: opacity * 0.8,
              child: Container(
                width: sparkleSize,
                height: sparkleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(150),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return sparkles;
  }
}

/// Animation data for a single card.
class _CardAnimData {
  final dynamic card; // PlayingCard
  final int index;
  _CardAnimData({required this.card, required this.index});
}

/// A single card that flies from center-ish to a target with rotation + fade.
class _FlyingCard extends StatelessWidget {
  final dynamic playingCard;
  final int cardIndex;
  final int totalCards;
  final double targetDx;
  final double targetDy;
  final bool isBita;
  final double progress; // 0.0 – 1.0

  const _FlyingCard({
    required this.playingCard,
    required this.cardIndex,
    required this.totalCards,
    required this.targetDx,
    required this.targetDy,
    required this.isBita,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Stagger each card so they leave sequentially.
    final staggerDelay = totalCards > 1 ? (cardIndex / totalCards) * 0.35 : 0.0;
    final t = ((progress - staggerDelay) / (1.0 - staggerDelay)).clamp(0.0, 1.0);

    if (t <= 0.0) return const SizedBox.shrink();

    // Eased progress.
    final eased = Curves.easeInQuad.transform(t);
    final fadeCurve = Curves.easeIn.transform(
      ((t - 0.4) / 0.6).clamp(0.0, 1.0),
    );

    // Per-card randomness.
    final rng = math.Random(cardIndex * 31 + 7);
    final scatterX = (rng.nextDouble() - 0.5) * 40;
    final scatterY = (rng.nextDouble() - 0.5) * 20;
    final spinDir = rng.nextBool() ? 1.0 : -1.0;
    final spinAmount = 0.3 + rng.nextDouble() * 1.2;

    // Fan offset for initial position.
    final fanSpacing = 30.0;
    final fanWidth = totalCards > 1 ? (totalCards - 1) * fanSpacing : 0.0;
    final startX = -fanWidth / 2 + cardIndex * fanSpacing + scatterX;
    final startY = scatterY;

    // Interpolated position.
    final dx = startX + (targetDx - startX) * eased;
    final dy = startY + (targetDy - startY) * eased;
    final rotation = eased * spinAmount * spinDir * math.pi * 2;
    final scale = 1.0 - eased * 0.4;
    final opacity = (1.0 - fadeCurve).clamp(0.0, 1.0);

    return Center(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: PlayingCardWidget(
                card: playingCard,
                isFaceUp: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
