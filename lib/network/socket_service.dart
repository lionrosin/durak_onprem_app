import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'discovery_service.dart';

/// Socket-based P2P networking for local multiplayer.
/// Uses TCP for reliable game communication and mDNS + UDP broadcast for discovery.
/// Works on real devices on same WiFi, simulators, and cross-platform (Android ↔ iOS).
class SocketNetworkService implements NetworkService {
  static const int defaultGamePort = 41235;

  // Discovery
  final DiscoveryService _discovery = DiscoveryService();
  StreamSubscription? _discoverySubscription;

  // Host mode
  ServerSocket? _serverSocket;
  final Map<String, _PeerSocket> _clients = {};

  // Client mode
  Socket? _hostConnection;
  String? _hostId;

  // Heartbeat
  Timer? _heartbeatTimer;
  final Map<String, DateTime> _lastHeartbeat = {};
  static const Duration _heartbeatInterval = Duration(seconds: 5);
  static const Duration _heartbeatTimeout = Duration(seconds: 15);

  // Reconnection
  Timer? _reconnectTimer;
  String? _lastHostId;

  // Streams
  final _peerDiscoveredController = StreamController<PeerDevice>.broadcast();
  final _peerConnectedController = StreamController<PeerConnection>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _messageController = StreamController<PeerMessage>.broadcast();

  String? _localName;
  String? _localId;
  bool _isHost = false;

  @override
  ConnectionMode get connectionMode => ConnectionMode.wifi;

  // ── Host Mode: Advertise & Accept Connections ───────────────────

  @override
  Future<void> startAdvertising({
    required String playerName,
    required String serviceType,
  }) async {
    _localName = playerName;
    _localId = playerName; // Simplified; use UUID in production
    _isHost = true;

    // Start TCP server with dynamic port
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0, // Let OS pick an available port!
      shared: true,
    );

    _serverSocket!.listen(_handleClientConnection);

    final gamePort = _serverSocket!.port;

    // Register with mDNS + UDP broadcast via DiscoveryService
    await _discovery.registerHost(
      hostName: playerName,
      port: gamePort,
    );

