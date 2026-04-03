import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';

/// Game lobby — host configures settings, clients wait.
class LobbyScreen extends StatefulWidget {
  final bool isHost;
  final List<Player> connectedPlayers;
  final Function(GameVariant variant)? onStartGame;
  final VoidCallback? onCancel;
  final String? hostName;

  const LobbyScreen({
    super.key,
    required this.isHost,
    required this.connectedPlayers,
    this.onStartGame,
    this.onCancel,
    this.hostName,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  GameVariant _selectedVariant = GameVariant.classic;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.feltGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                      onPressed: widget.onCancel,
                    ),
                    const Expanded(
                      child: Text(
                        'Game Lobby',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // balance
                  ],
                ),
                const SizedBox(height: 24),

                // Connection status
                _buildConnectionStatus(),
                const SizedBox(height: 24),

                // Player list
                Expanded(child: _buildPlayerList()),

                // Variant selection (host only)
                if (widget.isHost) ...[
                  const SizedBox(height: 16),
                  _buildVariantSelector(),
                ],

                const SizedBox(height: 16),

                // Start / Waiting
                if (widget.isHost)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.connectedPlayers.length >= minPlayers
                          ? () => widget.onStartGame?.call(_selectedVariant)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                          'Start Game (${widget.connectedPlayers.length}/$maxPlayers)'),
                    ),
                  )
                else
                  _buildWaitingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        color: AppTheme.gold,
        opacity: 0.1,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.isHost ? AppTheme.success : AppTheme.warning,
              shape: BoxShape.circle,
              boxShadow: AppTheme.glowShadows(
                widget.isHost ? AppTheme.success : AppTheme.warning,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.isHost
                ? 'Hosting — waiting for players to join'
                : 'Connected to ${widget.hostName ?? "host"}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Players',
            style: TextStyle(
              color: AppTheme.textGold,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: maxPlayers,
              separatorBuilder: (_, __) => const Divider(
                color: AppTheme.textSecondary,
                height: 1,
                indent: 48,
              ),
              itemBuilder: (context, index) {
                if (index < widget.connectedPlayers.length) {
                  final player = widget.connectedPlayers[index];
                  return _buildPlayerTile(player, index);
                }
                return _buildEmptySlot(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(Player player, int index) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.gold.withAlpha(40),
        child: Text(
          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        player.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        player.isHost ? 'Host' : 'Player ${index + 1}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Icon(
        Icons.check_circle,
        color: AppTheme.success,
        size: 20,
      ),
    );
  }

  Widget _buildEmptySlot(int index) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.surfaceCard.withAlpha(80),
        child: const Icon(Icons.person_outline,
            color: AppTheme.textSecondary, size: 20),
      ),
      title: Text(
        'Waiting for player...',
        style: TextStyle(
          color: AppTheme.textSecondary.withAlpha(120),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildVariantSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Mode',
            style: TextStyle(
              color: AppTheme.textGold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _VariantChip(
                  label: 'Classic',
                  isSelected: _selectedVariant == GameVariant.classic,
                  onTap: () =>
                      setState(() => _selectedVariant = GameVariant.classic),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VariantChip(
                  label: 'Transfer',
                  isSelected: _selectedVariant == GameVariant.transfer,
                  onTap: () =>
                      setState(() => _selectedVariant = GameVariant.transfer),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingIndicator() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        final dots = '.' * ((_dotController.value * 3).floor() + 1);
        return Text(
          'Waiting for host to start$dots',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
        );
      },
    );
  }
}

class _VariantChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VariantChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.gold.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.gold
                : AppTheme.textSecondary.withAlpha(60),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppTheme.gold : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
