# rubble_core

[![CI](https://github.com/Berkant35/rubble_core/actions/workflows/ci.yml/badge.svg)](https://github.com/Berkant35/rubble_core/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Core types of [BeneathSOS](https://github.com/Berkant35/beneathsos) in pure Dart (no Flutter):

- **Typed units** — `Meters`, `SquareMeters`, `Dbm`, `Decibels`, `Hpa` as zero-cost extension types.
  They never mix: `Meters + Dbm` does not compile, and a `Meters` is not a `double`.
- **Rubble geometry in local metres** — `SitePoint`, `RubblePolygon` (validated: ≥ 3 corners, no
  corners closer than 0.1 m, no crossing sides) with perimeter, area, bounds, centroid and `contains`.

```dart
final outline = RubblePolygon([
  SitePoint(Meters(0), Meters(0)),
  SitePoint(Meters(18.2), Meters(0)),
  SitePoint(Meters(18.2), Meters(12.4)),
  SitePoint(Meters(0), Meters(12.4)),
]);
outline.area; // SquareMeters(225.68)
```

Never latitude/longitude in v1; never a distance from RSSI (signal strength cannot separate distance
from attenuation — see the hub's feasibility study).

Licence: Apache-2.0.
