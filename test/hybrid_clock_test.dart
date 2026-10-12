import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

void main() {
  const a = DeviceId('device-a');
  const b = DeviceId('device-b');

  test('local events strictly increase with a frozen wall clock', () {
    final clock = HybridClock(device: a, nowMs: () => 1000);
    final t1 = clock.now();
    final t2 = clock.now();
    expect(t2.compareTo(t1), greaterThan(0));
    expect((t2.physicalMs, t2.counter), (1000, 1));
  });

  test('a backwards wall clock keeps the last physical time and counts up', () {
    var wall = 5000;
    final clock = HybridClock(device: a, nowMs: () => wall);
    final t1 = clock.now();
    wall = 3000;
    final t2 = clock.now();
    expect(t2.physicalMs, 5000);
    expect(t2.compareTo(t1), greaterThan(0));
  });

  test('an advancing wall clock resets the counter', () {
    var wall = 1000;
    final clock = HybridClock(device: a, nowMs: () => wall);
    clock.now();
    clock.now();
    wall = 2000;
    expect((clock.now().physicalMs, clock.now().counter), (2000, 1));
  });

  test('receiving from a device ahead in time adopts its physical time', () {
    final clock = HybridClock(device: a, nowMs: () => 1000);
    const remote = HybridTimestamp(physicalMs: 9000, counter: 4, device: b);
    final merged = clock.receive(remote);
    expect(merged.physicalMs, 9000);
    expect(merged.counter, 5);
    expect(merged.compareTo(remote), greaterThan(0));
    expect(clock.now().compareTo(merged), greaterThan(0));
  });

  test('ties on time and counter are broken by device id', () {
    const x = HybridTimestamp(physicalMs: 1, counter: 0, device: a);
    const y = HybridTimestamp(physicalMs: 1, counter: 0, device: b);
    expect(x.compareTo(y), lessThan(0));
  });

  test('serialised strings sort like the timestamps and parse back', () {
    final stamps = [
      const HybridTimestamp(physicalMs: 2, counter: 0, device: a),
      const HybridTimestamp(physicalMs: 1, counter: 10, device: a),
      const HybridTimestamp(physicalMs: 1, counter: 2, device: b),
      const HybridTimestamp(physicalMs: 1760000000000, counter: 0, device: a),
    ];
    final byValue = [...stamps]..sort();
    final byString = [...stamps]
      ..sort((x, y) => x.serialize().compareTo(y.serialize()));
    expect(byString, byValue);
    for (final s in stamps) {
      expect(HybridTimestamp.parse(s.serialize()), s);
    }
  });
}
