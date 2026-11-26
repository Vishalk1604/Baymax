import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion/fade_slide_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/pdf_service.dart';
import '../../services/settings_service.dart';
import 'checkup_flow_screen.dart';
import 'checkup_widgets.dart';
import 'vitals_ui.dart';

enum _Filter { all, attention, selfCare, monitor }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.attention => 'Needed a doctor',
        _Filter.selfCare => 'Self-care',
        _Filter.monitor => 'Monitoring',
      };

  bool matches(CheckupRecord r) => switch (this) {
        _Filter.all => true,
        _Filter.attention => r.triage == Triage.doctor || r.triage == Triage.emergency,
        _Filter.selfCare => r.triage == Triage.selfCare,
        _Filter.monitor => r.triage == Triage.monitor,
      };
}

class CheckupHistoryScreen extends StatefulWidget {
  const CheckupHistoryScreen({super.key});

  @override
  State<CheckupHistoryScreen> createState() => _CheckupHistoryScreenState();
}

class _CheckupHistoryScreenState extends State<CheckupHistoryScreen> {
  static const _limit = 200;
  late final Stream<List<CheckupRecord>> _stream =
      context.read<CheckupRepository>().watch(context.read<Session>().uid!, limit: _limit);
  _Filter _filter = _Filter.all;
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await PDFService().generateAndShareHistory();
    } catch (_) {
      if (mounted) AppToast.show(context, "Couldn't create the PDF. Try again.", kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckupRecord>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data;
        final records = all?.where(_filter.matches).toList();
        return GlassPage(
          title: 'History',
          subtitle: all == null || all.isEmpty
              ? 'Every check-up you save appears here.'
              : '${all.length} check-up${all.length == 1 ? '' : 's'} saved',
          showBack: true,
          actions: [
            if (all != null && all.isNotEmpty)
              _exporting
                  ? const SizedBox(width: 48, height: 48, child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))))
                  : LiquidIconButton(icon: Icons.ios_share_rounded, tooltip: 'Export as PDF', onPressed: _export),
          ],
          slivers: [
            if (snap.hasError && all == null)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Couldn’t load your history',
                  message: 'Check your connection. Your check-ups are safe.',
                ),
              )
            else if (all == null)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverToBoxAdapter(child: CheckupListSkeleton(rows: 6)),
              )
            else if (all.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.monitor_heart_outlined,
                  title: 'No check-ups yet',
                  message: 'Measure your vitals and tell Baymax how you feel. Results you save are kept here.',
                  actionLabel: 'Start a check-up',
                  onAction: () => Navigator.of(context)
                      .pushReplacement(MaterialPageRoute(builder: (_) => const CheckupFlowScreen())),
                ),
              )
            else ...[
              // Trends use device readings only; test-mode samples would skew them.
              if (all.where((r) => !r.testMode).length >= 2)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
                  sliver: SliverToBoxAdapter(
                    child: FadeSlideIn(child: _TrendsCard(records: all.where((r) => !r.testMode).toList())),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    itemCount: _Filter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                    itemBuilder: (context, i) {
                      final f = _Filter.values[i];
                      final n = all.where(f.matches).length;
                      return Center(
                        child: SelectChip(
                          label: f == _Filter.all ? f.label : '${f.label} · $n',
                          selected: _filter == f,
                          onChanged: (_) => setState(() => _filter = f),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
              if (records!.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'Nothing here',
                    message: 'No check-ups match “${_filter.label}”.',
                    actionLabel: 'Show all',
                    onAction: () => setState(() => _filter = _Filter.all),
                  ),
                )
              else
                _MonthGroups(records: records),
              if (all.length >= _limit)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.gutter),
                    child: Text('Showing your latest $_limit check-ups. The PDF export includes all of them.',
                        textAlign: TextAlign.center, style: context.text.bodySmall),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _MonthGroups extends StatelessWidget {
  const _MonthGroups({required this.records});
  final List<CheckupRecord> records;

  @override
  Widget build(BuildContext context) {
    // Records arrive newest first; keep that order within and across months.
    final groups = <String, List<CheckupRecord>>{};
    for (final r in records) {
      final key = r.time == null ? 'Just now' : Fmt.monthYear(r.time!);
      groups.putIfAbsent(key, () => []).add(r);
    }
    final entries = groups.entries.toList();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          final section = Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(e.key, padding: const EdgeInsets.only(bottom: Space.xs)),
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(
                    children: [
                      for (final (j, r) in e.value.indexed) ...[
                        if (j > 0) const Divider(indent: Space.md, endIndent: Space.md),
                        CheckupRow(record: r, showDate: false),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
          return i < 4 ? FadeSlideIn(delay: FadeSlideIn.stagger(i + 1), child: section) : section;
        },
      ),
    );
  }
}

/// Sparklines of the last check-ups, oldest → newest, with the latest value.
class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.records});
  final List<CheckupRecord> records;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final recent = records.take(14).toList().reversed.toList();
    Widget trend(VitalKind kind) {
      final values = recent.map(kind.valueOf).toList();
      final latest = values.last;
      final (status, tone) = kind.status(latest);
      final shown = switch (kind) {
        VitalKind.temperature => settings.formatTemp(latest),
        VitalKind.heartRate => '${latest.round()} bpm',
        VitalKind.spo2 => '${latest.round()}%',
      };
      return Expanded(
        child: Semantics(
          label: '${kind.label}: latest $shown, $status',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(kind.icon, size: 16, color: tone.color(context)),
                  const SizedBox(width: 4),
                  Flexible(child: Text(kind.shortLabel, style: context.text.labelMedium, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(shown, style: AppTypography.style(17, 760, tabular: true).copyWith(color: context.colors.textPrimary)),
              ),
              const SizedBox(height: Space.xs),
              Sparkline(values: values, color: tone == Tone.success ? context.colors.primary : tone.color(context), height: 34),
            ],
          ),
        ),
      );
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Trends', style: context.text.titleMedium)),
              Text('Last ${recent.length}', style: context.text.labelMedium),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              trend(VitalKind.temperature),
              const SizedBox(width: Space.md),
              trend(VitalKind.heartRate),
              const SizedBox(width: Space.md),
              trend(VitalKind.spo2),
            ],
          ),
        ],
      ),
    );
  }
}
