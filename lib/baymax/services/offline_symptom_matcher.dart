// =============================================================================
// OFFLINE SYMPTOM MATCHER — offline_symptom_matcher.dart
// TEST BUILDS ONLY (--dart-define=BAYMAX_OFFLINE_AI=true).
//
// Stands in for the LLM so the whole check-up flow can be exercised without
// an API key or network. It only spots fixed phrases and does not understand
// negation ("no fever" still matches "fever"), so it must never ship as the
// real symptom analyser.
// =============================================================================

import '../models/baymax_models.dart';
import 'baymax_llm_service.dart';

class OfflineSymptomMatcher extends BaymaxLlmService {
  OfflineSymptomMatcher() : super(config: const BaymaxLlmConfig(apiKey: ''));

  /// Phrase → symptom. Longer phrases are matched first and then removed, so
  /// "vomiting blood" doesn't also count as plain "vomiting".
  static const Map<String, StandardSymptom> phrases = {
    // Red flags
    'vomiting blood': StandardSymptom.blood_in_vomit,
    'blood in vomit': StandardSymptom.blood_in_vomit,
    'blood in stool': StandardSymptom.blood_in_stool,
    'black stool': StandardSymptom.black_stool,
    'severe abdominal pain': StandardSymptom.severe_abdominal_pain,
    'severe stomach pain': StandardSymptom.severe_abdominal_pain,
    'no urine': StandardSymptom.no_urine,
    'confused': StandardSymptom.confusion,
    'confusion': StandardSymptom.confusion,
    'seizure': StandardSymptom.seizures,
    'fainted': StandardSymptom.fainting,
    'fainting': StandardSymptom.fainting,
    'severe weakness': StandardSymptom.severe_weakness,
    'persistent vomiting': StandardSymptom.persistent_vomiting,
    "can't keep anything down": StandardSymptom.persistent_vomiting,
    'can’t keep anything down': StandardSymptom.persistent_vomiting,
    'cannot keep anything down': StandardSymptom.persistent_vomiting,
    // Breathing / swelling
    'difficulty breathing': StandardSymptom.breathing_difficulty,
    'shortness of breath': StandardSymptom.breathing_difficulty,
    'breathing difficulty': StandardSymptom.breathing_difficulty,
    'chest tightness': StandardSymptom.chest_tightness,
    'chest pain': StandardSymptom.chest_tightness,
    'chest pressure': StandardSymptom.chest_tightness,
    'wheezing': StandardSymptom.wheezing,
    'lip swelling': StandardSymptom.lip_swelling,
    'swollen lips': StandardSymptom.lip_swelling,
    'tongue swelling': StandardSymptom.tongue_swelling,
    'facial swelling': StandardSymptom.facial_swelling,
    'face swelling': StandardSymptom.facial_swelling,
    // Fever / pain
    'high fever': StandardSymptom.high_fever,
    'mild fever': StandardSymptom.mild_fever,
    'fever': StandardSymptom.fever,
    'migraine': StandardSymptom.migraine,
    'headache': StandardSymptom.headache,
    'body ache': StandardSymptom.body_ache,
    'body pain': StandardSymptom.body_ache,
    'muscle pain': StandardSymptom.muscle_pain,
    'joint pain': StandardSymptom.joint_pain,
    'back pain': StandardSymptom.back_pain,
    'neck pain': StandardSymptom.neck_pain,
    'sore throat': StandardSymptom.throat_pain,
    'throat pain': StandardSymptom.throat_pain,
    'ear pain': StandardSymptom.ear_pain,
    'toothache': StandardSymptom.tooth_pain,
    'tooth pain': StandardSymptom.tooth_pain,
    // Cold / allergy
    'runny nose': StandardSymptom.runny_nose,
    'blocked nose': StandardSymptom.blocked_nose,
    'stuffy nose': StandardSymptom.nasal_congestion,
    'sneezing': StandardSymptom.sneezing,
    'itchy eyes': StandardSymptom.itchy_eyes,
    'watery eyes': StandardSymptom.watery_eyes,
    'cough': StandardSymptom.cough,
    'rash': StandardSymptom.skin_rash,
    'hives': StandardSymptom.hives,
    'itching': StandardSymptom.itching,
    // Stomach
    'acid reflux': StandardSymptom.acid_reflux,
    'heartburn': StandardSymptom.heartburn,
    'bloating': StandardSymptom.bloating,
    'stomach cramps': StandardSymptom.stomach_cramps,
    'nausea': StandardSymptom.nausea,
    'vomiting': StandardSymptom.vomiting,
    'diarrhea': StandardSymptom.diarrhea,
    'diarrhoea': StandardSymptom.diarrhea,
    'loose motion': StandardSymptom.loose_stool,
    // General
    'dizzy': StandardSymptom.dizziness,
    'dizziness': StandardSymptom.dizziness,
    'lightheaded': StandardSymptom.lightheadedness,
    'dry mouth': StandardSymptom.dry_mouth,
    'tired': StandardSymptom.fatigue,
    'fatigue': StandardSymptom.fatigue,
    'weakness': StandardSymptom.weakness,
  };

  static List<StandardSymptom> match(String description) {
    var text = ' ${description.toLowerCase()} ';
    final found = <StandardSymptom>{};
    final keys = phrases.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in keys) {
      if (text.contains(phrase)) {
        found.add(phrases[phrase]!);
        text = text.replaceAll(phrase, ' ');
      }
    }
    return found.toList();
  }

  @override
  Future<LlmSymptomResult> symptomStandardizer({
    required String rawDescription,
    String? vitalsHint,
  }) async {
    return LlmSymptomResult(symptoms: match(rawDescription), success: true);
  }

  @override
  Future<LlmVerificationResult> evaluateVerificationAnswer({
    required VerificationQuestion question,
    required String userAnswer,
    String? patientContext,
  }) async {
    // Free-text answers need the real model; report "unclear" so the engine refers.
    return const LlmVerificationResult(optionIndex: -1, success: false, error: 'Offline matcher');
  }
}
