import 'package:rubble_core/src/geometry.dart';
import 'package:rubble_core/src/units.dart';

/// Strict field access for decoding: a missing or mistyped field throws a [FormatException] that
/// names the field, never a silent default.
final class JsonReader {
  /// Reads [json]; [context] names the object in error messages.
  const JsonReader(this.json, this.context);

  /// The object being read.
  final Map<String, Object?> json;

  /// Name used in error messages.
  final String context;

  Never _fail(String key) =>
      throw FormatException('Missing or invalid "$key" in $context');

  /// A string field.
  String string(String key) => switch (json[key]) {
    final String v => v,
    _ => _fail(key),
  };

  /// An integer field.
  int integer(String key) => switch (json[key]) {
    final int v => v,
    _ => _fail(key),
  };

  /// A finite number field (int or double).
  double number(String key) => switch (json[key]) {
    final num v when v.isFinite => v.toDouble(),
    _ => _fail(key),
  };

  /// A list of strings.
  List<String> strings(String key) => switch (json[key]) {
    final List<Object?> v when v.every((e) => e is String) => List.unmodifiable(
      v.cast<String>(),
    ),
    _ => _fail(key),
  };

  /// A nested object.
  JsonReader object(String key) => switch (json[key]) {
    final Map<String, Object?> v => JsonReader(v, '$context.$key'),
    _ => _fail(key),
  };

  /// A list of nested objects.
  List<JsonReader> objects(String key) => switch (json[key]) {
    final List<Object?> v when v.every((e) => e is Map<String, Object?>) => [
      for (final (i, e) in v.indexed)
        JsonReader(e! as Map<String, Object?>, '$context.$key[$i]'),
    ],
    _ => _fail(key),
  };

  /// A duration stored as milliseconds.
  Duration duration(String key) => Duration(milliseconds: integer(key));

  /// An enum value stored by name.
  T byName<T extends Enum>(List<T> values, String key) {
    final name = string(key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    return _fail(key);
  }

  /// A site point stored as `{"x": metres, "y": metres}`.
  SitePoint point(String key) {
    final p = object(key);
    return SitePoint(Meters(p.number('x')), Meters(p.number('y')));
  }
}

/// JSON of a site point.
Map<String, Object?> pointJson(SitePoint p) => {'x': p.x.value, 'y': p.y.value};
