// =============================================================================
// BAYMAX SAFETY ENGINE — baymax_safety.dart
// Multi-layer safety validation: red flags, contraindications, vitals checks.
// Each layer runs independently. ANY failure can block a drug or escalate.
// =============================================================================

import '../models/baymax_models.dart';

// ---------------------------------------------------------------------------
// RESULT TYPE
// ---------------------------------------------------------------------------

class SafetyCheckResult {
  final bool passed;
  final List<SafetyAlert> alerts;
  final Set<Medication> blockedMedications;
  final bool escalationRequired;
  final String? escalationReason;

  const SafetyCheckResult({
    required this.passed,
    required this.alerts,
    required this.blockedMedications,
    required this.escalationRequired,
    this.escalationReason,
  });

  SafetyCheckResult merge(SafetyCheckResult other) {
    final allAlerts = [...alerts, ...other.alerts];
    final allBlocked = {...blockedMedications, ...other.blockedMedications};
    final escalate = escalationRequired || other.escalationRequired;
    return SafetyCheckResult(
      passed: !escalate && allBlocked.isEmpty,
      alerts: allAlerts,
      blockedMedications: allBlocked,
      escalationRequired: escalate,
      escalationReason: escalationReason ?? other.escalationReason,
    );
  }
}

// ---------------------------------------------------------------------------
// CONSTANTS — RED FLAG SYMPTOMS
// Any one of these triggers immediate escalation; no OTC recommendation.
// ---------------------------------------------------------------------------

class RedFlagConstants {
  static const Set<StandardSymptom> globalRedFlags = {
    StandardSymptom.blood_in_vomit,
    StandardSymptom.black_stool,
    StandardSymptom.blood_in_stool,
    StandardSymptom.confusion,
    StandardSymptom.seizures,
    StandardSymptom.fainting,
    StandardSymptom.low_spo2,
    StandardSymptom.severe_weakness,
    StandardSymptom.no_urine,
  };

  static const Set<StandardSymptom> anaphylaxisMarkers = {
    StandardSymptom.facial_swelling,
    StandardSymptom.lip_swelling,
    StandardSymptom.tongue_swelling,
  };

  // Anaphylaxis requires ALL: swelling + breathing_difficulty
  static bool isAnaphylaxis(List<StandardSymptom> symptoms) {
    final hasSwelling = symptoms.any(anaphylaxisMarkers.contains);
    final hasBreathing =
        symptoms.contains(StandardSymptom.breathing_difficulty);
    return hasSwelling && hasBreathing;
  }

  static const Map<StandardSymptom, String> redFlagMessages = {
    StandardSymptom.blood_in_vomit:
        'Blood in vomit detected — possible GI bleeding. Emergency referral required.',
    StandardSymptom.black_stool:
        'Black/tarry stool detected — possible GI bleed (melena). Seek emergency care.',
    StandardSymptom.blood_in_stool:
        'Blood in stool — possible GI bleed or serious infection. Emergency referral required.',
    StandardSymptom.confusion:
        'Confusion/altered mental state — possible serious systemic cause. Seek emergency care.',
    StandardSymptom.seizures:
        'Seizures reported. Emergency referral required immediately.',
    StandardSymptom.fainting:
        'Fainting/loss of consciousness — possible cardiac or neurological cause. Seek emergency care.',
    StandardSymptom.low_spo2:
        'Low SpO₂ detected. Seek emergency care.',
    StandardSymptom.severe_weakness:
        'Severe weakness reported. May indicate serious systemic illness. Seek emergency care.',
    StandardSymptom.no_urine:
        'No urine output — possible acute kidney injury or severe dehydration. Seek emergency care immediately.',
  };
}

// ---------------------------------------------------------------------------
// LAYER 1 — VITALS SAFETY CHECK
// Blocks all OTC recommendations if vitals are out of safe range.
// ---------------------------------------------------------------------------

