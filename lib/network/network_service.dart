/// Abstract interface for P2P connectivity.
/// Implementations handle platform-specific details.
abstract class NetworkService {
  /// Start advertising this device as a game host.
  Future<void> startAdvertising({
    required String playerName,
    required String serviceType,
  });

  /// Stop advertising.
  Future<void> stopAdvertising();

  /// Start browsing for nearby game hosts.
  Future<void> startBrowsing({
    required String playerName,
    required String playerId,
    required String serviceType,
  });

  /// Stop browsing.
  Future<void> stopBrowsing();

  /// Connect to a discovered peer.
  Future<bool> connectToPeer(String peerId);

  /// Disconnect from a peer.
  Future<void> disconnectFromPeer(String peerId);

  /// Disconnect from all peers.
  Future<void> disconnectAll();

  /// Send a message to a specific peer.
  Future<void> sendMessage(String peerId, String data);

  /// Broadcast a message to all connected peers.
  Future<void> broadcastMessage(String data);

  /// Stream of discovered peers.
  Stream<PeerDevice> get onPeerDiscovered;

  /// Stream of peer connection events.
  Stream<PeerConnection> get onPeerConnected;

  /// Stream of peer disconnection events.
  Stream<String> get onPeerDisconnected;

  /// Stream of received messages.
  Stream<PeerMessage> get onMessageReceived;

  /// Clean up resources.
  Future<void> dispose();
}

/// Represents a discovered nearby device.
class PeerDevice {
  final String id;
  final String name;
  final bool isAvailable;

  PeerDevice({
    required this.id,
    required this.name,
    this.isAvailable = true,
  });
}

/// Represents a peer connection event.
class PeerConnection {
  final String peerId;
  final String peerName;
  final bool isConnected;

  PeerConnection({
    required this.peerId,
    required this.peerName,
    required this.isConnected,
  });
}

/// Represents a message received from a peer.
class PeerMessage {
  final String senderId;
  final String data;

  PeerMessage({
    required this.senderId,
    required this.data,
  });
}
