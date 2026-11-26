// Unit tests for the parts of the app that decide medical outcomes.
// Pure Dart — no Firebase, no device, no network.
//
//   flutter test

import 'dart:convert';

import 'package:baymaxv1/baymax/baymax_controller.dart';
import 'package:baymaxv1/baymax/core/baymax_medication_engine.dart';
import 'package:baymaxv1/baymax/core/baymax_safety.dart';
import 'package:baymaxv1/baymax/models/baymax_models.dart';
import 'package:baymaxv1/baymax/services/baymax_llm_service.dart';
import 'package:baymaxv1/baymax/services/offline_symptom_matcher.dart';
import 'package:baymaxv1/data/models.dart';
import 'package:baymaxv1/data/repositories.dart';
import 'package:baymaxv1/models/medical_profile.dart';
import 'package:baymaxv1/services/medication_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

VitalsReading vitals({double temp = 36.8, double spo2 = 98, int hr = 75}) =>
    VitalsReading(temperatureCelsius: temp, spo2Percent: spo2, heartRateBpm: hr, timestamp: DateTime(2026));

PatientInput patient({
  List<StandardSymptom> symptoms = const [],
  VitalsReading? v,
  List<KnownCondition> conditions = const [],
  List<DrugAllergy> allergies = const [],
  int? age,
}) =>
    PatientInput(
      rawDescription: '',
      standardSymptoms: symptoms,
      vitals: v ?? vitals(),
      knownConditions: conditions,
      knownAllergies: allergies,
      patientAgeYears: age,
    );

MedicationDecision decideFor(List<StandardSymptom> symptoms, int answer, {Set<Medication> blocked = const {}}) {
  final matched = BaymaxCaseEngine.matchCase(symptoms);
  expect(matched, isNotNull, reason: 'expected a case for $symptoms');
  return BaymaxDecisionEngine.decide(
    matchedCase: matched!,
    verificationAnswerIndex: answer,
    blockedMedications: blocked,
    symptoms: symptoms,
  );
}

