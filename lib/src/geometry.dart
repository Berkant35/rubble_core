import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rubble_core/src/units.dart';

/// A point on the rubble site in local metres (x east, y north from an arbitrary origin). Never
/// latitude/longitude in v1.
@immutable
final class SitePoint {
  /// Creates a point.
  const SitePoint(this.x, this.y);

  /// East coordinate.
  final Meters x;

  /// North coordinate.
  final Meters y;

  /// Straight-line distance.
  Meters distanceTo(SitePoint other) => Meters(
    math.sqrt(
      math.pow(other.x.value - x.value, 2) +
          math.pow(other.y.value - y.value, 2),
    ),
  );

  /// Vector sum.
  SitePoint operator +(SitePoint other) => SitePoint(x + other.x, y + other.y);

  /// Vector difference.
  SitePoint operator -(SitePoint other) => SitePoint(x - other.x, y - other.y);

  @override
  bool operator ==(Object other) =>
      other is SitePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'SitePoint(${x.value} m, ${y.value} m)';
}

/// One side of the outline, from [start] to [end].
@immutable
final class PolygonEdge {
  /// Creates an edge.
  const PolygonEdge(this.start, this.end);

  /// First corner.
  final SitePoint start;

  /// Second corner.
  final SitePoint end;

  /// Length of the side.
  Meters get length => start.distanceTo(end);
}

/// Axis-aligned bounds of the outline.
@immutable
final class SiteBounds {
  /// Creates bounds.
  const SiteBounds(this.min, this.max);

  /// South-west corner.
  final SitePoint min;

  /// North-east corner.
  final SitePoint max;
}

/// Why a list of corners is not a valid rubble outline.
sealed class PolygonProblem {
  const PolygonProblem();
}

/// Fewer than three corners.
final class TooFewCorners extends PolygonProblem {
  /// Creates the problem.
  const TooFewCorners(this.count);

  /// How many corners were given.
  final int count;

  @override
  String toString() => 'An outline needs at least 3 corners, got $count.';
}

/// Corner [index] and the next one are closer than [RubblePolygon.minCornerSpacing].
final class CornersTooClose extends PolygonProblem {
  /// Creates the problem.
  const CornersTooClose(this.index);

  /// Index of the first of the two corners.
  final int index;

  @override
  String toString() => 'Corners $index and the next are closer than 0.1 m.';
}

/// Corner [index] is not a finite number.
final class NonFiniteCorner extends PolygonProblem {
  /// Creates the problem.
  const NonFiniteCorner(this.index);

  /// Index of the corner.
  final int index;

  @override
  String toString() => 'Corner $index is not a finite number.';
}

/// The outline encloses less than [RubblePolygon.minArea] (for example, all corners on one line).
final class DegenerateOutline extends PolygonProblem {
  /// Creates the problem.
  const DegenerateOutline();

  @override
  String toString() => 'The outline encloses (almost) no area.';
}

/// Two sides cross each other.
final class SelfIntersecting extends PolygonProblem {
  /// Creates the problem.
  const SelfIntersecting(this.first, this.second);

  /// Index of one crossing side.
  final int first;

  /// Index of the other crossing side.
  final int second;

  @override
  String toString() => 'Sides $first and $second cross each other.';
}

/// The rubble outline the rescuer drew, in local metres. Always valid: at least three finite
/// corners, no two consecutive corners closer than 0.1 m, no crossing sides, at least 0.01 m² area.
@immutable
final class RubblePolygon {
  /// Creates an outline; throws [ArgumentError] with the [PolygonProblem] if it is invalid.
  RubblePolygon(List<SitePoint> corners)
    : corners = List.unmodifiable(corners) {
    final problem = validate(corners);
    if (problem != null) {
      throw ArgumentError.value(corners, 'corners', '$problem');
    }
  }

  /// Smallest distance between consecutive corners.
  static const Meters minCornerSpacing = Meters(0.1);

  /// Smallest enclosed area.
  static const SquareMeters minArea = SquareMeters(0.01);

  /// Corners in drawing order.
  final List<SitePoint> corners;

