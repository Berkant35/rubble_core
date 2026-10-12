import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rubble_core/src/ids.dart';

/// A hybrid logical clock timestamp: physical time, a counter for events in the same millisecond,
/// and the device. Totally ordered in that order (Kulkarni et al., 2014).
@immutable
final class HybridTimestamp implements Comparable<HybridTimestamp> {
  /// Creates a timestamp.
  const HybridTimestamp({
    required this.physicalMs,
    required this.counter,
    required this.device,
  });

  /// Parses [serialize]'s output; throws [FormatException] otherwise.
  factory HybridTimestamp.parse(String value) {
    final first = value.indexOf('-');
    final second = first < 0 ? -1 : value.indexOf('-', first + 1);
    final physical = first < 0 ? null : int.tryParse(value.substring(0, first));
    final counter = second < 0
        ? null
        : int.tryParse(value.substring(first + 1, second), radix: 16);
    if (physical == null || counter == null || second + 1 >= value.length) {
      throw FormatException('Not a hybrid timestamp', value);
    }
    return HybridTimestamp(
      physicalMs: physical,
      counter: counter,
      device: DeviceId(value.substring(second + 1)),
    );
  }

  /// Wall-clock milliseconds (never decreasing on one device).
  final int physicalMs;

  /// Events within the same [physicalMs].
  final int counter;

  /// The device that produced the event.
  final DeviceId device;

  /// Fixed-width text that sorts exactly like the timestamps.
  String serialize() =>
      '${physicalMs.toString().padLeft(15, '0')}-'
      '${counter.toRadixString(16).padLeft(8, '0')}-${device.value}';

  @override
  int compareTo(HybridTimestamp other) {
    final byTime = physicalMs.compareTo(other.physicalMs);
    if (byTime != 0) return byTime;
    final byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) return byCounter;
    return device.value.compareTo(other.device.value);
  }

  @override
  bool operator ==(Object other) =>
      other is HybridTimestamp &&
      other.physicalMs == physicalMs &&
      other.counter == counter &&
      other.device == device;

  @override
  int get hashCode => Object.hash(physicalMs, counter, device);

  @override
  String toString() => serialize();
}

/// Issues hybrid timestamps for one device. Every timestamp is strictly greater than the previous
/// one, even when the wall clock jumps backwards.
final class HybridClock {
  /// Creates a clock for [device]; [nowMs] is the wall clock (injected for tests).
  HybridClock({required this.device, required this._nowMs});

  /// This device.
  final DeviceId device;
  final int Function() _nowMs;
  int _physical = -1;
  int _counter = 0;

  /// A timestamp for a local event.
  HybridTimestamp now() {
    final wall = _nowMs();
    if (wall > _physical) {
      _physical = wall;
      _counter = 0;
    } else {
      _counter += 1;
    }
    return _stamp();
  }

  /// Merges a timestamp received from another device and returns one greater than both.
  HybridTimestamp receive(HybridTimestamp remote) {
    final next = math.max(math.max(_physical, remote.physicalMs), _nowMs());
    if (next == _physical && next == remote.physicalMs) {
      _counter = math.max(_counter, remote.counter) + 1;
    } else if (next == _physical) {
      _counter += 1;
    } else if (next == remote.physicalMs) {
      _counter = remote.counter + 1;
    } else {
      _counter = 0;
    }
    _physical = next;
    return _stamp();
  }

  HybridTimestamp _stamp() =>
      HybridTimestamp(physicalMs: _physical, counter: _counter, device: device);
}
