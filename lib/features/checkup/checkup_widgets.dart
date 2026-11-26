import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models.dart';
import '../../services/settings_service.dart';
import 'checkup_details_screen.dart';
import 'vitals_ui.dart';

/// One check-up in a list: triage icon, when, vitals, triage pill.
class CheckupRow extends StatelessWidget {
  const CheckupRow({super.key, required this.record, this.showDate = true});
  final CheckupRecord record;

  /// False inside a list already grouped by day/month: shows the weekday+time.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final r = record;
    final when = r.time == null ? 'Check-up' : (showDate ? Fmt.dayTime(r.time!) : '${Fmt.shortDate(r.time!)} · ${Fmt.time(r.time!)}');
    return ListRow(
      icon: r.triage.icon,
      iconColor: r.triage.tone.color(context),
      title: when,
      subtitle: [
        settings.formatTemp(r.temperature),
        '${r.heartRate} bpm',
        '${r.spo2}%',
        if (r.testMode) 'test data',
      ].join(' · '),
      trailing: StatusPill(label: r.triage.label, tone: r.triage.tone, dense: true),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckupDetailsScreen(record: r))),
    );
  }
}

/// The headline of a result: triage level, what it means, and the summary.
class TriageCard extends StatelessWidget {
  const TriageCard({super.key, required this.triage, required this.summary});
  final Triage triage;
  final String summary;

  static String cleanSummary(String s) =>
      s.replaceFirst(RegExp(r'^[^\w(]+'), '').replaceFirst(RegExp(r'^(URGENT|NOTE)\s*:\s*'), '').trim();

  @override
  Widget build(BuildContext context) {
    final tone = triage.tone;
    final color = tone.color(context);
    final text = cleanSummary(summary);
    return Semantics(
      container: true,
      label: '${triage.label}. $text',
      excludeSemantics: true,
      child: SurfaceCard(
        color: tone.soft(context),
        borderColor: color.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Icon(triage.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(triage.label, style: context.text.headlineSmall!.copyWith(color: color)),
                      Text(triage.meaning, style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(text, style: context.text.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}

extension TriageMeaning on Triage {
  String get meaning => switch (this) {
        Triage.selfCare => 'You can likely manage this at home.',
        Triage.monitor => 'No medicine needed right now.',
        Triage.doctor => 'A doctor should look at this.',
        Triage.emergency => 'Please get medical help right away.',
      };
}

/// A vital reading with its status, in the person's temperature unit.
class VitalTile extends StatelessWidget {
  const VitalTile({super.key, required this.kind, required this.value});
  final VitalKind kind;
  final double value;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final (status, tone) = kind.status(value);
    final isTemp = kind == VitalKind.temperature;
    final shown = isTemp && settings.fahrenheit ? value * 9 / 5 + 32 : value;
    final unit = switch (kind) {
      VitalKind.temperature => settings.tempUnitLabel,
      VitalKind.heartRate => 'bpm',
      VitalKind.spo2 => '%',
    };
    return Semantics(
      label: '${kind.label} ${shown.toStringAsFixed(isTemp ? 1 : 0)} $unit, $status',
      excludeSemantics: true,
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.md),
        radius: Radii.md,
        child: Column(
          children: [
            Icon(kind.icon, color: tone.color(context), size: 22),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedNumber(
                value: shown,
                decimals: isTemp ? 1 : 0,
                style: AppTypography.style(26, 800, tabular: true).copyWith(color: context.colors.textPrimary),
              ),
            ),
            Text(unit, style: context.text.labelMedium),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, child: StatusPill(label: status, tone: tone, dense: true)),
          ],
        ),
      ),
    );
  }
}

/// Three vital tiles side by side.
class VitalsRow extends StatelessWidget {
  const VitalsRow({super.key, required this.temperature, required this.heartRate, required this.spo2});
  final double temperature;
  final int heartRate;
  final int spo2;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: VitalTile(kind: VitalKind.temperature, value: temperature)),
        const SizedBox(width: Space.sm),
        Expanded(child: VitalTile(kind: VitalKind.heartRate, value: heartRate.toDouble())),
        const SizedBox(width: Space.sm),
        Expanded(child: VitalTile(kind: VitalKind.spo2, value: spo2.toDouble())),
      ],
    );
  }
}

