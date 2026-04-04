import 'dart:async';
import 'network_service.dart';
import 'message_protocol.dart';
import '../models/game_state.dart';
import '../engine/game_manager.dart';

/// Handles game state synchronization between host and clients.
class GameSync {
  final NetworkService _network;
  final GameManager _gameManager;
  final bool isHost;
  final String localPlayerId;

  final List<StreamSubscription> _subscriptions = [];
  int _lastReceivedSeq = -1;

  GameSync({
    required NetworkService network,
    required GameManager gameManager,
    required this.isHost,
    required this.localPlayerId,
  })  : _network = network,
        _gameManager = gameManager {
    _setupListeners();
  }

  void _setupListeners() {
    _subscriptions.add(
      _network.onMessageReceived.listen(_handleMessage),
    );

    _subscriptions.add(
      _network.onPeerDisconnected.listen(_handleDisconnect),
    );
  }

  void _handleMessage(PeerMessage peerMessage) {
    try {
      final message = NetworkMessage.deserialize(peerMessage.data);

      switch (message.type) {
        case MessageType.stateUpdate:
          if (!isHost) {
            // Client receives state updates from host
            if (message.sequenceNumber > _lastReceivedSeq) {
              _lastReceivedSeq = message.sequenceNumber;
              final state = GameState.fromJson(message.payload);
              _gameManager.applyNetworkState(state);
            }
          }
          break;

        case MessageType.playerAction:
          if (isHost) {
            // Host receives actions from clients
            final action = GameAction.fromJson(message.payload);
            final success = _gameManager.processRemoteAction(action);
            if (success) {
              // Broadcast updated state to all clients
              _broadcastState();
            }
          }
          break;

        case MessageType.gameStart:
          if (!isHost) {
            final state = GameState.fromJson(message.payload);
            _gameManager.applyNetworkState(state);
          }
          break;

        case MessageType.ping:
          _network.sendMessage(
            peerMessage.senderId,
            NetworkMessage.pong(senderId: localPlayerId).serialize(),
          );
          break;

        case MessageType.pong:
          // Handle latency tracking if needed
          break;

        case MessageType.lobbyUpdate:
          // Handled by lobby screen
          break;

        case MessageType.playerLeft:
          // Handle player disconnection
          break;

        case MessageType.heartbeat:
          // Reply with heartbeat ack
          _network.sendMessage(
            peerMessage.senderId,
            NetworkMessage.heartbeatAck(senderId: localPlayerId).serialize(),
          );
          break;

        case MessageType.heartbeatAck:
        case MessageType.reconnect:
          // Handled at transport level
          break;
      }
    } catch (e) {
      // Malformed message — ignore
    }
  }

  void _handleDisconnect(String peerId) {
    // Mark player as disconnected in game state
    // In a full implementation, pause the game and wait for reconnection
  }

  /// Send a local player's action to the host (client mode).
  void sendAction(GameAction action) {
    if (!isHost) {
      final message = NetworkMessage.playerAction(
        action: action,
        senderId: localPlayerId,
      );
      // Send to host (first connected peer for simplicity)
      _network.broadcastMessage(message.serialize());
    }
  }

  /// Broadcast current game state to all clients (host mode).
  void _broadcastState() {
    if (isHost && _gameManager.state != null) {
      final message = NetworkMessage.stateUpdate(
        state: _gameManager.state!,
        senderId: localPlayerId,
      );
      _network.broadcastMessage(message.serialize());
    }
  }

  /// Broadcast game start state to all clients (host mode).
  void broadcastGameStart(GameState state) {
    if (isHost) {
      final message = NetworkMessage.gameStart(
        initialState: state,
        senderId: localPlayerId,
      );
      _network.broadcastMessage(message.serialize());
    }
  }

  /// Clean up.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