class VitalsSafetyCheck {
  /// Validates temperature, SpO2, heart rate against safe OTC thresholds.
  static SafetyCheckResult run(VitalsReading vitals) {
    final alerts = <SafetyAlert>[];
    var escalate = false;
    String? reason;

    // ── Temperature ──
    if (vitals.temperatureCelsius > 38.0) {
      escalate = true;
      reason = 'HYPERPYREXIA: Temperature ${vitals.temperatureCelsius.toStringAsFixed(1)}°C is dangerously high.';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🚨 $reason OTC paracetamol is insufficient. Seek emergency care IMMEDIATELY.',
        requiresEscalation: true,
      ));
    } else if (vitals.temperatureCelsius < 33.0) {
      escalate = true;
      reason = 'HYPOTHERMIA: Temperature ${vitals.temperatureCelsius.toStringAsFixed(1)}°C is critically low.';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🚨 $reason Seek emergency care IMMEDIATELY.',
        requiresEscalation: true,
      ));
    } else if (vitals.temperatureCelsius >= 37.5) {
      alerts.add(SafetyAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ Very high fever (${vitals.temperatureCelsius.toStringAsFixed(1)}°C). '
            'OTC management is a temporary measure only. Medical evaluation strongly advised within 24 hours.',
      ));
    }

    // ── SpO2 ──
    if (vitals.spo2Percent < 90.0) {
      escalate = true;
      reason = 'CRITICAL SpO₂: ${vitals.spo2Percent.toStringAsFixed(0)}% (dangerously low oxygen).';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🆘 $reason Call emergency services NOW.',
        requiresEscalation: true,
      ));
    } else if (vitals.spo2Percent < 95.0) {
      alerts.add(SafetyAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ Low SpO₂ ${vitals.spo2Percent.toStringAsFixed(0)}%. '
            'Below normal range. Seek medical evaluation before relying on OTC drugs.',
      ));
    }

    // ── Heart Rate ──
    if (vitals.heartRateBpm > 130) {
      escalate = true;
      reason = 'SEVERE TACHYCARDIA: Heart rate ${vitals.heartRateBpm} bpm.';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🚨 $reason Seek emergency care immediately.',
        requiresEscalation: true,
      ));
    } else if (vitals.heartRateBpm > 100) {
      alerts.add(SafetyAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ Elevated heart rate ${vitals.heartRateBpm} bpm. '
            'Monitor closely. If persistent, seek medical evaluation.',
      ));
    } else if (vitals.heartRateBpm < 50) {
      alerts.add(SafetyAlert(
        level: AlertLevel.warning,
        message:
            '⚠️ Low heart rate ${vitals.heartRateBpm} bpm (bradycardia). '
            'Seek medical evaluation.',
      ));
    }

    return SafetyCheckResult(
      passed: !escalate,
      alerts: alerts,
      blockedMedications: escalate ? Medication.values.toSet() : {},
      escalationRequired: escalate,
      escalationReason: reason,
    );
  }
}

// ---------------------------------------------------------------------------
// LAYER 2 — RED FLAG SYMPTOM CHECK
// Detects globally dangerous symptoms that block all OTC and escalate.
// ---------------------------------------------------------------------------

class RedFlagSymptomCheck {
  static SafetyCheckResult run(List<StandardSymptom> symptoms) {
    final alerts = <SafetyAlert>[];
    var escalate = false;
    String? reason;

    // Check global red flags
    for (final redFlag in RedFlagConstants.globalRedFlags) {
      if (symptoms.contains(redFlag)) {
        escalate = true;
        final msg = RedFlagConstants.redFlagMessages[redFlag] ?? redFlag.name;
        reason ??= msg;
        alerts.add(SafetyAlert(
          level: AlertLevel.emergency,
          message: '🚨 RED FLAG: $msg',
          requiresEscalation: true,
        ));
      }
    }

    // Check anaphylaxis pattern
    if (RedFlagConstants.isAnaphylaxis(symptoms)) {
      escalate = true;
      reason ??= 'Possible Anaphylaxis: Facial/lip/tongue swelling with breathing difficulty.';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🆘 ANAPHYLAXIS PATTERN detected. '
            'This is a medical emergency. Call 112/911 IMMEDIATELY.',
        requiresEscalation: true,
      ));
    }

    // Breathing difficulty without anaphylaxis — still dangerous
    if (symptoms.contains(StandardSymptom.breathing_difficulty) && !escalate) {
      escalate = true;
      reason = 'Breathing difficulty detected.';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🚨 BREATHING DIFFICULTY reported. This cannot be managed with OTC drugs. '
            'Seek emergency care immediately.',
        requiresEscalation: true,
      ));
    }

    // Severe abdominal pain check
    if (symptoms.contains(StandardSymptom.severe_abdominal_pain)) {
      escalate = true;
      reason ??= 'Severe abdominal pain (possible serious internal cause).';
      alerts.add(SafetyAlert(
        level: AlertLevel.emergency,
        message:
            '🚨 $reason Seek emergency evaluation immediately.',
        requiresEscalation: true,
      ));
    }

    return SafetyCheckResult(
      passed: !escalate,
      alerts: alerts,
      blockedMedications: escalate ? Medication.values.toSet() : {},
      escalationRequired: escalate,
      escalationReason: reason,
    );
  }
}

