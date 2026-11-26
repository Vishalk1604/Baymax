import 'package:cloud_firestore/cloud_firestore.dart';

import '../baymax/models/baymax_models.dart';

/// Whether a `users/{uid}/Medication` document is a course still in progress.
///
/// `Duration` is in days: 0 = ongoing, negative = stopped by the user,
/// otherwise the course ends `Duration` days after `createdAt`.
bool isMedicationActive(Map<String, dynamic> data, {DateTime? now}) {
  final duration = (data['Duration'] as num?)?.toInt() ?? 0;
  if (duration < 0) return false;
  if (duration == 0) return true;

  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  if (createdAt == null) return true; // just added; server timestamp still pending

  return (now ?? DateTime.now()).isBefore(createdAt.add(Duration(days: duration)));
}

/// Device compartments the user can assign to their own medicines.
/// 1–4 are reserved for the medicines the assistant recommends.
const List<int> userCompartments = [5, 6];

/// Whole words (generic and common brand names, including combination
/// products) that mean a medicine contains one of Baymax's ingredients.
const Map<String, Set<Medication>> _ingredientWords = {
  'paracetamol': {Medication.paracetamol},
  'acetaminophen': {Medication.paracetamol},
  'crocin': {Medication.paracetamol},
  'dolo': {Medication.paracetamol},
  'calpol': {Medication.paracetamol},
  'tylenol': {Medication.paracetamol},
  'panadol': {Medication.paracetamol},
  'sinarest': {Medication.paracetamol},
  'combiflam': {Medication.paracetamol, Medication.ibuprofen},
  'ibuprofen': {Medication.ibuprofen},
  'brufen': {Medication.ibuprofen},
  'advil': {Medication.ibuprofen},
  'motrin': {Medication.ibuprofen},
  'nurofen': {Medication.ibuprofen},
  'cetirizine': {Medication.cetirizine},
  'levocetirizine': {Medication.cetirizine},
  'zyrtec': {Medication.cetirizine},
  'cetzine': {Medication.cetirizine},
  'okacet': {Medication.cetirizine},
  'famotidine': {Medication.famotidine},
  'pepcid': {Medication.famotidine},
  'famocid': {Medication.famotidine},
  'ors': {Medication.ors},
  'electral': {Medication.ors},
};

/// Baymax ingredients in a medicine name, e.g. "Dolo 650" → paracetamol,
/// "Combiflam" → paracetamol + ibuprofen, "Paracetamol (650mg)" → paracetamol.
Set<Medication> ingredientsOf(String name) {
  final lower = name.toLowerCase();
  return {
    for (final word in lower.split(RegExp(r'[^a-z]+'))) ...?_ingredientWords[word],
    if (lower.contains('oral rehydration')) Medication.ors,
  };
}

/// Ingredients of every course in [names], so Baymax never recommends a
/// medicine the person is already taking, whoever added the course.
Set<Medication> activeIngredients(Iterable<String> names) => {for (final n in names) ...ingredientsOf(n)};
