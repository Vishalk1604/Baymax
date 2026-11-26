import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/notification_service.dart';
import '../profile/profile_form.dart';

/// Profile setup after sign-up (or for an account whose setup was abandoned).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 4;
  final _forms = List.generate(2, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _forward = true;
  bool _busy = false;

  late final TextEditingController _name;
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  String? _sex;
  String? _blood;
  Set<KnownCondition> _conditions = {};
  Set<DrugAllergy> _allergies = {};
  bool? _notificationsAllowed;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<Session>().user?.displayName ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  Future<void> _next() async {
    if (_step < 2 && !(_forms[_step].currentState?.validate() ?? true)) return;
    if (_step < _steps - 1) {
      _go(_step + 1);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final session = context.read<Session>();
    final user = session.user;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await context.read<ProfileRepository>().create(UserProfile(
            uid: user.uid,
            name: _name.text.trim(),
            email: user.email ?? '',
            age: int.tryParse(_age.text.trim()),
            sex: _sex,
            bloodType: _blood,
            heightCm: int.tryParse(_height.text.trim()),
            weightKg: int.tryParse(_weight.text.trim()),
            conditions: _conditions.toList(),
            allergies: _allergies.toList(),
          ));
      // The auth gate shows the app as soon as the profile exists.
    } catch (e) {
      if (mounted) AppToast.show(context, "Couldn't save your profile. Check your connection.", kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _allowNotifications() async {
    final ok = await NotificationService().requestPermissions();
    if (mounted) setState(() => _notificationsAllowed = ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(emphasis: 1.15)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.xs, 0),
                  child: Row(
                    children: [
                      Expanded(child: _StepProgress(step: _step, total: _steps)),
                      TextButton(
                        onPressed: () => context.read<AuthRepository>().signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.slow,
                    switchInCurve: Motion.emphasized,
                    switchOutCurve: Motion.exit,
                    // Anchor each step at the top (the default centres short steps).
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey(_step);
                      final dir = (_forward == incoming) ? 1.0 : -1.0;
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: Offset(0.12 * dir, 0), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(key: ValueKey(_step), child: _buildStep(context)),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, bottom + Space.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c.background.withValues(alpha: 0), c.background.withValues(alpha: 0.75)],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_step > 0) ...[
                        LiquidButton(
                          label: 'Back',
                          icon: Icons.arrow_back_rounded,
                          variant: LiquidButtonVariant.secondary,
                          expand: false,
                          onPressed: () => _go(_step - 1),
                        ),
                        const SizedBox(width: Space.sm),
                      ],
                      Expanded(
                        child: LiquidButton(
                          label: _step == _steps - 1 ? 'Finish setup' : 'Continue',
                          icon: _step == _steps - 1 ? Icons.check_rounded : null,
                          loading: _busy,
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page({required String title, required String subtitle, required List<Widget> children, Key? formKey}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.text.headlineLarge),
        const SizedBox(height: Space.xs),
        Text(subtitle, style: context.text.bodyLarge!.copyWith(color: context.colors.textSecondary)),
        const SizedBox(height: Space.xl),
        ...children,
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xl),
      child: formKey == null ? content : Form(key: formKey as GlobalKey<FormState>, child: content),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _page(
          formKey: _forms[0],
          title: 'Let’s get to know you',
          subtitle: 'Baymax tailors its guidance to you.',
          children: [
            AppTextField(
              label: 'Your name',
              controller: _name,
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: Space.md),
            NumberField(label: 'Age', controller: _age, min: 1, max: 120, unit: 'years', icon: Icons.cake_outlined),
            const SizedBox(height: Space.lg),
            const FieldLabel('Sex', hint: 'Optional — helps interpret some readings.'),
            ChoiceChips(options: sexOptions, selected: _sex, onSelected: (v) => setState(() => _sex = v)),
          ],
        );
      case 1:
        final h = int.tryParse(_height.text), w = int.tryParse(_weight.text);
        final bmi = (h != null && w != null && h > 0) ? w / ((h / 100) * (h / 100)) : null;
        return _page(
          formKey: _forms[1],
          title: 'About your body',
          subtitle: 'Optional, but useful for your health summary.',
          children: [
            Row(
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
              const SizedBox(height: Space.sm),
              Text('BMI ${bmi.toStringAsFixed(1)}', style: context.text.bodyMedium),
            ],
            const SizedBox(height: Space.lg),
            const FieldLabel('Blood type', hint: 'Skip it if you don’t know.'),
            ChoiceChips(options: bloodTypes, selected: _blood, onSelected: (v) => setState(() => _blood = v)),
          ],
        );
      case 2:
        return _page(
          title: 'Your medical history',
          subtitle: 'So Baymax never suggests a medicine that isn’t safe for you.',
          children: [
            MedicalHistoryEditor(
              conditions: _conditions,
              allergies: _allergies,
              onConditions: (v) => setState(() => _conditions = v),
              onAllergies: (v) => setState(() => _allergies = v),
            ),
          ],
        );
      default:
        return _page(
          title: 'Stay on track',
          subtitle: 'Baymax only asks for access when a feature needs it.',
          children: [
            _PermissionRow(
              icon: Icons.notifications_active_outlined,
              title: 'Medicine reminders',
              body: 'Get a nudge when a dose is due, and before clinic visits.',
              trailing: _notificationsAllowed == true
                  ? const StatusPill(label: 'Allowed', tone: Tone.success, icon: Icons.check_rounded)
                  : LiquidButton(
                      label: _notificationsAllowed == false ? 'Try again' : 'Allow',
                      size: LiquidButtonSize.small,
                      expand: false,
                      onPressed: _allowNotifications,
                    ),
            ),
            const SizedBox(height: Space.sm),
            const _PermissionRow(
              icon: Icons.bluetooth_rounded,
              title: 'Baymax device',
              body: 'Bluetooth is requested when you first connect your Baymax.',
            ),
            const SizedBox(height: Space.sm),
            const _PermissionRow(
              icon: Icons.location_on_outlined,
              title: 'Nearby care',
              body: 'Location is requested only when you search for clinics.',
            ),
          ],
        );
    }
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.icon, required this.title, required this.body, this.trailing});
  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          IconBadge(icon),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
        ],
      ),
    );
  }
}

/// Segmented progress capsule for multi-step flows.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: Motion.slow,
                curve: Motion.emphasized,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step ? c.primary : c.outline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
