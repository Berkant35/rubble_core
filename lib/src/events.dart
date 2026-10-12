import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rubble_core/src/geometry.dart';
import 'package:rubble_core/src/hybrid_clock.dart';
import 'package:rubble_core/src/ids.dart';
import 'package:rubble_core/src/json_reader.dart';
import 'package:rubble_core/src/units.dart';

/// Value equality from a list of properties (deep for nested lists).
abstract base class _Value {
  const _Value();

  @protected
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          const DeepCollectionEquality().equals((other as _Value).props, props);

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(props));
}

/// One user action in a session's append-only log (architecture §8). Decoding is strict.
sealed class SessionEvent extends _Value {
  const SessionEvent();

  /// Decodes `{"type": …, "payload": {…}}`; throws [FormatException] for anything unknown or invalid.
  factory SessionEvent.fromJson(Map<String, Object?> json) {
    final type = JsonReader(json, 'event').string('type');
    final r = JsonReader(json, type).object('payload');
    return switch (type) {
      'SiteCreated' => SiteCreated(
        title: r.string('title'),
        engineProfile: r.string('engineProfile'),
      ),
      'RubblePolygonSet' => RubblePolygonSet(_polygon(r)),
      'ScaleSet' => _guard(
        () => ScaleSet(
          factor: r.number('factor'),
          source: r.byName(ScaleSource.values, 'source'),
        ),
        'factor',
      ),
      'StructureAnnotated' => StructureAnnotated(
        kind: r.byName(StructureKind.values, 'kind'),
        at: r.point('at'),
      ),
      'AmbientScanCompleted' => AmbientScanCompleted(
        blacklisted: r.strings('blacklisted'),
        duration: r.duration('durationMs'),
      ),
      'BlacklistEdited' => BlacklistEdited(
        added: r.strings('added'),
        removed: r.strings('removed'),
      ),
      'TargetSelected' => TargetSelected(
        target: TargetId(r.string('target')),
        peripheralKey: r.string('peripheralKey'),
        label: r.string('label'),
      ),
      'TargetRelinked' => TargetRelinked(
        target: TargetId(r.string('target')),
        from: r.string('from'),
        to: r.string('to'),
      ),
      'MeasurementPointPlaced' => MeasurementPointPlaced(
        point: PointId(r.string('point')),
        at: r.point('at'),
      ),
      'MeasurementCompleted' => MeasurementCompleted(
        point: PointId(r.string('point')),
        duration: r.duration('durationMs'),
        readings: [
          for (final reading in r.objects('readings'))
            TargetReading._fromJson(reading),
        ],
      ),
      'MeasurementDiscarded' => MeasurementDiscarded(
        point: PointId(r.string('point')),
        reason: r.byName(DiscardReason.values, 'reason'),
      ),
      'GroundTruthRecorded' => GroundTruthRecorded(
        target: TargetId(r.string('target')),
        at: r.point('at'),
      ),
      'SessionClosed' => const SessionClosed(),
      _ => throw FormatException('Unknown event type "$type"'),
    };
  }

  /// Name stored in the `type` column.
  String get type;

  /// The event-specific fields.
  Map<String, Object?> payloadJson();

  /// `{"type": …, "payload": {…}}`.
  Map<String, Object?> toJson() => {'type': type, 'payload': payloadJson()};

  static RubblePolygon _polygon(JsonReader r) {
    final corners = [
      for (final c in r.objects('corners'))
        SitePoint(Meters(c.number('x')), Meters(c.number('y'))),
    ];
    final problem = RubblePolygon.validate(corners);
    if (problem != null) {
      throw FormatException('Invalid "corners" in ${r.context}: $problem');
    }
    return RubblePolygon(corners);
  }

  static T _guard<T>(T Function() build, String field) {
    try {
      return build();
    } on ArgumentError catch (error) {
      throw FormatException('Invalid "$field": ${error.message}');
    }
  }
}

/// A new rubble site.
final class SiteCreated extends SessionEvent {
  /// Creates the event.
  const SiteCreated({required this.title, required this.engineProfile});

  /// Site name, e.g. a street address.
  final String title;

  /// Engine profile id, e.g. `voided_pancake@1`.
  final String engineProfile;

  @override
  String get type => 'SiteCreated';

  @override
  Map<String, Object?> payloadJson() => {
    'title': title,
    'engineProfile': engineProfile,
  };

  @override
  List<Object?> get props => [title, engineProfile];
}

/// The rubble outline was drawn or redrawn (replaces the previous one).
final class RubblePolygonSet extends SessionEvent {
  /// Creates the event.
  const RubblePolygonSet(this.polygon);

  /// The outline.
  final RubblePolygon polygon;

  @override
  String get type => 'RubblePolygonSet';

  @override
  Map<String, Object?> payloadJson() => {
    'corners': [for (final c in polygon.corners) pointJson(c)],
  };

