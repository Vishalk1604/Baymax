// =============================================================================
// BAYMAX CONTROLLER — baymax_controller.dart
// Main orchestrator. This is the single entry point for the Flutter UI.
//
// FLOW:
//   Step 1 — analyzeVitals()         : Validate vitals → early exit if critical
//   Step 2 — standardizeSymptoms()   : LLM free-text → StandardSymptom list
//   Step 3 — runSafetyChecks()       : 4-layer safety engine
//   Step 4 — matchCase()             : Identify clinical case
//   Step 5 — getVerificationQuestion(): Return Q to present in UI
//   Step 6 — submitVerificationAnswer(): User answers → final recommendation
// =============================================================================

import 'models/baymax_models.dart';
import 'core/baymax_safety.dart';
import 'core/baymax_medication_engine.dart';
import 'services/baymax_llm_service.dart';

// ---------------------------------------------------------------------------
// STEP RESULT TYPES (each step returns one of these)
// ---------------------------------------------------------------------------

/// Returned by analyzeVitals(). If [requiresEmergency] = true, stop the flow.
class VitalsAnalysisResult {
  final bool requiresEmergency;
  final VitalsAlert? emergencyAlert;
  final List<StandardSymptom> vitalsSymptoms;

  const VitalsAnalysisResult({
    required this.requiresEmergency,
    this.emergencyAlert,
    required this.vitalsSymptoms,
  });
}

/// Returned by standardizeSymptoms(). Contains parsed symptoms + any LLM error.
class SymptomStandardizationResult {
  final List<StandardSymptom> symptoms;
  final bool llmSuccess;
  final String? llmError;

  const SymptomStandardizationResult({
    required this.symptoms,
    required this.llmSuccess,
    this.llmError,
  });
}

/// Returned by runSafetyChecks().
class SafetyCheckStepResult {
  final SafetyCheckResult safetyResult;
  final bool canProceed; // false = escalate NOW

  const SafetyCheckStepResult({
    required this.safetyResult,
    required this.canProceed,
  });
}

/// Returned by matchCase().
class CaseMatchResult {
  final MatchedCase? matchedCase;
  final bool hasMatch;

  const CaseMatchResult({
    required this.matchedCase,
    required this.hasMatch,
  });
}

// --------------------------------------------
// CONTROLLER
// ----------------------------------------

class BaymaxController {
  final BaymaxLlmService llmService;

  // Internal state — accumulated across the 6 steps.
  PatientInput? _patientInput;
  SafetyCheckResult? _safetyResult;
  MatchedCase? _matchedCase;
  List<StandardSymptom> _mergedSymptoms = [];

  BaymaxController({required this.llmService});

