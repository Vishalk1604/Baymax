// =============================================================================
// BAYMAX MODELS — baymax_models.dart
// All data structures, enums, and constants for the Baymax OTC algorithm.
// =============================================================================

// Enum values stay snake_case on purpose: their `.name` is the exact string the
// LLM taxonomy uses and what profiles store in Firestore (`conditions`,
// `allergies`). Renaming them would break both.
// ignore_for_file: constant_identifier_names

import '../core/vital_thresholds.dart';

export '../core/vital_thresholds.dart';

// ---------------------------------------------------------------------------
// STANDARD SYMPTOM TAXONOMY
// All symptoms the system understands. LLM maps free-text → these values.
// ---------------------------------------------------------------------------

enum StandardSymptom {
  // ── FEVER ──
  mild_fever,
  fever,
  high_fever,

  // ── PAIN ──
  headache,
  migraine,
  body_ache,
  muscle_pain,
  joint_pain,
  back_pain,
  neck_pain,
  throat_pain,
  ear_pain,
  tooth_pain,
  pelvic_pain,
  stomach_cramps,

  // ── RESPIRATORY / ENT ──
  sneezing,
  runny_nose,
  blocked_nose,
  nasal_congestion,
  itchy_nose,
  itchy_eyes,
  watery_eyes,
  sinus_pressure,
  cough,
  chest_tightness,
  wheezing,
  breathing_difficulty,

  // ── GI ──
  heartburn,
  acid_reflux,
  sour_taste,
  upper_stomach_discomfort,
  bloating,
  nausea,
  vomiting,
  persistent_vomiting,
  diarrhea,
  watery_stool,
  loose_stool,
  severe_abdominal_pain,

  // ── SKIN ──
  skin_rash,
  itching,
  hives,

  // ── DEHYDRATION / SYSTEMIC ──
  dizziness,
  lightheadedness,
  dry_mouth,
  reduced_urination,
  heat_exhaustion,
  excessive_sweating,
  weakness,
  fatigue,
  swelling,

  // ── NEUROLOGICAL ──
  confusion,
  seizures,
  fainting,
  sensitivity_to_light,

  // ── SEVERE / RED FLAG ──
  blood_in_vomit,
  black_stool,
  blood_in_stool,
  no_urine,
  low_spo2,
  severe_weakness,
  facial_swelling,
  lip_swelling,
  tongue_swelling,
}

// ---------------------------------------------------------------------------
// MEDICATIONS
// ---------------------------------------------------------------------------

enum Medication {
  paracetamol,
  ibuprofen,
  cetirizine,
  famotidine,
  ors,
  none,
}

extension MedicationInfo on Medication {
  String get displayName => switch (this) {
        Medication.paracetamol => 'Paracetamol (Acetaminophen)',
        Medication.ibuprofen => 'Ibuprofen',
        Medication.cetirizine => 'Cetirizine',
        Medication.famotidine => 'Famotidine',
        Medication.ors => 'ORS (Oral Rehydration Salts)',
        Medication.none => 'No medication',
      };

  String get simpleName => switch (this) {
        Medication.paracetamol => 'Paracetamol (650mg)',
        Medication.ibuprofen => 'Ibuprofen (400mg)',
        Medication.cetirizine => 'Cetirizine (10mg)',
        Medication.famotidine => 'Famotidine',
        Medication.ors => 'ORS',
        Medication.none => 'None',
      };

  String get genericName => switch (this) {
        Medication.paracetamol => 'Acetaminophen / Paracetamol',
        Medication.ibuprofen => 'Ibuprofen (NSAID)',
        Medication.cetirizine => 'Cetirizine (Antihistamine)',
        Medication.famotidine => 'Famotidine (H2 blocker)',
        Medication.ors => 'Oral Rehydration Salts',
        Medication.none => '—',
      };

  String get typicalPurpose => switch (this) {
        Medication.paracetamol => 'pain and fever relief',
        Medication.ibuprofen => 'inflammatory pain and fever',
        Medication.cetirizine => 'allergic and cold symptoms',
        Medication.famotidine => 'acid reflux and bloating',
        Medication.ors => 'rehydration and fluid loss',
        Medication.none => 'N/A',
      };

