import 'dart:async';
import 'network_service.dart';

// Note: This is a placeholder implementation.
// The actual implementation requires the flutter_nearby_connections_plus package.
// It will be wired up after dependencies are installed.
// For now, the app works in single-player (AI) mode.

/// Implementation of NetworkService using flutter_nearby_connections_plus.
/// Wraps Google Nearby Connections API (Android) and Multipeer Connectivity (iOS).
class NearbyServiceImpl implements NetworkService {
  static const String defaultServiceType = 'durak-game';

  final _peerDiscoveredController = StreamController<PeerDevice>.broadcast();
  final _peerConnectedController = StreamController<PeerConnection>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _messageController = StreamController<PeerMessage>.broadcast();

  bool _isAdvertising = false;
  bool _isBrowsing = false;
  final Map<String, String> _connectedPeers = {}; // peerId -> peerName

  @override
  Future<void> startAdvertising({
    required String playerName,
    required String serviceType,
  }) async {
    // TODO: Initialize flutter_nearby_connections_plus
    // nearbyService.init(
    //   serviceType: serviceType,
    //   strategy: Strategy.P2P_CLUSTER,
    //   callback: (isRunning) async {
    //     if (isRunning) {
    //       await nearbyService.startAdvertisingPeer();
    //       _isAdvertising = true;
    //     }
    //   },
    // );
    _isAdvertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
  }

  @override
  Future<void> startBrowsing({
    required String playerName,
    required String playerId,
    required String serviceType,
  }) async {
    _isBrowsing = true;
  }

  @override
  Future<void> stopBrowsing() async {
    _isBrowsing = false;
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    return false;
  }

  @override
  Future<void> disconnectFromPeer(String peerId) async {
    _connectedPeers.remove(peerId);
  }

  @override
  Future<void> disconnectAll() async {
    _connectedPeers.clear();
  }

  @override
  Future<void> sendMessage(String peerId, String data) async {
    // TODO: Use nearbyService.sendMessage(peerId, data)
  }

  @override
  Future<void> broadcastMessage(String data) async {
    for (final peerId in _connectedPeers.keys) {
      await sendMessage(peerId, data);
    }
  }

  @override
  Stream<PeerDevice> get onPeerDiscovered => _peerDiscoveredController.stream;

  @override
  Stream<PeerConnection> get onPeerConnected =>
      _peerConnectedController.stream;

  @override
  Stream<String> get onPeerDisconnected =>
      _peerDisconnectedController.stream;

  @override
  Stream<PeerMessage> get onMessageReceived => _messageController.stream;

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await stopBrowsing();
    await disconnectAll();
    await _peerDiscoveredController.close();
    await _peerConnectedController.close();
    await _peerDisconnectedController.close();
    await _messageController.close();
  }
}
