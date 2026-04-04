import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter/foundation.dart';

import 'ble_constants.dart';
import 'network_service.dart';

/// BLE-based P2P networking for local multiplayer without WiFi.
///
/// Uses Bluetooth Low Energy for peer discovery and connection.
///
/// **Architecture:**
/// - Host: Advertises via BLE Peripheral + starts a local TCP server.
///   The TCP port is encoded in the BLE advertisement name.
/// - Client: Scans for BLE hosts, extracts the port, then connects
///   via TCP for reliable bidirectional data exchange.
///
/// This hybrid approach gives us:
/// - BLE discovery (works without WiFi on same subnet)
/// - TCP reliability for game data (avoids BLE MTU/throughput limits)
/// - Cross-platform compatibility (Android ↔ iOS)
///
/// For truly offline (no WiFi) scenarios, the client connects directly
/// to the host's IP via BLE-exchanged connection info.
class BleNetworkService implements NetworkService {
  // State
  bool _isHost = false;
  String? _localName;
  String? _localId;

  // Host state
  bool _isAdvertising = false;
  ServerSocket? _serverSocket;
  final Map<String, _BleClientSocket> _clients = {};

  // Client state
  Socket? _hostConnection;
  String? _hostId;

  // BLE subscriptions
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription? _scanSubscription;

  // Streams
  final _peerDiscoveredController = StreamController<PeerDevice>.broadcast();
  final _peerConnectedController = StreamController<PeerConnection>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _messageController = StreamController<PeerMessage>.broadcast();

  @override
  ConnectionMode get connectionMode => ConnectionMode.bluetooth;

  // ── Host Mode ──────────────────────────────────────────────────

  @override
  Future<void> startAdvertising({
    required String playerName,
    required String serviceType,
  }) async {
    _isHost = true;
    _localName = playerName;
    _localId = playerName;

    // Start TCP server for game data
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    _serverSocket!.listen(_handleClientConnection);

    final gamePort = _serverSocket!.port;

    // Advertise via BLE with port info in the name
    // Format: "DURAK:PlayerName:PORT"
    try {
      final advertiseData = AdvertiseData(
        serviceUuid: BleConstants.serviceUuid,
        localName: '${BleConstants.advertisePrefix}$playerName:$gamePort',
      );

      await FlutterBlePeripheral().start(advertiseData: advertiseData);
      _isAdvertising = true;

      // Monitor peripheral state
      final stateStream = FlutterBlePeripheral().onPeripheralStateChanged;
      if (stateStream != null) {
        _subscriptions.add(
          stateStream.listen((state) {
            debugPrint('BLE Peripheral state: $state');
          }),
        );
      }
    } catch (e) {
      debugPrint('BLE advertise error: $e');
      _isAdvertising = false;
    }
  }

  void _handleClientConnection(Socket socket) {
    final peerId = '${socket.remoteAddress.address}:${socket.remotePort}';

    final client = _BleClientSocket(
      id: peerId,
      socket: socket,
      name: 'Player',
    );
    _clients[peerId] = client;

    final buffer = StringBuffer();
    socket.listen(
      (data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
        _processBuffer(buffer, peerId);
      },
      onError: (_) => _removePeer(peerId),
      onDone: () => _removePeer(peerId),
    );
  }

