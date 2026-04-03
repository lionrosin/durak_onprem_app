import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Stunning title screen with animated cards and game mode selection.
class HomeScreen extends StatefulWidget {
  final String playerName;
  final Function(String name) onCreateGame;
  final Function(String name) onJoinGame;
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

          // Create Game (Host)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  widget.onCreateGame(name.isEmpty ? 'Player' : name),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Create Game'),
            ),
          ),
          const SizedBox(height: 12),

          // Join Game
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  widget.onJoinGame(name.isEmpty ? 'Player' : name),
              icon: const Icon(Icons.search),
              label: const Text('Join Game'),
            ),
          ),
        ],
      ),
    );
  }
}
