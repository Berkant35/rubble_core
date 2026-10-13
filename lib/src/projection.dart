import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rubble_core/src/events.dart';
import 'package:rubble_core/src/geometry.dart';
import 'package:rubble_core/src/hybrid_clock.dart';
import 'package:rubble_core/src/ids.dart';
import 'package:rubble_core/src/units.dart';

const _deep = DeepCollectionEquality();

/// Where a measurement point stands.
enum PointStatus {
  /// Placed, not measured yet.
  placed,

  /// Measured at least once.
  measured,

  /// Thrown away (its readings are set aside, kept for the record).
  discarded,
}

/// A tracked target device.
@immutable
final class TargetState {
  /// Creates the state.
  TargetState({
    required this.peripheralKey,
    required this.label,
    List<String> previousKeys = const [],
  }) : previousKeys = List.unmodifiable(previousKeys);

  /// Current Bluetooth identity.
  final String peripheralKey;

  /// Display label; null when the target is known only from a relink (merged logs, v2).
  final String? label;

  /// Earlier identities, oldest first (identity rotation); never loses one.
  final List<String> previousKeys;

  @override
  bool operator ==(Object other) =>
      other is TargetState &&
      other.peripheralKey == peripheralKey &&
      other.label == label &&
      _deep.equals(other.previousKeys, previousKeys);

  @override
  int get hashCode =>
      Object.hash(peripheralKey, label, _deep.hash(previousKeys));
}

/// A measurement point and what was heard there.
@immutable
final class PointState {
  /// Creates the state.
  PointState({
    required this.id,
    required this.status,
    this.at,
    List<TargetReading> readings = const [],
    List<TargetReading> discardedReadings = const [],
  }) : readings = List.unmodifiable(readings),
       discardedReadings = List.unmodifiable(discardedReadings);

  /// Point id.
  final PointId id;

  /// Where it is; null when a measurement arrived before the point (kept, never dropped).
  final SitePoint? at;

  /// Readings of the current measurement, including non-detections (product rule 3).
  final List<TargetReading> readings;

  /// Readings set aside by a discard or a move; kept for the record, never sent to the engine.
  final List<TargetReading> discardedReadings;

  /// Placed, measured or discarded.
  final PointStatus status;

  @override
  bool operator ==(Object other) =>
      other is PointState &&
      other.id == id &&
      other.at == at &&
      other.status == status &&
      _deep.equals(other.readings, readings) &&
      _deep.equals(other.discardedReadings, discardedReadings);

  @override
  int get hashCode => Object.hash(
    id,
    at,
    status,
    _deep.hash(readings),
    _deep.hash(discardedReadings),
  );
}

/// A structure annotation.
typedef StructureNote = ({StructureKind kind, SitePoint at});

/// The rubble height and where the person most likely was.
typedef RubbleDepth = ({Meters height, TrappedLevel level});

/// Everything the screens need, rebuilt from the event log.
@immutable
final class SessionState {
  /// Creates a state; [SessionState.empty] is the start of every replay.
  const SessionState({
    required this.title,
    required this.engineProfile,
    required this.outline,
    required this.scale,
    required this.structures,
    required this.blacklist,
    required this.targets,
    required this.points,
    required this.groundTruths,
    required this.closed,
    required this.appliedIds,
    this.lastSurfaceScan,
    this.depth,
  });

  /// A session before any event.
  static const empty = SessionState(
    title: null,
    engineProfile: null,
    outline: null,
    scale: 1,
    structures: [],
    blacklist: {},
    targets: {},
    points: {},
    groundTruths: {},
    closed: false,
    appliedIds: {},
  );

  /// When the last surface scan finished (`AmbientScanCompleted`), even if it set nothing aside;
  /// null before the first one. A manual exclusion is not a scan.
  final HybridTimestamp? lastSurfaceScan;

  /// Site name.
  final String? title;

  /// Engine profile id.
  final String? engineProfile;

  /// The rubble outline, once drawn.
  final RubblePolygon? outline;

  /// Multiplier for drawn lengths.
  final double scale;