void main() {
  group('Temperature calibration', () {
    test('forehead reading converts to body temperature', () {
      expect(TemperatureCalibration.bodyFromForehead(33.6), closeTo(36.6, 0.001));
    });

    test('the old raw "normal" band no longer reads as fever or hypothermia', () {
      for (final raw in [33.0, 33.6, 34.2]) {
        final v = vitals(temp: TemperatureCalibration.bodyFromForehead(raw));
        expect(v.derivedSymptoms, isEmpty, reason: 'raw $raw');
        expect(v.isCritical, isFalse, reason: 'raw $raw');
      }
    });
  });

  group('Vitals grading (docs/IMPLEMENTATION.md §7)', () {
    test('a normal body temperature is not a fever', () {
      expect(vitals(temp: 36.8).derivedSymptoms, isEmpty);
    });

    test('fever tiers', () {
      expect(vitals(temp: 37.5).derivedSymptoms, [StandardSymptom.mild_fever]);
      expect(vitals(temp: 38.5).derivedSymptoms, [StandardSymptom.fever]);
      expect(vitals(temp: 39.3).derivedSymptoms, [StandardSymptom.high_fever]);
    });

    test('38.6 °C (test mode preset) is a fever, not an emergency', () {
      expect(vitals(temp: 38.6).isCritical, isFalse);
      expect(VitalsSafetyCheck.run(vitals(temp: 38.6)).escalationRequired, isFalse);
    });

    test('emergencies', () {
      expect(vitals(temp: 40.5).isCritical, isTrue);
      expect(vitals(temp: 34.5).isCritical, isTrue);
      expect(vitals(spo2: 88).isCritical, isTrue);
      expect(vitals(hr: 135).isCritical, isTrue);
    });

    test('SpO2 90–94 % is a warning with low_spo2, not an emergency', () {
      final v = vitals(spo2: 92);
      expect(v.derivedSymptoms, contains(StandardSymptom.low_spo2));
      expect(v.isCritical, isFalse);
      expect(v.alert?.level, AlertLevel.warning);
      expect(RedFlagSymptomCheck.run([StandardSymptom.low_spo2]).escalationRequired, isFalse);
    });

    test('alert shown and escalation decision always agree', () {
      for (final temp in [33.0, 34.9, 35.0, 36.0, 36.8, 37.3, 38.1, 39.1, 39.6, 40.0, 40.1, 41.0]) {
        for (final spo2 in [85.0, 89.9, 90.0, 94.0, 95.0, 99.0]) {
          for (final hr in [40, 49, 50, 100, 101, 130, 131, 150]) {
            final v = vitals(temp: temp, spo2: spo2, hr: hr);
            final check = VitalsSafetyCheck.run(v);
            expect(check.escalationRequired, v.isCritical, reason: '$temp °C, $spo2 %, $hr bpm');
            expect(check.escalationRequired, v.alert?.level == AlertLevel.emergency,
                reason: '$temp °C, $spo2 %, $hr bpm');
          }
        }
      }
    });
  });

  group('Contraindications', () {
    test('liver disease and heavy drinking block paracetamol', () {
      expect(ContraindicationCheck.run(patient(conditions: [KnownCondition.chronic_liver_disease])).blockedMedications,
          contains(Medication.paracetamol));
      expect(ContraindicationCheck.run(patient(conditions: [KnownCondition.heavy_alcohol_use])).blockedMedications,
          contains(Medication.paracetamol));
    });

    test('allergies block the matching medicine', () {
      expect(ContraindicationCheck.run(patient(allergies: [DrugAllergy.nsaid])).blockedMedications,
          contains(Medication.ibuprofen));
      expect(ContraindicationCheck.run(patient(allergies: [DrugAllergy.antihistamine])).blockedMedications,
          contains(Medication.cetirizine));
      expect(ContraindicationCheck.run(patient(allergies: [DrugAllergy.famotidine])).blockedMedications,
          contains(Medication.famotidine));
    });

    test('children are referred (adult doses only)', () {
      final result = ContraindicationCheck.run(patient(age: 8));
      expect(result.escalationRequired, isTrue);
      expect(result.escalationReason, isNotNull);
      expect(ContraindicationCheck.run(patient(age: 30)).escalationRequired, isFalse);
    });
  });

  group('Decision engine', () {
    const feverAllergy = [StandardSymptom.fever, StandardSymptom.sneezing];
    const feverOnly = [StandardSymptom.fever];

    test('an answer we could not map never yields a medicine', () {
      for (final symptoms in [
        feverAllergy,
        feverOnly,
        [StandardSymptom.heartburn],
        [StandardSymptom.sneezing],
        [StandardSymptom.diarrhea],
        [StandardSymptom.headache],
      ]) {
        for (final bad in [-1, 99]) {
          final d = decideFor(symptoms, bad);
          expect(d.escalationRequired, isTrue, reason: '$symptoms answer $bad');
          expect(d.primary, Medication.none, reason: '$symptoms answer $bad');
          expect(d.secondary, isNull, reason: '$symptoms answer $bad');
        }
      }
    });

    test('fever + allergy: liver disease is referred, not given paracetamol', () {
      final d = decideFor(feverAllergy, 0);
      expect(d.escalationRequired, isTrue);
      expect(d.primary, Medication.none);
    });

    test('fever + allergy: none of the above → paracetamol + cetirizine', () {
      final d = decideFor(feverAllergy, 2);
      expect(d.primary, Medication.paracetamol);
      expect(d.secondary, Medication.cetirizine);
    });

    test('a blocked co-medication is dropped', () {
      final d = decideFor(feverAllergy, 2, blocked: {Medication.cetirizine});
      expect(d.primary, Medication.paracetamol);
      expect(d.secondary, isNull);
    });

    test('fever: GI bleeding signs escalate, otherwise paracetamol', () {
      expect(decideFor(feverOnly, 1).escalationRequired, isTrue);
      expect(decideFor(feverOnly, 2).escalationRequired, isTrue);
      expect(decideFor(feverOnly, 5).primary, Medication.paracetamol);
    });

    test('blocked ibuprofen switches to paracetamol', () {
      final d = decideFor([StandardSymptom.migraine], 1, blocked: {Medication.ibuprofen});
      expect(d.primary, Medication.paracetamol);
    });

    test('everything blocked → refer to a doctor', () {
      final d = decideFor(feverOnly, 5, blocked: {Medication.paracetamol, Medication.ibuprofen});
      expect(d.escalationRequired, isTrue);
      expect(d.primary, Medication.none);
    });
  });

  group('Dosing', () {
    test('ibuprofen stays within the 1,200 mg/day OTC limit', () {
      final ibuprofen = Medication.ibuprofen.standardAdultDosing;
      expect(ibuprofen.maxDosesPerDay * 400, lessThanOrEqualTo(1200));
    });

    test('stored names map back to engine medicines', () {
      expect(MedicationInfo.fromName('Paracetamol (650mg)'), Medication.paracetamol);
      expect(MedicationInfo.fromName('Paracetamol (Acetaminophen)'), Medication.paracetamol);
      expect(MedicationInfo.fromName('Cetirizine (10mg)'), Medication.cetirizine);
      expect(MedicationInfo.fromName('Some other pill'), isNull);
    });
  });

  group('Controller', () {
    final offlineLlm = BaymaxLlmService(config: const BaymaxLlmConfig(apiKey: ''));

    test('no description → no LLM call needed, vitals symptoms still apply', () async {
      final controller = BaymaxController(llmService: offlineLlm);
      final v = vitals(temp: 38.5);
      final result = await controller.standardizeSymptoms(
        rawDescription: '   ',
        vitals: v,
        vitalsSymptoms: v.derivedSymptoms,
      );
      expect(result.llmSuccess, isTrue);
      expect(result.symptoms, contains(StandardSymptom.fever));
    });

    test('a description without an API key reports failure instead of guessing', () async {
      final controller = BaymaxController(llmService: offlineLlm);
      final v = vitals();
      final result = await controller.standardizeSymptoms(
        rawDescription: 'I have been vomiting blood',
        vitals: v,
        vitalsSymptoms: v.derivedSymptoms,
      );
      expect(result.llmSuccess, isFalse);
    });
  });

  group('Offline symptom matcher (test builds)', () {
    test('finds phrases and prefers the longer red-flag phrase', () {
      expect(OfflineSymptomMatcher.match('I have a fever and a runny nose'),
          unorderedEquals([StandardSymptom.fever, StandardSymptom.runny_nose]));
      expect(OfflineSymptomMatcher.match('I keep vomiting blood'), [StandardSymptom.blood_in_vomit]);
      expect(OfflineSymptomMatcher.match('feeling fine'), isEmpty);
    });
  });

  group('Spec rules (docs/IMPLEMENTATION.md §6)', () {
    test('severe kidney impairment blocks cetirizine and ibuprofen', () {
      final r = ContraindicationCheck.run(patient(conditions: [KnownCondition.severe_kidney_impairment]));
      expect(r.blockedMedications, containsAll([Medication.cetirizine, Medication.ibuprofen]));
      expect(r.blockedMedications, isNot(contains(Medication.paracetamol)));
      expect(r.escalationRequired, isFalse);
    });

    test('an antihistamine allergy stored as a condition still blocks cetirizine', () {
      final r = ContraindicationCheck.run(patient(conditions: [KnownCondition.antihistamine_allergy]));
      expect(r.blockedMedications, contains(Medication.cetirizine));
    });

    test('over 65: ibuprofen caution (info), not a block', () {
      final r = ContraindicationCheck.run(patient(age: 70));
      expect(r.blockedMedications, isEmpty);
      expect(r.escalationRequired, isFalse);
      expect(r.alerts.single.level, AlertLevel.info);
      expect(ContraindicationCheck.run(patient(age: 65)).alerts, isEmpty);
      // No caution when ibuprofen is already blocked.
      expect(
        ContraindicationCheck.run(patient(age: 70, conditions: [KnownCondition.kidney_disease]))
            .alerts
            .where((a) => a.level == AlertLevel.info),
        isEmpty,
      );
    });
  });

  group('Clinic search', () {
    final sample = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'name': 'City Hospital',
            'lat': 12.97,
            'lon': 77.59,
            'distance': 1200,
            'address_line2': 'MG Road, Bengaluru',
            'categories': ['healthcare', 'healthcare.hospital'],
            'place_id': 'abc',
            'datasource': {
              'raw': {'phone': '+91 80 1234 5678', 'opening_hours': '24/7', 'emergency': 'yes'},
            },
          },
        },
        {
          'type': 'Feature',
          'properties': {
            'name': 'Dr Rao Clinic',
            'lat': 12.96,
            'lon': 77.58,
            'distance': 400,
            'categories': ['healthcare', 'healthcare.clinic_or_praxis'],
            'datasource': {'raw': {'amenity': 'doctors'}},
          },
        },
        {'type': 'Feature', 'properties': {'lat': 1, 'lon': 1}}, // unnamed → skipped
      ],
    };

    test('Geoapify places are parsed, nearest first, unnamed ones skipped', () {
      final clinics = ClinicRepository.parseGeoapify(sample, 12.965, 77.585);
      expect(clinics.map((c) => c.name), ['Dr Rao Clinic', 'City Hospital']);
      expect(clinics.first.kind, ClinicKind.doctors);
      final h = clinics.last;
      expect(h.kind, ClinicKind.hospital);
      expect(h.emergency, isTrue);
      expect(h.phone, '+91 80 1234 5678');
      expect(h.openingHours, '24/7');
      expect(h.distanceKm, closeTo(1.2, 1e-9));
      expect(h.address, 'MG Road, Bengaluru');
    });

    test('falls back to Overpass when Geoapify fails', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'api.geoapify.com') return http.Response('{"error":"quota"}', 429);
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 1,
                'lat': 12.97,
                'lon': 77.59,
                'tags': {'name': 'Overpass Clinic', 'amenity': 'clinic'},
              },
            ],
          }),
          200,
        );
      });
      final repo = ClinicRepository(client: client, geoapifyKey: 'test-key');
      final clinics = await repo.nearby(latitude: 12.965, longitude: 77.585);
      expect(clinics.single.name, 'Overpass Clinic');
    });
  });

  group('Symptom reader replies', () {
    test('JSON is found inside code fences or surrounding text', () {
      expect(BaymaxLlmService.decodeJsonContent('{"symptoms": ["fever"]}')['symptoms'], ['fever']);
      expect(BaymaxLlmService.decodeJsonContent('```json\n{"symptoms": ["cough"]}\n```')['symptoms'], ['cough']);
      expect(BaymaxLlmService.decodeJsonContent('Here you go: {"index": 2} Hope it helps.')['index'], 2);
      expect(() => BaymaxLlmService.decodeJsonContent('no json here'), throwsFormatException);
    });
  });

  group('Red flags added 2026-11-25', () {
    test('chest tightness and persistent vomiting escalate and block every medicine', () {
      for (final s in [StandardSymptom.chest_tightness, StandardSymptom.persistent_vomiting]) {
        final r = RedFlagSymptomCheck.run([StandardSymptom.fever, s]);
        expect(r.escalationRequired, isTrue, reason: s.name);
        expect(r.blockedMedications, containsAll(Medication.values), reason: s.name);
        expect(r.alerts.single.level, AlertLevel.emergency, reason: s.name);
      }
    });

    test('plain vomiting is not a red flag', () {
      expect(RedFlagSymptomCheck.run([StandardSymptom.vomiting]).escalationRequired, isFalse);
    });

    test('offline matcher finds both, without also counting plain vomiting', () {
      expect(OfflineSymptomMatcher.match("I can't keep anything down"), [StandardSymptom.persistent_vomiting]);
      expect(OfflineSymptomMatcher.match('Symptoms: persistent vomiting.'), [StandardSymptom.persistent_vomiting]);
      expect(OfflineSymptomMatcher.match('some chest pain'), [StandardSymptom.chest_tightness]);
    });
  });

  group('Already taking (ingredient matching)', () {
    test('generic, brand and combination names map to ingredients', () {
      expect(ingredientsOf('Paracetamol (650mg)'), {Medication.paracetamol});
      expect(ingredientsOf('Dolo 650'), {Medication.paracetamol});
      expect(ingredientsOf('Combiflam'), {Medication.paracetamol, Medication.ibuprofen});
      expect(ingredientsOf('ORS'), {Medication.ors});
      expect(ingredientsOf('Metformin'), isEmpty);
      expect(ingredientsOf('Vitamin D for doctors'), isEmpty);
    });

    test('every assistant course name maps back to its own medicine', () {
      for (final m in Medication.values.where((m) => m != Medication.none)) {
        expect(activeIngredients([m.simpleName]), contains(m), reason: m.simpleName);
      }
    });
  });

  group('Medical profile & medication records', () {
    test('profile parses stored enum names and ignores unknown ones', () {
      final profile = MedicalProfile.fromUserDoc({
        'age': 42,
        'conditions': ['chronic_liver_disease', 'not_a_condition'],
        'allergies': ['nsaid'],
      });
      expect(profile.age, 42);
      expect(profile.conditions, [KnownCondition.chronic_liver_disease]);
      expect(profile.allergies, [DrugAllergy.nsaid]);
    });

    test('active / finished / stopped courses', () {
      final now = DateTime(2026, 6, 10);
      Timestamp daysAgo(int d) => Timestamp.fromDate(now.subtract(Duration(days: d)));

      expect(isMedicationActive({'Duration': 0, 'createdAt': daysAgo(100)}, now: now), isTrue);
      expect(isMedicationActive({'Duration': 7, 'createdAt': daysAgo(3)}, now: now), isTrue);
      expect(isMedicationActive({'Duration': 3, 'createdAt': daysAgo(4)}, now: now), isFalse);
      expect(isMedicationActive({'Duration': -1, 'createdAt': daysAgo(1)}, now: now), isFalse);
      expect(isMedicationActive({'Duration': 7}, now: now), isTrue); // timestamp still pending
    });
  });
}