  /// Standard adult dosing guidance strings
  DosingInfo get standardAdultDosing => switch (this) {
        Medication.paracetamol => const DosingInfo(
            dose: '650 mg',
            frequency: 'Min 6 hours apart',
            maxDailyDose: '3 tablets (1,950 mg)',
            minIntervalHours: 6,
            maxDosesPerDay: 3,
            notes: 'Take with or without food.'),
        Medication.ibuprofen => const DosingInfo(
            dose: '400 mg',
            frequency: '6–8 hours apart',
            // OTC ceiling is 1,200 mg/day; more needs a doctor's supervision.
            maxDailyDose: '3 tablets (1,200 mg)',
            minIntervalHours: 6,
            maxDosesPerDay: 3,
            notes: 'Always take with food or milk. Stay well hydrated.'),
        Medication.cetirizine => const DosingInfo(
            dose: '10 mg',
            frequency: 'Once daily',
            maxDailyDose: '10 mg/day',
            minIntervalHours: 24,
            maxDosesPerDay: 1,
            notes: 'May cause drowsiness. Avoid alcohol and driving.'),
        Medication.famotidine => const DosingInfo(
            dose: '10–20 mg',
            frequency: 'Once or twice daily',
            maxDailyDose: '40 mg/day',
            minIntervalHours: 12,
            maxDosesPerDay: 2,
            notes: 'Take 15–60 min before meals for best effect.'),
        Medication.ors => const DosingInfo(
            dose: '200–400 mL per loose stool or vomiting episode',
            frequency: 'After each fluid loss event; sip continuously',
            maxDailyDose: 'As tolerated (no max in non-renal adults)',
            minIntervalHours: 0,
            notes: 'Dissolve sachet in 1 L clean water. Drink slowly.'),
        Medication.none => const DosingInfo(
            dose: 'N/A',
            frequency: 'N/A',
            maxDailyDose: 'N/A',
            minIntervalHours: 0,
            notes: 'No medication indicated at this time.'),
      };

  /// Device compartment that holds this medicine (see firmware processCommand),
  /// or 0 when it isn't stocked in the device.
  int get deviceCompartment => switch (this) {
        Medication.paracetamol => 1,
        Medication.cetirizine => 2,
        Medication.ibuprofen => 3,
        Medication.famotidine => 4,
        Medication.ors || Medication.none => 0,
      };

  /// Resolves a stored medication name (simpleName, displayName or free text
  /// such as "Paracetamol (650mg)") back to a [Medication]. Returns null when
  /// it isn't one of the engine's medicines.
  static Medication? fromName(String? name) {
    if (name == null) return null;
    final lower = name.toLowerCase();
    for (final med in Medication.values) {
      if (med == Medication.none) continue;
      if (med.simpleName.toLowerCase() == lower || med.displayName.toLowerCase() == lower) return med;
    }
    if (lower.contains('paracetamol') || lower.contains('acetaminophen')) return Medication.paracetamol;
    if (lower.contains('ibuprofen')) return Medication.ibuprofen;
    if (lower.contains('cetirizine')) return Medication.cetirizine;
    if (lower.contains('famotidine')) return Medication.famotidine;
    if (lower == 'ors' || lower.contains('oral rehydration')) return Medication.ors;
    return null;
  }
}

class DosingInfo {
  final String dose;
  final String frequency;
  final String maxDailyDose;
  final int minIntervalHours;

  /// Maximum doses in any 24 hours; 0 means no fixed limit.
  final int maxDosesPerDay;
  final String notes;

  const DosingInfo({
    required this.dose,
    required this.frequency,
    required this.maxDailyDose,
    required this.minIntervalHours,
    this.maxDosesPerDay = 0,
    required this.notes,
  });
}

// ---------------------------------------------------------------------------
// VITALS
// ---------------------------------------------------------------------------

/// Raw vitals captured from device sensors / manual entry.
class VitalsReading {
  /// Body temperature in Celsius.
  final double temperatureCelsius;

  /// Blood oxygen saturation percentage (0–100).
  final double spo2Percent;

  /// Heart rate in beats per minute.
  final int heartRateBpm;

  /// Timestamp of reading.
  final DateTime timestamp;

  const VitalsReading({
    required this.temperatureCelsius,
    required this.spo2Percent,
    required this.heartRateBpm,
    required this.timestamp,
  });

