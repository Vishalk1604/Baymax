import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../baymax/baymax_controller.dart';
import '../../baymax/core/baymax_safety.dart';
import '../../baymax/models/baymax_models.dart';
import '../../baymax/services/baymax_llm_service.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../models/medical_profile.dart';
import '../../services/health_device_service.dart';
import '../../services/medication_utils.dart';

enum CheckupPhase { idle, analysing, question, result, error }

/// State and logic of one check-up. The algorithm steps are called in the
/// same order and with the same inputs as before the redesign:
/// vitals emergency check → symptom standardisation (with the medical
/// profile) → safety checks → case match → safety question → recommendation.
class CheckupFlow extends ChangeNotifier {
  CheckupFlow({required this.llm}) : controller = BaymaxController(llmService: llm) {
    connected = device.isConnected;
    measuring = device.isMeasuring;
    deviceStatus = device.measurementStatus;
    reading = device.lastReading;
    _subs.addAll([
      device.connectionStream.listen((v) {
        connected = v;
        notifyListeners();
      }),
      device.statusStream.listen((s) {
        deviceStatus = s;
        measuring = device.isMeasuring;
        notifyListeners();
      }),
      device.readingStream.listen((r) {
        reading = r;
        testMode = false;
        resetAnalysis();
        notifyListeners();
      }),
    ]);
  }

  final BaymaxLlmService llm;
  final BaymaxController controller;
  final HealthDeviceService device = HealthDeviceService();
  final List<StreamSubscription<dynamic>> _subs = [];

  // ── Vitals ──
  bool connected = false;
  bool measuring = false;
  String deviceStatus = 'Idle';
  HealthReading? reading;

  bool testMode = false;
  double testTemp = 38.6;
  double testHeartRate = 75;
  double testSpo2 = 98;

  HealthReading? get effectiveReading => testMode
      ? HealthReading(temperature: testTemp, heartRate: testHeartRate.round(), spo2: testSpo2.round())
      : reading;

  // ── Symptoms ──
  final Set<String> chips = <String>{};
  String freeText = '';

  /// What the symptom reader receives: the picked phrases plus free text.
  String get description {
    final parts = <String>[];
    if (chips.isNotEmpty) parts.add('Symptoms: ${chips.join(', ')}.');
    if (freeText.trim().isNotEmpty) parts.add(freeText.trim());
    return parts.join(' ');
  }

  // ── Analysis ──
  CheckupPhase phase = CheckupPhase.idle;
  List<StandardSymptom> symptoms = const [];
  List<SafetyAlert> alerts = const [];
  VerificationQuestion? question;
  RecommendationResult? result;
  String? error;
  bool saving = false;
  bool saved = false;

  Triage? get triage => result == null ? null : triageOf(result!);

  Future<void> startMeasurement() async {
    measuring = true;
    notifyListeners();
    await device.startMeasurement();
    measuring = device.isMeasuring;
    notifyListeners();
  }

  void setTestMode(bool on) {
    testMode = on;
    resetAnalysis();
    notifyListeners();
  }

  void setTestVitals({double? temperature, double? heartRate, double? spo2}) {
    testTemp = temperature ?? testTemp;
    testHeartRate = heartRate ?? testHeartRate;
    testSpo2 = spo2 ?? testSpo2;
    resetAnalysis();
    notifyListeners();
  }

  void toggleChip(String phrase) {
    chips.contains(phrase) ? chips.remove(phrase) : chips.add(phrase);
    notifyListeners();
  }

  void setFreeText(String text) {
    freeText = text;
  }

  void resetAnalysis() {
    phase = CheckupPhase.idle;
    symptoms = const [];
    alerts = const [];
    question = null;
    result = null;
    error = null;
    saved = false;
    controller.reset();
  }