  // ══════════════════════════════════════════════════════════════
  // STEP 1: analyzeVitals
  // ════════════════════════════════════════════════════════
  VitalsAnalysisResult analyzeVitals(VitalsReading vitals) {
    final safetyResult = VitalsSafetyCheck.run(vitals);
    final vitalsAlert = vitals.alert;

    return VitalsAnalysisResult(
      requiresEmergency: safetyResult.escalationRequired,
      emergencyAlert: safetyResult.escalationRequired ? vitalsAlert : null,
      vitalsSymptoms: vitals.derivedSymptoms,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: standardizeSymptoms
  // ═════════════════════════════════════════════════════════
  Future<SymptomStandardizationResult> standardizeSymptoms({
    required String rawDescription,
    required VitalsReading vitals,
    required List<StandardSymptom> vitalsSymptoms,
    List<KnownCondition> knownConditions = const [],
    List<DrugAllergy> knownAllergies = const [],
    int? patientAge,
  }) async {
    final vitalsHint =
        'Temp: ${vitals.temperatureCelsius.toStringAsFixed(1)}°C, '
        'SpO2: ${vitals.spo2Percent.toStringAsFixed(0)}%, '
        'HR: ${vitals.heartRateBpm} bpm';

    final llmResult = await llmService.symptomStandardizer(
      rawDescription: rawDescription,
      vitalsHint: vitalsHint,
    );

    final allSymptoms = {
      ...vitalsSymptoms,
      if (llmResult.success) ...llmResult.symptoms,
    }.toList();

    _patientInput = PatientInput(
      rawDescription: rawDescription,
      standardSymptoms: allSymptoms,
      vitals: vitals,
      knownConditions: knownConditions,
      knownAllergies: knownAllergies,
      patientAgeYears: patientAge,
    );
    _mergedSymptoms = _patientInput!.allSymptoms;

    return SymptomStandardizationResult(
      symptoms: allSymptoms,
      llmSuccess: llmResult.success,
      llmError: llmResult.error,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: runSafetyChecks
  // ══════════════════════════════════════════════════════════════════════════
  SafetyCheckStepResult runSafetyChecks() {
    assert(_patientInput != null, 'Call standardizeSymptoms() before runSafetyChecks()');
    final result = BaymaxSafetyEngine.runAllChecks(_patientInput!);
    _safetyResult = result;
    return SafetyCheckStepResult(
      safetyResult: result,
      canProceed: !result.escalationRequired,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4: matchCase
  // ══════════════════════════════════════════════════════════════════════════
  CaseMatchResult matchCase() {
    assert(_safetyResult != null, 'Call runSafetyChecks() before matchCase()');
    final matched = BaymaxCaseEngine.matchCase(_mergedSymptoms);
    _matchedCase = matched;
    return CaseMatchResult(matchedCase: matched, hasMatch: matched != null);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5: getVerificationQuestion
  // ══════════════════════════════════════════════════════════════════════════
  VerificationQuestion? getVerificationQuestion() {
    return _matchedCase?.verificationQuestion;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 6: submitVerificationAnswer
  // ══════════════════════════════════════════════════════════════════════════
  Future<RecommendationResult> submitVerificationAnswer({
    required String userAnswer,
    int optionIndex = -1,
  }) async {
    assert(_matchedCase != null);
    assert(_safetyResult != null);
    assert(_patientInput != null);

    int resolvedIndex = optionIndex;
    if (resolvedIndex < 0) {
      final evalResult = await llmService.evaluateVerificationAnswer(
        question: _matchedCase!.verificationQuestion,
        userAnswer: userAnswer,
        patientContext: 'Symptoms: ${_mergedSymptoms.map((s) => s.name).join(', ')}',
      );
      resolvedIndex = evalResult.optionIndex;
    }

    final decision = BaymaxDecisionEngine.decide(
      matchedCase: _matchedCase!,
      verificationAnswerIndex: resolvedIndex,
      blockedMedications: _safetyResult!.blockedMedications,
      symptoms: _mergedSymptoms,
    );

    return _buildResult(decision);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ESCALATION & HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  RecommendationResult buildEscalationResult({String? reason}) {
    final escalationReason = reason ?? _safetyResult?.escalationReason ?? 'Symptoms require medical evaluation.';
    return RecommendationResult(
      primaryMedication: Medication.none,
      dosing: Medication.none.standardAdultDosing,
      safetyAlerts: _safetyResult?.alerts ?? [],
      vitalsAlert: _patientInput?.vitals.alert,
      escalateToDoctor: true,
      escalationReason: escalationReason,
      summary: '⚠️ URGENT: $escalationReason Please consult a doctor immediately.',
      isWithinOtcBoundary: false,
    );
  }

  RecommendationResult buildNoMatchResult() {
    return RecommendationResult(
      primaryMedication: Medication.none,
      dosing: Medication.none.standardAdultDosing,
      safetyAlerts: _safetyResult?.alerts ?? [],
      vitalsAlert: _patientInput?.vitals.alert,
      escalateToDoctor: false,
      summary: 'ℹ️ No specific OTC match found. If symptoms worsen, please consult a doctor.',
      isWithinOtcBoundary: false,
    );
  }

  RecommendationResult _buildResult(MedicationDecision decision) {
    final allAlerts = <SafetyAlert>[...?_safetyResult?.alerts];

    if (decision.escalationRequired) {
      return RecommendationResult(
        primaryMedication: Medication.none,
        dosing: Medication.none.standardAdultDosing,
        safetyAlerts: allAlerts,
        vitalsAlert: _patientInput?.vitals.alert,
        escalateToDoctor: true,
        escalationReason: decision.escalationReason,
        summary: '⚠️ URGENT: ${decision.escalationReason ?? 'Medical evaluation required.'}',
        matchedCaseId: _matchedCase?.caseId,
        isWithinOtcBoundary: false,
      );
    }

    final primary = decision.primary;
    final secondary = decision.secondary;

    final summaryParts = <String>[];
    if (primary != Medication.none) {
      summaryParts.add('Recommended: ${primary.displayName} for ${primary.typicalPurpose}.');
    }
    if (secondary != null) {
      summaryParts.add('Also: ${secondary.displayName} for ${secondary.typicalPurpose}.');
    }
    summaryParts.add(decision.rationale);

    return RecommendationResult(
      primaryMedication: primary,
      secondaryMedication: secondary,
      dosing: primary.standardAdultDosing,
      secondaryDosing: secondary?.standardAdultDosing,
      safetyAlerts: allAlerts,
      vitalsAlert: _patientInput?.vitals.alert,
      escalateToDoctor: false,
      summary: summaryParts.join(' '),
      matchedCaseId: _matchedCase?.caseId,
      isWithinOtcBoundary: true,
    );
  }

  void reset() {
    _patientInput = null;
    _safetyResult = null;
    _matchedCase = null;
    _mergedSymptoms = [];
  }
}