    // Start heartbeat timer
    _startHeartbeat();
  }

  void _handleClientConnection(Socket socket) {
    final peerId = '${socket.remoteAddress.address}:${socket.remotePort}';

    final peer = _PeerSocket(
      id: peerId,
      socket: socket,
      name: 'Player',
    );
    _clients[peerId] = peer;
    _lastHeartbeat[peerId] = DateTime.now();

    // Set up data listener
    final buffer = StringBuffer();
    socket.listen(
      (data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
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
          final platform = json['platform'] as String? ?? 'unknown';

          if (_clients.containsKey(peerId)) {
            _clients[peerId]!.name = name;
            _clients[peerId]!.id = id;
            _clients[peerId]!.platform =
                PeerPlatform.fromString(platform);
          }

          _lastHeartbeat[peerId] = DateTime.now();

          _peerConnectedController.add(PeerConnection(
            peerId: id,
            peerName: name,
            isConnected: true,
            platform: PeerPlatform.fromString(platform),
          ));

          // Send handshake response
          _sendRaw(peerId, jsonEncode({
            'type': '_handshake_ack',
            'name': _localName,
            'id': _localId,
            'platform': PeerPlatform.current.name,
          }));
        } else if (json['type'] == 'heartbeat_ack') {
          // Update last heartbeat time
          _lastHeartbeat[peerId] = DateTime.now();
        } else {
          // Regular message — update heartbeat
          _lastHeartbeat[peerId] = DateTime.now();
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
    _lastHeartbeat.remove(peerId);
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

    // Subscribe to discovery service (mDNS + UDP fallback)
    _discoverySubscription = _discovery.onHostDiscovered.listen((host) {
      _peerDiscoveredController.add(PeerDevice(
        id: '${host.host}:${host.port}',
        name: host.name,
        isAvailable: true,
        connectionMode: ConnectionMode.wifi,
      ));
    });

    await _discovery.startDiscovery();
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    final parts = peerId.split(':');
    if (parts.length < 2) return false;
    final primaryHost = parts[0];
    final port = int.tryParse(parts[1]);
    if (port == null) return false;

    // Build a list of candidate IPs to try.
    final candidates = <String>[primaryHost];

    // If targeting an Android emulator IP (10.0.2.x), auto-setup adb forward
    // so we can reach it via localhost from the iOS simulator.
    if (primaryHost.startsWith('10.0.2.')) {
      await _tryAdbForward(port);
      // Put localhost BEFORE the unreachable emulator IP
      candidates.insert(0, '127.0.0.1');
    } else {
      if (!candidates.contains('127.0.0.1')) {
        candidates.add('127.0.0.1');
      }
    }

    if (!candidates.contains('10.0.2.2')) {
      candidates.add('10.0.2.2'); // Android emulator → host machine
    }

    debugPrint('[Socket] Connection candidates for port $port: $candidates');

    for (final host in candidates) {
      try {
        debugPrint('[Socket] Trying $host:$port...');

        _hostConnection = await Socket.connect(host, port,
            timeout: const Duration(seconds: 5));

        debugPrint('[Socket] ✓ Connected to $host:$port');
        _hostId = peerId;

        // Set up listener
        final buffer = StringBuffer();
        _hostConnection!.listen(
          (data) {
            buffer.write(utf8.decode(data, allowMalformed: true));
            _processHostBuffer(buffer);
          },
          onError: (error) {
            debugPrint('[Socket] Connection error: $error');
            _handleHostDisconnect();
          },
          onDone: () {
            debugPrint('[Socket] Connection closed by host');
            _handleHostDisconnect();
          },
        );

        // Send handshake with platform info
        _sendToHost(jsonEncode({
          'type': '_handshake',
          'name': _localName ?? 'Player',
          'id': _localId ?? 'unknown',
          'platform': PeerPlatform.current.name,
        }));

        return true;
      } catch (e) {
        debugPrint('[Socket] ✗ $host:$port failed: $e');
      }
    }

    debugPrint('[Socket] All connection candidates failed for port $port');
    return false;
  }

  /// Try to run `adb forward` to expose the Android emulator's port on localhost.
  /// Only works when running on the iOS simulator (macOS process) or macOS desktop.
  /// Fails silently on real iOS devices.
  Future<void> _tryAdbForward(int port) async {
    try {
      // Try to find adb
      final home = Platform.environment['HOME'] ?? '';
      final candidates = [
        '$home/Library/Android/sdk/platform-tools/adb',
        '/usr/local/bin/adb',
        '/opt/homebrew/bin/adb',
      ];

      for (final adbPath in candidates) {
        if (await File(adbPath).exists()) {
          debugPrint('[Socket] Running: $adbPath forward tcp:$port tcp:$port');
          final result = await Process.run(
            adbPath,
            ['forward', 'tcp:$port', 'tcp:$port'],
          );
          if (result.exitCode == 0) {
            debugPrint('[Socket] ✓ adb forward succeeded for port $port');
          } else {
            debugPrint('[Socket] ✗ adb forward failed: ${result.stderr}');
          }
          return;
        }
      }
      debugPrint('[Socket] adb not found — skipping port forward');
    } catch (e) {
      // Expected on real iOS devices where Process.run isn't available
      debugPrint('[Socket] adb forward not available: $e');
    }
  }

  void _handleHostDisconnect() {
    _hostConnection?.destroy();
    _hostConnection = null;
    _reconnectTimer?.cancel();

    debugPrint('[Socket] Host disconnected — notifying listeners');

    // Emit disconnect immediately so the UI can react.
    // The game should end or return to menu when the host leaves.
    _peerDisconnectedController.add(_hostId ?? _lastHostId ?? '');
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
          final platform = json['platform'] as String? ?? 'unknown';
          _hostId = id;
          _lastHostId = id;
          _peerConnectedController.add(PeerConnection(
            peerId: id,
            peerName: name,
            isConnected: true,
            platform: PeerPlatform.fromString(platform),
          ));
        } else if (json['type'] == 'heartbeat') {
          // Reply with heartbeat ack
          _sendToHost(jsonEncode({'type': 'heartbeat_ack'}));
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

  // ── Heartbeat ──────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isHost) {
        // Send heartbeat to all clients + check for stale
        final now = DateTime.now();
        for (final entry in _clients.entries.toList()) {
          final last = _lastHeartbeat[entry.key];
          if (last != null && now.difference(last) > _heartbeatTimeout) {
            // Client timed out
            _removePeer(entry.key);
          } else {
            try {
              entry.value.socket.write(
                  '${jsonEncode({"type": "heartbeat"})}\n');
            } catch (_) {
              _removePeer(entry.key);
            }
          }
        }
      }
    });
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _discovery.stopAll();
    await _serverSocket?.close();
    _serverSocket = null;
  }

  @override
  Future<void> stopBrowsing() async {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _discovery.stopAll();
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final peer in _clients.values.toList()) {
      peer.socket.destroy();
    }
    _clients.clear();
    _lastHeartbeat.clear();
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
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await disconnectAll();
    await _serverSocket?.close();
    await _discovery.dispose();
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
  PeerPlatform platform;

  _PeerSocket({
    required this.id,
    required this.socket,
    required this.name,
    this.platform = PeerPlatform.unknown, // ignore: unused_element_parameter
  });
}
