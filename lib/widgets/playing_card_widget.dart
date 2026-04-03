import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/card.dart';
import '../theme/app_theme.dart';

/// A beautifully rendered playing card with suit symbols, rank display,
/// and rich micro-animations (flip, glow, hover lift).
class PlayingCardWidget extends StatefulWidget {
  final PlayingCard card;
  final bool isFaceUp;
  final bool isPlayable;
  final bool isSelected;
  final bool isSmall;
  final bool animateEntry;
  final int entryDelay; // ms delay for staggered entry
  final VoidCallback? onTap;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isFaceUp = true,
    this.isPlayable = false,
    this.isSelected = false,
    this.isSmall = false,
    this.animateEntry = false,
    this.entryDelay = 0,
    this.onTap,
  });

  static const double normalWidth = 70;
  static const double normalHeight = 100;
  static const double smallWidth = 45;
  static const double smallHeight = 65;

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _tapController;
  late Animation<double> _entryScale;
  late Animation<double> _entryOpacity;
  late Animation<Offset> _entrySlide;
  late Animation<double> _tapScale;
  bool _isPressed = false;

  double get width => widget.isSmall
      ? PlayingCardWidget.smallWidth
      : PlayingCardWidget.normalWidth;
  double get height => widget.isSmall
      ? PlayingCardWidget.smallHeight
      : PlayingCardWidget.normalHeight;

  Color get _suitColor =>
      widget.card.suit.isRed ? AppTheme.suitRed : AppTheme.suitBlack;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entryScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    if (widget.animateEntry) {
      Future.delayed(Duration(milliseconds: widget.entryDelay), () {
        if (mounted) _entryController.forward();
      });
    } else {
      _entryController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.isPlayable) return;
    setState(() => _isPressed = true);
    _tapController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _tapController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _tapController]),
      builder: (context, child) {
        return SlideTransition(
          position: _entrySlide,
          child: FadeTransition(
            opacity: _entryOpacity,
            child: ScaleTransition(
              scale: _entryScale,
              child: ScaleTransition(
                scale: _tapScale,
                child: child,
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          transform: widget.isSelected
              ? Matrix4.translationValues(0.0, -14.0, 0.0)
              : Matrix4.identity(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.isSmall ? 6 : 8),
              boxShadow: [
                if (widget.isPlayable && !widget.isSmall)
                  BoxShadow(
                    color: AppTheme.gold
                        .withAlpha(widget.isSelected ? 140 : 70),
                    blurRadius: widget.isSelected ? 20 : 10,
                    spreadRadius: widget.isSelected ? 3 : 1,
                  ),
                if (_isPressed)
                  BoxShadow(
                    color: AppTheme.gold.withAlpha(200),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ...AppTheme.cardShadows,
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(widget.isSmall ? 6 : 8),
              child: widget.isFaceUp ? _buildFace() : _buildBack(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFace() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.cardFaceGradient),
      child: Stack(
        children: [
          // Border highlight
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(widget.isSmall ? 6 : 8),
                border: Border.all(
                  color: widget.isPlayable
                      ? AppTheme.gold.withAlpha(150)
                      : Colors.grey.withAlpha(80),
                  width: widget.isPlayable ? 2 : 0.5,
                ),
              ),
            ),
          ),

          // Top-left rank + suit
          Positioned(
            left: widget.isSmall ? 3 : 5,
            top: widget.isSmall ? 2 : 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.card.rank.symbol,
                  style: TextStyle(
                    fontSize: widget.isSmall ? 11 : 15,
                    fontWeight: FontWeight.w800,
                    color: _suitColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  widget.card.suit.symbol,
                  style: TextStyle(
                    fontSize: widget.isSmall ? 9 : 12,
                    color: _suitColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Bottom-right rank + suit (rotated)
          Positioned(
            right: widget.isSmall ? 3 : 5,
            bottom: widget.isSmall ? 2 : 4,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.card.rank.symbol,
                    style: TextStyle(
                      fontSize: widget.isSmall ? 11 : 15,
                      fontWeight: FontWeight.w800,
                      color: _suitColor,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    widget.card.suit.symbol,
                    style: TextStyle(
                      fontSize: widget.isSmall ? 9 : 12,
                      color: _suitColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center suit symbol (large)
          Center(
            child: Text(
              widget.card.suit.symbol,
              style: TextStyle(
                fontSize: widget.isSmall ? 22 : 32,
                color: _suitColor.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackGradient,
        borderRadius: BorderRadius.circular(widget.isSmall ? 6 : 8),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      child: Center(
        child: Container(
          width: width * 0.7,
          height: height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.isSmall ? 4 : 6),
            border: Border.all(
              color: AppTheme.goldDark.withAlpha(100),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.isSmall ? 4 : 6),
            child: CustomPaint(
              painter: _CardBackPatternPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws an ornate diamond pattern on card backs.
class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.goldDark.withAlpha(40)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 8.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(
          Offset(x + spacing / 2, y),
          Offset(x + spacing, y + spacing / 2),
          paint,
        );
        canvas.drawLine(
          Offset(x + spacing, y + spacing / 2),
          Offset(x + spacing / 2, y + spacing),
          paint,
        );
        canvas.drawLine(
          Offset(x + spacing / 2, y + spacing),
          Offset(x, y + spacing / 2),
          paint,
        );
        canvas.drawLine(
          Offset(x, y + spacing / 2),
          Offset(x + spacing / 2, y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