  /// Convenience: convert Fahrenheit input to Celsius internally.
  factory VitalsReading.fromFahrenheit({
    required double temperatureFahrenheit,
    required double spo2Percent,
    required int heartRateBpm,
    DateTime? timestamp,
  }) {
    return VitalsReading(
      temperatureCelsius: (temperatureFahrenheit - 32) * 5 / 9,
      spo2Percent: spo2Percent,
      heartRateBpm: heartRateBpm,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Returns vitals-derived symptom tags (thresholds: [VitalThresholds]).
  List<StandardSymptom> get derivedSymptoms {
    final symptoms = <StandardSymptom>[];
    final t = temperatureCelsius;

    if (t >= VitalThresholds.highFeverFrom) {
      symptoms.add(StandardSymptom.high_fever);
    } else if (t >= VitalThresholds.feverFrom) {
      symptoms.add(StandardSymptom.fever);
    } else if (t >= VitalThresholds.mildFeverFrom) {
      symptoms.add(StandardSymptom.mild_fever);
    }

    if (spo2Percent < VitalThresholds.spo2LowBelow) {
      symptoms.add(StandardSymptom.low_spo2);
    }

    return symptoms;
  }

  /// Every vitals alert, most severe first.
  ///
  /// This is the only place vitals are graded: [alert] and the safety
  /// engine's VitalsSafetyCheck both read from it, so the result card and the
  /// escalation decision can never disagree.
  List<VitalsAlert> get alerts {
    final t = temperatureCelsius;
    final tStr = t.toStringAsFixed(1);
    final spo2Str = spo2Percent.toStringAsFixed(0);
    final list = <VitalsAlert>[];

    // ── Temperature ──
    if (t > VitalThresholds.hyperpyrexiaAbove) {
      list.add(VitalsAlert(
        level: AlertLevel.emergency,
        vital: 'temperature',
        message: 'Hyperpyrexia: temperature $tStr°C is dangerously high. Seek emergency care immediately.',
      ));
    } else if (t < VitalThresholds.hypothermiaBelow) {
      list.add(VitalsAlert(
        level: AlertLevel.emergency,
        vital: 'temperature',
        message: 'Hypothermia: temperature $tStr°C is dangerously low. Seek emergency care immediately.',
      ));
    } else if (t >= VitalThresholds.veryHighFeverFrom) {
      list.add(VitalsAlert(
        level: AlertLevel.warning,
        vital: 'temperature',
        message: 'Very high fever ($tStr°C). Medicine only helps temporarily — see a doctor within 24 hours.',
      ));
    } else if (t >= VitalThresholds.highFeverFrom) {
      list.add(VitalsAlert(
        level: AlertLevel.warning,
        vital: 'temperature',
        message: 'High fever ($tStr°C). See a doctor if it does not come down or lasts more than 2 days.',
      ));
    } else if (t < VitalThresholds.normalFrom) {
      list.add(VitalsAlert(
        level: AlertLevel.info,
        vital: 'temperature',
        message: 'Temperature $tStr°C is slightly below normal. Keep warm and measure again.',
      ));
    }

    // ── SpO2 ──
    if (spo2Percent < VitalThresholds.spo2CriticalBelow) {
      list.add(VitalsAlert(
        level: AlertLevel.emergency,
        vital: 'spo2',
        message: 'Critical SpO₂ ($spo2Str%): oxygen level is dangerously low. Call emergency services now.',
      ));
    } else if (spo2Percent < VitalThresholds.spo2LowBelow) {
      list.add(VitalsAlert(
        level: AlertLevel.warning,
        vital: 'spo2',
        message: 'Low SpO₂ ($spo2Str%, normal is 95–100%). Measure again at rest; see a doctor if it stays low.',
      ));
    }

    // ── Heart rate ──
    if (heartRateBpm > VitalThresholds.severeTachycardiaAbove) {
      list.add(VitalsAlert(
        level: AlertLevel.emergency,
        vital: 'heartRate',
        message: 'Severe tachycardia: heart rate $heartRateBpm bpm. Seek emergency care immediately.',
      ));
    } else if (heartRateBpm > VitalThresholds.tachycardiaAbove) {
      list.add(VitalsAlert(
        level: AlertLevel.warning,
        vital: 'heartRate',
        message: 'Elevated heart rate ($heartRateBpm bpm). Rest and measure again; see a doctor if it stays high.',
      ));
    } else if (heartRateBpm < VitalThresholds.bradycardiaBelow) {
      list.add(VitalsAlert(
        level: AlertLevel.warning,
        vital: 'heartRate',
        message: 'Low heart rate ($heartRateBpm bpm, normal is 60–100). See a doctor if you feel dizzy or faint.',
      ));
    }

    list.sort((a, b) => b.level.index.compareTo(a.level.index));
    return list;
  }

  /// The most severe vitals alert, or null if all vitals are normal.
  VitalsAlert? get alert {
    final all = alerts;
    return all.isEmpty ? null : all.first;
  }

  /// True when any vital is in the emergency range.
  bool get isCritical => alerts.any((a) => a.level == AlertLevel.emergency);
}

// ---------------------------------------------------------------------------
// ALERTS
// ---------------------------------------------------------------------------

enum AlertLevel {
  info,
  warning,
  danger,
  emergency,
}

class VitalsAlert {
  final AlertLevel level;
  final String message;
  final String vital;

  const VitalsAlert({
    required this.level,
    required this.message,
    required this.vital,
  });
}

class SafetyAlert {
  final AlertLevel level;
  final String message;
  final String? blockedMedication;
  final bool requiresEscalation;

  const SafetyAlert({
    required this.level,
    required this.message,
    this.blockedMedication,
    this.requiresEscalation = false,
  });
}

// ---------------------------------------------------------------------------
// PATIENT INPUT (assembled before algorithm run)
// ---------------------------------------------------------------------------

class PatientInput {
  /// Raw natural-language symptom description from user.
  final String rawDescription;

  /// Standardized symptoms derived by LLM from rawDescription.
  final List<StandardSymptom> standardSymptoms;

  /// Vitals reading.
  final VitalsReading vitals;

  /// Known patient conditions / history (optional, user-reported).
  final List<KnownCondition> knownConditions;

  /// Known drug allergies (optional).
  final List<DrugAllergy> knownAllergies;

  /// Age of patient (optional – affects dosing).
  final int? patientAgeYears;

  const PatientInput({
    required this.rawDescription,
    required this.standardSymptoms,
    required this.vitals,
    this.knownConditions = const [],
    this.knownAllergies = const [],
    this.patientAgeYears,
  });

  /// Merged symptom set: LLM-parsed + vitals-derived (deduplicated).
  List<StandardSymptom> get allSymptoms {
    final merged = {...standardSymptoms, ...vitals.derivedSymptoms};
    return merged.toList();
  }
}

enum KnownCondition {
  chronic_liver_disease,
  heavy_alcohol_use,
  gastric_ulcer,
  kidney_disease,
  nsaid_asthma,
  heart_disease,
  severe_kidney_impairment,
  dehydration,
  antihistamine_allergy,
  hepatotoxic_drug_use,
}

enum DrugAllergy {
  nsaid,
  paracetamol,
  antihistamine,
  famotidine,
  sulfa,
}

// ---------------------------------------------------------------------------
// VERIFICATION QUESTION (generated by LLM, answered by user)
// ---------------------------------------------------------------------------

class VerificationQuestion {
  final String id;
  final String question;
  final List<String> options; // for multi-choice UI
  final bool allowFreeText;
  final String? context; // internal context for LLM evaluator

  const VerificationQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.allowFreeText = false,
    this.context,
  });
}