  /// The first problem with [corners], or null when they form a valid outline.
  static PolygonProblem? validate(List<SitePoint> corners) {
    if (corners.length < 3) return TooFewCorners(corners.length);
    for (final (i, c) in corners.indexed) {
      if (!c.x.value.isFinite || !c.y.value.isFinite) return NonFiniteCorner(i);
    }
    for (var i = 0; i < corners.length; i++) {
      if (corners[i].distanceTo(corners[(i + 1) % corners.length]) <
          minCornerSpacing) {
        return CornersTooClose(i);
      }
    }
    final n = corners.length;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final adjacent = j == i + 1 || (i == 0 && j == n - 1);
        if (adjacent) continue;
        if (_cross(
          corners[i],
          corners[(i + 1) % n],
          corners[j],
          corners[(j + 1) % n],
        )) {
          return SelfIntersecting(i, j);
        }
      }
    }
    final doubleArea = [
      for (var i = 0; i < n; i++) _cross2(corners[i], corners[(i + 1) % n]),
    ].sum;
    if (doubleArea.abs() / 2 < minArea.value) return const DegenerateOutline();
    return null;
  }

  /// The sides, closing back to the first corner.
  List<PolygonEdge> get edges => [
    for (var i = 0; i < corners.length; i++)
      PolygonEdge(corners[i], corners[(i + 1) % corners.length]),
  ];

  /// Total length of the outline.
  Meters get perimeter =>
      edges.fold(Meters.zero, (sum, edge) => sum + edge.length);

  /// Enclosed area, positive whichever way the outline was walked.
  SquareMeters get area => SquareMeters(_signedArea.abs());

  /// Area-weighted centre.
  SitePoint get centroid {
    final a = _signedArea;
    var cx = 0.0;
    var cy = 0.0;
    for (final edge in edges) {
      final cross = _cross2(edge.start, edge.end);
      cx += (edge.start.x.value + edge.end.x.value) * cross;
      cy += (edge.start.y.value + edge.end.y.value) * cross;
    }
    return SitePoint(Meters(cx / (6 * a)), Meters(cy / (6 * a)));
  }

  /// Axis-aligned bounds.
  SiteBounds get bounds {
    final xs = corners.map((c) => c.x.value);
    final ys = corners.map((c) => c.y.value);
    return SiteBounds(
      SitePoint(Meters(xs.min), Meters(ys.min)),
      SitePoint(Meters(xs.max), Meters(ys.max)),
    );
  }

  /// Whether [point] lies inside the outline; a point on a side counts as inside.
  bool contains(SitePoint point) {
    if (edges.any((edge) => _onSegment(point, edge.start, edge.end))) {
      return true;
    }
    var inside = false;
    for (final edge in edges) {
      final (a, b) = (edge.start, edge.end);
      final crosses =
          (a.y.value > point.y.value) != (b.y.value > point.y.value);
      if (crosses) {
        final x =
            a.x.value +
            (point.y.value - a.y.value) *
                (b.x.value - a.x.value) /
                (b.y.value - a.y.value);
        if (point.x.value < x) inside = !inside;
      }
    }
    return inside;
  }

  double get _signedArea =>
      edges.fold(0.0, (sum, edge) => sum + _cross2(edge.start, edge.end)) / 2;

  static double _cross2(SitePoint a, SitePoint b) =>
      a.x.value * b.y.value - b.x.value * a.y.value;

  static double _orientation(SitePoint a, SitePoint b, SitePoint c) =>
      (b.x.value - a.x.value) * (c.y.value - a.y.value) -
      (b.y.value - a.y.value) * (c.x.value - a.x.value);

  static bool _onSegment(SitePoint p, SitePoint a, SitePoint b) {
    if (_orientation(a, b, p).abs() > 1e-9) return false;
    final withinX =
        p.x.value >= math.min(a.x.value, b.x.value) - 1e-9 &&
        p.x.value <= math.max(a.x.value, b.x.value) + 1e-9;
    final withinY =
        p.y.value >= math.min(a.y.value, b.y.value) - 1e-9 &&
        p.y.value <= math.max(a.y.value, b.y.value) + 1e-9;
    return withinX && withinY;
  }

  static bool _cross(SitePoint a, SitePoint b, SitePoint c, SitePoint d) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);
    if ((o1 > 0) != (o2 > 0) &&
        (o3 > 0) != (o4 > 0) &&
        o1 != 0 &&
        o2 != 0 &&
        o3 != 0 &&
        o4 != 0) {
      return true;
    }
    return _onSegment(c, a, b) ||
        _onSegment(d, a, b) ||
        _onSegment(a, c, d) ||
        _onSegment(b, c, d);
  }

  @override
  bool operator ==(Object other) =>
      other is RubblePolygon &&
      const ListEquality<SitePoint>().equals(other.corners, corners);

  @override
  int get hashCode => const ListEquality<SitePoint>().hash(corners);
}
