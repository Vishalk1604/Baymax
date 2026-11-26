import '../baymax/models/baymax_models.dart';

/// The parts of `users/{uid}` the recommendation engine needs.
///
/// Stored as `conditions` / `allergies`: lists of enum names, so they map
/// straight onto [KnownCondition] / [DrugAllergy].
class MedicalProfile {
  final int? age;
  final List<KnownCondition> conditions;
  final List<DrugAllergy> allergies;

  const MedicalProfile({this.age, this.conditions = const [], this.allergies = const []});

  factory MedicalProfile.fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return const MedicalProfile();
    return MedicalProfile(
      age: (data['age'] as num?)?.toInt(),
      conditions: _parse(data['conditions'], KnownCondition.values),
      allergies: _parse(data['allergies'], DrugAllergy.values),
    );
  }

  static List<T> _parse<T extends Enum>(Object? raw, List<T> values) {
    if (raw is! List) return const [];
    final byName = {for (final v in values) v.name: v};
    return raw.map((e) => byName[e.toString()]).whereType<T>().toList();
  }

  /// Conditions the safety engine acts on, with user-facing labels.
  static const Map<KnownCondition, String> conditionLabels = {
    KnownCondition.chronic_liver_disease: 'Liver disease',
    KnownCondition.heavy_alcohol_use: 'Heavy alcohol use',
    KnownCondition.gastric_ulcer: 'Stomach ulcer',
    KnownCondition.kidney_disease: 'Kidney disease',
    KnownCondition.nsaid_asthma: 'Asthma worsened by painkillers',
    KnownCondition.heart_disease: 'Heart disease',
  };

  /// Allergies the safety engine acts on, with user-facing labels.
  static const Map<DrugAllergy, String> allergyLabels = {
    DrugAllergy.paracetamol: 'Paracetamol',
    DrugAllergy.nsaid: 'Ibuprofen / NSAIDs',
    DrugAllergy.antihistamine: 'Antihistamines (e.g. cetirizine)',
    DrugAllergy.famotidine: 'Famotidine',
  };
}
