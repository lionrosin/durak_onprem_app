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
import '../widgets/table_widget.dart';

/// Main gameplay screen — table, hand, opponents, action controls.
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

class _GameScreenState extends State<GameScreen> {
  PlayingCard? _selectedCard;

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

        // Check for game over
        if (state.phase == GamePhase.gameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onGameOver?.call();
          });
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.feltGradient),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar: exit + opponents
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

                  // Status bar with actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      onCardTap: (card) => _onCardTap(card, gm, state),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
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
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: () => _showExitDialog(context),
          ),
          const Spacer(),
          // Variant badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.gold.withAlpha(40)),
            ),
            child: Text(
              state.variant == GameVariant.transfer ? 'Transfer' : 'Classic',
              style: const TextStyle(
                color: AppTheme.textGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balance the close button
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
      // Attackers play directly
      gm.attack(card);
      _clearSelection();
      return;
    }

    if (gm.isDefender && state.phase == GamePhase.defending) {
      // In transfer mode, check if this is a transfer card
      if (state.variant == GameVariant.transfer &&
          !state.tablePairs.any((p) => p.isDefended) &&
          gm.canTransfer) {
        final attackRanks =
            state.tablePairs.map((p) => p.attackCard.rank).toSet();
        final canDefend = state.tablePairs.any((p) =>
            !p.isDefended && card.canBeat(p.attackCard, state.trumpSuit));

        if (attackRanks.contains(card.rank) && !canDefend) {
          // Only transfer option for this card
          gm.transfer(card);
          _clearSelection();
          return;
        }
      }

      // Find undefended attack card(s)
      final undefended =
          state.tablePairs.where((p) => !p.isDefended).toList();

      if (undefended.length == 1) {
        // Only one card to defend against — play directly
        gm.defend(undefended.first.attackCard, card);
        _clearSelection();
      } else if (undefended.length > 1) {
        // Multiple undefended — need to select which to defend
        if (_selectedCard == card) {
          // Already selected, deselect
          _clearSelection();
        } else {
          setState(() => _selectedCard = card);
          _showDefenseTargetDialog(card, undefended, gm);
        }
      }
      return;
    }

    // Helper attacker
    if (state.phase == GamePhase.attacking && !gm.isDefender) {
      gm.attack(card);
      _clearSelection();
    }
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Defend against which card?',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: undefended
                    .where((p) =>
                        defenseCard.canBeat(p.attackCard, gm.state!.trumpSuit))
                    .map((pair) {
                  return ActionChip(
                    label: Text(pair.attackCard.toString()),
                    onPressed: () {
                      Navigator.pop(ctx);
                      gm.defend(pair.attackCard, defenseCard);
                      _clearSelection();
                    },
                  );
                }).toList(),
              ),
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
        title: const Text('Leave Game?'),
        content: const Text('Are you sure you want to exit the current game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          ElevatedButton(
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
