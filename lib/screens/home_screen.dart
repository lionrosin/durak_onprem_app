import 'package:flutter/material.dart';
import '../network/network_service.dart';
import '../theme/app_theme.dart';

/// Stunning title screen with animated cards and game mode selection.
/// Now includes connection mode picker (WiFi / Bluetooth) for multiplayer.
class HomeScreen extends StatefulWidget {
  final String playerName;
  final Function(String name, ConnectionMode mode) onCreateGame;
  final Function(String name, ConnectionMode mode) onJoinGame;
  final Function(String name) onSinglePlayer;
  final VoidCallback? onSettings;

  const HomeScreen({
    super.key,
    required this.playerName,
    required this.onCreateGame,
    required this.onJoinGame,
    required this.onSinglePlayer,
    this.onSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playerName);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerName != oldWidget.playerName &&
        _nameController.text != widget.playerName) {
      _nameController.text = widget.playerName;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.feltGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated title
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: _buildTitle(),
                  ),
                  const SizedBox(height: 48),

                  // Player name input
                  _buildNameInput(),
                  const SizedBox(height: 36),

                  // Game mode buttons
                  _buildModeButtons(),
                  const SizedBox(height: 24),

                  // Settings
                  TextButton.icon(
                    onPressed: widget.onSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        // Card suits decorative
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSuitIcon('♠', AppTheme.textPrimary),
            _buildSuitIcon('♥', AppTheme.suitRed),
            _buildSuitIcon('♣', AppTheme.textPrimary),
            _buildSuitIcon('♦', AppTheme.suitRed),
          ],
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.goldGradient.createShader(bounds),
          child: const Text(
            'DURAK',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Card Game',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
            letterSpacing: 4,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildSuitIcon(String suit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        suit,
        style: TextStyle(fontSize: 28, color: color.withAlpha(180)),
      ),
    );
  }

  Widget _buildNameInput() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        controller: _nameController,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: 'Your Name',
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon:
              const Icon(Icons.person_outline, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildModeButtons() {
    final name = _nameController.text.trim();
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          // Single Player (AI)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  widget.onSinglePlayer(name.isEmpty ? 'Player' : name),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Play vs AI'),
            ),
          ),
          const SizedBox(height: 12),

          // Create Game (Host) — opens connection mode picker
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showConnectionModePicker(
                isHost: true,
                name: name.isEmpty ? 'Player' : name,
              ),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Create Game'),
            ),
          ),
          const SizedBox(height: 12),

          // Join Game — opens connection mode picker
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showConnectionModePicker(
                isHost: false,
                name: name.isEmpty ? 'Player' : name,
              ),
              icon: const Icon(Icons.search),
              label: const Text('Join Game'),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a bottom sheet to pick WiFi or Bluetooth connection mode.
  void _showConnectionModePicker({
    required bool isHost,
    required String name,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                isHost ? 'How to Host?' : 'How to Connect?',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isHost
                    ? 'Choose how players will connect to your game'
                    : 'Choose how to find nearby games',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // WiFi option
              _ConnectionModeCard(
                icon: Icons.wifi,
                iconColor: const Color(0xFF4FC3F7),
                title: 'WiFi',
                subtitle: 'Play over local network',
                description: 'All players must be on the same WiFi',
                onTap: () {
                  Navigator.pop(ctx);
                  if (isHost) {
                    widget.onCreateGame(name, ConnectionMode.wifi);
                  } else {
                    widget.onJoinGame(name, ConnectionMode.wifi);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Bluetooth option
              _ConnectionModeCard(
                icon: Icons.bluetooth,
                iconColor: const Color(0xFF42A5F5),
                title: 'Bluetooth',
                subtitle: 'Play nearby without WiFi',
                description: 'Uses Bluetooth Low Energy for close range play',
                onTap: () {
                  Navigator.pop(ctx);
                  if (isHost) {
                    widget.onCreateGame(name, ConnectionMode.bluetooth);
                  } else {
                    widget.onJoinGame(name, ConnectionMode.bluetooth);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A tappable card for connection mode selection.
class _ConnectionModeCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _ConnectionModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  State<_ConnectionModeCard> createState() => _ConnectionModeCardState();
}

class _ConnectionModeCardState extends State<_ConnectionModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.iconColor.withAlpha(15),
                widget.iconColor.withAlpha(5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.iconColor.withAlpha(40),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.iconColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withAlpha(140),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: widget.iconColor.withAlpha(100), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