  @override
  List<Object?> get props => [polygon];
}

/// How the drawing scale was found.
enum ScaleSource {
  /// Counted steps.
  steps,

  /// Measured with a tape.
  tape,

  /// Estimated by eye.
  estimate,
}

/// Drawn lengths are multiplied by [factor].
final class ScaleSet extends SessionEvent {
  /// Creates the event; [factor] must be positive.
  ScaleSet({required this.factor, required this.source}) {
    if (!(factor > 0)) {
      throw ArgumentError.value(factor, 'factor', 'must be > 0');
    }
  }

  /// Multiplier for drawn lengths.
  final double factor;

  /// How it was found.
  final ScaleSource source;

  @override
  String get type => 'ScaleSet';

  @override
  Map<String, Object?> payloadJson() => {
    'factor': factor,
    'source': source.name,
  };

  @override
  List<Object?> get props => [factor, source];
}

/// What the rubble looks like at a place (feeds the engine profile).
enum StructureKind {
  /// Floors collapsed onto each other.
  pancake,

  /// Large voids.
  voids,

  /// Dense debris.
  dense,
}

/// A structure annotation at [at].
final class StructureAnnotated extends SessionEvent {
  /// Creates the event.
  const StructureAnnotated({required this.kind, required this.at});

  /// What was seen.
  final StructureKind kind;

  /// Where.
  final SitePoint at;

  @override
  String get type => 'StructureAnnotated';

  @override
  Map<String, Object?> payloadJson() => {
    'kind': kind.name,
    'at': pointJson(at),
  };

  @override
  List<Object?> get props => [kind, at];
}

/// The ambient scan listed surface phones, which are never suggested as targets.
final class AmbientScanCompleted extends SessionEvent {
  /// Creates the event.
  const AmbientScanCompleted({
    required this.blacklisted,
    required this.duration,
  });

  /// Peripheral keys seen on the surface.
  final List<String> blacklisted;

  /// How long the scan ran.
  final Duration duration;

  @override
  String get type => 'AmbientScanCompleted';

  @override
  Map<String, Object?> payloadJson() => {
    'blacklisted': blacklisted,
    'durationMs': duration.inMilliseconds,
  };

  @override
  List<Object?> get props => [blacklisted, duration];
}

/// The user changed the blacklist.
final class BlacklistEdited extends SessionEvent {
  /// Creates the event.
  const BlacklistEdited({required this.added, required this.removed});

  /// Keys added.
  final List<String> added;

  /// Keys removed.
  final List<String> removed;

  @override
  String get type => 'BlacklistEdited';

  @override
  Map<String, Object?> payloadJson() => {'added': added, 'removed': removed};

  @override
  List<Object?> get props => [added, removed];
}

/// A device was chosen as a target (a device, never a person).
final class TargetSelected extends SessionEvent {
  /// Creates the event.
  const TargetSelected({
    required this.target,
    required this.peripheralKey,
    required this.label,
  });

  /// Target id.
  final TargetId target;

  /// Current Bluetooth identity.
  final String peripheralKey;

  /// Display label, e.g. "Apple · Find My".
  final String label;

  @override
  String get type => 'TargetSelected';

  @override
  Map<String, Object?> payloadJson() => {
    'target': target.value,
    'peripheralKey': peripheralKey,
    'label': label,
  };

  @override
  List<Object?> get props => [target, peripheralKey, label];
}

/// The target's Bluetooth identity rotated and the user confirmed the new one.
final class TargetRelinked extends SessionEvent {
  /// Creates the event.
  const TargetRelinked({
    required this.target,
    required this.from,
    required this.to,
  });

  /// Target id.
  final TargetId target;

  /// Previous identity.
  final String from;

  /// New identity.
  final String to;

  @override
  String get type => 'TargetRelinked';

  @override
  Map<String, Object?> payloadJson() => {
    'target': target.value,
    'from': from,
    'to': to,
  };

  @override
  List<Object?> get props => [target, from, to];
}

/// A measurement point was placed on the site.
final class MeasurementPointPlaced extends SessionEvent {
  /// Creates the event.
  const MeasurementPointPlaced({required this.point, required this.at});

  /// Point id.
  final PointId point;

  /// Where.
  final SitePoint at;

  @override
  String get type => 'MeasurementPointPlaced';

  @override
  Map<String, Object?> payloadJson() => {
    'point': point.value,
    'at': pointJson(at),
  };

  @override
  List<Object?> get props => [point, at];
}

/// What one target did during a measurement.
sealed class TargetReading extends _Value {
  const TargetReading(this.target);

  factory TargetReading._fromJson(JsonReader r) {
    final target = TargetId(r.string('target'));
    return switch (r.string('kind')) {
      'heard' => SessionEvent._guard(
        () => SignalHeard(
          target,
          median: Dbm(r.number('medianDbm')),
          samples: r.integer('samples'),
        ),
        'medianDbm',
      ),
      'none' => NoSignal(target),
      final kind => throw FormatException('Unknown reading kind "$kind"'),
    };
  }

