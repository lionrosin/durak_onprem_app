import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';

/// Game over screen with rich animations — confetti/particles for win,
/// dramatic red vignette for lose. Supports both single and multiplayer.
class GameOverScreen extends StatefulWidget {
  final GameState gameState;
  final String localPlayerId;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onBackToMenu;
  final bool isMultiplayer;

  const GameOverScreen({
    super.key,
    required this.gameState,
    required this.localPlayerId,
    this.onPlayAgain,
    this.onBackToMenu,
    this.isMultiplayer = false,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _particleController;
  late final AnimationController _pulseController;
  late final AnimationController _buttonsController;

  late final Animation<double> _iconScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _rankingsFade;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;
  late final Animation<double> _pulse;

  final List<_Particle> _particles = [];
  final _random = math.Random();

  bool get _isLocalDurak =>
      widget.gameState.durakIndex >= 0 &&
      widget.gameState.players[widget.gameState.durakIndex].id ==
          widget.localPlayerId;

  bool get _isDraw => widget.gameState.durakIndex < 0;

  Player? get _durak => widget.gameState.durakIndex >= 0
      ? widget.gameState.players[widget.gameState.durakIndex]
      : null;

  @override
  void initState() {
    super.initState();

    // Main sequential entrance
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.2, 0.45, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _rankingsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.45, 0.7, curve: Curves.easeOut),
      ),
    );