// ---------------------------------------------------------------------------
// LAYER 3 — CONTRAINDICATION CHECK (per medication)
// Blocks specific drugs based on known conditions and allergy history.
// ---------------------------------------------------------------------------

class ContraindicationCheck {
  static SafetyCheckResult run(PatientInput input) {
    final alerts = <SafetyAlert>[];
    final blocked = <Medication>{};

    // ── PARACETAMOL contraindications ──
    if (input.knownConditions.contains(KnownCondition.chronic_liver_disease)) {
      blocked.add(Medication.paracetamol);
      alerts.add(SafetyAlert(
        level: AlertLevel.danger,
        message:
            '⛔ PARACETAMOL BLOCKED: Chronic liver disease present. '
            'Paracetamol is hepatotoxic at standard doses in liver disease. Consult a doctor.',
        blockedMedication: 'Paracetamol',
      ));
    }
    if (input.knownConditions.contains(KnownCondition.heavy_alcohol_use)) {
      blocked.add(Medication.paracetamol);
      alerts.add(SafetyAlert(
        level: AlertLevel.danger,
        message:
            '⛔ PARACETAMOL BLOCKED: Heavy alcohol use increases hepatotoxicity risk. '
            'Do not use paracetamol. Seek medical advice.',
        blockedMedication: 'Paracetamol',
      ));
    }
    if (input.knownAllergies.contains(DrugAllergy.paracetamol)) {
      blocked.add(Medication.paracetamol);
      alerts.add(SafetyAlert(
        level: AlertLevel.danger,
        message:
            '⛔ PARACETAMOL BLOCKED: Known allergy on record.',
        blockedMedication: 'Paracetamol',
      ));
    }

    // ── IBUPROFEN contraindications ──
    final ibuprofenContraindications = [
      (KnownCondition.gastric_ulcer, 'Gastric ulcer history'),
      (KnownCondition.kidney_disease, 'Kidney disease'),
      (KnownCondition.nsaid_asthma, 'NSAID-exacerbated asthma'),
      (KnownCondition.heart_disease, 'Heart disease'),
    ];
    for (final (condition, label) in ibuprofenContraindications) {
      if (input.knownConditions.contains(condition)) {
        blocked.add(Medication.ibuprofen);
        alerts.add(SafetyAlert(
          level: AlertLevel.danger,
          message:
              '⛔ IBUPROFEN BLOCKED: $label. NSAIDs are contraindicated. Use Paracetamol instead.',
          blockedMedication: 'Ibuprofen',
        ));
      }
    }
    if (input.knownAllergies.contains(DrugAllergy.nsaid)) {
      blocked.add(Medication.ibuprofen);
      alerts.add(SafetyAlert(
        level: AlertLevel.danger,
        message:
            '⛔ IBUPROFEN BLOCKED: Known NSAID allergy on record.',
        blockedMedication: 'Ibuprofen',
      ));
    }

    // Ibuprofen symptom-based contraindications (from symptom list)
    if (input.allSymptoms.contains(StandardSymptom.reduced_urination) ||
        input.allSymptoms.contains(StandardSymptom.no_urine)) {
      blocked.add(Medication.ibuprofen);
      alerts.add(SafetyAlert(
        level: AlertLevel.danger,
        message:
            '⛔ IBUPROFEN BLOCKED: Signs of dehydration/reduced urine output. '
            'NSAIDs can cause acute kidney injury in dehydrated patients.',
        blockedMedication: 'Ibuprofen',
      ));
    }

    final escalationRequired =
        alerts.any((a) => a.requiresEscalation == true);

    return SafetyCheckResult(
      passed: blocked.isEmpty && !escalationRequired,
      alerts: alerts,
      blockedMedications: blocked,
      escalationRequired: escalationRequired,
    );
  }
}

