import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Central play area showing attack/defense card pairs with animations.
class TableWidget extends StatelessWidget {
  final List<TablePair> tablePairs;
  final VoidCallback? onTableTap;

  const TableWidget({
    super.key,
    required this.tablePairs,
    this.onTableTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTableTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 150,
          minWidth: double.infinity,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppTheme.tableGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.goldDark.withAlpha(50),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppTheme.feltGreenLight.withAlpha(30),
              blurRadius: 40,
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Felt texture overlay
              Positioned.fill(
                child: CustomPaint(painter: _FeltTexturePainter()),
              ),
              // Cards
              tablePairs.isEmpty ? _buildEmptyTable() : _buildPairs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              color: AppTheme.textSecondary.withAlpha(80),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Play a card to attack',
              style: TextStyle(
                color: AppTheme.textSecondary.withAlpha(120),
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List.generate(tablePairs.length, (index) {
          return _AnimatedTablePair(
            pair: tablePairs[index],
            index: index,
          );
        }),
      ),
    );
  }
}

/// Animated table pair — cards slide in with staggered timing.
class _AnimatedTablePair extends StatefulWidget {
  final TablePair pair;
  final int index;

  const _AnimatedTablePair({
    required this.pair,
    required this.index,
  });

  @override
  State<_AnimatedTablePair> createState() => _AnimatedTablePairState();
}

class _AnimatedTablePairState extends State<_AnimatedTablePair>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideIn;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideIn = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideIn.value),
          child: Opacity(
            opacity: _fadeIn.value,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: PlayingCardWidget.normalWidth + 18,
        height: PlayingCardWidget.normalHeight + 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Attack card (bottom)
            Positioned(
              left: 0,
              top: 0,
              child: PlayingCardWidget(
                card: widget.pair.attackCard,
                isFaceUp: true,
              ),
            ),
            // Defense card (overlapping, offset)
            if (widget.pair.defenseCard != null)
              Positioned(
                left: 16,
                top: 20,
                child: PlayingCardWidget(
                  card: widget.pair.defenseCard!,
                  isFaceUp: true,
                  animateEntry: true,
                  entryDelay: 100,
                ),
              ),
            // Undefended indicator (pulsing)
            if (!widget.pair.isDefended)
              Positioned(
                right: -2,
                top: -2,
                child: _PulsingDot(color: AppTheme.warning),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing dot indicator for undefended cards.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        return Container(
          width: 12 * _scale.value,
          height: 12 * _scale.value,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(120),
                blurRadius: 8 * _scale.value,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Subtle felt texture overlay for the table.
class _FeltTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(3)
      ..strokeWidth = 0.3
      ..style = PaintingStyle.stroke;

    // Subtle crosshatch pattern
    const step = 12.0;
    for (double i = 0; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
