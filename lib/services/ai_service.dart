import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = "YOUR_API_KEY"; // Replace with your actual API key or load from environment variables
  static const String _baseUrl = "https://models.github.ai/inference";

  static const bool testMode = true;

  Future<Map<String, dynamic>> extractSymptoms({
    required String observations,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": "openai/gpt-4o-mini",
          "temperature": 0.1,
          "messages": [
            {
              "role": "system",
              "content": """You are a medical symptom extraction agent. Analyze the user's text and map them to standardized symptoms from the provided vocabulary.
              
RETURN JSON ONLY:
{
  "symptoms_detected": [],
  "possible_symptoms_uncertain": [],
  "severity_flags": []
}

SYMPTOM VOCABULARY:
CORE: fever, chills, fatigue, weakness, loss_of_appetite, night_sweats
PAIN: headache, migraine, body_ache, muscle_pain, joint_pain, neck_pain, back_pain, chest_pain, abdominal_pain, upper_abdominal_pain, lower_abdominal_pain, pelvic_pain, throat_pain, ear_pain, tooth_pain, pain_swallowing
CONTEXT: high_fever, mild_fever, low_body_temperature, stiff_neck, swollen_lymph_nodes
RESPIRATORY: sneezing, runny_nose, blocked_nose, nasal_congestion, itchy_nose, itchy_eyes, watery_eyes, post_nasal_drip, sore_throat, cough, dry_cough, wet_cough, phlegm, green_mucus, yellow_mucus, shortness_of_breath, breathing_difficulty, wheezing, chest_tightness
GI: heartburn, acid_reflux, sour_taste, nausea, vomiting, persistent_vomiting, diarrhea, watery_stool, loose_stool, constipation, bloating, gas, stomach_cramps, upper_stomach_discomfort, severe_abdominal_pain, blood_in_vomit, blood_in_stool, black_stool, difficulty_swallowing
DEHYDRATION/HEAT: dizziness, lightheadedness, dry_mouth, reduced_urination, no_urine, excessive_sweating, heat_exhaustion, severe_weakness
NEUROLOGICAL: confusion, drowsiness, fainting, seizures, blurred_vision, sensitivity_to_light
CARDIO-RESP: rapid_heartbeat, irregular_heartbeat, very_fast_heartbeat, very_slow_heartbeat, low_spo2
SKIN: skin_rash, itching, hives, skin_swelling, facial_swelling, lip_swelling, tongue_swelling
ENT: ear_discharge, hearing_loss, sinus_pressure, facial_pain
REACTION: drug_allergy, nsaid_asthma, sedation
SYSTEM: symptoms_worsening, unknown_severe_pain, multi_symptom_complex

RULES:
1. Return JSON object only. No text outside JSON.
2. Normalize symptoms (e.g. "head hurts" -> "headache").
3. Use ONLY vocabulary provided. Never invent names.
4. If confidence <70% -> put in possible_symptoms_uncertain.
5. If implied emergency -> also add to severity_flags.
6. Do NOT suggest medication."""
            },
            {
              "role": "user",
              "content": "Extract symptoms from this text: $observations"
            }
          ],
          "response_format": { "type": "json_object" }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return jsonDecode(content);
      }
      return {"error": "API Issue"};
    } catch (e) {
      return {"error": "Connection Issue"};
    }
  }

  Map<String, dynamic> analyzeHealthStatus({
    required List<String> symptoms,
    required List<String> flags,
    required double temp,
    required int hr,
    required int spo2,
  }) {
    // Basic health analysis without medication recommendation
    List<String> emergencyTriggers = [
      'chest_pain', 'breathing_difficulty', 'confusion', 'drowsiness', 
      'seizures', 'fainting', 'no_urine', 'severe_weakness'
    ];
    
    bool hasEmergency = symptoms.any((s) => emergencyTriggers.contains(s)) || flags.isNotEmpty;
    bool abnormalVitals = temp > 38.0 || temp < 35.0 || spo2 < 94 || hr > 120 || hr < 50;

    if (hasEmergency || abnormalVitals) {
      return {
        "status": "emergency",
        "message": "🚨 IMMEDIATE MEDICAL ATTENTION REQUIRED. Please seek professional medical help immediately."
      };
    }

    if (symptoms.isNotEmpty) {
      return {
        "status": "caution",
        "message": "Symptoms detected. We recommend monitoring your condition and consulting a doctor if they persist or worsen."
      };
    }

    return {
      "status": "normal",
      "message": "Your vitals and reported symptoms appear within normal ranges. Stay hydrated and rest."
    };
  }
}
