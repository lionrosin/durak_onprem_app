import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/game_manager.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/card_hand_widget.dart';
import '../widgets/deck_widget.dart';
import '../widgets/game_status_bar.dart';
import '../widgets/player_avatar_widget.dart';
import '../widgets/round_end_overlay.dart';
import '../widgets/table_widget.dart';

/// Main gameplay screen — table, hand, opponents, action controls.
/// Enhanced with smooth phase transitions and micro-animations.
class GameScreen extends StatefulWidget {
  final VoidCallback? onGameOver;
  final VoidCallback? onExit;

  const GameScreen({
    super.key,
    this.onGameOver,
    this.onExit,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  PlayingCard? _selectedCard;
  GamePhase? _lastPhase;

  // Round-end animation state
  RoundEndEvent? _activeRoundEnd;
  bool _showingRoundEnd = false;

  // Phase change flash animation
  late final AnimationController _phaseFlashController;
  late final Animation<double> _phaseFlashOpacity;

  // Status bar slide animation
  late final AnimationController _statusSlideController;
  late final Animation<Offset> _statusSlide;

  @override
  void initState() {
    super.initState();

    _phaseFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _phaseFlashOpacity = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(
          parent: _phaseFlashController, curve: Curves.easeOut),
    );

    _statusSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _statusSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _statusSlideController, curve: Curves.easeOutCubic));

