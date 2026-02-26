// =============================================================================
// BAYMAX MEDICATION ENGINE — baymax_medication_engine.dart
// Implements all clinical cases. Takes verified symptom profile + 
// verification answers → selects appropriate medication.
// Updated with co-medication support (e.g. Paracetamol + Cetirizine)
// =============================================================================

import '../models/baymax_models.dart';

// ---------------------------------------------------------------------------
// CASE MATCHING
// ---------------------------------------------------------------------------

class MatchedCase {
  final String caseId;
  final String caseName;
  final List<Medication> candidateMedications;
  final VerificationQuestion verificationQuestion;

  const MatchedCase({
    required this.caseId,
    required this.caseName,
    required this.candidateMedications,
    required this.verificationQuestion,
  });
}

// ---------------------------------------------------------------------------
// CASE DEFINITIONS — maps symptom clusters to cases
// ---------------------------------------------------------------------------

class BaymaxCaseEngine {
  static MatchedCase? matchCase(List<StandardSymptom> symptoms) {
    bool hasAny(Iterable<StandardSymptom> required) =>
        required.any(symptoms.contains);

    // --- Symptom Clusters ---
    final hasFever = hasAny([StandardSymptom.fever, StandardSymptom.mild_fever, StandardSymptom.high_fever]);
    
    final hasPain = hasAny([
      StandardSymptom.headache, StandardSymptom.body_ache, StandardSymptom.muscle_pain,
      StandardSymptom.joint_pain, StandardSymptom.neck_pain, StandardSymptom.back_pain,
      StandardSymptom.throat_pain, StandardSymptom.ear_pain, StandardSymptom.tooth_pain,
      StandardSymptom.migraine, StandardSymptom.pelvic_pain
    ]);

    final hasAllergyCluster = hasAny([
      StandardSymptom.sneezing, StandardSymptom.runny_nose, StandardSymptom.blocked_nose,
      StandardSymptom.nasal_congestion, StandardSymptom.itchy_nose, StandardSymptom.itchy_eyes,
      StandardSymptom.watery_eyes, StandardSymptom.skin_rash, StandardSymptom.itching, StandardSymptom.hives
    ]);

    final hasGiAcid = hasAny([
      StandardSymptom.heartburn, StandardSymptom.acid_reflux, StandardSymptom.sour_taste,
      StandardSymptom.upper_stomach_discomfort, StandardSymptom.bloating
    ]);

    final hasDehydration = hasAny([
      StandardSymptom.diarrhea, StandardSymptom.watery_stool, StandardSymptom.loose_stool,
      StandardSymptom.dizziness, StandardSymptom.lightheadedness, StandardSymptom.dry_mouth,
      StandardSymptom.reduced_urination, StandardSymptom.heat_exhaustion, StandardSymptom.excessive_sweating,
      StandardSymptom.weakness
    ]);

    // ── CASE 1: Viral / Cold Pattern (Fever + Pain + Allergies) ──
    if (hasFever && hasAllergyCluster) {
      return MatchedCase(
        caseId: 'C01_ALLERGY',
        caseName: 'Fever/Pain with Cold/Allergy Symptoms',
        candidateMedications: [Medication.paracetamol, Medication.cetirizine],
        verificationQuestion: VerificationQuestion(
          id: 'C01_Q1_A',
          question: 'Do you have any of the following history or symptoms?',
          options: [
            'Stomach pain or liver disease',
            'Severe breathing difficulty',
            'None of the above',
          ],
          context: 'Checking for Paracetamol contraindications or severe respiratory issues.',
        ),
      );
    }

    // ── CASE 2: Fever Only or Fever + Pain ──
    if (hasFever) {
      return MatchedCase(
        caseId: 'C01',
        caseName: 'Fever with optional Pain',
        candidateMedications: [Medication.paracetamol, Medication.ibuprofen],
        verificationQuestion: VerificationQuestion(
          id: 'C01_Q1',
          question: 'To help me choose the best medicine, do you have any of these?',
          options: [
            'Stomach pain or history of ulcers',
            'Black or very dark coloured stool',
            'Vomiting blood',
            'Known kidney problems',
            'Asthma that gets worse with painkillers',
            'None of these apply to me',
          ],
          context: 'Blood/Stool options -> Red Alert. Others -> Paracetamol. None -> Ibuprofen.',
        ),
      );
    }

    // ── CASE 3: GI Acid / Bloating ──
    if (hasGiAcid) {
      return MatchedCase(
        caseId: 'C03',
        caseName: 'Acid Reflux or Bloating',
        candidateMedications: [Medication.famotidine],
        verificationQuestion: VerificationQuestion(
          id: 'C03_Q1',
          question: 'Are your stomach symptoms associated with any of the following red flags?',
          options: [
            'Persistent vomiting (cannot keep anything down)',
            'Vomiting blood or dark material',
            'Severe, unbearable abdominal pain',
            'No red flags, just heartburn/bloating',
          ],
          context: 'First three -> Red Alert. Last -> Famotidine.',
        ),
      );
    }

    // ── CASE 4: Allergies only ──
    if (hasAllergyCluster && !hasFever) {
      return MatchedCase(
        caseId: 'C04',
        caseName: 'Allergy Symptoms',
        candidateMedications: [Medication.cetirizine],
        verificationQuestion: VerificationQuestion(
          id: 'C04_Q1',
          question: 'Are you experiencing any swelling of the lips, tongue, or face?',
          options: [
            'Yes, there is visible swelling in my face or mouth',
            'No swelling, just typical allergy symptoms (itching/sneezing)',
          ],
          context: 'Swelling -> Red Alert (Anaphylaxis risk). No swelling -> Cetirizine.',
        ),
      );
    }

    // ── CASE 5: Dehydration / GI Loss (ORS) ──
    if (hasDehydration) {
      return MatchedCase(
        caseId: 'C05',
        caseName: 'Dehydration or Fluid Loss',
        candidateMedications: [Medication.ors],
        verificationQuestion: VerificationQuestion(
          id: 'C05_Q1',
          question: 'Which of these best describes your current state?',
          options: [
            'Very little to no urine output today',
            'Feeling very faint, confused, or had a seizure',
            'Moderate symptoms (thirst, dizziness, or diarrhea)',
          ],
          context: 'First two -> Red Alert. Last -> ORS.',
        ),
      );
    }

    // ── CASE 6: Isolated Pain ──
    if (hasPain) {
      return MatchedCase(
        caseId: 'C06',
        caseName: 'Isolated Pain Relief',
        candidateMedications: [Medication.paracetamol, Medication.ibuprofen],
        verificationQuestion: VerificationQuestion(
          id: 'C06_Q1',
          question: 'Do you have any history of stomach ulcers or kidney disease?',
          options: [
            'Yes, I have stomach or kidney issues',
            'No, I have no such issues',
          ],
          context: 'Yes -> Paracetamol. No -> Ibuprofen (if inflammatory) or Paracetamol.',
        ),
      );
    }

    return null; // No matching case
  }
}