  /// Structure annotations, in order.
  final List<StructureNote> structures;

  /// The rubble height and likely level, once the rescuers gave them.
  final RubbleDepth? depth;

  /// Surface phones never suggested as targets.
  final Set<String> blacklist;

  /// Tracked targets.
  final Map<TargetId, TargetState> targets;

  /// Measurement points, in the order they appeared.
  final Map<PointId, PointState> points;

  /// Research mode: where each target was found.
  final Map<TargetId, SitePoint> groundTruths;

  /// Whether the session was closed.
  final bool closed;

  /// Events already applied (replays are idempotent).
  final Set<EventId> appliedIds;

  /// Points with readings that were not discarded, in order.
  Iterable<PointState> get measuredPoints =>
      points.values.where((p) => p.status == PointStatus.measured);

  SessionState _copy({
    String? title,
    String? engineProfile,
    RubblePolygon? outline,
    double? scale,
    List<StructureNote>? structures,
    Set<String>? blacklist,
    Map<TargetId, TargetState>? targets,
    Map<PointId, PointState>? points,
    Map<TargetId, SitePoint>? groundTruths,
    bool? closed,
    HybridTimestamp? lastSurfaceScan,
    RubbleDepth? depth,
    required Set<EventId> appliedIds,
  }) => SessionState(
    title: title ?? this.title,
    engineProfile: engineProfile ?? this.engineProfile,
    outline: outline ?? this.outline,
    scale: scale ?? this.scale,
    structures: List.unmodifiable(structures ?? this.structures),
    blacklist: Set.unmodifiable(blacklist ?? this.blacklist),
    targets: Map.unmodifiable(targets ?? this.targets),
    points: Map.unmodifiable(points ?? this.points),
    groundTruths: Map.unmodifiable(groundTruths ?? this.groundTruths),
    closed: closed ?? this.closed,
    lastSurfaceScan: lastSurfaceScan ?? this.lastSurfaceScan,
    depth: depth ?? this.depth,
    appliedIds: Set.unmodifiable(appliedIds),
  );

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.title == title &&
      other.engineProfile == engineProfile &&
      other.outline == outline &&
      other.scale == scale &&
      other.closed == closed &&
      other.lastSurfaceScan == lastSurfaceScan &&
      other.depth == depth &&
      _deep.equals(other.structures, structures) &&
      _deep.equals(other.blacklist, blacklist) &&
      _deep.equals(other.targets, targets) &&
      _deep.equals(other.points, points) &&
      _deep.equals(other.groundTruths, groundTruths) &&
      _deep.equals(other.appliedIds, appliedIds);

  @override
  int get hashCode => Object.hash(
    title,
    engineProfile,
    outline,
    scale,
    closed,
    lastSurfaceScan,
    depth,
    _deep.hash(points),
    _deep.hash(targets),
    _deep.hash(appliedIds),
  );
}

/// Rebuilds a [SessionState] from events — pure, deterministic and idempotent.
abstract final class SessionProjection {
  /// Sorts by hybrid time, then `seq`, then event id, and applies every event; input order does
  /// not matter.
  ///
  /// [apply] alone matches [replay] only while events arrive in that order; a late event with an
  /// older timestamp (merged logs, v2) needs a full [replay].
  static SessionState replay(Iterable<EventEnvelope> log) {
    final ordered = [...log]
      ..sort((a, b) {
        final byTime = a.hlc.compareTo(b.hlc);
        if (byTime != 0) return byTime;
        final bySeq = a.seq.compareTo(b.seq);
        return bySeq != 0 ? bySeq : a.id.value.compareTo(b.id.value);
      });
    return ordered.fold(SessionState.empty, apply);
  }