  /// The target.
  final TargetId target;

  Map<String, Object?> _toJson();
}

/// The target was heard.
final class SignalHeard extends TargetReading {
  /// Creates a reading; [median] must be plausible and [samples] not negative.
  SignalHeard(super.target, {required this.median, required this.samples}) {
    if (!median.isPlausible) {
      throw ArgumentError.value(
        median.value,
        'median',
        'outside −127 … +20 dBm',
      );
    }
    if (samples < 0) {
      throw ArgumentError.value(samples, 'samples', 'must be ≥ 0');
    }
  }

  /// Median RSSI over the samples.
  final Dbm median;

  /// Number of samples.
  final int samples;

  @override
  Map<String, Object?> _toJson() => {
    'target': target.value,
    'kind': 'heard',
    'medianDbm': median.value,
    'samples': samples,
  };

  @override
  List<Object?> get props => [target, median, samples];
}

/// The target was not heard — stored as data, never dropped (product rule 3).
final class NoSignal extends TargetReading {
  /// Creates a non-detection.
  const NoSignal(super.target);

  @override
  Map<String, Object?> _toJson() => {'target': target.value, 'kind': 'none'};

  @override
  List<Object?> get props => [target];
}

/// A point measurement finished.
final class MeasurementCompleted extends SessionEvent {
  /// Creates the event.
  const MeasurementCompleted({
    required this.point,
    required this.duration,
    required this.readings,
  });

  /// Point id.
  final PointId point;

  /// How long it ran.
  final Duration duration;

  /// One reading per tracked target.
  final List<TargetReading> readings;

  @override
  String get type => 'MeasurementCompleted';

  @override
  Map<String, Object?> payloadJson() => {
    'point': point.value,
    'durationMs': duration.inMilliseconds,
    'readings': [for (final r in readings) r._toJson()],
  };

  @override
  List<Object?> get props => [point, duration, readings];
}

/// Why a measurement was thrown away.
enum DiscardReason {
  /// The user discarded it.
  userDiscarded,

  /// The phone moved too much.
  moved,

  /// The app was interrupted.
  interrupted,
}

/// A measurement was discarded.
final class MeasurementDiscarded extends SessionEvent {
  /// Creates the event.
  const MeasurementDiscarded({required this.point, required this.reason});

  /// Point id.
  final PointId point;

  /// Why.
  final DiscardReason reason;

  @override
  String get type => 'MeasurementDiscarded';

  @override
  Map<String, Object?> payloadJson() => {
    'point': point.value,
    'reason': reason.name,
  };

  @override
  List<Object?> get props => [point, reason];
}

/// Research mode: where the phone was actually found.
final class GroundTruthRecorded extends SessionEvent {
  /// Creates the event.
  const GroundTruthRecorded({required this.target, required this.at});

  /// Target id.
  final TargetId target;

  /// Where it was found.
  final SitePoint at;

  @override
  String get type => 'GroundTruthRecorded';

  @override
  Map<String, Object?> payloadJson() => {
    'target': target.value,
    'at': pointJson(at),
  };

  @override
  List<Object?> get props => [target, at];
}

/// The session was closed.
final class SessionClosed extends SessionEvent {
  /// Creates the event.
  const SessionClosed();

  @override
  String get type => 'SessionClosed';

  @override
  Map<String, Object?> payloadJson() => const {};

  @override
  List<Object?> get props => const [];
}

/// An event with its log metadata (one row of the `events` table).
final class EventEnvelope extends _Value {
  /// Creates an envelope.
  const EventEnvelope({
    required this.id,
    required this.session,
    required this.seq,
    required this.hlc,
    required this.event,
  });

  /// Decodes [toJson]'s output strictly.
  factory EventEnvelope.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, 'envelope');
    final schema = r.integer('schema');
    if (schema != schemaVersion) {
      throw FormatException('Unsupported event schema $schema');
    }
    return EventEnvelope(
      id: EventId(r.string('id')),
      session: SessionId(r.string('session')),
      seq: r.integer('seq'),
      hlc: HybridTimestamp.parse(r.string('hlc')),
      event: SessionEvent.fromJson(json),
    );
  }

  /// Version of this JSON layout.
  static const schemaVersion = 1;

  /// Event id (UUIDv7).
  final EventId id;

  /// Session.
  final SessionId session;

  /// Position in the session log, from 1.
  final int seq;

  /// Hybrid logical time (carries the device).
  final HybridTimestamp hlc;

  /// The event.
  final SessionEvent event;

  /// Flat JSON: envelope fields plus `type` and `payload`.
  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'id': id.value,
    'session': session.value,
    'seq': seq,
    'hlc': hlc.serialize(),
    ...event.toJson(),
  };

  @override
  List<Object?> get props => [id, session, seq, hlc, event];
}
