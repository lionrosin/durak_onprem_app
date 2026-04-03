import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';

/// Status bar showing current phase, trump suit, and action buttons.
class GameStatusBar extends StatelessWidget {
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

  String get _statusText {
    if (phase == GamePhase.gameOver) return 'Game Over';
    if (isAttacker && phase == GamePhase.attacking) return 'Your Attack';
    if (isDefender && phase == GamePhase.defending) return 'Your Defense';
    if (isDefender && phase == GamePhase.attacking) return 'Waiting...';
    if (isAttacker && phase == GamePhase.defending) return 'Defending...';
    return 'Waiting...';
  }

  Color get _statusColor {
    if (phase == GamePhase.gameOver) return AppTheme.textSecondary;
    if (isAttacker && phase == GamePhase.attacking) return AppTheme.error;
    if (isDefender && phase == GamePhase.defending) return AppTheme.warning;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.glassDecoration(
        color: Colors.black,
        opacity: 0.3,
        borderRadius: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error message
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  color: AppTheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Phase indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.glowShadows(_statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canPickUp)
                    _ActionButton(
                      label: 'Pick Up',
                      icon: Icons.back_hand_outlined,
                      color: AppTheme.warning,
                      onTap: onPickUp,
                    ),
                  if (canPass) ...[
                    if (canPickUp) const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Pass',
                      icon: Icons.skip_next_rounded,
                      color: AppTheme.success,
                      onTap: onPass,
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

class _ActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
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
