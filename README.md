# rubble_core

[![CI](https://github.com/Berkant35/rubble_core/actions/workflows/ci.yml/badge.svg)](https://github.com/Berkant35/rubble_core/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Core types of [BeneathSOS](https://github.com/Berkant35/beneathsos) in pure Dart (no Flutter):

- **Typed units** — `Meters`, `SquareMeters`, `Dbm`, `Decibels`, `Hpa` as zero-cost extension types.
  They never mix: `Meters + Dbm` does not compile, and a `Meters` is not a `double`.
- **Rubble geometry in local metres** — `SitePoint`, `RubblePolygon` (validated: ≥ 3 finite corners,
  no corners closer than 0.1 m, no crossing sides, at least 0.01 m²) with perimeter, area, bounds,
  centroid and `contains`.
- **Identifiers and time** — monotonic UUIDv7 (`Uuid7Generator`) and typed ids (`SessionId`,
  `EventId`, `DeviceId`, `PointId`, `TargetId` — they never mix); a hybrid logical clock
  (`HybridClock`, `HybridTimestamp`) so logs from several phones merge in one order. After a restart,
  seed the clock with the last stored timestamp (`HybridClock(last: …)`).
- **Session events** — 13 sealed `SessionEvent` types inside an `EventEnvelope` with strict JSON
  (schema 1): anything missing, mistyped, unknown or non-finite throws a `FormatException` naming the
  field. A point where the phone was not heard is stored as `NoSignal` — no signal is data.
- **Session projection** — `SessionProjection.replay(events)` rebuilds the immutable `SessionState`
  the screens show. Pure and deterministic: input order and duplicate events do not matter, discarded
  or moved points set their readings aside, and no target identity is ever lost.

```dart
final outline = RubblePolygon([
  SitePoint(Meters(0), Meters(0)),
  SitePoint(Meters(18.2), Meters(0)),
  SitePoint(Meters(18.2), Meters(12.4)),
  SitePoint(Meters(0), Meters(12.4)),
]);
outline.area; // SquareMeters(225.68)

final state = SessionProjection.replay(storedEvents);
state.outline;        // the latest outline, by hybrid-clock order
state.measuredPoints; // points with readings for the engine, non-detections included
```

Never latitude/longitude in v1; never a distance from RSSI (signal strength cannot separate distance
from attenuation — see the hub's feasibility study).

Licence: Apache-2.0.
