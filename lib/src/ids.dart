import 'dart:math' as math;

/// A UUID version 7 (RFC 9562): 48-bit Unix milliseconds first, so ids sort chronologically.
extension type const Uuid7._(String value) {
  /// Parses the canonical lower-case form; throws [FormatException] for anything else.
  factory Uuid7.parse(String value) {
    if (!_pattern.hasMatch(value)) {
      throw FormatException('Not a canonical UUIDv7', value);
    }
    return Uuid7._(value);
  }

  static final _pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// Creation time in Unix milliseconds.
  int get timestampMs =>
      int.parse(value.substring(0, 8) + value.substring(9, 13), radix: 16);
}

/// Generates monotonic UUIDv7s from an injected clock and random source (deterministic in tests).
/// Within one millisecond each id uses the previous `rand_a + 1`; on overflow the timestamp moves
/// on by 1 ms. A clock that goes backwards never yields a smaller id.
final class Uuid7Generator {
  /// Creates a generator.
  Uuid7Generator({required this._nowMs, required this._random});

  final int Function() _nowMs;
  final math.Random _random;
  int _lastMs = -1;
  int _lastRandA = 0;

  static const _randAMax = 0xfff;

  /// The next id, strictly greater than the previous one.
  Uuid7 next() {
    var ms = math.max(_nowMs(), _lastMs);
    int randA;
    if (ms == _lastMs) {
      randA = _lastRandA + 1;
      if (randA > _randAMax) {
        ms += 1;
        randA = _random.nextInt(_randAMax + 1);
      }
    } else {
      randA = _random.nextInt(_randAMax + 1);
    }
    _lastMs = ms;
    _lastRandA = randA;
    final high = _random.nextInt(1 << 30); // top 30 of the 62 random bits
    final low = _random.nextInt(1 << 32); // low 32 bits
    final time = ms.toRadixString(16).padLeft(12, '0');
    final version = (0x7000 | randA).toRadixString(16).padLeft(4, '0');
    final variant = (0x8000 | (high >> 16)).toRadixString(16).padLeft(4, '0');
    final node = ((high & 0xffff) * 0x100000000 + low)
        .toRadixString(16)
        .padLeft(12, '0');
    return Uuid7._(
      '${time.substring(0, 8)}-${time.substring(8)}-$version-$variant-$node',
    );
  }
}

/// A rubble-site session.
extension type const SessionId(String value) {}

/// One event in a session's log.
extension type const EventId(String value) {}

/// The phone that recorded an event (for merging sessions across devices in v2).
extension type const DeviceId(String value) {}

/// A measurement point on the site.
extension type const PointId(String value) {}

/// A tracked target device.
extension type const TargetId(String value) {}