class VerificationAnswer {
  final String questionId;
  final String answer; // selected option or free-text

  const VerificationAnswer({
    required this.questionId,
    required this.answer,
  });
}

// ---------------------------------------------------------------------------
// RECOMMENDATION RESULT
// ---------------------------------------------------------------------------

class RecommendationResult {
  /// Primary medication recommendation.
  final Medication primaryMedication;

  /// Optional co-medication (e.g. ORS + Paracetamol).
  final Medication? secondaryMedication;

  /// Dosing information for primary medication.
  final DosingInfo dosing;

  /// Optional dosing for secondary medication.
  final DosingInfo? secondaryDosing;

  /// All safety alerts generated.
  final List<SafetyAlert> safetyAlerts;

  /// Vitals-level alert (if any).
  final VitalsAlert? vitalsAlert;

  /// Whether the case was escalated to medical referral.
  final bool escalateToDoctor;

  /// Reason for escalation (if applicable).
  final String? escalationReason;

  /// Human-readable summary.
  final String summary;

  /// The matching case ID from the algorithm.
  final String? matchedCaseId;

  /// Flags whether the recommendation is within OTC boundaries.
  final bool isWithinOtcBoundary;

  const RecommendationResult({
    required this.primaryMedication,
    this.secondaryMedication,
    required this.dosing,
    this.secondaryDosing,
    required this.safetyAlerts,
    this.vitalsAlert,
    required this.escalateToDoctor,
    this.escalationReason,
    required this.summary,
    this.matchedCaseId,
    required this.isWithinOtcBoundary,
  });
}

// ---------------------------------------------------------------------------
// ALGORITHM RUN STATE (internal, used by controller)
// ---------------------------------------------------------------------------

class AlgorithmState {
  final PatientInput input;
  final List<SafetyAlert> accumulatedAlerts;
  final List<VerificationAnswer> verificationAnswers;
  bool escalationTriggered;
  String? escalationReason;
  String? matchedCaseId;

  AlgorithmState({
    required this.input,
    List<SafetyAlert>? accumulatedAlerts,
    List<VerificationAnswer>? verificationAnswers,
    this.escalationTriggered = false,
    this.escalationReason,
    this.matchedCaseId,
  })  : accumulatedAlerts = accumulatedAlerts ?? [],
        verificationAnswers = verificationAnswers ?? [];
}
