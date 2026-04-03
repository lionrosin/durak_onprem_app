import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';

/// Displays an opponent's info: name, card count, and role indicator.
class PlayerAvatarWidget extends StatelessWidget {
  final Player player;
  final bool isAttacker;
  final bool isDefender;
  final bool isCurrentTurn;
  final bool isLocalPlayer;

  const PlayerAvatarWidget({
    super.key,
    required this.player,
    this.isAttacker = false,
    this.isDefender = false,
    this.isCurrentTurn = false,
    this.isLocalPlayer = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.glassDecoration(
        color: isCurrentTurn ? AppTheme.gold : Colors.white,
        opacity: isCurrentTurn ? 0.2 : 0.1,
        borderRadius: 14,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar circle
          _buildAvatar(),
          const SizedBox(width: 10),
          // Name + role
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: TextStyle(
                  color: isLocalPlayer ? AppTheme.goldLight : AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAttacker) _buildRoleBadge('ATK', AppTheme.error),
                  if (isDefender) _buildRoleBadge('DEF', AppTheme.warning),
                  if (player.hasEmptyHand)
                    _buildRoleBadge('DONE', AppTheme.success),
                  if (!isAttacker && !isDefender && !player.hasEmptyHand)
                    _buildCardCount(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCurrentTurn ? AppTheme.goldGradient : null,
        color: isCurrentTurn ? null : AppTheme.surfaceCard,
        border: Border.all(
          color: player.connectionStatus == ConnectionStatus.connected
              ? (isCurrentTurn ? AppTheme.gold : AppTheme.textSecondary)
              : AppTheme.error,
          width: 2,
        ),
        boxShadow: isCurrentTurn ? AppTheme.glowShadows(AppTheme.gold) : null,
      ),
      child: Center(
        child: Text(
          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: isCurrentTurn ? AppTheme.feltGreenDark : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardCount() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.style_outlined,
          size: 12,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 3),
        Text(
          '${player.cardCount}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
