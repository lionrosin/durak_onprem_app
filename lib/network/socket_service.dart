import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'network_service.dart';

/// Socket-based P2P networking for local multiplayer.
/// Uses TCP for reliable game communication and UDP broadcast for discovery.
/// Works on simulators, real devices on same WiFi, and cross-platform.
class SocketNetworkService implements NetworkService {
  static const int discoveryPort = 41234;
  static const int defaultGamePort = 41235;
  static const String discoveryPrefix = 'DURAK_GAME:';

  // Discovery
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;

  // Host mode
  ServerSocket? _serverSocket;
  final Map<String, _PeerSocket> _clients = {};

  // Client mode
  Socket? _hostConnection;
  String? _hostId;

  // Streams
  final _peerDiscoveredController = StreamController<PeerDevice>.broadcast();
  final _peerConnectedController = StreamController<PeerConnection>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _messageController = StreamController<PeerMessage>.broadcast();

  String? _localName;
  String? _localId;
  bool _isHost = false;

  // ── Host Mode: Advertise & Accept Connections ───────────────────

  @override
  Future<void> startAdvertising({
    required String playerName,
    required String serviceType,
  }) async {
    _localName = playerName;
    _localId = playerName; // Simplified; use UUID in production
    _isHost = true;

    // Start TCP server with dynamic port 0
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0, // Let OS pick an available port!
      shared: true,
    );

    _serverSocket!.listen(_handleClientConnection);

    // Start UDP broadcast for discovery
    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _udpSocket!.broadcastEnabled = true;

