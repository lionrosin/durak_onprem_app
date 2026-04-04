/// BLE constants for Durak game networking.
///
/// Defines the GATT service and characteristic UUIDs used for
/// cross-platform Bluetooth Low Energy multiplayer.
class BleConstants {
  BleConstants._();

  // ── Service & Characteristic UUIDs ─────────────────────────────

  /// Main Durak game BLE service UUID.
  static const String serviceUuid = '12345678-1234-5678-abcd-000000000001';

  /// Characteristic for client → host messages (write, writable).
  static const String writeCharUuid = '12345678-1234-5678-abcd-000000000002';

  /// Characteristic for host → client messages (notify).
  static const String notifyCharUuid = '12345678-1234-5678-abcd-000000000003';

  // ── Chunk Protocol ─────────────────────────────────────────────

  /// Header size for chunked messages: [seqId, totalChunks, chunkIndex].
  static const int chunkHeaderSize = 3;

  /// Minimum MTU we'll work with.
  static const int minMtu = 23;

  /// Default MTU we request on Android.
  static const int requestedMtu = 512;

  /// Maximum payload per chunk (conservative, works with typical 185-512 MTU).
  static const int maxChunkPayload = 180;

  // ── Timing ─────────────────────────────────────────────────────

  /// Scan timeout when browsing for hosts.
  static const Duration scanTimeout = Duration(seconds: 15);

  /// Connection attempt timeout.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Delay between chunk writes (to avoid BLE congestion).
  static const Duration chunkWriteDelay = Duration(milliseconds: 50);

  // ── Advertising ────────────────────────────────────────────────

  /// Advertise name prefix used to identify Durak game hosts.
  static const String advertisePrefix = 'DURAK:';
}
