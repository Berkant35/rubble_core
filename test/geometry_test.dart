import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

SitePoint p(double x, double y) => SitePoint(Meters(x), Meters(y));

void main() {
  group('SitePoint', () {
    test('distance in metres and value equality', () {
      expect(p(0, 0).distanceTo(p(3, 4)).value, 5);
      expect(p(1, 2), p(1, 2));
      expect(p(1, 2).hashCode, p(1, 2).hashCode);
      expect(p(1, 2), isNot(p(2, 1)));
    });

    test('vector sum and difference', () {
      expect(p(1, 2) + p(3, 4), p(4, 6));
      expect(p(3, 4) - p(1, 1), p(2, 3));
    });
  });

  group('RubblePolygon validation', () {
    test('fewer than 3 corners', () {
      expect(RubblePolygon.validate([p(0, 0), p(1, 0)]), isA<TooFewCorners>());
      expect(() => RubblePolygon([p(0, 0), p(1, 0)]), throwsArgumentError);
    });

    test('consecutive corners closer than 0.1 m (including last → first)', () {
      expect(
        RubblePolygon.validate([p(0, 0), p(0.05, 0), p(1, 1)]),
        isA<CornersTooClose>().having((e) => e.index, 'index', 0),
      );
      expect(
        RubblePolygon.validate([p(0, 0), p(5, 0), p(5, 5), p(0.05, 0)]),
        isA<CornersTooClose>().having((e) => e.index, 'index', 3),
      );
    });

    test('a bow-tie is self-intersecting', () {
      expect(
        RubblePolygon.validate([p(0, 0), p(10, 10), p(10, 0), p(0, 10)]),
        isA<SelfIntersecting>(),
      );
    });

    test('a valid outline has no problem', () {
      expect(
        RubblePolygon.validate([p(0, 0), p(10, 0), p(10, 5), p(0, 5)]),
        isNull,
      );
    });
  });

  group('RubblePolygon measures', () {
    final rect = RubblePolygon([p(0, 0), p(10, 0), p(10, 5), p(0, 5)]);
    // L-shape: a 10 × 10 square with the top-right 5 × 5 quarter cut away (area 75).
    final ell = RubblePolygon([
      p(0, 0),
      p(10, 0),
      p(10, 5),
      p(5, 5),
      p(5, 10),
      p(0, 10),
    ]);

    test('perimeter, area and edge lengths of a rectangle', () {
      expect(rect.perimeter.value, 30);
      expect(rect.area.value, 50);
      expect(rect.edges.map((e) => e.length.value), [10, 5, 10, 5]);
    });

    test('area is positive whichever way the outline was walked', () {
      final clockwise = RubblePolygon([p(0, 0), p(0, 5), p(10, 5), p(10, 0)]);
      expect(clockwise.area.value, 50);
    });

    test('concave L-shape area and perimeter', () {
      expect(ell.area.value, 75);
      expect(ell.perimeter.value, 40);
    });

    test(
      'contains: inside, outside, on the edge, and in the concave notch',
      () {
        expect(ell.contains(p(2, 2)), isTrue);
        expect(ell.contains(p(-1, 2)), isFalse);
        expect(ell.contains(p(10, 2)), isTrue); // on the edge counts as inside
        expect(ell.contains(p(7, 7)), isFalse); // the cut-away quarter
      },
    );

    test('bounds and centroid', () {
      expect(rect.bounds.min, p(0, 0));
      expect(rect.bounds.max, p(10, 5));
      expect(rect.centroid, p(5, 2.5));
      expect(ell.centroid.x.value, closeTo(25 / 6, 1e-9));
      expect(ell.centroid.y.value, closeTo(25 / 6, 1e-9));
    });

    test('value equality on the corners', () {
      expect(RubblePolygon([p(0, 0), p(10, 0), p(10, 5), p(0, 5)]), rect);
      expect(rect, isNot(ell));
    });
  });
}
