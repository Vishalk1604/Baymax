import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import 'profile_form.dart';

/// Edits the profile, including the medical history the safety checks use.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final UserProfile? _original = context.read<Session>().profile;

  late final _name = TextEditingController(text: _original?.name ?? '');
  late final _age = TextEditingController(text: _original?.age?.toString() ?? '');
  late final _height = TextEditingController(text: _original?.heightCm?.toString() ?? '');
  late final _weight = TextEditingController(text: _original?.weightKg?.toString() ?? '');
  late String? _sex = sexOptions.contains(_original?.sex) ? _original?.sex : null;
  late String? _blood = bloodTypes.contains(_original?.bloodType) ? _original?.bloodType : null;
  late Set<KnownCondition> _conditions = {...?_original?.conditions};
  late Set<DrugAllergy> _allergies = {...?_original?.allergies};

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _age, _height, _weight]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final original = _original;
    if (original == null || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ProfileRepository>().update(UserProfile(
            uid: original.uid,
            name: _name.text.trim(),
            email: original.email,
            age: int.tryParse(_age.text.trim()),
            sex: _sex,
            bloodType: _blood,
            heightCm: int.tryParse(_height.text.trim()),
            weightKg: int.tryParse(_weight.text.trim()),
            conditions: _conditions.toList(),
            allergies: _allergies.toList(),
            createdAt: original.createdAt,
          ));
      if (!mounted) return;
      _dirty = false;
      AppToast.show(context, 'Profile saved', kind: ToastKind.success);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, "Couldn't save. Check your connection and try again.", kind: ToastKind.error);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(
      context,
      title: 'Discard changes?',
      message: 'Your edits to your profile won’t be saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (leave && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = int.tryParse(_height.text), w = int.tryParse(_weight.text);
    final bmi = (h != null && w != null && h > 0) ? w / ((h / 100) * (h / 100)) : null;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: GlassPage(
        title: 'Edit profile',
        showBack: true,
        bottom: LiquidButton(label: 'Save changes', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'About you',
                      children: [
                        AppTextField(
                          label: 'Name',
                          controller: _name,
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: Space.md),
                        NumberField(label: 'Age', controller: _age, min: 1, max: 120, unit: 'years', icon: Icons.cake_outlined),
                        const SizedBox(height: Space.md),
                        const FieldLabel('Sex', hint: 'Optional.'),
                        ChoiceChips(
                          options: sexOptions,
                          selected: _sex,
                          onSelected: (v) => setState(() {
                            _sex = v;
                            _dirty = true;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    _Section(
                      title: 'Body',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: NumberField(
                                label: 'Height',
                                controller: _height,
                                min: 40,
                                max: 250,
                                unit: 'cm',
                                required: false,
                                icon: Icons.height_rounded,
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: NumberField(
                                label: 'Weight',
                                controller: _weight,
                                min: 2,
                                max: 300,
                                unit: 'kg',
                                required: false,
                                icon: Icons.monitor_weight_outlined,
                              ),
                            ),
                          ],
                        ),
                        if (bmi != null) ...[
                          const SizedBox(height: Space.xs),
                          Text('BMI ${bmi.toStringAsFixed(1)} · ${bmiCategory(bmi)}', style: context.text.bodyMedium),
                        ],
                        const SizedBox(height: Space.md),
                        const FieldLabel('Blood type', hint: 'Tap again to clear.'),
                        ChoiceChips(
                          options: bloodTypes,
                          selected: _blood,
                          onSelected: (v) => setState(() {
                            _blood = v;
                            _dirty = true;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    _Section(
                      title: 'Medical history',
                      subtitle: 'Baymax checks every recommendation against this.',
                      children: [
                        MedicalHistoryEditor(
                          conditions: _conditions,
                          allergies: _allergies,
                          onConditions: (v) => setState(() {
                            _conditions = v;
                            _dirty = true;
                          }),
                          onAllergies: (v) => setState(() {
                            _allergies = v;
                            _dirty = true;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    const InfoBanner(
                      icon: Icons.lock_outline_rounded,
                      message: 'Your medical history stays in your account. It’s used on this phone to keep '
                          'recommendations safe and isn’t sent to the AI service.',
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Underweight", "Healthy", "Overweight", "Obese" (WHO adult ranges).
String bmiCategory(double bmi) => switch (bmi) {
      < 18.5 => 'Underweight',
      < 25 => 'Healthy range',
      < 30 => 'Overweight',
      _ => 'Obese range',
    };

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: context.text.bodySmall),
          ],
          const SizedBox(height: Space.md),
          ...children,
        ],
      ),
    );
  }
}