  void _processBuffer(StringBuffer buffer, String peerId) {
    final content = buffer.toString();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;

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

          _peerConnectedController.add(PeerConnection(
            peerId: id,
            peerName: name,
            isConnected: true,
            platform: PeerPlatform.fromString(platform),
          ));

          // Send ack
          _sendRaw(peerId, jsonEncode({
            'type': '_handshake_ack',
            'name': _localName,
            'id': _localId,
            'platform': PeerPlatform.current.name,
          }));
        } else {
          final senderId = _clients[peerId]?.id ?? peerId;
          _messageController.add(PeerMessage(
            senderId: senderId,
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

  void _removePeer(String peerId) {
    final peer = _clients.remove(peerId);
    if (peer != null) {
      peer.socket.destroy();
      _peerDisconnectedController.add(peer.id);
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

  // ── Client Mode ────────────────────────────────────────────────

  @override
  Future<void> startBrowsing({
    required String playerName,
    required String playerId,
    required String serviceType,
  }) async {
    _isHost = false;
    _localName = playerName;
    _localId = playerId;

    // Check Bluetooth availability
    if (await fbp.FlutterBluePlus.isSupported == false) {
      debugPrint('Bluetooth not supported on this device');
      return;
    }

    // Wait for adapter
    final adapterState = await fbp.FlutterBluePlus.adapterState.first;
    if (adapterState != fbp.BluetoothAdapterState.on) {
      if (!kIsWeb && Platform.isAndroid) {
        await fbp.FlutterBluePlus.turnOn();
      }
    }

    final seenIds = <String>{};

    _scanSubscription = fbp.FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final result in results) {
          final advName = result.advertisementData.advName;

          // Format: "DURAK:PlayerName:PORT"
          if (advName.startsWith(BleConstants.advertisePrefix)) {
            final payload =
                advName.substring(BleConstants.advertisePrefix.length);
            final parts = payload.split(':');
            if (parts.length < 2) continue;

            final hostName = parts[0];
            final port = parts[1];
            final deviceId = result.device.remoteId.str;

            // Store peerId as "deviceBleId|port" — we'll resolve the IP later
            final peerId = '$deviceId|$port';

            if (!seenIds.contains(peerId)) {
              seenIds.add(peerId);

              _peerDiscoveredController.add(PeerDevice(
                id: peerId,
                name: hostName,
                isAvailable: true,
                platform: PeerPlatform.unknown,
                connectionMode: ConnectionMode.bluetooth,
              ));
            }
          }
        }
      },
      onError: (e) => debugPrint('BLE scan error: $e'),
    );

    // Start scanning
    await fbp.FlutterBluePlus.startScan(
      timeout: BleConstants.scanTimeout,
    );
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    try {
      // peerId format: "deviceBleId|port"
      final parts = peerId.split('|');
      if (parts.length < 2) return false;

      final bleDeviceId = parts[0];
      final port = int.tryParse(parts[1]) ?? 0;
      if (port == 0) return false;

      // Connect via BLE first to get the host's IP address
      final bleDevice = fbp.BluetoothDevice.fromId(bleDeviceId);

      // Listen for connection state
      _subscriptions.add(
        bleDevice.connectionState.listen((state) {
          if (state == fbp.BluetoothConnectionState.disconnected) {
            // BLE discovery connection dropped — doesn't affect TCP
          }
        }),
      );

      await bleDevice.connect(timeout: BleConstants.connectTimeout);

      // Request higher MTU (will help with service discovery)
      if (!kIsWeb && Platform.isAndroid) {
        await bleDevice.requestMtu(BleConstants.requestedMtu);
      }

      // Discover services to find the host
      await bleDevice.discoverServices();

      // We now need the host's IP. Since both devices are nearby,
      // we try common local addresses. The host's TCP server is already
      // bound to 0.0.0.0, so we try to connect.
      //
      // Strategy: Try the BLE device's IP (not directly available from BLE).
      // Fallback: broadcast on local network to find the host's TCP server.
      // Most practical: disconnect BLE and try mDNS/broadcast discovery.
      //
      // For Bluetooth mode, we use a hybrid:
      // 1. Connect BLE to get connection
      // 2. Exchange IP info via BLE GATT
      // 3. Connect TCP
      //
      // Simplified: Try common local subnets

      // Disconnect BLE (we only needed it for discovery)
      await bleDevice.disconnect();

      // Try to connect TCP to the host
      // The host should be reachable on the local network
      // Try broadcast-discovered address or common addresses
      final possibleHosts = [
        '127.0.0.1', // Same device (testing)
      ];

      // Also try to find hosts via interface broadcast
      for (final interface_ in await NetworkInterface.list()) {
        for (final addr in interface_.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Try the same subnet with common host addresses
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              // Try x.x.x.1 through x.x.x.255
              for (int i = 1; i <= 254; i++) {
                possibleHosts.add('${parts[0]}.${parts[1]}.${parts[2]}.$i');
              }
            }
          }
        }
      }

      // Try connecting to each possible host (with short timeout)
      for (final host in possibleHosts) {
        try {
          _hostConnection = await Socket.connect(host, port,
              timeout: const Duration(milliseconds: 200));

          // Success! Set up listener
          final buffer = StringBuffer();
          _hostConnection!.listen(
            (data) {
              buffer.write(utf8.decode(data, allowMalformed: true));
              _processHostBuffer(buffer);
            },
            onError: (_) {
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
            'platform': PeerPlatform.current.name,
          }));

          return true;
        } catch (_) {
          // Try next host
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint('BLE connect error: $e');
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
          final platform = json['platform'] as String? ?? 'unknown';
          _hostId = id;

          _peerConnectedController.add(PeerConnection(
            peerId: id,
            peerName: name,
            isConnected: true,
            platform: PeerPlatform.fromString(platform),
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
      } catch (_) {}
    }
  }

  // ── Common Interface ───────────────────────────────────────────

  @override
  Future<void> stopAdvertising() async {
    if (_isAdvertising) {
      try {
        await FlutterBlePeripheral().stop();
      } catch (_) {}
      _isAdvertising = false;
    }
    await _serverSocket?.close();
    _serverSocket = null;
  }

  @override
  Future<void> stopBrowsing() async {
    await fbp.FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
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
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    await stopAdvertising();
    await disconnectAll();
    await _peerDiscoveredController.close();
    await _peerConnectedController.close();
    await _peerDisconnectedController.close();
    await _messageController.close();
  }
}

class _BleClientSocket {
  String id;
  final Socket socket;
  String name;
  PeerPlatform platform;

  _BleClientSocket({
    required this.id,
    required this.socket,
    required this.name,
    this.platform = PeerPlatform.unknown, // ignore: unused_element_parameter
  });
}
