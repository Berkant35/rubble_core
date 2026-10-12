import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

SitePoint p(double x, double y) => SitePoint(Meters(x), Meters(y));

const _session = SessionId('s1');
const _device = DeviceId('device-a');
const _t1 = TargetId('t1');
const _p1 = PointId('p1');
const _p2 = PointId('p2');

EventEnvelope e(int seq, SessionEvent event) => EventEnvelope(
  id: EventId('e$seq'),
  session: _session,
  seq: seq,
  hlc: HybridTimestamp(physicalMs: 1000 + seq, counter: 0, device: _device),
  event: event,
);

final _log = [
  e(
    1,
    const SiteCreated(
      title: 'Atatürk Cad. 12',
      engineProfile: 'voided_pancake@1',
    ),
  ),
  e(
    2,
    RubblePolygonSet(RubblePolygon([p(0, 0), p(18, 0), p(18, 12), p(0, 12)])),
  ),
  e(3, ScaleSet(factor: 1.05, source: ScaleSource.steps)),
  e(4, StructureAnnotated(kind: StructureKind.voids, at: p(4, 5))),
  e(
    5,
    const AmbientScanCompleted(
      blacklisted: ['aa', 'bb'],
      duration: Duration(seconds: 30),
    ),
  ),
  e(6, const BlacklistEdited(added: ['cc'], removed: ['aa'])),
  e(
    7,
    const TargetSelected(
      target: _t1,
      peripheralKey: 'apple-1',
      label: 'Apple · Find My',
    ),
  ),
  e(8, MeasurementPointPlaced(point: _p1, at: p(2, 2))),
  e(
    9,
    MeasurementCompleted(
      point: _p1,
      duration: const Duration(seconds: 15),
      readings: [SignalHeard(_t1, median: const Dbm(-80), samples: 30)],
    ),
  ),
  e(10, const TargetRelinked(target: _t1, from: 'apple-1', to: 'apple-2')),
  e(11, MeasurementPointPlaced(point: _p2, at: p(10, 6))),
  e(
    12,
    const MeasurementCompleted(
      point: _p2,
      duration: Duration(seconds: 15),
      readings: [NoSignal(_t1)],
    ),
  ),
  e(13, GroundTruthRecorded(target: _t1, at: p(11, 7))),
  e(14, const SessionClosed()),
];

void main() {
  final state = SessionProjection.replay(_log);

  test('a full session replays into the expected state', () {
    expect(state.title, 'Atatürk Cad. 12');
    expect(state.engineProfile, 'voided_pancake@1');
    expect(state.outline!.area.value, 216);
    expect(state.scale, 1.05);
    expect(state.structures.single.kind, StructureKind.voids);
    expect(state.blacklist, {'bb', 'cc'});
    expect(state.groundTruths[_t1], p(11, 7));
    expect(state.closed, isTrue);
    expect(state.appliedIds, hasLength(14));
  });

  test('a relink changes the current identity and keeps the history', () {
    final target = state.targets[_t1]!;
    expect(target.peripheralKey, 'apple-2');
    expect(target.previousKeys, ['apple-1']);
    expect(target.label, 'Apple · Find My');
  });

  test('non-detections stay in the readings (rule 3)', () {
    expect(state.points[_p2]!.readings.single, isA<NoSignal>());
    expect(state.measuredPoints.map((pt) => pt.id), [_p1, _p2]);
  });

  test('shuffled input gives the same state as sorted input', () {
    final shuffled = [..._log.reversed];
    expect(SessionProjection.replay(shuffled), state);
  });

  test('events from two devices apply in clock order, not sequence order', () {
    const deviceB = DeviceId('device-b');
    final square = RubblePolygon([p(0, 0), p(10, 0), p(10, 10), p(0, 10)]);
    final triangle = RubblePolygon([p(0, 0), p(8, 0), p(4, 6)]);
    final early = EventEnvelope(
      id: const EventId('a2'),
      session: _session,
      seq: 2,
      hlc: const HybridTimestamp(physicalMs: 2000, counter: 0, device: _device),
      event: RubblePolygonSet(square),
    );
    final late = EventEnvelope(
      id: const EventId('b1'),
      session: _session,
      seq: 1,
      hlc: const HybridTimestamp(physicalMs: 3000, counter: 0, device: deviceB),
      event: RubblePolygonSet(triangle),
    );
    expect(SessionProjection.replay([early, late]).outline, triangle);
    expect(SessionProjection.replay([late, early]).outline, triangle);
  });

  test('a duplicated event is applied once', () {
    final doubled = SessionProjection.replay([..._log, _log[8]]);
    expect(doubled, state);
    expect(doubled.points[_p1]!.readings, hasLength(1));
  });

  test('a discarded point keeps its readings but is not a measured point', () {
    final discarded = SessionProjection.replay([
      ..._log,
      e(
        15,
        const MeasurementDiscarded(point: _p1, reason: DiscardReason.moved),
      ),
    ]);
    expect(discarded.points[_p1]!.status, PointStatus.discarded);
    expect(discarded.points[_p1]!.readings, hasLength(1));
    expect(discarded.measuredPoints.map((pt) => pt.id), [_p2]);
  });

  test(
    'a measurement before its point is placed is kept, without a position',
    () {
      final early = SessionProjection.replay([
        e(
          1,
          const MeasurementCompleted(
            point: PointId('p9'),
            duration: Duration(seconds: 15),
            readings: [NoSignal(_t1)],
          ),
        ),
      ]);
      final point = early.points[const PointId('p9')]!;
      expect(point.at, isNull);
      expect(point.status, PointStatus.measured);
      expect(point.readings.single, isA<NoSignal>());
    },
  );

  test('an empty log is an empty session', () {
    final empty = SessionProjection.replay(const []);
    expect(empty.outline, isNull);
    expect(empty.scale, 1);
    expect(empty.closed, isFalse);
  });
}
