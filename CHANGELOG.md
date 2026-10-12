## 0.1.0
- Session events v1 (13 types, sealed) with strict JSON and the `EventEnvelope` (schema 1);
  "no signal" readings are kept as data.
- Monotonic UUIDv7 ids (`Uuid7Generator`, `Uuid7.parse`) and typed ids (`SessionId`, `EventId`,
  `DeviceId`, `PointId`, `TargetId`); hybrid logical clock (`HybridClock`, `HybridTimestamp`).
- Typed units (`Meters`, `SquareMeters`, `Dbm`, `Decibels`, `Hpa`) and rubble geometry
  (`SitePoint`, `RubblePolygon` with validation, perimeter, area, bounds, centroid, `contains`).