// ---------------------------------------------------------------------------
// DECISION ENGINE
// ---------------------------------------------------------------------------

class BaymaxDecisionEngine {
  static MedicationDecision decide({
    required MatchedCase matchedCase,
    required int verificationAnswerIndex,
    required Set<Medication> blockedMedications,
    required List<StandardSymptom> symptoms,
  }) {
    final bool declined = verificationAnswerIndex < 0;
    Medication primary = Medication.none;
    Medication? secondary;
    String rationale = '';
    bool escalate = false;
    String? escalationReason;

    switch (matchedCase.caseId) {
      case 'C01_ALLERGY': // Fever/Pain + Allergies (Co-medication)
        if (verificationAnswerIndex == 1) {
          escalate = true;
          escalationReason = 'RED ALERT: Severe breathing difficulty detected. Seek emergency care immediately.';
        } else {
          primary = Medication.paracetamol;
          secondary = Medication.cetirizine;
          rationale = ''; 
          if (verificationAnswerIndex == 0) {
            rationale = '(Note: Caution advised with liver history).';
          }
        }
        break;

      case 'C01': // Fever (+ optional Pain)
        if (declined || verificationAnswerIndex == 5) {
          primary = Medication.paracetamol;
          rationale = ''; 
        } else if (verificationAnswerIndex == 1 || verificationAnswerIndex == 2) {
          escalate = true;
          escalationReason = 'RED ALERT: Possible GI bleeding detected. Please seek emergency care immediately.';
        } else {
          // stomach pain, kidney, or asthma -> Paracetamol is safer
          primary = Medication.paracetamol;
          rationale = 'Paracetamol selected as the safer option for your profile.';
        }
        break;

      case 'C03': // GI Acid
        if (verificationAnswerIndex < 3 && !declined) {
          escalate = true;
          escalationReason = 'RED ALERT: Severe GI symptoms or bleeding signs detected. Emergency medical evaluation required.';
        } else {
          primary = Medication.famotidine;
          rationale = '';
        }
        break;

      case 'C04': // Allergy
        if (verificationAnswerIndex == 0 && !declined) {
          escalate = true;
          escalationReason = 'RED ALERT: Facial/lip swelling suggests a severe allergic reaction (Anaphylaxis). Call emergency services immediately.';
        } else {
          primary = Medication.cetirizine;
          rationale = '';
        }
        break;

      case 'C05': // Dehydration
        if (verificationAnswerIndex < 2 && !declined) {
          escalate = true;
          escalationReason = 'RED ALERT: Severe dehydration or systemic failure signs. Immediate medical intervention required.';
        } else {
          primary = Medication.ors;
          rationale = '';
        }
        break;

      case 'C06': // Isolated Pain
        if (verificationAnswerIndex == 0) {
          primary = Medication.paracetamol;
          rationale = '';
        } else {
          if (symptoms.contains(StandardSymptom.migraine) || symptoms.contains(StandardSymptom.joint_pain) || symptoms.contains(StandardSymptom.muscle_pain)) {
            primary = Medication.ibuprofen;
            rationale = '';
          } else {
            primary = Medication.paracetamol;
            rationale = '';
          }
        }
        break;
    }

    // Safety Override
    if (blockedMedications.contains(primary)) {
      if (primary == Medication.ibuprofen && !blockedMedications.contains(Medication.paracetamol)) {
        primary = Medication.paracetamol;
        rationale += ' [Switching to Paracetamol as Ibuprofen is contraindicated for you.]';
      } else {
        primary = Medication.none;
        escalate = true;
        escalationReason ??= 'The safest medication for your case is blocked by your medical profile. Please consult a doctor.';
      }
    }

    return MedicationDecision(
      primary: primary,
      secondary: secondary,
      rationale: rationale,
      escalationRequired: escalate,
      escalationReason: escalationReason,
    );
  }
}

class MedicationDecision {
  final Medication primary;
  final Medication? secondary;
  final String rationale;
  final bool escalationRequired;
  final String? escalationReason;

  const MedicationDecision({
    required this.primary,
    this.secondary,
    required this.rationale,
    required this.escalationRequired,
    this.escalationReason,
  });
}
