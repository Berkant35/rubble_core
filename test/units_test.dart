import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

void main() {
  group('Meters', () {
    test('adds, subtracts, negates and scales', () {
      expect((const Meters(3) + const Meters(1.5)).value, 4.5);
      expect((const Meters(3) - const Meters(5)).value, -2);
      expect((-const Meters(2)).value, -2);
      expect((const Meters(2) * 3).value, 6);
      expect((const Meters(9) / 3).value, 3);
      expect(const Meters(-4).abs().value, 4);
    });

    test('compares and has a zero', () {
      expect(const Meters(1).compareTo(const Meters(2)), lessThan(0));
      expect(const Meters(1) < const Meters(2), isTrue);
      expect(Meters.zero.value, 0);
    });

    // Does not compile — units never mix (extension types do not implement double):
    // const Meters(1) + const Dbm(-70);
  });

  test('SquareMeters add and compare', () {
    expect((const SquareMeters(10) + const SquareMeters(5)).value, 15);
    expect(
      const SquareMeters(10).compareTo(const SquareMeters(5)),
      greaterThan(0),
    );
  });

  group('Dbm', () {
    test('a difference of two levels is in decibels', () {
      final Decibels diff = const Dbm(-60) - const Dbm(-71);
      expect(diff.value, 11);
      expect((const Decibels(-3)).abs().value, 3);
    });

    test('plausible RSSI range is −127 … +20 dBm', () {
      expect(const Dbm(-71).isPlausible, isTrue);
      expect(Dbm.minPlausible.isPlausible, isTrue);
      expect(const Dbm(-128).isPlausible, isFalse);
      expect(const Dbm(21).isPlausible, isFalse);
    });

    test('compares', () {
      expect(const Dbm(-60).compareTo(const Dbm(-70)), greaterThan(0));
    });
  });

  test('Hpa differences stay pressure', () {
    final Hpa diff = const Hpa(1013.2) - const Hpa(1012.0);
    expect(diff.value, closeTo(1.2, 1e-9));
    expect(const Hpa(1000).compareTo(const Hpa(1013)), lessThan(0));
  });
}
