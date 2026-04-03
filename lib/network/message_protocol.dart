import 'dart:convert';

import '../models/game_state.dart';

/// Message types for network communication between host and clients.
enum MessageType {
  /// Full game state update (host → clients)
  stateUpdate,

  /// Player action (client → host)
  playerAction,

  /// Lobby update (host → clients)
  lobbyUpdate,

  /// Game start signal (host → clients)
  gameStart,

  /// Keep-alive ping/pong
  ping,
  pong,

  /// Player left notification
  playerLeft,
}

/// A network message with type, payload, and sequence number.
class NetworkMessage {
  final MessageType type;
  final Map<String, dynamic> payload;
  final int sequenceNumber;
  final String senderId;

  NetworkMessage({
    required this.type,
    required this.payload,
    required this.sequenceNumber,
    required this.senderId,
  });

  String serialize() {
    return jsonEncode({
      'type': type.name,
      'payload': payload,
      'seq': sequenceNumber,
      'senderId': senderId,
    });
  }

  factory NetworkMessage.deserialize(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return NetworkMessage(
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
      ),
      payload: json['payload'] as Map<String, dynamic>,
      sequenceNumber: json['seq'] as int? ?? 0,
      senderId: json['senderId'] as String,
    );
  }

  // ── Factory constructors for common messages ───────────────────

  factory NetworkMessage.stateUpdate({
    required GameState state,
    required String senderId,
  }) {
    return NetworkMessage(
      type: MessageType.stateUpdate,
      payload: state.toJson(),
      sequenceNumber: state.sequenceNumber,
      senderId: senderId,
    );
  }

  factory NetworkMessage.playerAction({
    required GameAction action,
    required String senderId,
  }) {
    return NetworkMessage(
      type: MessageType.playerAction,
      payload: action.toJson(),
      sequenceNumber: 0,
      senderId: senderId,
    );
  }

  factory NetworkMessage.lobbyUpdate({
    required List<Map<String, dynamic>> players,
    required String senderId,
  }) {
    return NetworkMessage(
      type: MessageType.lobbyUpdate,
      payload: {'players': players},
      sequenceNumber: 0,
      senderId: senderId,
    );
  }

  factory NetworkMessage.gameStart({
    required GameState initialState,
    required String senderId,
  }) {
    return NetworkMessage(
      type: MessageType.gameStart,
      payload: initialState.toJson(),
      sequenceNumber: 0,
      senderId: senderId,
    );
  }

  factory NetworkMessage.ping({required String senderId}) {
    return NetworkMessage(
      type: MessageType.ping,
      payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      sequenceNumber: 0,
      senderId: senderId,
    );
  }

  factory NetworkMessage.pong({required String senderId}) {
    return NetworkMessage(
      type: MessageType.pong,
      payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      sequenceNumber: 0,
      senderId: senderId,
    );
  }
}
