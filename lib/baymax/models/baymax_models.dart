// =============================================================================
// BAYMAX MODELS — baymax_models.dart
// All data structures, enums, and constants for the Baymax OTC algorithm.
// =============================================================================

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
            maxDailyDose: '3 tablets',
            minIntervalHours: 6,
            notes: 'Take with or without food.'),
        Medication.ibuprofen => const DosingInfo(
            dose: '400 mg',
            frequency: '6 hours apart',
            maxDailyDose: '4 tablets',
            minIntervalHours: 6,
            notes: 'Always take with food or milk. Stay well hydrated.'),
        Medication.cetirizine => const DosingInfo(
            dose: '10 mg',
            frequency: 'Once daily',
            maxDailyDose: '10 mg/day',
            minIntervalHours: 24,
            notes: 'May cause drowsiness. Avoid alcohol and driving.'),
        Medication.famotidine => const DosingInfo(
            dose: '10–20 mg',
            frequency: 'Once or twice daily',
            maxDailyDose: '40 mg/day',
            minIntervalHours: 12,
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
}

class DosingInfo {
  final String dose;
  final String frequency;
  final String maxDailyDose;
  final int minIntervalHours;
  final String notes;

  const DosingInfo({
    required this.dose,
    required this.frequency,
    required this.maxDailyDose,
    required this.minIntervalHours,
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

  /// Returns vitals-derived symptom tags.
  List<StandardSymptom> get derivedSymptoms {
    final symptoms = <StandardSymptom>[];

    // Temperature interpretation — UPDATED THRESHOLDS
    if (temperatureCelsius >= 32.8 && temperatureCelsius <= 34.4) {
      // Normal range as per request
    } else if (temperatureCelsius > 34.4 && temperatureCelsius <= 39.0) {
      symptoms.add(StandardSymptom.fever);
    } else if (temperatureCelsius > 39.0) {
      symptoms.add(StandardSymptom.high_fever);
    }

    // SpO2 interpretation
    if (spo2Percent < 95.0) {
      symptoms.add(StandardSymptom.low_spo2);
    }

    return symptoms;
  }

  /// Returns the vitals-level triage alert (null if all normal).
  VitalsAlert? get alert {
    // Critical temperature — UPDATED
    if (temperatureCelsius > 40.0) {
      return VitalsAlert(
        level: AlertLevel.emergency,
        message:
            '⚠️ HYPERPYREXIA: Temperature ${temperatureCelsius.toStringAsFixed(1)}°C is life-threatening. Seek emergency care immediately.',
        vital: 'temperature',
      );
    }
    // Hypothermia adjusted based on new "Normal" floor of 32.8
    if (temperatureCelsius < 32.0) {
      return VitalsAlert(
        level: AlertLevel.emergency,
        message:
            '⚠️ HYPOTHERMIA: Temperature ${temperatureCelsius.toStringAsFixed(1)}°C is critically low. Seek emergency care immediately.',
        vital: 'temperature',
      );
    }

    // Critical SpO2
    if (spo2Percent < 90.0) {
      return VitalsAlert(
        level: AlertLevel.emergency,
        message:
            '🆘 CRITICAL SpO₂: ${spo2Percent.toStringAsFixed(0)}%. Oxygen saturation is dangerously low. Call emergency services NOW.',
        vital: 'spo2',
      );
    }
    if (spo2Percent < 95.0) {
      return VitalsAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ LOW SpO₂: ${spo2Percent.toStringAsFixed(0)}%. Below normal range (95–100%). Seek medical evaluation.',
        vital: 'spo2',
      );
    }

    // Critical heart rate
    if (heartRateBpm > 130) {
      return VitalsAlert(
        level: AlertLevel.emergency,
        message:
            '⚠️ SEVERE TACHYCARDIA: Heart rate $heartRateBpm bpm. Seek emergency care.',
        vital: 'heartRate',
      );
    }
    if (heartRateBpm > 100) {
      return VitalsAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ TACHYCARDIA: Heart rate $heartRateBpm bpm. Elevated. Monitor and seek care if persistent.',
        vital: 'heartRate',
      );
    }
    if (heartRateBpm < 50) {
      return VitalsAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ BRADYCARDIA: Heart rate $heartRateBpm bpm. Below normal (60–100). Seek medical evaluation.',
        vital: 'heartRate',
      );
    }

    return null;
  }
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
