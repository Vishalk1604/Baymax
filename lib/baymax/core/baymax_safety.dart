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
//
// `low_spo2` is deliberately NOT here: SpO2 is graded by VitalsSafetyCheck
// (< 90 % emergency, 90–94 % warning), per docs/IMPLEMENTATION.md §7.
// ---------------------------------------------------------------------------

class RedFlagConstants {
  static const Set<StandardSymptom> globalRedFlags = {
    StandardSymptom.blood_in_vomit,
    StandardSymptom.black_stool,
    StandardSymptom.blood_in_stool,
    StandardSymptom.confusion,
    StandardSymptom.seizures,
    StandardSymptom.fainting,
    StandardSymptom.severe_weakness,
    StandardSymptom.no_urine,
    // Added 2026-11-25 after the doctor review (owner's decision; needs re-review):
    StandardSymptom.chest_tightness,
    StandardSymptom.persistent_vomiting,
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
    StandardSymptom.severe_weakness:
        'Severe weakness reported. May indicate serious systemic illness. Seek emergency care.',
    StandardSymptom.no_urine:
        'No urine output — possible acute kidney injury or severe dehydration. Seek emergency care immediately.',
    StandardSymptom.chest_tightness:
        'Chest tightness — can have a heart or lung cause and needs an urgent medical check. Do not self-medicate.',
    StandardSymptom.persistent_vomiting:
        "Persistent vomiting (can't keep anything down) — risk of dehydration, and medicine taken by mouth "
            "won't stay down. Seek urgent medical care.",
  };
}

// ---------------------------------------------------------------------------
// LAYER 1 — VITALS SAFETY CHECK
// Blocks all OTC recommendations if vitals are out of safe range.
// ---------------------------------------------------------------------------

class VitalsSafetyCheck {
  /// Grades vitals with the same rules as [VitalsReading.alerts] (thresholds
  /// live in VitalThresholds), so the alert shown and the escalation decision
  /// always agree. Any emergency-level vital blocks every medication.
  static SafetyCheckResult run(VitalsReading vitals) {
    final vitalsAlerts = vitals.alerts;
    final emergencies =
        vitalsAlerts.where((a) => a.level == AlertLevel.emergency).toList();
    final escalate = emergencies.isNotEmpty;

    return SafetyCheckResult(
      passed: !escalate,
      alerts: [
        for (final a in vitalsAlerts)
          SafetyAlert(
            level: a.level,
            message: a.message,
            requiresEscalation: a.level == AlertLevel.emergency,
          ),
      ],
      blockedMedications: escalate ? Medication.values.toSet() : {},
      escalationRequired: escalate,
      escalationReason: escalate ? emergencies.first.message : null,
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
      reason ??= 'Possible anaphylaxis (face, lip or tongue swelling with breathing difficulty). Call 112 immediately.';
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
      reason = 'Breathing difficulty cannot be treated with OTC medicine. Seek emergency care immediately.';
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
      const abdominalReason =
          'Severe abdominal pain can have a serious internal cause. Seek emergency evaluation immediately.';
      reason ??= abdominalReason;
      alerts.add(const SafetyAlert(
        level: AlertLevel.emergency,
        message: '🚨 $abdominalReason',
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
  /// Every dose in [MedicationInfo.standardAdultDosing] is an adult dose.
  static const int minAdultDosingAge = 12;

  static SafetyCheckResult run(PatientInput input) {
    final alerts = <SafetyAlert>[];
    final blocked = <Medication>{};
    String? escalationReason;

    // ── Age ──
    final age = input.patientAgeYears;
    if (age != null && age < minAdultDosingAge) {
      escalationReason =
          'Baymax only gives adult doses. For anyone under $minAdultDosingAge, ask a doctor or pharmacist '
          'for the right medicine and dose.';
      blocked.addAll(Medication.values);
      alerts.add(SafetyAlert(
        level: AlertLevel.danger,
        message: '⛔ $escalationReason',
        requiresEscalation: true,
      ));
    }

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
      (KnownCondition.severe_kidney_impairment, 'Severe kidney impairment'),
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

    // Over 65: NSAIDs are riskier but still an option (spec: caution, info).
    if (age != null && age > 65 && !blocked.contains(Medication.ibuprofen)) {
      alerts.add(const SafetyAlert(
        level: AlertLevel.info,
        message: 'ℹ️ IBUPROFEN CAUTION: Over 65, NSAIDs raise the risk of stomach bleeding and kidney problems. '
            'Take ibuprofen with food and for the shortest time possible.',
      ));
    }

    // ── CETIRIZINE / FAMOTIDINE allergies ──
    // An antihistamine allergy can be stored as an allergy or (older profiles)
    // as a condition; both must block cetirizine.
    if (input.knownAllergies.contains(DrugAllergy.antihistamine) ||
        input.knownConditions.contains(KnownCondition.antihistamine_allergy)) {
      blocked.add(Medication.cetirizine);
      alerts.add(const SafetyAlert(
        level: AlertLevel.danger,
        message: '⛔ CETIRIZINE BLOCKED: Known antihistamine allergy on record.',
        blockedMedication: 'Cetirizine',
      ));
    }
    if (input.knownConditions.contains(KnownCondition.severe_kidney_impairment)) {
      blocked.add(Medication.cetirizine);
      alerts.add(const SafetyAlert(
        level: AlertLevel.danger,
        message: '⛔ CETIRIZINE BLOCKED: Severe kidney impairment. The dose has to be adjusted by a doctor.',
        blockedMedication: 'Cetirizine',
      ));
    }
    if (input.knownAllergies.contains(DrugAllergy.famotidine)) {
      blocked.add(Medication.famotidine);
      alerts.add(const SafetyAlert(
        level: AlertLevel.danger,
        message: '⛔ FAMOTIDINE BLOCKED: Known famotidine allergy on record.',
        blockedMedication: 'Famotidine',
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
      escalationReason: escalationReason,
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
        escalationReason:
            'Your symptoms involve ${systems.length} body systems, which is beyond what OTC medicine should handle. Please see a doctor.',
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
