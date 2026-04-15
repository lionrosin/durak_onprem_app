import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'engine/ai_player.dart';
import 'engine/game_manager.dart';
import 'models/game_state.dart';
import 'models/player.dart';
import 'network/ble_network_service.dart';
import 'network/message_protocol.dart';
import 'network/network_service.dart';
import 'network/socket_service.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const DurakApp());
}

class DurakApp extends StatelessWidget {
  const DurakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameManager(),
      child: MaterialApp(
        title: 'Durak',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppShell(),
      ),
    );
  }
}

/// Root navigation shell managing screen transitions and multiplayer state.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

enum AppScreen { home, lobby, game, gameOver, settings }

class _AppShellState extends State<AppShell> {
  AppScreen _currentScreen = AppScreen.home;
  final _uuid = const Uuid();

  // Settings state
  String _playerName = 'Player';
  GameVariant _defaultVariant = GameVariant.classic;
  bool _soundEnabled = true;

  // AI game state
  AiPlayer? _aiPlayer;
  Timer? _aiTimer;

  // Multiplayer state
  NetworkService? _networkService;
  ConnectionMode _connectionMode = ConnectionMode.wifi;
  bool _isHost = false;
  String _localPlayerId = '';
  final List<Player> _lobbyPlayers = [];
  final List<PeerDevice> _discoveredPeers = [];
  final List<StreamSubscription> _networkSubs = [];
  GameVariant _lobbyVariant = GameVariant.classic;
  bool _isConnecting = false;

  @override
  void dispose() {
    _aiTimer?.cancel();
    _cleanupNetwork();
    super.dispose();
  }

  void _cleanupNetwork() {
    for (final sub in _networkSubs) {
      sub.cancel();
    }
    _networkSubs.clear();
    _networkService?.dispose();
    _networkService = null;
  }