    // Broadcast presence periodically
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _broadcastPresence(),
    );
    _broadcastPresence(); // Broadcast immediately
  }

  void _broadcastPresence() {
    if (_udpSocket == null || _localName == null) return;

    final message = '$discoveryPrefix$_localName:${_serverSocket?.port ?? defaultGamePort}';
    final data = utf8.encode(message);

    try {
      // Broadcast to common subnet addresses
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), discoveryPort);
      // Also try localhost for same-machine simulator testing
      _udpSocket!.send(data, InternetAddress('127.0.0.1'), discoveryPort);
    } catch (_) {
      // Ignore broadcast errors
    }
  }

  void _handleClientConnection(Socket socket) {
    final peerId = '${socket.remoteAddress.address}:${socket.remotePort}';

    final peer = _PeerSocket(
      id: peerId,
      socket: socket,
      name: 'Player',
    );
    _clients[peerId] = peer;

    // Set up data listener
    final buffer = StringBuffer();
    socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
        _processBuffer(buffer, peerId);
      },
      onError: (error) {
        _removePeer(peerId);
      },
      onDone: () {
        _removePeer(peerId);
      },
    );
  }

  void _processBuffer(StringBuffer buffer, String peerId) {
    // Messages are newline-delimited JSON
    final content = buffer.toString();
    final lines = content.split('\n');

    // Process complete lines (all but the last which may be incomplete)
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;

        // Handle handshake
        if (json['type'] == '_handshake') {
          final name = json['name'] as String;
          final id = json['id'] as String;

          if (_clients.containsKey(peerId)) {
            _clients[peerId]!.name = name;
            _clients[peerId]!.id = id;
          }

          _peerConnectedController.add(PeerConnection(
            peerId: id,
            peerName: name,
            isConnected: true,
          ));

          // Send handshake response
          _sendRaw(peerId, jsonEncode({
            'type': '_handshake_ack',
            'name': _localName,
            'id': _localId,
          }));
        } else {
          // Regular message
          final senderId = _clients[peerId]?.id ?? peerId;
          _messageController.add(PeerMessage(
            senderId: senderId,
            data: line,
          ));
        }
      } catch (_) {
        // Skip malformed messages
      }
    }

    // Keep the incomplete last part
    buffer.clear();
    if (lines.last.isNotEmpty) {
      buffer.write(lines.last);
    }
  }

  void _removePeer(String peerId) {
    final peer = _clients.remove(peerId);
    if (peer != null) {
      peer.socket.destroy();
      _peerDisconnectedController.add(peer.id);
    }
  }

  // ── Client Mode: Browse & Connect ──────────────────────────────

  @override
  Future<void> startBrowsing({
    required String playerName,
    required String playerId,
    required String serviceType,
  }) async {
    _localName = playerName;
    _localId = playerId;
    _isHost = false;

    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _udpSocket!.broadcastEnabled = true;

    _udpSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data);
        if (!message.startsWith(discoveryPrefix)) return;

        final parts = message.substring(discoveryPrefix.length).split(':');
        if (parts.length < 2) return;

        final hostName = parts[0];
        final port = parts[1];
        final hostAddress = datagram.address.address;
        final peerId = '$hostAddress:$port';

        _peerDiscoveredController.add(PeerDevice(
          id: peerId,
          name: hostName,
          isAvailable: true,
        ));
      }
    });
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    try {
      final parts = peerId.split(':');
      final host = parts[0];
      final port = int.parse(parts[1]);

      _hostConnection = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
      _hostId = peerId;

      // Set up listener
      final buffer = StringBuffer();
      _hostConnection!.listen(
        (data) {
          buffer.write(utf8.decode(data));
          _processHostBuffer(buffer);
        },
        onError: (error) {
          _peerDisconnectedController.add(_hostId ?? peerId);
          _hostConnection = null;
        },
        onDone: () {
          _peerDisconnectedController.add(_hostId ?? peerId);
          _hostConnection = null;
        },
      );

      // Send handshake
      _sendToHost(jsonEncode({
        'type': '_handshake',
        'name': _localName ?? 'Player',
        'id': _localId ?? 'unknown',
      }));

      return true;
    } catch (e) {
      return false;
    }
  }

  void _processHostBuffer(StringBuffer buffer) {
    final content = buffer.toString();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;

        if (json['type'] == '_handshake_ack') {
          final name = json['name'] as String;
          final id = json['id'] as String;
          _hostId = id;
          _peerConnectedController.add(PeerConnection(
            peerId: id,
            peerName: name,
            isConnected: true,
          ));
        } else {
          _messageController.add(PeerMessage(
            senderId: _hostId ?? 'host',
            data: line,
          ));
        }
      } catch (_) {}
    }

    buffer.clear();
    if (lines.last.isNotEmpty) {
      buffer.write(lines.last);
    }
  }

  void _sendToHost(String data) {
    if (_hostConnection != null) {
      try {
        _hostConnection!.write('$data\n');
      } catch (_) {
        // Ignore write errors to closed sockets
      }
    }
  }

  void _sendRaw(String peerId, String data) {
    final peer = _clients[peerId];
    if (peer != null) {
      try {
        peer.socket.write('$data\n');
      } catch (_) {
        _removePeer(peerId);
      }
    }
  }

  // ── Common Interface ───────────────────────────────────────────

  @override
  Future<void> stopAdvertising() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    await _serverSocket?.close();
    _serverSocket = null;
  }

  @override
  Future<void> stopBrowsing() async {
    _udpSocket?.close();
    _udpSocket = null;
  }

  @override
  Future<void> disconnectFromPeer(String peerId) async {
    if (_isHost) {
      _removePeer(peerId);
    } else {
      _hostConnection?.destroy();
      _hostConnection = null;
    }
  }

  @override
  Future<void> disconnectAll() async {
    for (final peer in _clients.values.toList()) {
      peer.socket.destroy();
    }
    _clients.clear();
    _hostConnection?.destroy();
    _hostConnection = null;
  }

  @override
  Future<void> sendMessage(String peerId, String data) async {
    if (_isHost) {
      // Find client by their logical ID
      for (final entry in _clients.entries) {
        if (entry.value.id == peerId) {
          _sendRaw(entry.key, data);
          return;
        }
      }
    } else {
      _sendToHost(data);
    }
  }

  @override
  Future<void> broadcastMessage(String data) async {
    if (_isHost) {
      for (final peerId in _clients.keys.toList()) {
        _sendRaw(peerId, data);
      }
    } else {
      _sendToHost(data);
    }
  }

  @override
  Stream<PeerDevice> get onPeerDiscovered => _peerDiscoveredController.stream;

  @override
  Stream<PeerConnection> get onPeerConnected => _peerConnectedController.stream;

  @override
  Stream<String> get onPeerDisconnected => _peerDisconnectedController.stream;

  @override
  Stream<PeerMessage> get onMessageReceived => _messageController.stream;

  @override
  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    await disconnectAll();
    await _serverSocket?.close();
    _udpSocket?.close();
    await _peerDiscoveredController.close();
    await _peerConnectedController.close();
    await _peerDisconnectedController.close();
    await _messageController.close();
  }
}

class _PeerSocket {
  String id;
  final Socket socket;
  String name;

  _PeerSocket({
    required this.id,
    required this.socket,
    required this.name,
  });
}
