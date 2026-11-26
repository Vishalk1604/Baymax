// =============================================================================
// VITAL THRESHOLDS — vital_thresholds.dart
// The single source of truth for every vitals cut-off in the app.
// Values follow docs/IMPLEMENTATION.md §7. Every temperature here is a BODY
// temperature in °C; raw forehead readings from the device must go through
// [TemperatureCalibration.bodyFromForehead] first.
// =============================================================================

class VitalThresholds {
  VitalThresholds._();

  // ── Temperature (°C, body) ──
  /// Below this: hypothermia → emergency.
  static const double hypothermiaBelow = 35.0;

  /// 35.0 up to this: subnormal (re-measure). From this up: normal.
  static const double normalFrom = 36.1;

  /// 37.3–38.0 → `mild_fever`.
  static const double mildFeverFrom = 37.3;

  /// 38.1–39.0 → `fever`.
  static const double feverFrom = 38.1;

  /// 39.1–40.0 → `high_fever` + warning.
  static const double highFeverFrom = 39.1;

  /// 39.5–40.0 → `high_fever` + strong warning.
  static const double veryHighFeverFrom = 39.5;

  /// Above this: hyperpyrexia → emergency.
  static const double hyperpyrexiaAbove = 40.0;

  // ── SpO2 (%) ──
  /// Below this: critical → emergency.
  static const double spo2CriticalBelow = 90.0;

  /// 90–94: low → warning + `low_spo2`.
  static const double spo2LowBelow = 95.0;

  // ── Heart rate (bpm) ──
  /// Below this: bradycardia → warning.
  static const int bradycardiaBelow = 50;

  /// Above this (up to [severeTachycardiaAbove]): tachycardia → warning.
  static const int tachycardiaAbove = 100;

  /// Above this: severe tachycardia → emergency.
  static const int severeTachycardiaAbove = 130;

  // ── Plausibility ──
  // A reading outside these ranges is a sensor fault, not a vital sign, and
  // must never reach the recommendation engine.
  static const double minPlausibleBodyTemp = 30.0;
  static const double maxPlausibleBodyTemp = 45.0;
  static const int minPlausibleHeartRate = 30;
  static const int maxPlausibleHeartRate = 220;
  static const int minPlausibleSpo2 = 70;
  static const int maxPlausibleSpo2 = 100;

  static bool isPlausibleBodyTemp(double celsius) =>
      celsius >= minPlausibleBodyTemp && celsius <= maxPlausibleBodyTemp;

  static bool isPlausibleHeartRate(int bpm) =>
      bpm >= minPlausibleHeartRate && bpm <= maxPlausibleHeartRate;

  static bool isPlausibleSpo2(int percent) =>
      percent >= minPlausibleSpo2 && percent <= maxPlausibleSpo2;
}

/// Converts the device's forehead reading into an estimated body temperature.
///
/// The MLX90614 measures forehead *skin*, which runs a few degrees below core
/// temperature. The app previously treated raw readings of 32.8–34.4 °C as
/// normal; that band's midpoint (33.6 °C) lines up with the clinical normal
/// midpoint (~36.6 °C) at an offset of +3.0 °C.
///
/// VALIDATE THIS against a clinical thermometer on several people before
/// relying on it — it is the one number every fever decision depends on.
class TemperatureCalibration {
  TemperatureCalibration._();

  static const double foreheadToBodyOffsetC = 3.0;

  static double bodyFromForehead(double foreheadCelsius) =>
      foreheadCelsius + foreheadToBodyOffsetC;
}