  /// Create the appropriate NetworkService for the selected connection mode.
  NetworkService _createNetworkService(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.wifi:
        return SocketNetworkService();
      case ConnectionMode.bluetooth:
        return BleNetworkService();
    }
  }

  /// Request Bluetooth permissions (Android 12+).
  Future<bool> _requestBluetoothPermissions() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();

      final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited,
      );
      return allGranted;
    }

    // iOS handles Bluetooth permissions via Info.plist usage descriptions
    // and prompts automatically on first use.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case AppScreen.home:
        return HomeScreen(
          key: const ValueKey('home'),
          playerName: _playerName,
          onCreateGame: _onCreateGame,
          onJoinGame: _onJoinGame,
          onSinglePlayer: _onSinglePlayer,
          onSettings: _onSettings,
        );
      case AppScreen.lobby:
        return LobbyScreen(
          key: const ValueKey('lobby'),
          isHost: _isHost,
          connectedPlayers: _lobbyPlayers,
          onStartGame: _onStartMultiplayerGame,
          onCancel: _backToHome,
          hostName: _isHost ? null : _lobbyPlayers.firstOrNull?.name,
          connectionMode: _connectionMode,
        );
      case AppScreen.game:
        return GameScreen(
          key: const ValueKey('game'),
          onGameOver: _onGameOver,
          onExit: _backToHome,
        );
      case AppScreen.gameOver:
        final gm = context.read<GameManager>();
        return GameOverScreen(
          key: const ValueKey('gameOver'),
          gameState: gm.state!,
          localPlayerId: gm.localPlayerId!,
          onPlayAgain: _onPlayAgain,
          onBackToMenu: _backToHome,
          isMultiplayer: _aiPlayer == null && _networkService != null,
        );
      case AppScreen.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          playerName: _playerName,
          defaultVariant: _defaultVariant,
          soundEnabled: _soundEnabled,
          onSave: (name, variant, sound) {
            setState(() {
              _playerName = name;
              _defaultVariant = variant;
              _soundEnabled = sound;
            });
          },
        );
    }
  }

  // ── Single Player (AI) ─────────────────────────────────────────

  void _onSinglePlayer(String name) {
    _playerName = name;
    final gm = context.read<GameManager>();
    _localPlayerId = _uuid.v4();
    final aiId = _uuid.v4();

    final players = [
      Player(
        id: _localPlayerId,
        name: name,
        isHost: true,
        platform: PeerPlatform.current,
      ),
      Player(id: aiId, name: 'AI Bot'),
    ];

    gm.createGame(
      gameId: _uuid.v4(),
      localPlayerId: _localPlayerId,
      localPlayerName: name,
      players: players,
      variant: _defaultVariant,
    );
    gm.startGame();

    _aiPlayer = AiPlayer(playerId: aiId);
    _startAiLoop();

    setState(() => _currentScreen = AppScreen.game);
  }

  void _startAiLoop() {
    _aiTimer?.cancel();
    _aiTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      final gm = context.read<GameManager>();
      if (gm.state == null ||
          gm.state!.phase == GamePhase.gameOver ||
          _aiPlayer == null) {
        _aiTimer?.cancel();
        return;
      }

      final action = _aiPlayer!.decideAction(gm.state!);
      if (action != null) {
        gm.processRemoteAction(action);
      }
    });
  }

  // ── Multiplayer: Create Game (Host) ────────────────────────────

  Future<void> _onCreateGame(String name, ConnectionMode mode) async {
    _playerName = name;
    _isHost = true;
    _connectionMode = mode;
    _localPlayerId = _uuid.v4();
    _lobbyVariant = _defaultVariant;

    // Request BLE permissions if needed
    if (mode == ConnectionMode.bluetooth) {
      final granted = await _requestBluetoothPermissions();
      if (!granted) {
        if (mounted) {
          _showSnack('Bluetooth permissions are required for Bluetooth mode');
        }
        return;
      }
    }

    // Set up network
    _cleanupNetwork();
    _networkService = _createNetworkService(mode);

    _lobbyPlayers.clear();
    _lobbyPlayers.add(Player(
      id: _localPlayerId,
      name: name,
      isHost: true,
      platform: PeerPlatform.current,
    ));

    // Listen for connections
    _networkSubs.add(
      _networkService!.onPeerConnected.listen((conn) {
        setState(() {
          if (_lobbyPlayers.length < maxPlayers) {
            _lobbyPlayers.add(Player(
              id: conn.peerId,
              name: conn.peerName,
              platform: conn.platform,
            ));
          }
        });
        // Broadcast lobby update to all clients
        _broadcastLobbyUpdate();
      }),
    );

    _networkSubs.add(
      _networkService!.onPeerDisconnected.listen((peerId) {
        if (_currentScreen == AppScreen.game) {
          _showDisconnectPopup('A player disconnected. Returning to main menu.');
          _backToHome();
        } else {
          setState(() {
            _lobbyPlayers.removeWhere((p) => p.id == peerId);
          });
          _broadcastLobbyUpdate();
        }
      }),
    );

    _networkSubs.add(
      _networkService!.onMessageReceived.listen(_handleNetworkMessage),
    );

    // Start advertising
    await _networkService!.startAdvertising(
      playerName: name,
      serviceType: 'durak-game',
    );

    setState(() => _currentScreen = AppScreen.lobby);
  }

  void _broadcastLobbyUpdate() {
    if (_networkService == null) return;
    final msg = NetworkMessage.lobbyUpdate(
      players: _lobbyPlayers.map((p) => p.toPublicJson()).toList(),
      senderId: _localPlayerId,
    );
    _networkService!.broadcastMessage(msg.serialize());
  }

  // ── Multiplayer: Join Game (Client) ────────────────────────────

  Future<void> _onJoinGame(String name, ConnectionMode mode) async {
    _playerName = name;
    _isHost = false;
    _connectionMode = mode;
    _localPlayerId = _uuid.v4();

    // Request BLE permissions if needed
    if (mode == ConnectionMode.bluetooth) {
      final granted = await _requestBluetoothPermissions();
      if (!granted) {
        if (mounted) {
          _showSnack('Bluetooth permissions are required for Bluetooth mode');
        }
        return;
      }
    }

    _cleanupNetwork();
    _networkService = _createNetworkService(mode);
    _discoveredPeers.clear();

    final gm = context.read<GameManager>();

    // Wire network callback for sending actions to host
    gm.onActionToSend = (action) {
      if (_networkService != null) {
        final msg = NetworkMessage.playerAction(
          action: action,
          senderId: _localPlayerId,
        );
        _networkService!.broadcastMessage(msg.serialize());
      }
    };

    // Listen for discovered peers
    _networkSubs.add(
      _networkService!.onPeerDiscovered.listen((peer) {
        debugPrint('[Main] Peer discovered: ${peer.name} at ${peer.id}');
        // Avoid duplicates
        if (!_discoveredPeers.any((p) => p.id == peer.id)) {
          _discoveredPeers.add(peer);
          // Auto-connect to first discovered host (while still on home/searching)
          if (_currentScreen == AppScreen.home && !_isConnecting) {
            _connectToHost(peer);
          }
        }
      }),
    );

    _networkSubs.add(
      _networkService!.onPeerConnected.listen((conn) {
        _lobbyPlayers.clear();
        _lobbyPlayers.add(Player(
          id: conn.peerId,
          name: conn.peerName,
          isHost: true,
          platform: conn.platform,
        ));
        _lobbyPlayers.add(Player(
          id: _localPlayerId,
          name: name,
          platform: PeerPlatform.current,
        ));
        setState(() => _currentScreen = AppScreen.lobby);
      }),
    );

    _networkSubs.add(
      _networkService!.onPeerDisconnected.listen((peerId) {
        if (_currentScreen == AppScreen.game) {
          _showDisconnectPopup('Host disconnected. Returning to main menu.');
          _backToHome();
        } else if (_currentScreen == AppScreen.lobby) {
          _showSnack('Host disconnected');
          _backToHome();
        }
      }),
    );

    _networkSubs.add(
      _networkService!.onMessageReceived.listen(_handleNetworkMessage),
    );

    // Start browsing
    await _networkService!.startBrowsing(
      playerName: name,
      playerId: _localPlayerId,
      serviceType: 'durak-game',
    );

    if (mounted) {
      final modeLabel = mode == ConnectionMode.wifi
          ? 'local network'
          : 'Bluetooth';
      _showSnack('Searching for games via $modeLabel...');
    }
  }


  Future<void> _connectToHost(PeerDevice peer) async {
    if (_isConnecting) return;
    _isConnecting = true;

    if (mounted) {
      _showSnack('Found "${peer.name}" — connecting...');
    }

    debugPrint('[Main] Attempting connection to ${peer.name} at ${peer.id}');
    final success = await _networkService!.connectToPeer(peer.id);

    _isConnecting = false;

    if (!success && mounted) {
      _showSnack('Could not connect to ${peer.name}. Will retry when found again.');
      // Remove from discovered so it can be re-discovered
      _discoveredPeers.removeWhere((p) => p.id == peer.id);
    }
  }

  // ── Multiplayer: Start Game (Host) ─────────────────────────────

  void _onStartMultiplayerGame(GameVariant variant) {
    if (!_isHost) return;
    _lobbyVariant = variant;

    final gm = context.read<GameManager>();
    gm.createGame(
      gameId: _uuid.v4(),
      localPlayerId: _localPlayerId,
      localPlayerName: _playerName,
      players: List.from(_lobbyPlayers),
      variant: variant,
    );
    gm.startGame();

    // Wire network callbacks for state broadcasting
    gm.onStateBroadcast = (state) {
      if (_networkService != null) {
        final msg = NetworkMessage.stateUpdate(
          state: state,
          senderId: _localPlayerId,
        );
        _networkService!.broadcastMessage(msg.serialize());
      }
    };

    // Send game state to all clients
    if (_networkService != null && gm.state != null) {
      final msg = NetworkMessage.gameStart(
        initialState: gm.state!,
        senderId: _localPlayerId,
      );
      _networkService!.broadcastMessage(msg.serialize());
    }

    setState(() => _currentScreen = AppScreen.game);
  }

  // ── Network Message Handler ────────────────────────────────────

  void _handleNetworkMessage(PeerMessage peerMessage) {
    try {
      final message = NetworkMessage.deserialize(peerMessage.data);

      switch (message.type) {
        case MessageType.stateUpdate:
          if (!_isHost) {
            final state = GameState.fromJson(message.payload);
            context.read<GameManager>().applyNetworkState(state);
          }
          break;

        case MessageType.playerAction:
          if (_isHost) {
            final action = GameAction.fromJson(message.payload);
            final gm = context.read<GameManager>();
            final success = gm.processRemoteAction(action);
            if (success && gm.state != null) {
              // Broadcast updated state
              final msg = NetworkMessage.stateUpdate(
                state: gm.state!,
                senderId: _localPlayerId,
              );
              _networkService!.broadcastMessage(msg.serialize());
            }
          }
          break;

        case MessageType.gameStart:
          if (!_isHost) {
            final state = GameState.fromJson(message.payload);
            final gm = context.read<GameManager>();
            gm.setLocalPlayerId(_localPlayerId);
            gm.applyNetworkState(state);
            setState(() => _currentScreen = AppScreen.game);
          }
          break;

        case MessageType.lobbyUpdate:
          if (!_isHost) {
            final playersJson =
                message.payload['players'] as List<dynamic>;
            setState(() {
              _lobbyPlayers.clear();
              for (final pj in playersJson) {
                _lobbyPlayers.add(Player(
                  id: pj['id'] as String,
                  name: pj['name'] as String,
                  isHost: pj['isHost'] as bool? ?? false,
                  platform: PeerPlatform.fromString(
                    pj['platform'] as String? ?? 'unknown',
                  ),
                ));
              }
            });
          }
          break;

        case MessageType.ping:
          _networkService?.sendMessage(
            peerMessage.senderId,
            NetworkMessage.pong(senderId: _localPlayerId).serialize(),
          );
          break;

        case MessageType.heartbeat:
          _networkService?.sendMessage(
            peerMessage.senderId,
            NetworkMessage.heartbeatAck(senderId: _localPlayerId).serialize(),
          );
          break;

        case MessageType.pong:
        case MessageType.playerLeft:
        case MessageType.heartbeatAck:
        case MessageType.reconnect:
          // Handled at transport level or not yet implemented
          break;
      }
    } catch (e) {
      debugPrint('Error handling network message: $e');
    }
  }

  void _onSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          playerName: _playerName,
          defaultVariant: _defaultVariant,
          soundEnabled: _soundEnabled,
          onSave: (name, variant, sound) {
            setState(() {
              _playerName = name;
              _defaultVariant = variant;
              _soundEnabled = sound;
            });
          },
        ),
      ),
    );
  }

  void _onGameOver() {
    _aiTimer?.cancel();
    setState(() => _currentScreen = AppScreen.gameOver);
  }

  void _onPlayAgain() {
    if (_aiPlayer != null) {
      _onSinglePlayer(_playerName);
    } else if (_isHost) {
      _onStartMultiplayerGame(_lobbyVariant);
    } else {
      _backToHome();
    }
  }

  void _backToHome() {
    _aiTimer?.cancel();
    _aiPlayer = null;
    _cleanupNetwork();
    _lobbyPlayers.clear();
    _discoveredPeers.clear();
    context.read<GameManager>().resetGame();
    setState(() => _currentScreen = AppScreen.home);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showDisconnectPopup(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Game Ended', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