  Future<void> evaluate({required MedicalProfile profile, required bool symptomReaderConfigured}) async {
    final r = effectiveReading;
    if (r == null) return;
    resetAnalysis();
    phase = CheckupPhase.analysing;
    notifyListeners();
    // Keep the "analysing" state on screen long enough to read, even when
    // the answer comes back instantly.
    final minimumShow = Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      final vitals = VitalsReading(
        temperatureCelsius: r.temperature,
        spo2Percent: r.spo2.toDouble(),
        heartRateBpm: r.heartRate,
        timestamp: DateTime.now(),
      );

      // 1. Vitals in the emergency range: stop here.
      final vitalsAnalysis = controller.analyzeVitals(vitals);
      if (vitalsAnalysis.requiresEmergency) {
        alerts = VitalsSafetyCheck.run(vitals).alerts;
        result = controller.buildEscalationResult(reason: vitalsAnalysis.emergencyAlert?.message);
        await minimumShow;
        _finish(CheckupPhase.result);
        return;
      }

      // 2. Read the description with the person's medical history.
      final symptomResult = await controller.standardizeSymptoms(
        rawDescription: description,
        vitals: vitals,
        vitalsSymptoms: vitalsAnalysis.vitalsSymptoms,
        knownConditions: profile.conditions,
        knownAllergies: profile.allergies,
        patientAge: profile.age,
      );
      await minimumShow;

      // A red flag in an unread description would be missed: stop instead of
      // recommending from vitals alone.
      if (!symptomResult.llmSuccess) {
        error = symptomReaderConfigured
            ? 'We couldn’t read your symptoms. Check your internet connection and try again.'
            : 'Symptom analysis isn’t set up in this build (no API key), so Baymax can’t give guidance yet.';
        _finish(CheckupPhase.error);
        return;
      }
      symptoms = symptomResult.symptoms;

      // 3. Safety checks.
      final safety = controller.runSafetyChecks();
      alerts = safety.safetyResult.alerts;
      if (!safety.canProceed) {
        result = controller.buildEscalationResult();
        _finish(CheckupPhase.result);
        return;
      }

      // 4. Match a case and ask its safety question.
      final match = controller.matchCase();
      final q = match.hasMatch ? controller.getVerificationQuestion() : null;
      if (q == null) {
        result = controller.buildNoMatchResult();
        _finish(CheckupPhase.result);
        return;
      }
      question = q;
      _finish(CheckupPhase.question);
    } catch (e) {
      error = 'Something went wrong while analysing. Please try again.';
      debugPrint('Check-up evaluation failed: $e');
      _finish(CheckupPhase.error);
    }
  }

  /// Answers the safety question. [activeMedicineNames] lists courses still
  /// in progress, so Baymax doesn't stack another course of the same medicine.
  Future<void> answer(int optionIndex, {required Future<Set<String>> Function() activeMedicineNames}) async {
    final q = question;
    if (q == null) return;
    phase = CheckupPhase.analysing;
    notifyListeners();
    try {
      final res = await controller.submitVerificationAnswer(userAnswer: q.options[optionIndex], optionIndex: optionIndex);
      if (!res.escalateToDoctor) {
        // Matched by ingredient, so the person's own "Dolo 650" counts as paracetamol.
        final active = activeIngredients(await activeMedicineNames());
        final alreadyTaking = [res.primaryMedication, res.secondaryMedication]
            .whereType<Medication>()
            .where((m) => m != Medication.none && active.contains(m))
            .toList();
        if (alreadyTaking.isNotEmpty) {
          final names = alreadyTaking.map((m) => m.simpleName).join(' and ');
          result = RecommendationResult(
            primaryMedication: Medication.none,
            dosing: Medication.none.standardAdultDosing,
            safetyAlerts: [
              ...res.safetyAlerts,
              SafetyAlert(
                level: AlertLevel.danger,
                message:
                    "⚠️ You are already taking $names. If symptoms haven't improved, please consult a doctor instead of self-medicating further.",
                requiresEscalation: true,
              ),
            ],
            escalateToDoctor: true,
            escalationReason: 'Persistent symptoms despite ongoing medication ($names).',
            summary:
                '⚠️ Since you are already taking $names and symptoms persist, please visit a doctor for a proper evaluation. Do not take extra doses.',
            matchedCaseId: res.matchedCaseId,
            isWithinOtcBoundary: false,
          );
          _finish(CheckupPhase.result);
          return;
        }
      }
      result = res;
      _finish(CheckupPhase.result);
    } catch (e) {
      error = 'Something went wrong. Please try again.';
      _finish(CheckupPhase.error);
    }
  }

  void _finish(CheckupPhase next) {
    phase = next;
    notifyListeners();
  }

  /// Saves the check-up and adds any recommended medicines that aren't
  /// already being taken.
  Future<void> save({
    required String uid,
    required CheckupRepository checkups,
    required MedicationRepository medications,
  }) async {
    final r = effectiveReading;
    final res = result;
    if (r == null || res == null || saving) return;
    saving = true;
    notifyListeners();
    try {
      final index = await checkups.save(uid, {
        'Temp': r.temperature,
        if (r.rawSensorTemperature != null) 'RawSensorTemp': r.rawSensorTemperature,
        'SpO2': r.spo2,
        'HeartRate': r.heartRate,
        'Observation': description,
        'Symptoms': symptoms.map((s) => s.name).toList(),
        'SafetyAlerts': res.safetyAlerts.map((a) => a.message).toList(),
        'Recommendation': res.summary,
        'Medication': res.primaryMedication.displayName,
        if (res.secondaryMedication != null) 'SecondaryMedication': res.secondaryMedication!.displayName,
        if (res.matchedCaseId != null) 'MatchedCase': res.matchedCaseId,
        'Escalated': res.escalateToDoctor,
        'Triage': triageOf(res).key,
        'TestMode': testMode,
      });

      if (!res.escalateToDoctor && res.primaryMedication != Medication.none) {
        final active = activeIngredients(await medications.activeNames(uid));
        final symptomText = symptoms.map((s) => s.name).join(', ');
        if (!active.contains(res.primaryMedication)) {
          await medications.addAssistantCourse(uid,
              medication: res.primaryMedication, dosing: res.dosing, checkupIndex: index, symptoms: symptomText);
        }
        final secondary = res.secondaryMedication;
        if (secondary != null && !active.contains(secondary)) {
          await medications.addAssistantCourse(uid,
              medication: secondary,
              dosing: res.secondaryDosing ?? secondary.standardAdultDosing,
              checkupIndex: index,
              symptoms: symptomText);
        }
      }
      saved = true;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    llm.dispose();
    super.dispose();
  }
}
