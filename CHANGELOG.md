## 0.3.0
- `RubbleDepthSet` (height of the rubble, `TrappedLevel` where the person most likely was) and
  `SessionState.depth` — the depth the signal cannot tell, given by the rescuers.

## 0.2.0
- `SessionState.lastSurfaceScan`: when the last surface scan finished, even one that set nothing
  aside (a manual exclusion is not a scan).

## 0.1.0
- Session projection (`SessionProjection.replay`): idempotent and order-independent; logs from
  several devices apply in hybrid-clock order, ties by event id; discarded or moved points set
  their readings aside (`discardedReadings`); target identities are never lost.
- `HybridClock(last:)` continues after the last stored timestamp across restarts.
- Numbers must be finite; `RubblePolygon` rejects non-finite corners (`NonFiniteCorner`) and outlines
  under 0.01 m² (`DegenerateOutline`).
- Session events v1 (13 types, sealed) with strict JSON and the `EventEnvelope` (schema 1);
  "no signal" readings are kept as data.
- Monotonic UUIDv7 ids (`Uuid7Generator`, `Uuid7.parse`) and typed ids (`SessionId`, `EventId`,
  `DeviceId`, `PointId`, `TargetId`); hybrid logical clock (`HybridClock`, `HybridTimestamp`).
- Typed units (`Meters`, `SquareMeters`, `Dbm`, `Decibels`, `Hpa`) and rubble geometry
  (`SitePoint`, `RubblePolygon` with validation, perimeter, area, bounds, centroid, `contains`).
