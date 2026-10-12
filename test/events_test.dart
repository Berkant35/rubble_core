import 'dart:convert';

import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

SitePoint p(double x, double y) => SitePoint(Meters(x), Meters(y));

const _target = TargetId('t1');
const _point = PointId('p1');

final _events = <SessionEvent>[
  const SiteCreated(
    title: 'Atatürk Cad. 12',
    engineProfile: 'voided_pancake@1',
  ),
  RubblePolygonSet(
    RubblePolygon([p(0, 0), p(18.2, 0), p(18.2, 12.4), p(0, 12.4)]),
  ),
  ScaleSet(factor: 1.05, source: ScaleSource.steps),
  StructureAnnotated(kind: StructureKind.voids, at: p(4, 5)),
  const AmbientScanCompleted(
    blacklisted: ['aa:bb', 'cc:dd'],
    duration: Duration(seconds: 30),
  ),
  const BlacklistEdited(added: ['ee:ff'], removed: ['aa:bb']),
  const TargetSelected(
    target: _target,
    peripheralKey: 'apple-1',
    label: 'Apple · Find My',
  ),
  const TargetRelinked(target: _target, from: 'apple-1', to: 'apple-2'),
  MeasurementPointPlaced(point: _point, at: p(3, 2)),
  MeasurementCompleted(
    point: _point,
    duration: const Duration(seconds: 15),
    readings: [
      SignalHeard(_target, median: const Dbm(-71.5), samples: 42),
      const NoSignal(TargetId('t2')),
    ],
  ),
  const MeasurementDiscarded(point: _point, reason: DiscardReason.moved),
  GroundTruthRecorded(target: _target, at: p(9, 6)),
  const SessionClosed(),
];

EventEnvelope _envelope(SessionEvent event, int seq) => EventEnvelope(
  id: EventId('0190c0de-1234-7abc-8def-0123456789a$seq'),
  session: const SessionId('0190c0de-0000-7abc-8def-000000000000'),
  seq: seq,
  hlc: HybridTimestamp(
    physicalMs: 1760000000000 + seq,
    counter: 0,
    device: const DeviceId('device-a'),
  ),
  event: event,
);

void main() {
  test('all 13 v1 event types are covered', () {
    expect(_events.map((e) => e.type).toSet(), hasLength(13));
  });

  for (final (i, event) in _events.indexed) {
    test('${event.type} round-trips through JSON (envelope included)', () {
      final envelope = _envelope(event, i % 10);
      final text = jsonEncode(envelope.toJson());
      final decoded = EventEnvelope.fromJson(
        jsonDecode(text) as Map<String, Object?>,
      );
      expect(decoded, envelope);
      expect(decoded.event, event);
    });
  }

  test('a non-detection survives as data', () {
    final json =
        jsonDecode(jsonEncode(_events[9].toJson())) as Map<String, Object?>;
    final decoded = SessionEvent.fromJson(json) as MeasurementCompleted;
    expect(
      decoded.readings.whereType<NoSignal>().single.target,
      const TargetId('t2'),
    );
  });

  group('strict decoding', () {
    Map<String, Object?> json(SessionEvent e) =>
        jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;

    test('unknown type', () {
      expect(
        () => SessionEvent.fromJson({'type': 'Teleported', 'payload': {}}),
        throwsFormatException,
      );
    });

    test('missing field', () {
      final j = json(_events[0]);
      (j['payload']! as Map<String, Object?>).remove('title');
      expect(() => SessionEvent.fromJson(j), throwsFormatException);
    });

    test('mistyped field', () {
      final j = json(_events[8]);
      ((j['payload']! as Map<String, Object?>)['at']!
              as Map<String, Object?>)['x'] =
          'three';
      expect(() => SessionEvent.fromJson(j), throwsFormatException);
    });

    test('invalid polygon', () {
      final j = json(_events[1]);
      (j['payload']! as Map<String, Object?>)['corners'] = [
        {'x': 0, 'y': 0},
        {'x': 1, 'y': 0},
      ];
      expect(() => SessionEvent.fromJson(j), throwsFormatException);
    });

    test('unknown enum name', () {
      final j = json(_events[2]);
      (j['payload']! as Map<String, Object?>)['source'] = 'laser';
      expect(() => SessionEvent.fromJson(j), throwsFormatException);
    });
  });

  group('validation', () {
    test('scale factor must be positive', () {
      expect(
        () => ScaleSet(factor: 0, source: ScaleSource.tape),
        throwsArgumentError,
      );
    });

    test('readings must be plausible', () {
      expect(
        () => SignalHeard(_target, median: const Dbm(-140), samples: 3),
        throwsArgumentError,
      );
      expect(
        () => SignalHeard(_target, median: const Dbm(-70), samples: -1),
        throwsArgumentError,
      );
    });
  });
}
