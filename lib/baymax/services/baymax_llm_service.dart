// =============================================================================
// BAYMAX LLM SERVICE — baymax_llm_service.dart
// Two LLM-powered functions:
//   1. symptomStandardizer() — converts free-text → StandardSymptom list
//   2. evaluateVerificationAnswer() — interprets user answer → option index
// Uses any OpenAI-compatible chat-completions API; the default is NVIDIA's
// (build.nvidia.com). The LLM only reads text — every medical decision is made
// by the rule engine.
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Send OpenAI's `response_format: json_object`. Off by default: not every
  /// model on NVIDIA's API accepts it, and replies are parsed leniently anyway.
  final bool jsonMode;

  const BaymaxLlmConfig({
    this.baseUrl = 'https://integrate.api.nvidia.com/v1/chat/completions',
    required this.apiKey,
    this.model = 'nvidia/nemotron-3.5-bolt-e4b',
    this.maxTokens = 500,
    this.timeout = const Duration(seconds: 30),
    this.jsonMode = false,
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

  static const String _missingKeyError =
      'No LLM API key configured. Run with --dart-define-from-file=.env (see .env.example).';

  Future<LlmSymptomResult> symptomStandardizer({
    required String rawDescription,
    String? vitalsHint,
  }) async {
    if (config.apiKey.isEmpty) {
      return const LlmSymptomResult(symptoms: [], success: false, error: _missingKeyError);
    }

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
        body: jsonEncode(_requestBody(systemPrompt, userMessage)),
      ).timeout(config.timeout);

      if (response.statusCode != 200) {
        debugPrint('Symptom reader HTTP ${response.statusCode}: ${_brief(response.body)}');
        return LlmSymptomResult(symptoms: [], success: false, error: 'API Error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final content = decodeJsonContent('${decoded['choices'][0]['message']['content']}');
      
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
    if (config.apiKey.isEmpty) {
      return const LlmVerificationResult(optionIndex: -1, success: false, error: _missingKeyError);
    }

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
        body: jsonEncode(_requestBody(systemPrompt, userMessage)),
      ).timeout(config.timeout);

      if (response.statusCode != 200) {
        debugPrint('Answer reader HTTP ${response.statusCode}: ${_brief(response.body)}');
        return LlmVerificationResult(optionIndex: -1, success: false, error: 'API Error');
      }

      final decoded = jsonDecode(response.body);
      final content = decodeJsonContent('${decoded['choices'][0]['message']['content']}');
      return LlmVerificationResult(
        optionIndex: (content['index'] as num).toInt(),
        success: true,
        reasoning: content['reasoning'],
      );
    } catch (e) {
      return LlmVerificationResult(optionIndex: -1, success: false, error: 'Error: $e');
    }
  }

  Map<String, Object?> _requestBody(String systemPrompt, String userMessage) => {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        // Extraction, not conversation: keep it close to deterministic.
        'temperature': 0.1,
        'max_tokens': config.maxTokens,
        if (config.jsonMode) 'response_format': {'type': 'json_object'},
      };

  static String _brief(String body) => body.length > 300 ? '${body.substring(0, 300)}…' : body;

  /// Parses the JSON object in a model reply, tolerating ```json fences and
  /// text around it (common without OpenAI's JSON mode).
  static Map<String, dynamic> decodeJsonContent(String content) {
    var text = content.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end < start) throw const FormatException('No JSON object in the model reply');
    return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
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
