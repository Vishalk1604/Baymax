import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../baymax/models/baymax_models.dart';
import '../../baymax/services/baymax_llm_service.dart';
import '../../baymax/services/offline_symptom_matcher.dart';
import '../../config/app_config.dart';
import '../../core/motion/fade_slide_in.dart';
import '../../core/motion/jelly.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../models/medical_profile.dart';
import '../device/device_sheet.dart';
import '../profile/edit_profile_screen.dart';
import 'checkup_flow.dart';
import 'checkup_widgets.dart';

class CheckupFlowScreen extends StatefulWidget {
  const CheckupFlowScreen({super.key});

  @override
  State<CheckupFlowScreen> createState() => _CheckupFlowScreenState();
}

class _CheckupFlowScreenState extends State<CheckupFlowScreen> {
  late final CheckupFlow _flow = CheckupFlow(
    llm: AppConfig.useOfflineSymptomMatcher
        ? OfflineSymptomMatcher()
        : BaymaxLlmService(
            config: const BaymaxLlmConfig(
              apiKey: AppConfig.llmApiKey,
              baseUrl: AppConfig.llmBaseUrl,
              model: AppConfig.llmModel,
            ),
          ),
  );
  final _freeText = TextEditingController();
  final _scroll = ScrollController();
  int _step = 0;

  static const _stepTitles = ['Your vitals', 'How do you feel?', 'Your results'];

