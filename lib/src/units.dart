/// Physical quantities as zero-cost types. They do not implement `double`, so different units can
/// never be mixed by accident; `.value` is the explicit way out for maths and storage.
library;

/// A length or a local site coordinate in metres (negative as a coordinate).
extension type const Meters(double value) {
  /// Zero metres.
  static const Meters zero = Meters(0);

  /// Sum.
  Meters operator +(Meters other) => Meters(value + other.value);

  /// Difference.
  Meters operator -(Meters other) => Meters(value - other.value);

  /// Negation.
  Meters operator -() => Meters(-value);

  /// Scaled by [factor].
  Meters operator *(num factor) => Meters(value * factor);

  /// Divided by [divisor].
  Meters operator /(num divisor) => Meters(value / divisor);

  /// Less than.
  bool operator <(Meters other) => value < other.value;

  /// Greater than.
  bool operator >(Meters other) => value > other.value;

  /// Absolute value.
  Meters abs() => Meters(value.abs());

  /// Ordering by value.
  int compareTo(Meters other) => value.compareTo(other.value);
}

/// An area in square metres.
extension type const SquareMeters(double value) {
  /// Sum.
  SquareMeters operator +(SquareMeters other) =>
      SquareMeters(value + other.value);

  /// Difference.
  SquareMeters operator -(SquareMeters other) =>
      SquareMeters(value - other.value);

  /// Ordering by value.
  int compareTo(SquareMeters other) => value.compareTo(other.value);
}

/// Received signal strength in dBm (a mean over samples may be fractional).
extension type const Dbm(double value) {
  /// Lowest and highest RSSI a phone reports in practice.
  static const Dbm minPlausible = Dbm(-127);

  /// Highest plausible RSSI.
  static const Dbm maxPlausible = Dbm(20);

  /// The difference between two levels, in decibels.
  Decibels operator -(Dbm other) => Decibels(value - other.value);

  /// Whether this lies in the range phones report (−127 … +20 dBm).
  bool get isPlausible =>
      value >= minPlausible.value && value <= maxPlausible.value;

  /// Ordering by value (stronger is greater).
  int compareTo(Dbm other) => value.compareTo(other.value);
}

/// A difference between two signal levels, in decibels.
extension type const Decibels(double value) {
  /// Sum.
  Decibels operator +(Decibels other) => Decibels(value + other.value);

  /// Difference.
  Decibels operator -(Decibels other) => Decibels(value - other.value);

  /// Absolute value.
  Decibels abs() => Decibels(value.abs());
}

/// Barometric pressure in hectopascals. Depth is never derived from RSSI (product rule 2).
extension type const Hpa(double value) {
  /// Difference.
  Hpa operator -(Hpa other) => Hpa(value - other.value);

  /// Ordering by value.
  int compareTo(Hpa other) => value.compareTo(other.value);
}
