// =============================================================================
// BAYMAX LLM SERVICE — baymax_llm_service.dart
// Two LLM-powered functions:
//   1. symptomStandardizer() — converts free-text → StandardSymptom list
//   2. evaluateVerificationAnswer() — interprets user answer → option index
// Uses GitHub Models API (OpenAI-compatible).
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/baymax_models.dart';

// ---------------------------------------------------------------------------
// CONFIGURATION
// ---------------------------------------------------------------------------

class BaymaxLlmConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final int maxTokens;
  final Duration timeout;

  const BaymaxLlmConfig({
    this.baseUrl = 'https://models.github.ai/inference/chat/completions',
    required this.apiKey,
    this.model = 'openai/gpt-4o-mini',
    this.maxTokens = 500,
    this.timeout = const Duration(seconds: 20),
  });
}

// ---------------------------------------------------------------------------
// RESPONSE TYPES
// ---------------------------------------------------------------------------

class LlmSymptomResult {
  final List<StandardSymptom> symptoms;
  final bool success;
  final String? error;

  const LlmSymptomResult({
    required this.symptoms,
    required this.success,
    this.error,
  });
}

class LlmVerificationResult {
  final int optionIndex;
  final bool success;
  final String? error;
  final String? reasoning;

  const LlmVerificationResult({
    required this.optionIndex,
    required this.success,
    this.error,
    this.reasoning,
  });
}

// ---------------------------------------------------------------------------
// SYMPTOM TAXONOMY
// ---------------------------------------------------------------------------

const String _symptomTaxonomyJson = '''
[
  "mild_fever","fever","high_fever",
  "headache","migraine","body_ache","muscle_pain","joint_pain","back_pain","neck_pain",
  "throat_pain","ear_pain","tooth_pain","pelvic_pain","stomach_cramps",
  "sneezing","runny_nose","blocked_nose","nasal_congestion","itchy_nose","itchy_eyes",
  "watery_eyes","sinus_pressure","cough","chest_tightness","wheezing","breathing_difficulty",
  "heartburn","acid_reflux","sour_taste","upper_stomach_discomfort","bloating","nausea",
  "vomiting","persistent_vomiting","diarrhea","watery_stool","loose_stool",
  "severe_abdominal_pain","skin_rash","itching","hives","dizziness","lightheadedness",
  "dry_mouth","reduced_urination","heat_exhaustion","excessive_sweating","weakness","fatigue",
  "swelling","confusion","seizures","fainting","sensitivity_to_light","blood_in_vomit",
  "black_stool","blood_in_stool","no_urine","low_spo2","severe_weakness",
  "facial_swelling","lip_swelling","tongue_swelling"
]
''';

// ---------------------------------------------------------------------------
// MAIN SERVICE CLASS
// ---------------------------------------------------------------------------

class BaymaxLlmService {
  final BaymaxLlmConfig config;
  final http.Client _client;

  BaymaxLlmService({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  Future<LlmSymptomResult> symptomStandardizer({
    required String rawDescription,
    String? vitalsHint,
  }) async {
    final systemPrompt = '''
You are a medical symptom extractor. Analyze the user's description and map to standardized symptoms.
RETURN JSON ONLY: {"symptoms": ["symptom1", "symptom2"]}
RULES:
1. Use ONLY symptoms from the provided taxonomy.
2. Fever mapping: 37.3-38.0 -> mild_fever, 38.1-39.0 -> fever, >39.0 -> high_fever.
3. Be conservative. No markdown.

TAXONOMY:
$_symptomTaxonomyJson
''';

    final userMessage = vitalsHint != null
        ? 'Vitals: $vitalsHint\nPatient: "$rawDescription"'
        : 'Patient: "$rawDescription"';

    try {
      final response = await _client.post(
        Uri.parse(config.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage}
          ],
          'response_format': {'type': 'json_object'}
        }),
      ).timeout(config.timeout);

      if (response.statusCode != 200) {
        return LlmSymptomResult(symptoms: [], success: false, error: 'API Error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final content = jsonDecode(decoded['choices'][0]['message']['content']);
      
      List<dynamic> rawList = content['symptoms'] ?? [];

      final symptoms = rawList
          .map((s) => _parseSymptom(s.toString()))
          .whereType<StandardSymptom>()
          .toList();

      return LlmSymptomResult(symptoms: symptoms, success: true);
    } catch (e) {
      return LlmSymptomResult(symptoms: [], success: false, error: 'Error: $e');
    }
  }

  Future<LlmVerificationResult> evaluateVerificationAnswer({
    required VerificationQuestion question,
    required String userAnswer,
    String? patientContext,
  }) async {
    final optionList = question.options.asMap().entries.map((e) => '${e.key}: "${e.value}"').join('\n');
    final systemPrompt = '''
Map the patient's answer to the closest option index (0-based).
RETURN JSON ONLY: {"index": <int>, "reasoning": "string"}
RULES:
1. Return 0-based index. -1 if ambiguous/declined.
2. Valid indices: 0 to ${question.options.length - 1}.
INTERNAL CONTEXT: ${question.context ?? 'None'}
''';

    final userMessage = 'QUESTION: ${question.question}\nOPTIONS:\n$optionList\nANSWER: "$userAnswer"\nPATIENT CONTEXT: $patientContext';

    try {
      final response = await _client.post(
        Uri.parse(config.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage}
          ],
          'response_format': {'type': 'json_object'}
        }),
      ).timeout(config.timeout);

      if (response.statusCode != 200) {
        return LlmVerificationResult(optionIndex: -1, success: false, error: 'API Error');
      }

      final decoded = jsonDecode(response.body);
      final content = jsonDecode(decoded['choices'][0]['message']['content']);
      return LlmVerificationResult(
        optionIndex: (content['index'] as num).toInt(),
        success: true,
        reasoning: content['reasoning'],
      );
    } catch (e) {
      return LlmVerificationResult(optionIndex: -1, success: false, error: 'Error: $e');
    }
  }

  StandardSymptom? _parseSymptom(String name) {
    try {
      return StandardSymptom.values.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
