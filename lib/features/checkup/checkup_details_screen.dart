import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/motion/fade_slide_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/settings_service.dart';
import '../shell/main_shell.dart';
import 'checkup_widgets.dart';

class CheckupDetailsScreen extends StatelessWidget {
  const CheckupDetailsScreen({super.key, required this.record});
  final CheckupRecord record;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this check-up?',
      message: 'It will be removed from your history. Medicines it added stay in your list.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    final uid = context.read<Session>().uid;
    if (uid == null) return;
    try {
      await context.read<CheckupRepository>().delete(uid, record.id);
      if (!context.mounted) return;
      AppToast.show(context, 'Check-up deleted', kind: ToastKind.success);
      Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) AppToast.show(context, "Couldn't delete. Try again.", kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final settings = context.watch<SettingsService>();
    final triage = r.triage;
    final needsCare = triage == Triage.doctor || triage == Triage.emergency;
    final notes = r.safetyAlerts.map(SafetyNote.parse).toList();
    final raw = r.rawSensorTemperature;

    var i = 0;
    Widget item(Widget child) => FadeSlideIn(delay: FadeSlideIn.stagger(i++), child: child);

    return GlassPage(
      title: 'Check-up',
      subtitle: [
        if (r.time != null) Fmt.dayTime(r.time!),
        if (r.testMode) 'test data',
      ].join(' · '),
      showBack: true,
      actions: [
        LiquidIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete check-up', onPressed: () => _delete(context)),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              item(TriageCard(triage: triage, summary: r.recommendation)),
              if (needsCare) ...[
                const SizedBox(height: Space.md),
                item(Row(
                  children: [
                    if (triage == Triage.emergency) ...[
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
                        label: 'Book a visit',
                        icon: Icons.event_available_rounded,
                        variant: LiquidButtonVariant.secondary,
                        size: LiquidButtonSize.medium,
                        onPressed: () => MainShell.openTab(context, MainShell.visits),
                      ),
                    ),
                  ],
                )),
              ],
              if (r.testMode) ...[
                const SizedBox(height: Space.md),
                const InfoBanner(
                  tone: Tone.warning,
                  icon: Icons.science_rounded,
                  message: 'Test mode — these vitals were sample values, not a device reading.',
                ),
              ],
              const SizedBox(height: Space.xl),
              Text('Vitals', style: context.text.titleLarge),
              const SizedBox(height: Space.sm),
              item(VitalsRow(temperature: r.temperature, heartRate: r.heartRate, spo2: r.spo2)),
              if (raw != null && (raw - r.temperature).abs() >= 0.1) ...[
                const SizedBox(height: Space.xs),
                Text(
                  'The forehead sensor read ${settings.formatTemp(raw)}; Baymax estimates body temperature from it.',
                  style: context.text.bodySmall,
                ),
              ],
              if (r.observation.trim().isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                Text('What you told Baymax', style: context.text.titleLarge),
                const SizedBox(height: Space.sm),
                item(SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, color: context.colors.primary),
                      const SizedBox(width: Space.xs),
                      Expanded(child: Text(r.observation.trim(), style: context.text.bodyLarge)),
                    ],
                  ),
                )),
              ],
              if (r.symptoms.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Text('Symptoms noted', style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                SymptomPills(names: r.symptoms),
              ],
              if (r.medicines.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                Text('Recommended', style: context.text.titleLarge),
                const SizedBox(height: Space.sm),
                for (final name in r.medicines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: item(_StoredMedicine(name: name)),
                  ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                SafetyNotes(notes: notes),
              ],
              const SizedBox(height: Space.md),
              Text(
                'Baymax is not a medical device and doesn’t replace a doctor. If you feel worse, get medical care.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ],
    );
  }
}

/// A medicine name from history; shows the engine's dosing when it's one of
/// the engine's medicines.
class _StoredMedicine extends StatelessWidget {
  const _StoredMedicine({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final med = MedicationInfo.fromName(name);
    if (med == null) {
      return SurfaceCard(
        child: Row(
          children: [
            const IconBadge(Icons.medication_rounded),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(name, style: context.text.titleMedium)),
          ],
        ),
      );
    }
    return MedicineCard(medication: med, dosing: med.standardAdultDosing);
  }
}