  /// Applies one event; an event id already applied is ignored.
  static SessionState apply(SessionState state, EventEnvelope envelope) {
    if (state.appliedIds.contains(envelope.id)) return state;
    final applied = {...state.appliedIds, envelope.id};
    return switch (envelope.event) {
      SiteCreated(:final title, :final engineProfile) => state._copy(
        title: title,
        engineProfile: engineProfile,
        appliedIds: applied,
      ),
      RubblePolygonSet(:final polygon) => state._copy(
        outline: polygon,
        appliedIds: applied,
      ),
      ScaleSet(:final factor) => state._copy(
        scale: factor,
        appliedIds: applied,
      ),
      RubbleDepthSet(:final height, :final level) => state._copy(
        depth: (height: height, level: level),
        appliedIds: applied,
      ),
      StructureAnnotated(:final kind, :final at) => state._copy(
        structures: [...state.structures, (kind: kind, at: at)],
        appliedIds: applied,
      ),
      AmbientScanCompleted(:final blacklisted) => state._copy(
        blacklist: {...state.blacklist, ...blacklisted},
        lastSurfaceScan: envelope.hlc,
        appliedIds: applied,
      ),
      BlacklistEdited(:final added, :final removed) => state._copy(
        blacklist: {...state.blacklist, ...added}..removeAll(removed),
        appliedIds: applied,
      ),
      TargetSelected(:final target, :final peripheralKey, :final label) =>
        state._copy(
          targets: {
            ...state.targets,
            target: _rekey(state.targets[target], peripheralKey, label: label),
          },
          appliedIds: applied,
        ),
      TargetRelinked(:final target, :final from, :final to) => state._copy(
        targets: {
          ...state.targets,
          target: _rekey(
            state.targets[target],
            to,
            label: state.targets[target]?.label,
            from: from,
          ),
        },
        appliedIds: applied,
      ),
      MeasurementPointPlaced(:final point, :final at) => state._copy(
        points: {
          ...state.points,
          point: _place(state.points[point], point, at),
        },
        appliedIds: applied,
      ),
      MeasurementCompleted(:final point, :final readings) => state._copy(
        points: {
          ...state.points,
          point: PointState(
            id: point,
            at: state.points[point]?.at,
            status: PointStatus.measured,
            readings: [...?state.points[point]?.readings, ...readings],
            discardedReadings:
                state.points[point]?.discardedReadings ?? const [],
          ),
        },
        appliedIds: applied,
      ),
      MeasurementDiscarded(:final point) => state._copy(
        points: {
          ...state.points,
          point: _setAside(state.points[point], point, PointStatus.discarded),
        },
        appliedIds: applied,
      ),
      GroundTruthRecorded(:final target, :final at) => state._copy(
        groundTruths: {...state.groundTruths, target: at},
        appliedIds: applied,
      ),
      SessionClosed() => state._copy(closed: true, appliedIds: applied),
    };
  }

  /// Places [id] at [at]. Moving a point sets its readings aside: they were heard somewhere else.
  static PointState _place(PointState? old, PointId id, SitePoint at) {
    if (old == null) {
      return PointState(id: id, at: at, status: PointStatus.placed);
    }
    if (old.at == null || old.at == at) {
      return PointState(
        id: id,
        at: at,
        status: old.status,
        readings: old.readings,
        discardedReadings: old.discardedReadings,
      );
    }
    final moved = _setAside(old, id, PointStatus.placed);
    return PointState(
      id: id,
      at: at,
      status: moved.status,
      discardedReadings: moved.discardedReadings,
    );
  }

  /// Moves the current readings of [id] to its discarded readings.
  static PointState _setAside(
    PointState? old,
    PointId id,
    PointStatus status,
  ) => PointState(
    id: id,
    at: old?.at,
    status: status,
    discardedReadings: [...?old?.discardedReadings, ...?old?.readings],
  );

  /// [old] under [key]; every earlier identity, [from] included, stays in the history.
  static TargetState _rekey(
    TargetState? old,
    String key, {
    required String? label,
    String? from,
  }) {
    final history = [...?old?.previousKeys];
    for (final k in [from, old?.peripheralKey]) {
      if (k != null && k != key && !history.contains(k)) history.add(k);
    }
    return TargetState(
      peripheralKey: key,
      label: label,
      previousKeys: history..remove(key),
    );
  }
}
