import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    // Get our local IPs to embed in the mDNS TXT record
    final localIps = await _getLocalIpAddresses();
    debugPrint('[Discovery] Host IPs: $localIps');

    if (localIps.isEmpty) {
      debugPrint('[Discovery] WARNING: No local network IPs found!');
    }

    // Warn if only emulator IPs are available
    final hasRealIp = localIps.any((ip) => !ip.startsWith('10.0.2.'));
    if (!hasRealIp && localIps.isNotEmpty) {
      debugPrint('[Discovery] WARNING: Only emulator IPs detected (10.0.2.x). '
          'Cross-device connections may not work. '
          'For emulator↔simulator testing, use: '
          'adb forward tcp:$port tcp:$port');
    }

    // Register via mDNS — include IPs in TXT record as fallback
    try {
      _registration = await nsd.register(nsd.Service(
        name: hostName,
        type: serviceType,
        port: port,
        txt: {
          'ips': Uint8List.fromList(utf8.encode(localIps.join(','))),
        },
      ));
      debugPrint('[Discovery] mDNS registered: $hostName on port $port');
    } catch (e) {
      debugPrint('[Discovery] mDNS registration failed: $e');
    }

    // Also broadcast via UDP as fallback — include our actual IP addresses
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
    } catch (e) {
      debugPrint('[Discovery] UDP broadcast setup failed: $e');
    }
  }

  /// Get all local IPv4 addresses for this device.
  Future<List<String>> _getLocalIpAddresses() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            result.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return result;
  }

  void _broadcastUdp(String hostName, int port) async {
    if (_udpSocket == null) return;

    // Include our local IP addresses in the broadcast so clients
    // know exactly where to connect (avoids mDNS hostname resolution issues)
    final localIps = await _getLocalIpAddresses();
    final ipsJoined = localIps.join(',');

    // Format: DURAK_GAME:hostName:port:ip1,ip2,...
    final message = '$udpPrefix$hostName:$port:$ipsJoined';
    final data = utf8.encode(message);
    try {
      _udpSocket!.send(
          data, InternetAddress('255.255.255.255'), udpDiscoveryPort);
      // Also send to localhost (for simulator testing)
      _udpSocket!.send(
          data, InternetAddress('127.0.0.1'), udpDiscoveryPort);

      // Send to subnet broadcast addresses
      for (final ip in localIps) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          try {
            _udpSocket!.send(data,
                InternetAddress(subnetBroadcast), udpDiscoveryPort);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ── Client: Discover Hosts ─────────────────────────────────────

  /// Start discovering game hosts via mDNS + UDP fallback.
  Future<void> startDiscovery() async {
    final seen = <String>{};

    // mDNS discovery
    try {
      _discovery = await nsd.startDiscovery(serviceType,
          ipLookupType: nsd.IpLookupType.v4);
      _discovery!.addServiceListener((service, status) async {
        if (status == nsd.ServiceStatus.found && service.name != null) {
          debugPrint('[Discovery] mDNS found: name=${service.name}, '
              'host=${service.host}, port=${service.port}, '
              'addresses=${service.addresses?.map((a) => a.address).toList()}');

          String resolvedHost = '';

          // 1. Try addresses from auto-resolve + IP lookup
          if (service.addresses != null && service.addresses!.isNotEmpty) {
            // Prefer IPv4 addresses
            for (final addr in service.addresses!) {
              if (addr.type == InternetAddressType.IPv4) {
                resolvedHost = addr.address;
                break;
              }
            }
            // Fall back to any address
            if (resolvedHost.isEmpty) {
              resolvedHost = service.addresses!.first.address;
            }
          }

          // 2. If no addresses yet, try resolving the hostname ourselves
          if (resolvedHost.isEmpty && service.host != null) {
            resolvedHost = await _resolveHostname(service.host!);
          }

          // 3. If still empty, try resolving the service again manually
          if (resolvedHost.isEmpty) {
            try {
              final resolved = await nsd.resolve(service);
              debugPrint('[Discovery] Re-resolved: '
                  'host=${resolved.host}, '
                  'addresses=${resolved.addresses?.map((a) => a.address).toList()}');

              if (resolved.addresses != null &&
                  resolved.addresses!.isNotEmpty) {
                for (final addr in resolved.addresses!) {
                  if (addr.type == InternetAddressType.IPv4) {
                    resolvedHost = addr.address;
                    break;
                  }
                }
                if (resolvedHost.isEmpty) {
                  resolvedHost = resolved.addresses!.first.address;
                }
              }

              if (resolvedHost.isEmpty && resolved.host != null) {
                resolvedHost = await _resolveHostname(resolved.host!);
              }
            } catch (e) {
              debugPrint('[Discovery] Re-resolve failed: $e');
            }
          }

          // 4. Try extracting IPs from the TXT record (host embeds them)
          if (resolvedHost.isEmpty) {
            final txtIpsBytes = service.txt?['ips'];
            final txtIps = txtIpsBytes != null
                ? utf8.decode(txtIpsBytes, allowMalformed: true)
                : null;
            if (txtIps != null && txtIps.isNotEmpty) {
              final ips = txtIps.split(',');
              for (final ip in ips) {
                if (ip.isNotEmpty && !ip.startsWith('10.0.2.')) {
                  resolvedHost = ip;
                  debugPrint('[Discovery] Using IP from TXT record: $ip');
                  break;
                }
              }
              // Fall back to emulator IP if nothing else
              if (resolvedHost.isEmpty && ips.isNotEmpty) {
                resolvedHost = ips.first;
                debugPrint('[Discovery] Using emulator IP from TXT: ${ips.first}');
              }
            }
          }

          final port = service.port ?? 0;
          final id = '$resolvedHost:$port';

          if (resolvedHost.isNotEmpty && port > 0 && !seen.contains(id)) {
            seen.add(id);
            debugPrint('[Discovery] Emitting discovered host: '
                '${service.name} at $resolvedHost:$port');
            _discoveredController.add(DiscoveredHost(
              id: id,
              name: service.name!,
              host: resolvedHost,
              port: port,
              isMdns: true,
            ));
          } else if (resolvedHost.isEmpty) {
            debugPrint('[Discovery] WARNING: Could not resolve IP for '
                '${service.name} (host=${service.host})');
          }
        }
      });
    } catch (e) {
      debugPrint('[Discovery] mDNS discovery start failed: $e');
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

          // Format: DURAK_GAME:hostName:port:ip1,ip2,...
          final payload = message.substring(udpPrefix.length);
          final parts = payload.split(':');
          if (parts.length < 2) return;

          final hostName = parts[0];
          final port = int.tryParse(parts[1]) ?? 0;

          // Determine best host address:
          // 1. Use the explicit IPs from the broadcast (if present)
          // 2. Fall back to the datagram source address
          String hostAddress = datagram.address.address;

          if (parts.length >= 3 && parts[2].isNotEmpty) {
            // Prefer the explicit IPs from the host
            final explicitIps = parts[2].split(',');
            if (explicitIps.isNotEmpty) {
              // Use the first non-loopback IP
              for (final ip in explicitIps) {
                if (ip.isNotEmpty && ip != '127.0.0.1') {
                  hostAddress = ip;
                  break;
                }
              }
            }
          }

          final id = '$hostAddress:$port';

          if (!seen.contains(id) && port > 0) {
            seen.add(id);
            debugPrint('[Discovery] UDP found: $hostName at $hostAddress:$port');
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
    } catch (e) {
      debugPrint('[Discovery] UDP listener failed: $e');
    }
  }

  /// Attempt to resolve an mDNS hostname to an IPv4 address.
  /// This handles the common cross-platform issue where Android can't
  /// resolve ".local" hostnames natively.
  Future<String> _resolveHostname(String hostname) async {
    try {
      // Try standard DNS lookup first
      final addresses = await InternetAddress.lookup(hostname,
          type: InternetAddressType.IPv4);
      if (addresses.isNotEmpty) {
        debugPrint('[Discovery] Resolved $hostname -> ${addresses.first.address}');
        return addresses.first.address;
      }
    } catch (_) {
      debugPrint('[Discovery] DNS lookup failed for $hostname');
    }

    // If the hostname looks like an IP address already, use it directly
    final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (ipRegex.hasMatch(hostname)) {
      return hostname;
    }

    // Try lookup without specifying type
    try {
      final addresses = await InternetAddress.lookup(hostname);
      for (final addr in addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          debugPrint('[Discovery] Resolved $hostname -> ${addr.address} (any)');
          return addr.address;
        }
      }
      // Fall back to IPv6 if only that's available
      if (addresses.isNotEmpty) {
        debugPrint('[Discovery] Resolved $hostname -> ${addresses.first.address} (v6)');
        return addresses.first.address;
      }
    } catch (_) {
      debugPrint('[Discovery] All DNS lookups failed for $hostname');
    }

    return '';
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
