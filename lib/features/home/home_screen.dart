import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/motion/fade_slide_in.dart';
import '../../core/motion/jelly.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/settings_service.dart';
import '../checkup/checkup_history_screen.dart';
import '../checkup/checkup_widgets.dart';
import '../checkup/vitals_ui.dart';
import '../device/device_sheet.dart';
import '../medications/add_medication_screen.dart';
import '../medications/dose_actions.dart';
import '../shell/main_shell.dart';
import '../visits/visit_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final String _uid = context.read<Session>().uid!;
  // Created once: a new stream per build would resubscribe on every rebuild.
  late final Stream<List<CheckupRecord>> _checkups = context.read<CheckupRepository>().watch(_uid, limit: 30);
  late final Stream<List<Appointment>> _visits = context.read<AppointmentRepository>().watch(_uid);

  ValueChanged<int> get onOpenTab => widget.onOpenTab;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final profile = session.profile;
    final now = DateTime.now();

    return StreamBuilder<List<CheckupRecord>>(
      stream: _checkups,
      builder: (context, snap) {
        final records = snap.data ?? const <CheckupRecord>[];
        final real = records.where((r) => !r.testMode).toList();
        return GlassPage(
          inShell: true,
          title: '${Fmt.greeting(now)}, ${profile?.firstName ?? 'there'}',
          subtitle: DateFormat('EEEE, d MMMM').format(now),
          titleTrailing: JellyPress(
            onTap: () => onOpenTab(3),
            semanticLabel: 'Open profile',
            intensity: 1.2,
            child: InitialsAvatar(name: profile?.name ?? '', size: 46),
          ),
          actions: [
            DeviceConnectionBuilder(
              builder: (context, connected) => LiquidIconButton(
                icon: connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                tooltip: connected ? 'Baymax connected' : 'Connect your Baymax',
                badge: !connected,
                onPressed: () => showDeviceSheet(context),
              ),
            ),
          ],
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.list(
                children: [
                  FadeSlideIn(child: _CheckupHero(last: records.isEmpty ? null : records.first)),
                  const SizedBox(height: Space.xl),
                  FadeSlideIn(delay: FadeSlideIn.stagger(1), child: _VitalsSection(records: real)),
                  const SizedBox(height: Space.xl),
                  FadeSlideIn(delay: FadeSlideIn.stagger(2), child: _TodayMedicines(onOpenTab: onOpenTab)),
                  const SizedBox(height: Space.xl),
                  FadeSlideIn(delay: FadeSlideIn.stagger(3), child: _NextVisit(visits: _visits, onOpenTab: onOpenTab)),
                  const SizedBox(height: Space.xl),
                  FadeSlideIn(delay: FadeSlideIn.stagger(4), child: _RecentCheckups(records: records)),
                  const SizedBox(height: Space.lg),
                  Text(
                    'Baymax gives general guidance and isn’t a medical device. If you feel very unwell, call 112.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheckupHero extends StatelessWidget {
  const _CheckupHero({required this.last});
  final CheckupRecord? last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textOn = context.isDark ? c.onPrimary : Colors.white;
    return SurfaceCard(
      onTap: () => MainShell.startCheckup(context),
      semanticLabel: 'Start a check-up',
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
      borderColor: Colors.transparent,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.primary, Color.lerp(c.primary, c.accent, 0.75)!],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start a check-up', style: context.text.headlineSmall!.copyWith(color: textOn)),
                const SizedBox(height: 6),
                Text(
                  'Measure your vitals, describe how you feel and get guidance in about two minutes.',
                  style: context.text.bodyMedium!.copyWith(color: textOn.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: Space.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: textOn.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 16, color: textOn),
                      const SizedBox(width: 6),
                      Text(
                        last?.time == null ? 'No check-ups yet' : 'Last: ${Fmt.dayTime(last!.time!)}',
                        style: AppTypography.style(13, 640).copyWith(color: textOn),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.xs),
          LiquidOrb(
            size: 104,
            child: Icon(Icons.monitor_heart_rounded, color: Colors.white.withValues(alpha: 0.95), size: 34),
          ),
        ],
      ),
    );
  }
}

class _VitalsSection extends StatelessWidget {
  const _VitalsSection({required this.records});
  final List<CheckupRecord> records;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Your vitals',
          padding: EdgeInsets.zero,
          action: records.isEmpty ? null : 'History',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckupHistoryScreen())),
        ),
        const SizedBox(height: Space.sm),
        if (records.isEmpty)
          SurfaceCard(
            child: Row(
              children: [
                const IconBadge(Icons.insights_rounded),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text('Your readings and trends appear here after your first check-up.', style: context.text.bodyMedium),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              for (final (i, kind) in VitalKind.values.indexed) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(child: _VitalTile(kind: kind, records: records, settings: settings)),
              ],
            ],
          ),
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({required this.kind, required this.records, required this.settings});
  final VitalKind kind;
  final List<CheckupRecord> records;
  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final latest = kind.valueOf(records.first);
    final (status, tone) = kind.status(latest);
    final history = records.take(7).map(kind.valueOf).toList().reversed.toList();
    final display = switch (kind) {
      VitalKind.temperature => settings.formatTemp(latest, unit: false),
      VitalKind.heartRate => latest.round().toString(),
      VitalKind.spo2 => latest.round().toString(),
    };
    final unit = switch (kind) {
      VitalKind.temperature => settings.tempUnitLabel,
      VitalKind.heartRate => 'bpm',
      VitalKind.spo2 => '%',
    };
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.sm),
      radius: Radii.md + 2,
      child: Semantics(
        label: '${kind.label} $display $unit, $status',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kind.icon, size: 16, color: tone.color(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(kind.shortLabel, style: context.text.labelMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: display, style: AppTypography.style(26, 800, tabular: true).copyWith(color: c.textPrimary)),
                  TextSpan(text: ' $unit', style: context.text.labelMedium),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            StatusPill(label: status, tone: tone, dense: true),
            const SizedBox(height: Space.xs),
            Sparkline(values: history, color: tone.color(context), height: 28, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

class _TodayMedicines extends StatelessWidget {
  const _TodayMedicines({required this.onOpenTab});
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final doses = context.watch<Session>().doses;
    if (doses == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: doses,
      builder: (context, _) {
        final now = DateTime.now();
        final slots = doses.todaySlots(now);
        final taken = slots.where((s) => s.taken).length;
        final next = doses.nextDose(now);
        // Check-up medicines have no fixed times; they're taken as needed.
        final asNeeded = doses.activeCourses.where((c) => c.isAssistant).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Today’s medicines', padding: EdgeInsets.zero, action: 'See all', onAction: () => onOpenTab(1)),
            const SizedBox(height: Space.sm),
            if (doses.loading)
              const SurfaceCard(child: Skeleton(height: 64))
            else if (slots.isEmpty && asNeeded.isNotEmpty)
              SurfaceCard(
                onTap: () => onOpenTab(1),
                child: Row(
                  children: [
                    IconBadge(Icons.auto_awesome_rounded, color: context.colors.accent),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From your check-up', style: context.text.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${asNeeded.map((c) => c.name).join(' · ')} — take as needed; Baymax keeps the doses safely spaced.',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.colors.textTertiary),
                  ],
                ),
              )
            else if (slots.isEmpty)
              SurfaceCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMedicationScreen())),
                child: Row(
                  children: [
                    const IconBadge(Icons.add_alarm_rounded),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No doses scheduled today', style: context.text.titleSmall),
                          const SizedBox(height: 2),
                          Text('Add a medicine to get reminders and track doses.', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.colors.textTertiary),
                  ],
                ),
              )
            else
              SurfaceCard(
                child: Row(
                  children: [
                    ProgressRing(
                      progress: slots.isEmpty ? 0 : taken / slots.length,
                      size: 76,
                      stroke: 8,
                      color: taken == slots.length ? context.colors.success : null,
                      child: Text('$taken/${slots.length}', style: AppTypography.style(18, 800, tabular: true)),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: next == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(taken == slots.length ? 'All done for today' : 'Nothing due right now',
                                    style: context.text.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  taken == slots.length ? 'Every dose today is taken. Nicely done.' : 'Check the Medicines tab for missed doses.',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Next: ${next.course.name}', style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  [Fmt.time(next.time), next.course.doseLabel, if (next.course.foodLabel != null) next.course.foodLabel!]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: context.text.bodySmall,
                                ),
                                const SizedBox(height: Space.sm),
                                LiquidButton(
                                  label: next.canTakeAt(now) ? 'Take now' : 'Upcoming',
                                  size: LiquidButtonSize.small,
                                  expand: false,
                                  icon: next.canTakeAt(now) ? Icons.check_rounded : Icons.schedule_rounded,
                                  onPressed: next.canTakeAt(now) ? () => takeDose(context, course: next.course, at: next.time) : null,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            if (slots.isNotEmpty && asNeeded.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs, left: Space.xs),
                child: Text(
                  '+ ${asNeeded.map((c) => c.name).join(', ')} from your check-up, taken as needed',
                  style: context.text.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NextVisit extends StatelessWidget {
  const _NextVisit({required this.visits, required this.onOpenTab});
  final Stream<List<Appointment>> visits;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<List<Appointment>>(
      stream: visits,
      builder: (context, snap) {
        final upcoming = (snap.data ?? const <Appointment>[]).where((a) => a.isUpcoming).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Next visit', padding: EdgeInsets.zero, action: 'Visits', onAction: () => onOpenTab(2)),
            const SizedBox(height: Space.sm),
            if (upcoming.isEmpty)
              SurfaceCard(
                onTap: () => onOpenTab(2),
                child: Row(
                  children: [
                    IconBadge(Icons.local_hospital_rounded, color: c.info),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No visits booked', style: context.text.titleSmall),
                          const SizedBox(height: 2),
                          Text('Find a clinic or hospital near you.', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ],
                ),
              )
            else
              VisitCard(visit: upcoming.first, compact: true),
          ],
        );
      },
    );
  }
}

class _RecentCheckups extends StatelessWidget {
  const _RecentCheckups({required this.records});
  final List<CheckupRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Recent check-ups',
          padding: EdgeInsets.zero,
          action: 'See all',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckupHistoryScreen())),
        ),
        const SizedBox(height: Space.sm),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              for (final (i, r) in records.take(3).indexed) ...[
                if (i > 0) const Divider(indent: Space.md, endIndent: Space.md),
                CheckupRow(record: r),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