    // Particles (confetti or fall)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Pulsing glow behind icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Buttons slide up
    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOutCubic),
    );

    // Generate particles
    _generateParticles();

    // Kick off animations
    _enterController.forward();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _buttonsController.forward();
    });
  }

  void _generateParticles() {
    final count = _isLocalDurak ? 20 : 50;
    for (int i = 0; i < count; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 8 + 3,
        speed: _random.nextDouble() * 0.3 + 0.1,
        rotation: _random.nextDouble() * math.pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 2,
        color: _isLocalDurak
            ? HSLColor.fromAHSL(
                    1, _random.nextDouble() * 30, 0.8, 0.5)
                .toColor()
            : HSLColor.fromAHSL(
                    1, _random.nextDouble() * 60 + 30, 0.9, 0.6)
                .toColor(),
        shape: _random.nextInt(3),
      ));
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _buttonsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isLocalDurak
                    ? [
                        const Color(0xFF1A0000),
                        const Color(0xFF2D0A0A),
                        AppTheme.feltGreenDark,
                      ]
                    : [
                        const Color(0xFF0D1B0F),
                        AppTheme.feltGreen,
                        const Color(0xFF1B3A20),
                      ],
              ),
            ),
          ),

          // Animated particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleController.value,
                isWin: !_isLocalDurak && !_isDraw,
              ),
            ),
          ),

          // Radial vignette
          if (_isLocalDurak)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.red.withAlpha(20),
                    Colors.red.withAlpha(40),
                  ],
                ),
              ),
            ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _enterController,
                    _pulseController,
                    _buttonsController,
                  ]),
                  builder: (context, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with pulsing glow
                      _buildResultIcon(),
                      const SizedBox(height: 28),

                      // Title text with slide
                      _buildTitle(),
                      const SizedBox(height: 8),

                      // Subtitle
                      _buildSubtitle(),
                      const SizedBox(height: 36),

                      // Rankings card
                      _buildRankings(),
                      const SizedBox(height: 40),

                      // Action buttons
                      _buildButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultIcon() {
    final iconColor = _isLocalDurak
        ? AppTheme.error
        : _isDraw
            ? AppTheme.textSecondary
            : AppTheme.gold;

    return Transform.scale(
      scale: _iconScale.value,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing glow
          Container(
            width: 120 * _pulse.value,
            height: 120 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withAlpha((60 * _pulse.value).toInt()),
                  blurRadius: 40 * _pulse.value,
                  spreadRadius: 10 * _pulse.value,
                ),
              ],
            ),
          ),
          // Icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isLocalDurak
                  ? const LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFCF2020)],
                    )
                  : _isDraw
                      ? const LinearGradient(
                          colors: [Color(0xFF555555), Color(0xFF888888)],
                        )
                      : AppTheme.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withAlpha(80),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isLocalDurak
                  ? Icons.sentiment_dissatisfied_rounded
                  : _isDraw
                      ? Icons.handshake_outlined
                      : Icons.emoji_events_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Opacity(
      opacity: _titleFade.value,
      child: Transform.translate(
        offset: Offset(0, _titleSlide.value),
        child: ShaderMask(
          shaderCallback: (bounds) => (_isLocalDurak
                  ? const LinearGradient(
                      colors: [AppTheme.error, Color(0xFFFF7043)],
                    )
                  : _isDraw
                      ? const LinearGradient(
                          colors: [Color(0xFFAAAAAA), Color(0xFFDDDDDD)],
                        )
                      : AppTheme.goldGradient)
              .createShader(bounds),
          child: Text(
            _isLocalDurak
                ? 'You\'re the Durak!'
                : _isDraw
                    ? 'It\'s a Draw!'
                    : 'Victory!',
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    String subtitle = '';
    if (_isLocalDurak) {
      subtitle = 'Better luck next time!';
    } else if (_isDraw) {
      subtitle = 'Nobody lost this round.';
    } else if (_durak != null) {
      subtitle = '${_durak!.name} is the Durak (Fool)!';
    }

    return Opacity(
      opacity: _titleFade.value,
      child: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRankings() {
    final gs = widget.gameState;
    final rankings = <_PlayerRank>[];

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

    return Opacity(
      opacity: _rankingsFade.value,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withAlpha(15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.leaderboard_rounded,
                    color: AppTheme.gold, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Results',
                  style: TextStyle(
                    color: AppTheme.textGold,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.white.withAlpha(10), height: 1),
            const SizedBox(height: 10),
            // Player list
            ...rankings.asMap().entries.map((entry) {
              final r = entry.value;
              final delay = entry.key * 0.1;
              final itemOpacity = _rankingsFade.value > delay
                  ? (((_rankingsFade.value - delay) / (1 - delay))
                      .clamp(0.0, 1.0))
                  : 0.0;

              return Opacity(
                opacity: itemOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      // Rank medal/number
                      SizedBox(
                        width: 32,
                        child: _buildRankBadge(r),
                      ),
                      const SizedBox(width: 10),
                      // Name
                      Expanded(
                        child: Text(
                          r.player.name + (r.isLocal ? ' (You)' : ''),
                          style: TextStyle(
                            color: r.isLocal
                                ? AppTheme.goldLight
                                : AppTheme.textPrimary,
                            fontWeight: r.isLocal
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // Badge
                      if (r.isDurak)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.error.withAlpha(60)),
                          ),
                          child: const Text(
                            'DURAK',
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      if (r.rank == 1 && !r.isDurak)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.gold.withAlpha(60)),
                          ),
                          child: const Text(
                            'WINNER',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(_PlayerRank r) {
    if (r.isDurak) {
      return const Text('💩', style: TextStyle(fontSize: 18));
    }
    if (r.rank == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 18));
    }
    if (r.rank == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 18));
    }
    if (r.rank == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 18));
    }
    return Text(
      '#${r.rank}',
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildButtons() {
    return FadeTransition(
      opacity: _buttonsFade,
      child: SlideTransition(
        position: _buttonsSlide,
        child: SizedBox(
          width: 280,
          child: Column(
            children: [
              // Play Again
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLocalDurak
                        ? AppTheme.error.withAlpha(200)
                        : AppTheme.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: (_isLocalDurak
                            ? AppTheme.error
                            : AppTheme.gold)
                        .withAlpha(80),
                  ),
                  icon: Icon(
                    _isLocalDurak
                        ? Icons.refresh_rounded
                        : Icons.replay_rounded,
                  ),
                  label: Text(
                    _isLocalDurak ? 'Rematch!' : 'Play Again',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Exit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: widget.onBackToMenu,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(
                        color: AppTheme.textSecondary.withAlpha(80)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text(
                    'Exit to Menu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Particle System ──────────────────────────────────────────────

class _Particle {
  double x, y, size, speed, rotation, rotationSpeed;
  Color color;
  int shape; // 0 = circle, 1 = square, 2 = diamond

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.shape,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isWin;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.isWin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withAlpha(150);

      // Calculate position based on progress
      double y;
      if (isWin) {
        // Confetti falls from top
        y = ((p.y + progress * p.speed * 3) % 1.2) * size.height - 20;
      } else {
        // Ash rises from bottom
        y = size.height -
            ((p.y + progress * p.speed * 2) % 1.2) * size.height;
      }

      final x =
          p.x * size.width + math.sin(progress * math.pi * 4 + p.y * 10) * 20;
      final rotation = p.rotation + progress * p.rotationSpeed * math.pi * 2;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case 1:
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
          break;
        case 2:
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, 0)
            ..lineTo(0, p.size / 2)
            ..lineTo(-p.size / 2, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
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
