import 'package:flutter/material.dart';

import '../../baymax/core/vital_thresholds.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models.dart';

enum VitalKind { temperature, heartRate, spo2 }

/// Presentation of the three vitals. Status uses the same thresholds as the
/// recommendation engine (VitalThresholds), so the UI and the algorithm agree.
extension VitalKindUi on VitalKind {
  String get label => switch (this) {
        VitalKind.temperature => 'Temperature',
        VitalKind.heartRate => 'Heart rate',
        VitalKind.spo2 => 'Oxygen (SpO₂)',
      };

  String get shortLabel => switch (this) {
        VitalKind.temperature => 'Temp',
        VitalKind.heartRate => 'Heart',
        VitalKind.spo2 => 'SpO₂',
      };

  IconData get icon => switch (this) {
        VitalKind.temperature => Icons.thermostat_rounded,
        VitalKind.heartRate => Icons.favorite_rounded,
        VitalKind.spo2 => Icons.water_drop_rounded,
      };

  double valueOf(CheckupRecord r) => switch (this) {
        VitalKind.temperature => r.temperature,
        VitalKind.heartRate => r.heartRate.toDouble(),
        VitalKind.spo2 => r.spo2.toDouble(),
      };

  (String, Tone) status(double v) {
    switch (this) {
      case VitalKind.temperature:
        if (v > VitalThresholds.hyperpyrexiaAbove) return ('Dangerously high', Tone.danger);
        if (v < VitalThresholds.hypothermiaBelow) return ('Dangerously low', Tone.danger);
        if (v >= VitalThresholds.highFeverFrom) return ('High fever', Tone.warning);
        if (v >= VitalThresholds.feverFrom) return ('Fever', Tone.warning);
        if (v >= VitalThresholds.mildFeverFrom) return ('Mild fever', Tone.warning);
        if (v < VitalThresholds.normalFrom) return ('A bit low', Tone.info);
        return ('Normal', Tone.success);
      case VitalKind.heartRate:
        if (v > VitalThresholds.severeTachycardiaAbove) return ('Very high', Tone.danger);
        if (v > VitalThresholds.tachycardiaAbove) return ('High', Tone.warning);
        if (v < VitalThresholds.bradycardiaBelow) return ('Low', Tone.warning);
        return ('Normal', Tone.success);
      case VitalKind.spo2:
        if (v < VitalThresholds.spo2CriticalBelow) return ('Critical', Tone.danger);
        if (v < VitalThresholds.spo2LowBelow) return ('Low', Tone.warning);
        return ('Normal', Tone.success);
    }
  }
}

extension TriageUi on Triage {
  Tone get tone => switch (this) {
        Triage.selfCare => Tone.success,
        Triage.monitor => Tone.info,
        Triage.doctor => Tone.warning,
        Triage.emergency => Tone.danger,
      };

  IconData get icon => switch (this) {
        Triage.selfCare => Icons.spa_rounded,
        Triage.monitor => Icons.visibility_rounded,
        Triage.doctor => Icons.medical_services_rounded,
        Triage.emergency => Icons.emergency_rounded,
      };
}

/// "fever" → "Fever", "runny_nose" → "Runny nose".
String symptomLabel(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