/// A safety alert split into a short title and the explanation, e.g.
/// "⛔ IBUPROFEN BLOCKED: Known NSAID allergy" → "Ibuprofen blocked" /
/// "Known NSAID allergy".
class SafetyNote {
  const SafetyNote({this.title, required this.message, required this.tone, required this.icon});
  final String? title;
  final String message;
  final Tone tone;
  final IconData icon;

  static final _heading = RegExp(r"^([A-Z][A-Z0-9 /&'()\-]{2,}[A-Z)])\s*:\s*(.+)$", dotAll: true);

  factory SafetyNote.parse(String raw, {AlertLevel? level}) {
    final trimmed = raw.trim();
    Tone tone;
    IconData icon;
    if (level != null) {
      (tone, icon) = switch (level) {
        AlertLevel.info => (Tone.info, Icons.info_outline_rounded),
        AlertLevel.warning => (Tone.warning, Icons.warning_amber_rounded),
        AlertLevel.danger => (Tone.danger, Icons.block_rounded),
        AlertLevel.emergency => (Tone.danger, Icons.emergency_rounded),
      };
      if (trimmed.startsWith('⛔')) icon = Icons.block_rounded;
    } else if (trimmed.startsWith('🚨') || trimmed.startsWith('🆘')) {
      (tone, icon) = (Tone.danger, Icons.emergency_rounded);
    } else if (trimmed.startsWith('⛔')) {
      (tone, icon) = (Tone.danger, Icons.block_rounded);
    } else if (trimmed.startsWith('⚠')) {
      (tone, icon) = (Tone.warning, Icons.warning_amber_rounded);
    } else {
      (tone, icon) = (Tone.info, Icons.info_outline_rounded);
    }

    final text = trimmed.replaceFirst(RegExp(r'^[^\w(]+'), '');
    final m = _heading.firstMatch(text);
    if (m != null) {
      final h = m.group(1)!.toLowerCase();
      return SafetyNote(title: h[0].toUpperCase() + h.substring(1), message: m.group(2)!.trim(), tone: tone, icon: icon);
    }
    return SafetyNote(message: text, tone: tone, icon: icon);
  }
}

/// "Safety notes" section; renders nothing when there are none.
class SafetyNotes extends StatelessWidget {
  const SafetyNotes({super.key, required this.notes, this.title = 'Safety notes'});
  final List<SafetyNote> notes;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: Space.xs),
        for (final n in notes) ...[
          InfoBanner(title: n.title, message: n.message, tone: n.tone, icon: n.icon),
          const SizedBox(height: Space.xs),
        ],
      ],
    );
  }
}

/// A recommended medicine with its dosing guidance.
class MedicineCard extends StatelessWidget {
  const MedicineCard({super.key, required this.medication, required this.dosing, this.footer});
  final Medication medication;
  final DosingInfo dosing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fact(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 104, child: Text(label, style: context.text.bodySmall)),
              Expanded(child: Text(value, style: context.text.bodyMedium!.copyWith(color: c.textPrimary))),
            ],
          ),
        );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.medication_rounded),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medication.displayName, style: context.text.titleMedium),
                    Text('For ${medication.typicalPurpose}', style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          fact('Dose', dosing.dose),
          fact('How often', dosing.frequency),
          fact('Max per day', dosing.maxDailyDose),
          if (dosing.notes.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(dosing.notes, style: context.text.bodySmall!.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (medication.deviceCompartment > 0) ...[
            const SizedBox(height: Space.sm),
            StatusPill(
              label: 'Compartment ${medication.deviceCompartment} in your Baymax',
              icon: Icons.inventory_2_outlined,
              tone: Tone.primary,
              dense: true,
            ),
          ],
          if (footer != null) ...[const SizedBox(height: Space.sm), footer!],
        ],
      ),
    );
  }
}

/// Symptoms as soft pills.
class SymptomPills extends StatelessWidget {
  const SymptomPills({super.key, required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final s in names) StatusPill(label: symptomLabel(s), tone: Tone.primary)],
    );
  }
}

/// Loading placeholder shaped like a list of check-up rows.
class CheckupListSkeleton extends StatelessWidget {
  const CheckupListSkeleton({super.key, this.rows = 4});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: Space.md),
            const Row(
              children: [
                Skeleton(width: 40, height: 40, radius: 20),
                SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Skeleton(width: 140, height: 14), SizedBox(height: 8), Skeleton(width: 190, height: 12)],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
