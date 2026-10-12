import 'dart:math';

import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

/// A random source that always returns [value] — for deterministic rand_a.
class _Fixed implements Random {
  _Fixed(this.value);
  final int value;
  @override
  int nextInt(int max) => value % max;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  const ms = 1760000000000;

  test('version 7, variant 10, and the timestamp round-trips', () {
    final id = Uuid7Generator(nowMs: () => ms, random: Random(1)).next();
    expect(
      id.value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(id.timestampMs, ms);
    expect(Uuid7.parse(id.value), id);
  });

  test('1000 ids in the same millisecond are strictly increasing', () {
    final generator = Uuid7Generator(nowMs: () => ms, random: Random(2));
    final ids = [for (var i = 0; i < 1000; i++) generator.next().value];
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i].compareTo(ids[i - 1]), greaterThan(0), reason: 'at $i');
    }
  });

  test('rand_a overflow advances the timestamp by one millisecond', () {
    final generator = Uuid7Generator(nowMs: () => ms, random: _Fixed(0xfff));
    final first = generator.next();
    final second = generator.next();
    expect(first.timestampMs, ms);
    expect(second.timestampMs, ms + 1);
    expect(second.value.compareTo(first.value), greaterThan(0));
  });

  test('a clock going backwards never yields a smaller id', () {
    var now = ms;
    final generator = Uuid7Generator(nowMs: () => now, random: Random(3));
    final first = generator.next();
    now = ms - 5000;
    final second = generator.next();
    expect(second.value.compareTo(first.value), greaterThan(0));
  });

  test('parse rejects non-v7, wrong variant, upper case and wrong length', () {
    expect(
      () => Uuid7.parse('0190c0de-1234-4abc-8def-0123456789ab'),
      throwsFormatException,
    ); // v4
    expect(
      () => Uuid7.parse('0190c0de-1234-7abc-cdef-0123456789ab'),
      throwsFormatException,
    ); // variant 11
    expect(
      () => Uuid7.parse('0190C0DE-1234-7ABC-8DEF-0123456789AB'),
      throwsFormatException,
    );
    expect(
      () => Uuid7.parse('0190c0de-1234-7abc-8def-0123456789a'),
      throwsFormatException,
    );
  });

  test('typed ids wrap the id string', () {
    final id = Uuid7Generator(nowMs: () => ms, random: Random(4)).next();
    expect(SessionId(id.value).value, id.value);
    // Does not compile — typed ids never mix:
    // final PointId p = TargetId(id.value);
  });
}
