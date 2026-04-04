import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';

/// Status bar showing current phase, trump suit, and action buttons.
/// Features animated phase transitions and smooth button reveals.
class GameStatusBar extends StatefulWidget {
  final GamePhase phase;
  final bool isAttacker;
  final bool isDefender;
  final Suit trumpSuit;
  final bool canPass;
  final bool canPickUp;
  final bool canTransfer;
  final VoidCallback? onPass;
  final VoidCallback? onPickUp;
  final String? errorMessage;

  const GameStatusBar({
    super.key,
    required this.phase,
    required this.isAttacker,
    required this.isDefender,
    required this.trumpSuit,
    this.canPass = false,
    this.canPickUp = false,
    this.canTransfer = false,
    this.onPass,
    this.onPickUp,
    this.errorMessage,
  });

  @override
  State<GameStatusBar> createState() => _GameStatusBarState();
}

class _GameStatusBarState extends State<GameStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _errorController;
  late Animation<double> _errorShake;

  @override
  void initState() {
    super.initState();
    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _errorShake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(GameStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null &&
        widget.errorMessage != oldWidget.errorMessage) {
      _errorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _errorController.dispose();
    super.dispose();
  }

  String get _statusText {
    if (widget.phase == GamePhase.gameOver) return 'Game Over';
    if (widget.isAttacker && widget.phase == GamePhase.attacking) {
      return '⚔️ Your Attack';
    }
    if (widget.isDefender && widget.phase == GamePhase.defending) {
      return '🛡️ Your Defense';
    }
    if (widget.isDefender && widget.phase == GamePhase.attacking) {
      return 'Waiting for attack...';
    }
    if (widget.isAttacker && widget.phase == GamePhase.defending) {
      return 'Opponent defending...';
    }
    return 'Waiting...';
  }

  Color get _statusColor {
    if (widget.phase == GamePhase.gameOver) return AppTheme.textSecondary;
    if (widget.isAttacker && widget.phase == GamePhase.attacking) {
      return AppTheme.error;
    }
    if (widget.isDefender && widget.phase == GamePhase.defending) {
      return AppTheme.warning;
    }
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor.withAlpha(40),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withAlpha(15),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error message with shake
          if (widget.errorMessage != null)
            AnimatedBuilder(
              animation: _errorShake,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _errorShake.value *
                        ((_errorShake.value * 10) % 2 == 0 ? 4 : -4),
                    0,
                  ),
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Phase indicator with animated dot
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedStatusDot(color: _statusColor),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusText),
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canPickUp)
                    _ActionButton(
                      label: 'Pick Up',
                      icon: Icons.back_hand_outlined,
                      color: AppTheme.warning,
                      onTap: widget.onPickUp,
                    ),
                  if (widget.canPass) ...[
                    if (widget.canPickUp) const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Pass',
                      icon: Icons.skip_next_rounded,
                      color: AppTheme.success,
                      onTap: widget.onPass,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated status dot that pulses when active.
class _AnimatedStatusDot extends StatefulWidget {
  final Color color;
  const _AnimatedStatusDot({required this.color});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
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
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
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
          width: 8 * _scale.value,
          height: 8 * _scale.value,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(100),
                blurRadius: 6 * _scale.value,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(
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
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(_pressed ? 50 : 25),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: widget.color.withAlpha(_pressed ? 150 : 80)),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: widget.color.withAlpha(40),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 16),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
