import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';

/// Game over screen showing the winner and the "durak" (loser).
class GameOverScreen extends StatefulWidget {
  final GameState gameState;
  final String localPlayerId;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onBackToMenu;

  const GameOverScreen({
    super.key,
    required this.gameState,
    required this.localPlayerId,
    this.onPlayAgain,
    this.onBackToMenu,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
    _scaleUp = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLocalDurak =>
      widget.gameState.durakIndex >= 0 &&
      widget.gameState.players[widget.gameState.durakIndex].id ==
          widget.localPlayerId;

  Player? get _durak => widget.gameState.durakIndex >= 0
      ? widget.gameState.players[widget.gameState.durakIndex]
      : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.feltGradient),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleUp,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Result icon
                      Icon(
                        _isLocalDurak
                            ? Icons.sentiment_dissatisfied_rounded
                            : Icons.emoji_events_rounded,
                        size: 80,
                        color: _isLocalDurak
                            ? AppTheme.error
                            : AppTheme.gold,
                      ),
                      const SizedBox(height: 24),

                      // Main result text
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            (_isLocalDurak
                                    ? const LinearGradient(
                                        colors: [
                                          AppTheme.error,
                                          Color(0xFFFF7043)
                                        ],
                                      )
                                    : AppTheme.goldGradient)
                                .createShader(bounds),
                        child: Text(
                          _isLocalDurak ? 'You\'re the Durak!' : 'You Win!',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      if (_durak != null && !_isLocalDurak)
                        Text(
                          '${_durak!.name} is the Durak (Fool)!',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      if (_durak == null)
                        const Text(
                          'It\'s a draw!',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Player rankings
                      _buildRankings(),

                      const SizedBox(height: 40),

                      // Buttons
                      SizedBox(
                        width: 260,
                        child: ElevatedButton.icon(
                          onPressed: widget.onPlayAgain,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Play Again'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton.icon(
                          onPressed: widget.onBackToMenu,
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Back to Menu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankings() {
    final gs = widget.gameState;
    final rankings = <_PlayerRank>[];

    // Finished players are ranked by order they finished (earlier = better)
    int rank = 1;
    for (int i = 0; i < gs.players.length; i++) {
      if (i == gs.durakIndex) continue;
      rankings.add(_PlayerRank(
        player: gs.players[i],
        rank: rank++,
        isLocal: gs.players[i].id == widget.localPlayerId,
      ));
    }
    if (_durak != null) {
      rankings.add(_PlayerRank(
        player: _durak!,
        rank: gs.players.length,
        isDurak: true,
        isLocal: _isLocalDurak,
      ));
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(opacity: 0.1),
      child: Column(
        children: rankings
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          r.isDurak ? '💩' : '#${r.rank}',
                          style: TextStyle(
                            color: r.isDurak
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.player.name + (r.isLocal ? ' (You)' : ''),
                          style: TextStyle(
                            color: r.isLocal
                                ? AppTheme.goldLight
                                : AppTheme.textPrimary,
                            fontWeight:
                                r.isLocal ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (r.isDurak)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DURAK',
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _PlayerRank {
  final Player player;
  final int rank;
  final bool isDurak;
  final bool isLocal;

  _PlayerRank({
    required this.player,
    required this.rank,
    this.isDurak = false,
    this.isLocal = false,
  });
}
