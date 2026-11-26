// Typed views of the Firestore documents under users/{uid}. Field names match
// what earlier versions of the app wrote, so existing data keeps working.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../baymax/models/baymax_models.dart';
import '../models/medical_profile.dart';
import '../services/medication_utils.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
double? _double(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
List<String> _strings(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.age,
    this.sex,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.conditions = const [],
    this.allergies = const [],
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final int? age;
  final String? sex;
  final String? bloodType;
  final int? heightCm;
  final int? weightKg;
  final List<KnownCondition> conditions;
  final List<DrugAllergy> allergies;
  final DateTime? createdAt;

  String get firstName {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'there' : first;
  }

  double? get bmi {
    final h = heightCm, w = weightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  MedicalProfile get medical => MedicalProfile(age: age, conditions: conditions, allergies: allergies);

  factory UserProfile.fromDoc(String uid, Map<String, dynamic> d) {
    final medical = MedicalProfile.fromUserDoc(d);
    return UserProfile(
      uid: uid,
      name: '${d['name'] ?? ''}',
      email: '${d['email'] ?? ''}',
      age: _int(d['age']),
      sex: d['gender'] as String?,
      bloodType: d['blood'] as String?,
      heightCm: _int(d['height']),
      weightKg: _int(d['weight']),
      conditions: medical.conditions,
      allergies: medical.allergies,
      createdAt: _date(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        if (age != null) 'age': age,
        if (sex != null) 'gender': sex,
        if (bloodType != null) 'blood': bloodType,
        if (heightCm != null) 'height': heightCm,
        if (weightKg != null) 'weight': weightKg,
        'conditions': conditions.map((c) => c.name).toList(),
        'allergies': allergies.map((a) => a.name).toList(),
      };

  UserProfile copyWith({
    String? name,
    int? age,
    String? sex,
    String? bloodType,
    int? heightCm,
    int? weightKg,
    List<KnownCondition>? conditions,
    List<DrugAllergy>? allergies,
  }) =>
      UserProfile(
        uid: uid,
        name: name ?? this.name,
        email: email,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        bloodType: bloodType ?? this.bloodType,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        conditions: conditions ?? this.conditions,
        allergies: allergies ?? this.allergies,
        createdAt: createdAt,
      );
}

/// How urgent a check-up outcome is, for colour and wording.
enum Triage { selfCare, monitor, doctor, emergency }

extension TriageText on Triage {
  String get label => switch (this) {
        Triage.selfCare => 'Self-care',
        Triage.monitor => 'Keep an eye on it',
        Triage.doctor => 'See a doctor',
        Triage.emergency => 'Get help now',
      };

  /// Stored in the check-up document.
  String get key => name;

  static Triage? parse(Object? v) {
    for (final t in Triage.values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

/// Triage of a finished recommendation.
Triage triageOf(RecommendationResult r) {
  if (!r.escalateToDoctor) {
    return r.primaryMedication == Medication.none ? Triage.monitor : Triage.selfCare;
  }
  final emergency = r.safetyAlerts.any((a) => a.level == AlertLevel.emergency) ||
      r.vitalsAlert?.level == AlertLevel.emergency;
  return emergency ? Triage.emergency : Triage.doctor;
}

class CheckupRecord {
  const CheckupRecord({
    required this.id,
    required this.time,
    required this.temperature,
    required this.heartRate,
    required this.spo2,
    this.rawSensorTemperature,
    this.observation = '',
    this.symptoms = const [],
    this.safetyAlerts = const [],
    this.recommendation = '',
    this.medication,
    this.secondaryMedication,
    this.matchedCase,
    this.escalated = false,
    this.testMode = false,
    this.storedTriage,
  });

  final String id;
  final DateTime? time;
  final double temperature;
  final double? rawSensorTemperature;
  final int heartRate;
  final int spo2;
  final String observation;
  final List<String> symptoms;
  final List<String> safetyAlerts;
  final String recommendation;
  final String? medication;
  final String? secondaryMedication;
  final String? matchedCase;
  final bool escalated;
  final bool testMode;
  final Triage? storedTriage;

  /// Medicines recommended, excluding "No medication".
  List<String> get medicines => [medication, secondaryMedication]
      .whereType<String>()
      .where((m) => m.isNotEmpty && m != Medication.none.displayName)
      .toList();

  Triage get triage {
    if (storedTriage != null) return storedTriage!;
    // Records saved before triage was stored: infer from the wording.
    if (!escalated) return medicines.isEmpty ? Triage.monitor : Triage.selfCare;
    final text = '$recommendation ${safetyAlerts.join(' ')}'.toLowerCase();
    const urgent = ['emergency', '112', '911', 'immediately', 'red alert', 'red flag'];
    return urgent.any(text.contains) ? Triage.emergency : Triage.doctor;
  }

  factory CheckupRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      CheckupRecord.fromMap(doc.id, doc.data());

  factory CheckupRecord.fromMap(String id, Map<String, dynamic> d) {
    var symptoms = _strings(d['Symptoms']);
    if (symptoms.isEmpty && d['SymptomsJson'] is Map) {
      symptoms = _strings((d['SymptomsJson'] as Map)['symptoms_detected']);
    }
    return CheckupRecord(
      id: id,
      time: _date(d['TimeStamp']),
      temperature: _double(d['Temp']) ?? 0,
      rawSensorTemperature: _double(d['RawSensorTemp']),
      heartRate: _int(d['HeartRate']) ?? 0,
      spo2: _int(d['SpO2']) ?? 0,
      observation: '${d['Observation'] ?? ''}',
      symptoms: symptoms,
      safetyAlerts: _strings(d['SafetyAlerts']),
      recommendation: '${d['Recommendation'] ?? d['AIOutput'] ?? ''}',
      medication: d['Medication'] as String?,
      secondaryMedication: d['SecondaryMedication'] as String?,
      matchedCase: d['MatchedCase'] as String?,
      escalated: d['Escalated'] == true,
      testMode: d['TestMode'] == true,
      storedTriage: TriageText.parse(d['Triage']),
    );
  }
}

/// Units a dose can be entered in. Stored singular, shown with the amount.
abstract final class DoseUnits {
  static const all = ['mg', 'mcg', 'g', 'ml', 'IU', 'tablet', 'capsule', 'drop', 'puff'];
  static const _countable = {'tablet', 'capsule', 'drop', 'puff'};

  static String format(int amount, String unit) =>
      '$amount ${_countable.contains(unit) && amount != 1 ? '${unit}s' : unit}';

  static String label(String unit) => _countable.contains(unit) ? '${unit}s' : unit;
}

/// "Food Relation" values exactly as earlier versions stored them.
abstract final class FoodRelation {
  static const after = 'After Food';
  static const before = 'Before Food';
  static const withFood = 'With Food';
  static const any = 'No Preference';
  static const options = [after, before, withFood, any];

  static String? label(String? stored) => switch (stored) {
        null || '' => null,
        FoodRelation.after => 'After food',
        FoodRelation.before => 'Before food',
        FoodRelation.withFood => 'With food',
        FoodRelation.any => 'Any time',
        _ => stored,
      };
}

class MedicationCourse {
  const MedicationCourse({
    required this.id,
    required this.name,
    required this.raw,
    this.dosage = 0,
    this.doseText,
    this.unit,
    this.foodRelation,
    this.durationDays = 0,
    this.index = 0,
    this.compartment,
    this.source,
    this.symptoms,
    this.createdAt,
  });

  final String id;
  final String name;

  /// The stored document, for helpers that work on raw maps.
  final Map<String, dynamic> raw;
  final int dosage;
  final String? doseText;
  final String? unit;
  final String? foodRelation;

  /// 0 = ongoing, negative = stopped, otherwise days from [createdAt].
  final int durationDays;

  /// 0 for the user's own medicines, >0 for assistant recommendations.
  final int index;
  final int? compartment;
  final String? source;
  final String? symptoms;
  final DateTime? createdAt;

  bool get isAssistant => index > 0;
  bool get isStopped => durationDays < 0;
  bool get isOngoing => durationDays == 0;
  bool isActiveAt(DateTime now) => isMedicationActive(raw, now: now);
  bool get isActive => isActiveAt(DateTime.now());

  DateTime? get endsAt =>
      durationDays > 0 ? (createdAt ?? DateTime.now()).add(Duration(days: durationDays)) : null;

  /// 0–1 through a fixed-length course (null when ongoing or stopped).
  double? get courseProgress {
    final end = endsAt;
    final start = createdAt;
    if (end == null || start == null) return null;
    final total = end.difference(start).inMinutes;
    if (total <= 0) return 1;
    return (DateTime.now().difference(start).inMinutes / total).clamp(0.0, 1.0);
  }

  Medication? get engineMedication => MedicationInfo.fromName(name);

  /// Compartment to dispense from (0 = not stocked in the device). Courses
  /// saved before compartments existed fall back to the assistant's slots.
  int get deviceCompartment {
    if (raw.containsKey('Compartment')) return compartment ?? 0;
    return engineMedication?.deviceCompartment ?? 0;
  }

  String get doseLabel {
    if (doseText != null && doseText!.isNotEmpty) return doseText!;
    if (dosage <= 0) return engineMedication?.standardAdultDosing.dose ?? '';
    return DoseUnits.format(dosage, unit ?? 'mg');
  }

  /// Display text for the stored food relation.
  String? get foodLabel => FoodRelation.label(foodRelation);

  factory MedicationCourse.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return MedicationCourse(
      id: doc.id,
      raw: d,
      name: '${d['Name'] ?? 'Medicine'}',
      dosage: _int(d['Dosage']) ?? 0,
      doseText: d['DoseText'] as String?,
      unit: d['Unit'] as String?,
      foodRelation: d['Food Relation'] as String?,
      durationDays: _int(d['Duration']) ?? 0,
      index: _int(d['Index']) ?? 0,
      compartment: _int(d['Compartment']),
      source: d['Source'] as String?,
      symptoms: d['Symptoms'] as String?,
      createdAt: _date(d['createdAt']),
    );
  }
}

/// One scheduled dose today.
class DoseSlot {
  const DoseSlot({required this.course, required this.time, required this.taken});

  final MedicationCourse course;

  /// Today at the reminder's time.
  final DateTime time;
  final bool taken;

  TimeOfDay get timeOfDay => TimeOfDay(hour: time.hour, minute: time.minute);

  /// Doses can be taken from an hour before until an hour after.
  bool canTakeAt(DateTime now) =>
      !taken && now.isAfter(time.subtract(const Duration(hours: 1))) && now.isBefore(time.add(const Duration(hours: 1)));

  bool missedAt(DateTime now) => !taken && now.isAfter(time.add(const Duration(hours: 1)));
}

class Appointment {
  const Appointment({
    required this.id,
    required this.clinicName,
    required this.time,
    this.clinicId,
    this.doctorName,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.reason,
    this.notes,
  });

  final String id;
  final String clinicName;
  final DateTime time;
  final String? clinicId;
  final String? doctorName;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? reason;
  final String? notes;

  bool get isUpcoming => time.isAfter(DateTime.now());

  factory Appointment.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final doctor = d['DoctorName'] as String?;
    return Appointment(
      id: doc.id,
      clinicName: '${d['clinicName'] ?? doctor ?? 'Clinic visit'}',
      time: _date(d['Time']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      clinicId: d['clinicId'] as String?,
      // Older bookings stored a placeholder doctor name.
      doctorName: doctor == 'Dr. Specialist' ? null : doctor,
      address: d['address'] as String?,
      phone: d['phone'] as String?,
      latitude: _double(d['lat']),
      longitude: _double(d['lng']),
      reason: d['reason'] as String?,
      notes: d['notes'] as String?,
    );
  }
}

enum ClinicKind { hospital, clinic, doctors, dentist, pharmacy }

extension ClinicKindText on ClinicKind {
  String get label => switch (this) {
        ClinicKind.hospital => 'Hospital',
        ClinicKind.clinic => 'Clinic',
        ClinicKind.doctors => 'Doctor',
        ClinicKind.dentist => 'Dentist',
        ClinicKind.pharmacy => 'Pharmacy',
      };
}

class Clinic {
  const Clinic({
    required this.id,
    required this.name,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.address,
    this.phone,
    this.openingHours,
    this.emergency = false,
  });

  final String id;
  final String name;
  final ClinicKind kind;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? address;
  final String? phone;
  final String? openingHours;

  /// Has an emergency department (OSM `emergency=yes`).
  final bool emergency;

  String get distanceLabel =>
      distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km';
}
