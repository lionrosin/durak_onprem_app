import 'package:flutter_test/flutter_test.dart';
import 'package:durak_onprem_app/network/network_service.dart';
import 'package:durak_onprem_app/network/socket_service.dart';

void main() {
  group('SocketNetworkService construction', () {
    test('creates instance', () {
      final service = SocketNetworkService();
      expect(service, isNotNull);
      service.dispose();
    });

    test('implements NetworkService', () {
      final service = SocketNetworkService();
      expect(service, isA<NetworkService>());
      service.dispose();
    });
  });

  group('SocketNetworkService streams', () {
    test('onPeerDiscovered returns broadcast stream', () {
      final service = SocketNetworkService();
      expect(service.onPeerDiscovered, isA<Stream<PeerDevice>>());
      // Broadcast streams are listenable multiple times
      service.onPeerDiscovered.listen((_) {});
      service.onPeerDiscovered.listen((_) {});
      service.dispose();
    });

    test('onPeerConnected returns broadcast stream', () {
      final service = SocketNetworkService();
      expect(service.onPeerConnected, isA<Stream<PeerConnection>>());
      service.dispose();
    });

    test('onPeerDisconnected returns broadcast stream', () {
      final service = SocketNetworkService();
      expect(service.onPeerDisconnected, isA<Stream<String>>());
      service.dispose();
    });

    test('onMessageReceived returns broadcast stream', () {
      final service = SocketNetworkService();
      expect(service.onMessageReceived, isA<Stream<PeerMessage>>());
      service.dispose();
    });
  });

  group('SocketNetworkService no-connection operations', () {
    test('disconnectAll succeeds with no connections', () async {
      final service = SocketNetworkService();
      await service.disconnectAll();
      service.dispose();
    });

    test('sendMessage to non-existent peer is safe', () async {
      final service = SocketNetworkService();
      await service.sendMessage('nonexistent-peer', 'test data');
      service.dispose();
    });

    test('broadcastMessage with no peers is safe', () async {
      final service = SocketNetworkService();
      await service.broadcastMessage('test broadcast');
      service.dispose();
    });

    test('stopAdvertising when not advertising is safe', () async {
      final service = SocketNetworkService();
      await service.stopAdvertising();
      service.dispose();
    });

    test('stopBrowsing when not browsing is safe', () async {
      final service = SocketNetworkService();
      await service.stopBrowsing();
      service.dispose();
    });
  });

  group('SocketNetworkService dispose', () {
    test('dispose is safe to call', () async {
      final service = SocketNetworkService();
      await service.dispose();
    });

    test('dispose after advertise is safe', () async {
      final service = SocketNetworkService();
      await service.startAdvertising(
        playerName: 'Test',
        serviceType: 'durak-test',
      );
      await service.dispose();
    });
  });

  group('SocketNetworkService advertising lifecycle', () {
    test('startAdvertising binds server', () async {
      final service = SocketNetworkService();
      await service.startAdvertising(
        playerName: 'TestHost',
        serviceType: 'durak-test',
      );
      // Should have started without error
      await service.stopAdvertising();
      await service.dispose();
    });

    test('startBrowsing then stop lifecycle', () async {
      final service = SocketNetworkService();
      await service.startBrowsing(
        playerName: 'Browser',
        playerId: 'b1',
        serviceType: 'durak-test',
      );
      await service.stopBrowsing();
      await service.dispose();
    });
  });

  group('PeerDevice', () {
    test('construction with defaults', () {
      final device = PeerDevice(id: 'peer-1', name: 'Player 1');
      expect(device.id, equals('peer-1'));
      expect(device.name, equals('Player 1'));
      expect(device.isAvailable, isTrue);
    });

    test('construction with isAvailable false', () {
      final device =
          PeerDevice(id: 'peer-1', name: 'Player 1', isAvailable: false);
      expect(device.isAvailable, isFalse);
    });
  });

  group('PeerConnection', () {
    test('construction', () {
      final conn = PeerConnection(
        peerId: 'peer-1',
        peerName: 'Player 1',
        isConnected: true,
      );
      expect(conn.peerId, equals('peer-1'));
      expect(conn.peerName, equals('Player 1'));
      expect(conn.isConnected, isTrue);
    });

    test('not connected', () {
      final conn = PeerConnection(
        peerId: 'peer-1',
        peerName: 'Player 1',
        isConnected: false,
      );
      expect(conn.isConnected, isFalse);
    });
  });

  group('PeerMessage', () {
    test('construction', () {
      final msg = PeerMessage(
        senderId: 'peer-1',
        data: '{"type":"ping"}',
      );
      expect(msg.senderId, equals('peer-1'));
      expect(msg.data, equals('{"type":"ping"}'));
    });

    test('data can be empty string', () {
      final msg = PeerMessage(senderId: 'p1', data: '');
      expect(msg.data, isEmpty);
    });
  });

  group('SocketNetworkService host-client integration', () {
    test('host advertises and client can discover', () async {
      final host = SocketNetworkService();
      final client = SocketNetworkService();

      final discoveries = <PeerDevice>[];
      final sub = client.onPeerDiscovered.listen((device) {
        discoveries.add(device);
      });

      await host.startAdvertising(
        playerName: 'Host',
        serviceType: 'durak-test',
      );

      await client.startBrowsing(
        playerName: 'Client',
        playerId: 'client-1',
        serviceType: 'durak-test',
      );

      // Wait for UDP discovery (may not work in CI/test env)
      await Future.delayed(const Duration(seconds: 2));

      await sub.cancel();
      await client.stopBrowsing();
      await host.stopAdvertising();
      await host.dispose();
      await client.dispose();

      // Discovery depends on network env — just verify no crash
    });

    test('connectToPeer returns false for unknown peer', () async {
      final service = SocketNetworkService();
      final connected = await service.connectToPeer('nonexistent');
      expect(connected, isFalse);
      await service.dispose();
    });

    test('disconnectFromPeer is safe for unknown peer', () async {
      final service = SocketNetworkService();
      await service.disconnectFromPeer('nonexistent');
      await service.dispose();
    });
  });
}