  @override
  void dispose() {
    _flow.dispose();
    _freeText.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    // Each step starts at its top.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _back() async {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    if (_step == 2 && _flow.result != null && !_flow.saved) {
      final discard = await confirmAction(
        context,
        title: 'Leave without saving?',
        message: 'This check-up won’t be added to your history.',
        confirmLabel: 'Leave',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    _flow.resetAnalysis();
    _goTo(_step - 1);
  }

  Future<void> _analyse() async {
    _goTo(2);
    final profile = context.read<Session>().profile;
    await _flow.evaluate(
      profile: profile?.medical ?? const MedicalProfile(),
      symptomReaderConfigured: AppConfig.useOfflineSymptomMatcher || AppConfig.hasLlmKey,
    );
  }

  Future<void> _answer(int i) async {
    final uid = context.read<Session>().uid;
    final meds = context.read<MedicationRepository>();
    await _flow.answer(i, activeMedicineNames: () async => uid == null ? <String>{} : meds.activeNames(uid));
  }

  Future<void> _save() async {
    final uid = context.read<Session>().uid;
    if (uid == null) return;
    try {
      await _flow.save(
        uid: uid,
        checkups: context.read<CheckupRepository>(),
        medications: context.read<MedicationRepository>(),
      );
      if (!mounted) return;
      final res = _flow.result!;
      final added = !res.escalateToDoctor && res.primaryMedication != Medication.none;
      AppToast.show(
        context,
        added ? 'Saved — medicines added to your list' : 'Check-up saved',
        kind: ToastKind.success,
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) AppToast.show(context, "Couldn't save. Check your connection and try again.", kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) => PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: GlassPage(
          title: _step == 2 && _flow.phase == CheckupPhase.question ? 'One quick question' : _stepTitles[_step],
          subtitle: switch (_step) {
            0 => 'Temperature, heart rate and oxygen.',
            1 => 'Pick what fits, or describe it in your own words.',
            _ => null,
          },
          onBack: _back,
          showBack: true,
          controller: _scroll,
          actions: [
            if (_step == 0)
              LiquidIconButton(
                icon: _flow.testMode ? Icons.science_rounded : Icons.science_outlined,
                tooltip: _flow.testMode ? 'Turn off test mode' : 'Use sample vitals (test mode)',
                onPressed: () => _flow.setTestMode(!_flow.testMode),
              ),
          ],
          bottom: _dock(context),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
                child: _FlowSteps(step: _step),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: Motion.slow,
                  switchInCurve: Motion.emphasized,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('$_step-${_flow.phase}'),
                    child: switch (_step) {
                      0 => _VitalsStep(flow: _flow),
                      1 => _SymptomsStep(flow: _flow, controller: _freeText),
                      _ => _ResultsStep(flow: _flow, onAnswer: _answer, onRetry: _analyse, onEdit: () => _goTo(1)),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _dock(BuildContext context) {
    final f = _flow;
    switch (_step) {
      case 0:
        if (f.effectiveReading != null) {
          return LiquidButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: () => _goTo(1));
        }
        if (f.connected) {
          return LiquidButton(
            label: f.measuring ? 'Measuring…' : 'Take reading',
            icon: Icons.play_arrow_rounded,
            loading: f.measuring,
            onPressed: f.measuring ? null : f.startMeasurement,
          );
        }
        return LiquidButton(label: 'Connect Baymax', icon: Icons.bluetooth_searching_rounded, onPressed: () => showDeviceSheet(context));
      case 1:
        return LiquidButton(
          label: f.chips.isEmpty && f.freeText.trim().isEmpty ? 'Continue without symptoms' : 'Analyse',
          icon: Icons.auto_awesome_rounded,
          onPressed: _analyse,
        );
      default:
        if (f.phase != CheckupPhase.result) return null;
        return LiquidButton(label: 'Save to history', icon: Icons.bookmark_add_rounded, loading: f.saving, onPressed: _save);
    }
  }
}

/// Labelled three-step progress capsule.
class _FlowSteps extends StatelessWidget {
  const _FlowSteps({required this.step});
  final int step;

  static const _labels = ['Vitals', 'Symptoms', 'Results'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step ${step + 1} of 3: ${_labels[step]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: Motion.slow,
                    curve: Motion.emphasized,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step ? c.primary : c.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[i],
                    style: AppTypography.style(12.5, i == step ? 720 : 560)
                        .copyWith(color: i <= step ? c.textPrimary : c.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── Step 1 ──

class _VitalsStep extends StatelessWidget {
  const _VitalsStep({required this.flow});
  final CheckupFlow flow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reading = flow.effectiveReading;
    final mood = flow.measuring
        ? OrbMood.active
        : (reading != null && !flow.testMode ? OrbMood.success : OrbMood.idle);
    final status = flow.testMode
        ? 'Sample vitals — move the sliders to try different readings.'
        : flow.measuring
            ? flow.deviceStatus
            : reading != null
                ? 'Reading complete'
                : flow.connected
                    ? 'Ready when you are. Tap “Take reading”.'
                    : 'Connect your Baymax to measure.';
    final icon = flow.deviceStatus.toLowerCase().contains('finger')
        ? Icons.touch_app_rounded
        : flow.deviceStatus.toLowerCase().contains('temperature')
            ? Icons.thermostat_rounded
            : (mood == OrbMood.success ? Icons.check_rounded : Icons.monitor_heart_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!flow.connected && !flow.testMode) ...[
          SurfaceCard(
            child: Row(
              children: [
                const IconBadge(Icons.bluetooth_disabled_rounded),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Baymax isn’t connected', style: context.text.titleSmall),
                      Text('Or try the flow with sample vitals.', style: context.text.bodySmall),
                    ],
                  ),
                ),
                TextButton(onPressed: () => flow.setTestMode(true), child: const Text('Use sample')),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
        ],
        Center(
          child: LiquidOrb(
            mood: mood,
            size: 210,
            child: Icon(icon, size: 46, color: Colors.white.withValues(alpha: 0.95)),
          ),
        ),
        const SizedBox(height: Space.sm),
        Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: Motion.base,
            child: Text(
              status,
              key: ValueKey(status),
              textAlign: TextAlign.center,
              style: context.text.titleMedium!.copyWith(color: flow.measuring ? c.primary : c.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (reading != null)
          FadeSlideIn(child: VitalsRow(temperature: reading.temperature, heartRate: reading.heartRate, spo2: reading.spo2)),
        if (flow.testMode) ...[
          const SizedBox(height: Space.lg),
          _TestModePanel(flow: flow),
        ],
      ],
    );
  }
}

class _TestModePanel extends StatelessWidget {
  const _TestModePanel({required this.flow});
  final CheckupFlow flow;

  @override
  Widget build(BuildContext context) {
    Widget slider(String label, double value, double min, double max, int divisions, String shown, ValueChanged<double> onChanged) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: context.text.titleSmall)),
                Text(shown, style: AppTypography.style(15, 720, tabular: true)),
              ],
            ),
            Slider(value: value, min: min, max: max, divisions: divisions, label: shown, onChanged: onChanged),
          ],
        );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            tone: Tone.warning,
            icon: Icons.science_rounded,
            message: 'Test mode: these vitals aren’t from your device. Saved results are marked as test data.',
          ),
          const SizedBox(height: Space.md),
          slider('Temperature', flow.testTemp, 34, 42, 80, '${flow.testTemp.toStringAsFixed(1)} °C',
              (v) => flow.setTestVitals(temperature: double.parse(v.toStringAsFixed(1)))),
          slider('Heart rate', flow.testHeartRate, 40, 160, 120, '${flow.testHeartRate.round()} bpm',
              (v) => flow.setTestVitals(heartRate: v.roundToDouble())),
          slider('Oxygen (SpO₂)', flow.testSpo2, 80, 100, 20, '${flow.testSpo2.round()} %',
              (v) => flow.setTestVitals(spo2: v.roundToDouble())),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── Step 2 ──

class _SymptomGroup {
  const _SymptomGroup(this.title, this.items, {this.urgent = false});
  final String title;
  final List<(String label, String phrase)> items;
  final bool urgent;
}

const _groups = [
  _SymptomGroup('Common', [
    ('Fever', 'fever'),
    ('Headache', 'headache'),
    ('Cough', 'cough'),
    ('Sore throat', 'sore throat'),
    ('Runny nose', 'runny nose'),
    ('Sneezing', 'sneezing'),
    ('Body ache', 'body ache'),
    ('Tiredness', 'fatigue'),
  ]),
  _SymptomGroup('Stomach', [
    ('Nausea', 'nausea'),
    ('Vomiting', 'vomiting'),
    ('Diarrhoea', 'diarrhea'),
    ('Heartburn', 'heartburn'),
    ('Bloating', 'bloating'),
    ('Stomach cramps', 'stomach cramps'),
  ]),
  _SymptomGroup('Other', [
    ('Rash', 'rash'),
    ('Itching', 'itching'),
    ('Dizziness', 'dizziness'),
    ('Watery eyes', 'watery eyes'),
    ('Joint pain', 'joint pain'),
    ('Back pain', 'back pain'),
  ]),
  _SymptomGroup('Urgent', [
    ('Hard to breathe', 'difficulty breathing'),
    ('Chest tightness', 'chest tightness'),
    ('Can’t keep anything down', 'persistent vomiting'),
    ('Fainted', 'fainting'),
    ('Confused', 'confusion'),
    ('Vomiting blood', 'vomiting blood'),
    ('Severe stomach pain', 'severe stomach pain'),
  ], urgent: true),
];

class _SymptomsStep extends StatelessWidget {
  const _SymptomsStep({required this.flow, required this.controller});
  final CheckupFlow flow;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<Session>().profile;
    final history = [
      ...?profile?.conditions.map((c) => MedicalProfile.conditionLabels[c]).whereType<String>(),
      ...?profile?.allergies.map((a) => '${MedicalProfile.allergyLabels[a]} allergy'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in _groups) ...[
          Row(
            children: [
              if (group.urgent) ...[Icon(Icons.warning_amber_rounded, size: 18, color: context.colors.danger), const SizedBox(width: 6)],
              Text(group.title, style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final (label, phrase) in group.items)
                SelectChip(
                  label: label,
                  tone: group.urgent ? Tone.danger : Tone.primary,
                  selected: flow.chips.contains(phrase),
                  onChanged: (_) => flow.toggleChip(phrase),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
        ],
        AppTextField(
          label: 'Anything else?',
          hint: 'e.g. “sore throat since yesterday, worse at night”',
          controller: controller,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: flow.setFreeText,
        ),
        const SizedBox(height: Space.lg),
        SurfaceCard(
          padding: const EdgeInsets.all(Space.md),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          child: Row(
            children: [
              const IconBadge(Icons.shield_outlined, size: 40),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your medical history', style: context.text.titleSmall),
                    Text(
                      history.isEmpty ? 'No conditions or allergies on file — tap to add.' : history.join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, size: 18, color: context.colors.textTertiary),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────── Step 3 ──

class _ResultsStep extends StatelessWidget {
  const _ResultsStep({required this.flow, required this.onAnswer, required this.onRetry, required this.onEdit});
  final CheckupFlow flow;
  final ValueChanged<int> onAnswer;
  final VoidCallback onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    switch (flow.phase) {
      case CheckupPhase.idle:
      case CheckupPhase.analysing:
        return Column(
          children: [
            const SizedBox(height: Space.lg),
            const LiquidOrb(mood: OrbMood.active, size: 200, child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 42)),
            const SizedBox(height: Space.md),
            Text('Analysing…', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Checking your vitals, symptoms and medical history for safety.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ],
        );
      case CheckupPhase.error:
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          tone: context.colors.warning,
          title: 'We couldn’t finish',
          message: flow.error ?? 'Please try again.',
          actionLabel: 'Try again',
          onAction: onRetry,
        );
      case CheckupPhase.question:
        return _QuestionView(flow: flow, onAnswer: onAnswer);
      case CheckupPhase.result:
        return _ResultView(flow: flow, onEdit: onEdit);
    }
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.flow, required this.onAnswer});
  final CheckupFlow flow;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final q = flow.question!;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flow.symptoms.isNotEmpty) ...[
          Text('What Baymax understood', style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          SymptomPills(names: [for (final x in flow.symptoms) x.name]),
          const SizedBox(height: Space.lg),
        ],
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(size: 28),
                  const SizedBox(width: Space.xs),
                  Text('Baymax asks', style: context.text.labelMedium!.copyWith(color: c.primary)),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(q.question, style: context.text.titleLarge),
              const SizedBox(height: Space.md),
              for (final (i, option) in q.options.indexed)
                FadeSlideIn(
                  delay: FadeSlideIn.stagger(i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: JellyPress(
                      onTap: () => onAnswer(i),
                      intensity: 0.5,
                      semanticLabel: option,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                        decoration: BoxDecoration(
                          color: c.surfaceMuted,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: c.outline),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(option, style: context.text.titleSmall)),
                            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: c.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        SafetyNotes(notes: _notes(flow.alerts)),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.flow, required this.onEdit});
  final CheckupFlow flow;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final res = flow.result!;
    final triage = flow.triage!;
    final medicines = [
      if (res.primaryMedication != Medication.none) (res.primaryMedication, res.dosing),
      if (res.secondaryMedication != null)
        (res.secondaryMedication!, res.secondaryDosing ?? res.secondaryMedication!.standardAdultDosing),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: TriageCard(triage: triage, summary: res.summary)),
        if (triage == Triage.emergency || triage == Triage.doctor) ...[
          const SizedBox(height: Space.md),
          FadeSlideIn(delay: FadeSlideIn.stagger(1), child: _CareActions(emergency: triage == Triage.emergency)),
        ],
        if (medicines.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Text('Recommended medicines', style: context.text.titleLarge),
          const SizedBox(height: Space.sm),
          for (final (i, (med, dosing)) in medicines.indexed)
            FadeSlideIn(
              delay: FadeSlideIn.stagger(i + 2),
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: MedicineCard(medication: med, dosing: dosing),
              ),
            ),
        ],
        if (flow.symptoms.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('What Baymax understood', style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          SymptomPills(names: [for (final x in flow.symptoms) x.name]),
        ],
        const SizedBox(height: Space.lg),
        SafetyNotes(notes: _notes(res.safetyAlerts.isNotEmpty ? res.safetyAlerts : flow.alerts)),
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_note_rounded), label: const Text('Change symptoms')),
        ),
        if (flow.testMode)
          const Padding(
            padding: EdgeInsets.only(bottom: Space.xs),
            child: InfoBanner(tone: Tone.warning, icon: Icons.science_rounded, message: 'Test mode — sample vitals, saved as test data.'),
          ),
        Text(
          'Baymax is not a medical device and doesn’t replace a doctor. If you feel worse, get medical care.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _CareActions extends StatelessWidget {
  const _CareActions({required this.emergency});
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (emergency) ...[
          Expanded(
            child: LiquidButton(
              label: 'Call 112',
              icon: Icons.call_rounded,
              variant: LiquidButtonVariant.danger,
              size: LiquidButtonSize.medium,
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
            ),
          ),
          const SizedBox(width: Space.sm),
        ],
        Expanded(
          child: LiquidButton(
            label: emergency ? 'Hospital' : 'Find a clinic',
            icon: Icons.local_hospital_rounded,
            variant: LiquidButtonVariant.secondary,
            size: LiquidButtonSize.medium,
            onPressed: () => launchUrl(
              Uri.parse('https://www.google.com/maps/search/?api=1&query=${emergency ? 'hospital' : 'clinic'}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
      ],
    );
  }
}

List<SafetyNote> _notes(List<SafetyAlert> alerts) =>
    [for (final a in alerts) SafetyNote.parse(a.message, level: a.level)];
