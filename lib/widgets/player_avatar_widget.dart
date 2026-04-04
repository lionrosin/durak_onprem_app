import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';

/// Displays an opponent's info with animated turn glow and card count.
class PlayerAvatarWidget extends StatefulWidget {
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
  State<PlayerAvatarWidget> createState() => _PlayerAvatarWidgetState();
}

class _PlayerAvatarWidgetState extends State<PlayerAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.isCurrentTurn) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PlayerAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentTurn && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isCurrentTurn && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isCurrentTurn
                ? AppTheme.gold
                    .withAlpha((20 + 15 * _glowAnim.value).toInt())
                : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isCurrentTurn
                  ? AppTheme.gold.withAlpha((60 * _glowAnim.value).toInt())
                  : Colors.white.withAlpha(15),
              width: 1,
            ),
            boxShadow: widget.isCurrentTurn
                ? [
                    BoxShadow(
                      color: AppTheme.gold
                          .withAlpha((30 * _glowAnim.value).toInt()),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.player.name,
                style: TextStyle(
                  color: widget.isLocalPlayer
                      ? AppTheme.goldLight
                      : AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isAttacker)
                    _buildRoleBadge('⚔️ ATK', AppTheme.error),
                  if (widget.isDefender)
                    _buildRoleBadge('🛡️ DEF', AppTheme.warning),
                  if (widget.player.hasEmptyHand)
                    _buildRoleBadge('✓ DONE', AppTheme.success),
                  if (!widget.player.hasEmptyHand) ...[
                    if (widget.isAttacker || widget.isDefender)
                      const SizedBox(width: 6),
                    _buildCardCount(),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.isCurrentTurn ? AppTheme.goldGradient : null,
        color: widget.isCurrentTurn ? null : AppTheme.surfaceCard,
        border: Border.all(
          color: widget.player.connectionStatus == ConnectionStatus.connected
              ? (widget.isCurrentTurn
                  ? AppTheme.gold
                  : AppTheme.textSecondary.withAlpha(120))
              : AppTheme.error,
          width: 2,
        ),
        boxShadow: widget.isCurrentTurn
            ? [
                BoxShadow(
                  color: AppTheme.gold.withAlpha(60),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          widget.player.name.isNotEmpty
              ? widget.player.name[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: widget.isCurrentTurn
                ? AppTheme.feltGreenDark
                : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
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
          '${widget.player.cardCount}',
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
