import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/medical_profile.dart';

const sexOptions = ['Female', 'Male', 'Other', 'Prefer not to say'];
const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// Label for a form group.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs, top: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: context.text.titleSmall),
          if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: context.text.bodySmall)],
        ],
      ),
    );
  }
}

/// Single-choice chips.
class ChoiceChips extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.selected, required this.onSelected});

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final o in options)
          SelectChip(
            label: o,
            selected: selected == o,
            onChanged: (on) => onSelected(on ? o : null),
          ),
      ],
    );
  }
}

/// Integer field with unit and range validation.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    this.unit,
    this.required = true,
    this.icon,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final int min;
  final int max;
  final String? unit;
  final bool required;
  final IconData? icon;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      icon: icon,
      suffixText: unit,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      validator: (v) {
        final text = v?.trim() ?? '';
        if (text.isEmpty) return required ? 'Enter your ${label.toLowerCase()}' : null;
        final n = int.tryParse(text);
        if (n == null || n < min || n > max) return '$label must be between $min and $max${unit != null ? ' $unit' : ''}';
        return null;
      },
    );
  }
}

/// Conditions and allergies the safety checks act on.
class MedicalHistoryEditor extends StatelessWidget {
  const MedicalHistoryEditor({
    super.key,
    required this.conditions,
    required this.allergies,
    required this.onConditions,
    required this.onAllergies,
  });

  final Set<KnownCondition> conditions;
  final Set<DrugAllergy> allergies;
  final ValueChanged<Set<KnownCondition>> onConditions;
  final ValueChanged<Set<DrugAllergy>> onAllergies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Conditions', hint: 'Select any that apply.'),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final e in MedicalProfile.conditionLabels.entries)
              SelectChip(
                label: e.value,
                selected: conditions.contains(e.key),
                onChanged: (on) => onConditions(on ? ({...conditions, e.key}) : ({...conditions}..remove(e.key))),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        const FieldLabel('Medicine allergies'),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final e in MedicalProfile.allergyLabels.entries)
              SelectChip(
                label: e.value,
                tone: Tone.danger,
                selected: allergies.contains(e.key),
                onChanged: (on) => onAllergies(on ? ({...allergies, e.key}) : ({...allergies}..remove(e.key))),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        const InfoBanner(
          tone: Tone.info,
          icon: Icons.shield_outlined,
          message: 'Baymax uses this to block medicines that aren’t safe for you — for example, no paracetamol with liver disease.',
        ),
      ],
    );
  }
}
