import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nsd/nsd.dart' as nsd;

/// Wraps mDNS/DNS-SD discovery with a UDP broadcast fallback.
/// Used by SocketNetworkService for cross-platform host discovery.
class DiscoveryService {
  static const String serviceType = '_durak._tcp';
  static const int udpDiscoveryPort = 41234;
  static const String udpPrefix = 'DURAK_GAME:';

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  RawDatagramSocket? _udpSocket;
  Timer? _udpBroadcastTimer;

  final _discoveredController = StreamController<DiscoveredHost>.broadcast();

  /// Stream of discovered hosts.
  Stream<DiscoveredHost> get onHostDiscovered => _discoveredController.stream;

  // ── Host: Register Service ─────────────────────────────────────

  /// Register this device as a game host via mDNS + UDP fallback.
  Future<void> registerHost({
    required String hostName,
    required int port,
  }) async {
    // Register via mDNS (works cross-platform: Android + iOS)
    try {
      _registration = await nsd.register(nsd.Service(
        name: hostName,
        type: serviceType,
        port: port,
      ));
    } catch (e) {
      // mDNS registration may fail on some devices; fallback to UDP only
    }

    // Also broadcast via UDP as fallback
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpDiscoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket!.broadcastEnabled = true;

      _udpBroadcastTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _broadcastUdp(hostName, port),
      );
      _broadcastUdp(hostName, port);
    } catch (_) {
      // UDP broadcast not available
    }
  }

  void _broadcastUdp(String hostName, int port) {
    if (_udpSocket == null) return;
    final message = '$udpPrefix$hostName:$port';
    final data = utf8.encode(message);
    try {
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), udpDiscoveryPort);
      _udpSocket!.send(data, InternetAddress('127.0.0.1'), udpDiscoveryPort);
    } catch (_) {}
  }

  // ── Client: Discover Hosts ─────────────────────────────────────

  /// Start discovering game hosts via mDNS + UDP fallback.
  Future<void> startDiscovery() async {
    final seen = <String>{};

    // mDNS discovery
    try {
      _discovery = await nsd.startDiscovery(serviceType,
          ipLookupType: nsd.IpLookupType.any);
      _discovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found && service.name != null) {
          final host = service.addresses?.isNotEmpty == true
              ? service.addresses!.first.address
              : '';
          final port = service.port ?? 0;
          final id = '$host:$port';

          if (host.isNotEmpty && port > 0 && !seen.contains(id)) {
            seen.add(id);
            _discoveredController.add(DiscoveredHost(
              id: id,
              name: service.name!,
              host: host,
              port: port,
              isMdns: true,
            ));
          }
        }
      });
    } catch (_) {
      // mDNS discovery may fail on some devices
    }

    // UDP fallback listener
    try {
      _udpSocket ??= await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpDiscoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram == null) return;

          final message = utf8.decode(datagram.data);
          if (!message.startsWith(udpPrefix)) return;

          final parts = message.substring(udpPrefix.length).split(':');
          if (parts.length < 2) return;

          final hostName = parts[0];
          final port = int.tryParse(parts[1]) ?? 0;
          final hostAddress = datagram.address.address;
          final id = '$hostAddress:$port';

          if (!seen.contains(id) && port > 0) {
            seen.add(id);
            _discoveredController.add(DiscoveredHost(
              id: id,
              name: hostName,
              host: hostAddress,
              port: port,
              isMdns: false,
            ));
          }
        }
      });
    } catch (_) {
      // UDP fallback not available
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────

  /// Stop all discovery and registration.
  Future<void> stopAll() async {
    _udpBroadcastTimer?.cancel();
    _udpBroadcastTimer = null;

    if (_registration != null) {
      try {
        await nsd.unregister(_registration!);
      } catch (_) {}
      _registration = null;
    }

    if (_discovery != null) {
      try {
        await nsd.stopDiscovery(_discovery!);
      } catch (_) {}
      _discovery = null;
    }

    _udpSocket?.close();
    _udpSocket = null;
  }

  Future<void> dispose() async {
    await stopAll();
    await _discoveredController.close();
  }
}

/// A discovered game host.
class DiscoveredHost {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool isMdns;

  DiscoveredHost({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.isMdns,
  });
}