// ---------------------------------------------------------------------------
// LAYER 4 — MULTI-SYMPTOM COMPLEXITY CHECK
// If symptoms span multiple unrelated systems, block OTC and escalate.
// ---------------------------------------------------------------------------

class ComplexityCheck {
  static SafetyCheckResult run(List<StandardSymptom> symptoms) {
    // Count distinct symptom systems involved
    final systems = <String>{};

    if (symptoms.any(_respiratorySymptoms.contains)) systems.add('respiratory');
    if (symptoms.any(_giSymptoms.contains)) systems.add('gastrointestinal');
    if (symptoms.any(_neuroSymptoms.contains)) systems.add('neurological');
    if (symptoms.any(_painSymptoms.contains)) systems.add('pain');
    if (symptoms.any(_skinSymptoms.contains)) systems.add('skin');
    if (symptoms.any(_feverSymptoms.contains)) systems.add('fever');

    // 4+ systems = complex multi-system presentation → escalate
    if (systems.length >= 4) {
      return SafetyCheckResult(
        passed: false,
        alerts: [
          SafetyAlert(
            level: AlertLevel.danger,
            message:
                '⚠️ COMPLEX MULTI-SYSTEM PRESENTATION: Symptoms span ${systems.length} body systems. '
                'This exceeds OTC management scope. Medical evaluation is required.',
            requiresEscalation: true,
          ),
        ],
        blockedMedications: Medication.values.toSet(),
        escalationRequired: true,
        escalationReason: 'Multi-system symptom complexity (${systems.length} systems involved).',
      );
    }

    return SafetyCheckResult(
      passed: true,
      alerts: [],
      blockedMedications: {},
      escalationRequired: false,
    );
  }

  static const Set<StandardSymptom> _respiratorySymptoms = {
    StandardSymptom.sneezing, StandardSymptom.runny_nose,
    StandardSymptom.blocked_nose, StandardSymptom.nasal_congestion,
    StandardSymptom.cough, StandardSymptom.chest_tightness,
    StandardSymptom.wheezing, StandardSymptom.breathing_difficulty,
  };
  static const Set<StandardSymptom> _giSymptoms = {
    StandardSymptom.heartburn, StandardSymptom.acid_reflux,
    StandardSymptom.nausea, StandardSymptom.vomiting,
    StandardSymptom.diarrhea, StandardSymptom.stomach_cramps,
    StandardSymptom.bloating, StandardSymptom.upper_stomach_discomfort,
  };
  static const Set<StandardSymptom> _neuroSymptoms = {
    StandardSymptom.confusion, StandardSymptom.seizures,
    StandardSymptom.fainting, StandardSymptom.dizziness,
    StandardSymptom.lightheadedness, StandardSymptom.sensitivity_to_light,
  };
  static const Set<StandardSymptom> _painSymptoms = {
    StandardSymptom.headache, StandardSymptom.migraine,
    StandardSymptom.body_ache, StandardSymptom.muscle_pain,
    StandardSymptom.joint_pain, StandardSymptom.back_pain,
    StandardSymptom.neck_pain, StandardSymptom.throat_pain,
    StandardSymptom.ear_pain, StandardSymptom.tooth_pain,
  };
  static const Set<StandardSymptom> _skinSymptoms = {
    StandardSymptom.skin_rash, StandardSymptom.itching, StandardSymptom.hives,
  };
  static const Set<StandardSymptom> _feverSymptoms = {
    StandardSymptom.mild_fever, StandardSymptom.fever, StandardSymptom.high_fever,
  };
}

// ---------------------------------------------------------------------------
// COMPOSITE SAFETY ENGINE — runs all 4 layers in sequence
// ---------------------------------------------------------------------------

class BaymaxSafetyEngine {
  static SafetyCheckResult runAllChecks(PatientInput input) {
    final vitalsResult = VitalsSafetyCheck.run(input.vitals);
    final redFlagResult = RedFlagSymptomCheck.run(input.allSymptoms);
    final contraindicationResult = ContraindicationCheck.run(input);
    final complexityResult = ComplexityCheck.run(input.allSymptoms);

    return vitalsResult
        .merge(redFlagResult)
        .merge(contraindicationResult)
        .merge(complexityResult);
  }
}