    _statusSlideController.forward();
  }

  @override
  void dispose() {
    _phaseFlashController.dispose();
    _statusSlideController.dispose();
    super.dispose();
  }

  void _triggerPhaseFlash(GamePhase newPhase) {
    if (_lastPhase != newPhase) {
      _lastPhase = newPhase;
      _phaseFlashController.forward(from: 0);
      _statusSlideController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameManager>(
      builder: (context, gm, _) {
        final state = gm.state;
        if (state == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Trigger phase flash on phase changes
        _triggerPhaseFlash(state.phase);

        // Detect round-end events from GameManager
        if (gm.lastRoundEnd != null && !_showingRoundEnd) {
          final event = gm.lastRoundEnd!;
          gm.clearRoundEnd();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _activeRoundEnd = event;
                _showingRoundEnd = true;
              });
            }
          });
        }

        // Check for game over
        if (state.phase == GamePhase.gameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onGameOver?.call();
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // Main game content
              Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.feltGradient),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar: exit + variant badge
                      _buildTopBar(state, gm),

                      // Opponent info
                      _buildOpponents(state, gm),

                      const SizedBox(height: 8),

                      // Table + Deck row
                      Expanded(
                        child: Row(
                          children: [
                            // Deck on the left
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: DeckWidget(
                                remainingCards: state.deck.remaining,
                                trumpCard: state.deck.trumpCard,
                                trumpSuit: state.trumpSuit,
                              ),
                            ),
                            // Table in center
                            Expanded(
                              child: TableWidget(
                                tablePairs: state.tablePairs,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Status bar with actions (animated slide)
                      SlideTransition(
                        position: _statusSlide,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: GameStatusBar(
                            phase: state.phase,
                            isAttacker: gm.isAttacker,
                            isDefender: gm.isDefender,
                            trumpSuit: state.trumpSuit,
                            canPass: gm.isAttacker &&
                                state.phase == GamePhase.attacking &&
                                state.hasTableCards,
                            canPickUp: gm.isDefender &&
                                (state.phase == GamePhase.defending ||
                                    state.phase == GamePhase.attacking),
                            canTransfer: gm.canTransfer,
                            onPass: () => gm.pass(),
                            onPickUp: () {
                              gm.pickUp();
                              _clearSelection();
                            },
                            errorMessage: gm.errorMessage,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Player's hand
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CardHandWidget(
                          cards: gm.localPlayer?.hand ?? [],
                          playableCards: gm.playableCards.toSet(),
                          selectedCard: _selectedCard,
                          enabled: gm.isMyTurn,
                          trumpSuit: state.trumpSuit,
                          onCardTap: (card) =>
                              _onCardTap(card, gm, state),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Phase change flash overlay
              AnimatedBuilder(
                animation: _phaseFlashController,
                builder: (context, _) {
                  if (_phaseFlashOpacity.value <= 0.01) {
                    return const SizedBox.shrink();
                  }
                  return IgnorePointer(
                    child: Container(
                      color: (gm.isAttacker
                              ? AppTheme.error
                              : gm.isDefender
                                  ? AppTheme.warning
                                  : AppTheme.gold)
                          .withAlpha(
                              (_phaseFlashOpacity.value * 60).toInt()),
                    ),
                  );
                },
              ),

              // Round-end card-flying animation overlay
              if (_showingRoundEnd && _activeRoundEnd != null)
                RoundEndOverlay(
                  event: _activeRoundEnd!,
                  onComplete: () {
                    if (mounted) {
                      setState(() {
                        _showingRoundEnd = false;
                        _activeRoundEnd = null;
                      });
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(GameState state, GameManager gm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Exit button with confirmation
          _AnimatedIconButton(
            icon: Icons.close,
            onTap: () => _showExitDialog(context),
          ),
          const Spacer(),
          // Variant badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.gold.withAlpha(40)),
            ),
            child: Text(
              state.variant == GameVariant.transfer
                  ? 'Transfer'
                  : 'Classic',
              style: const TextStyle(
                color: AppTheme.textGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          // Turn indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: gm.isMyTurn
                  ? AppTheme.success.withAlpha(25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: gm.isMyTurn
                  ? Border.all(color: AppTheme.success.withAlpha(60))
                  : null,
            ),
            child: Text(
              gm.isMyTurn ? 'YOUR TURN' : '',
              style: TextStyle(
                color: AppTheme.success,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponents(GameState state, GameManager gm) {
    final opponents = <Widget>[];
    for (int i = 0; i < state.players.length; i++) {
      if (state.players[i].id == gm.localPlayerId) continue;
      opponents.add(
        PlayerAvatarWidget(
          player: state.players[i],
          isAttacker: i == state.attackerIndex,
          isDefender: i == state.defenderIndex,
          isCurrentTurn: (i == state.attackerIndex &&
                  state.phase == GamePhase.attacking) ||
              (i == state.defenderIndex &&
                  state.phase == GamePhase.defending),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: opponents,
      ),
    );
  }

  void _onCardTap(PlayingCard card, GameManager gm, GameState state) {
    if (gm.isAttacker && state.phase == GamePhase.attacking) {
      gm.attack(card);
      _clearSelection();
      return;
    }

    if (gm.isDefender && state.phase == GamePhase.defending) {
      // Check what this card can do
      final attackRanks =
          state.tablePairs.map((p) => p.attackCard.rank).toSet();
      final canTransferCard = gm.canTransfer &&
          attackRanks.contains(card.rank);
      final undefended =
          state.tablePairs.where((p) => !p.isDefended).toList();
      final canDefendWith = undefended
          .any((p) => card.canBeat(p.attackCard, state.trumpSuit));

      // Card can BOTH defend and transfer → let user choose
      if (canTransferCard && canDefendWith) {
        _showDefendOrTransferDialog(card, undefended, gm);
        return;
      }

      // Card can ONLY transfer
      if (canTransferCard && !canDefendWith) {
        gm.transfer(card);
        _clearSelection();
        return;
      }

      // Card can ONLY defend
      if (canDefendWith) {
        if (undefended.length == 1) {
          gm.defend(undefended.first.attackCard, card);
          _clearSelection();
        } else {
          if (_selectedCard == card) {
            _clearSelection();
          } else {
            setState(() => _selectedCard = card);
            _showDefenseTargetDialog(card, undefended, gm);
          }
        }
        return;
      }

      return;
    }

    // Helper attacker
    if (state.phase == GamePhase.attacking && !gm.isDefender) {
      gm.attack(card);
      _clearSelection();
    }
  }

  /// Shows a choice dialog when a card can both defend and transfer.
  void _showDefendOrTransferDialog(
    PlayingCard card,
    List<TablePair> undefended,
    GameManager gm,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Text(
                'What do you want to do with ${card.rank.symbol}${card.suit.symbol}?',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Transfer option
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    gm.transfer(card);
                    _clearSelection();
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer Attack'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: BorderSide(color: AppTheme.warning.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Defend option(s)
              ...undefended
                  .where((p) =>
                      card.canBeat(p.attackCard, gm.state!.trumpSuit))
                  .map((pair) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        gm.defend(pair.attackCard, card);
                        _clearSelection();
                      },
                      icon: const Icon(Icons.shield_outlined),
                      label: Text(
                          'Beat ${pair.attackCard.rank.symbol}${pair.attackCard.suit.symbol}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success.withAlpha(180),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  void _showDefenseTargetDialog(
    PlayingCard defenseCard,
    List<TablePair> undefended,
    GameManager gm,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              const Text(
                'Defend against which card?',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: undefended
                    .where((p) => defenseCard.canBeat(
                        p.attackCard, gm.state!.trumpSuit))
                    .map((pair) {
                  return ActionChip(
                    label: Text(
                      pair.attackCard.toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      gm.defend(pair.attackCard, defenseCard);
                      _clearSelection();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDialog,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Game?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
            'Are you sure you want to exit the current game?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error.withAlpha(200),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onExit?.call();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedCard = null;
    });
  }
}

/// Animated icon button with scale press effect.
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _AnimatedIconButton({required this.icon, this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
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
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon,
              color: AppTheme.textSecondary, size: 22),
        ),
      ),
    );
  }
}
