import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/motion/fade_slide_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_nav_bar.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../checkup/vitals_ui.dart';
import '../device/device_sheet.dart';
import 'add_medication_screen.dart';
import 'dose_actions.dart';

enum _View { today, all }

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  _View _view = _View.today;

  void _add() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMedicationScreen()));

  @override
  Widget build(BuildContext context) {
    final doses = context.watch<Session>().doses;
    if (doses == null) {
      return const GlassPage(inShell: true, title: 'Medicines', slivers: []);
    }
    return ListenableBuilder(
      listenable: doses,
      builder: (context, _) {
        final now = DateTime.now();
        final slots = doses.todaySlots(now);
        final taken = slots.where((s) => s.taken).length;
        final active = doses.activeCourses;
        final subtitle = doses.loading
            ? 'Loading…'
            : slots.isEmpty
            ? (active.isEmpty
                  ? 'Reminders, doses and your Baymax.'
                  : '${active.length} active · nothing scheduled today')
            : '$taken of ${slots.length} dose${slots.length == 1 ? '' : 's'} taken today';
        return GlassPage(
          inShell: true,
          title: 'Medicines',
          subtitle: subtitle,
          actions: [
            LiquidIconButton(icon: Icons.add_rounded, tooltip: 'Add a medicine', primary: true, onPressed: _add),
          ],
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
              sliver: SliverToBoxAdapter(
                child: GlassSegmented<_View>(
                  values: _View.values,
                  labels: const ['Today', 'All medicines'],
                  selected: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  layoutBuilder: (current, previous) =>
                      Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                  child: KeyedSubtree(
                    key: ValueKey(_view),
                    child: doses.loading
                        ? const Column(
                            children: [
                              SurfaceCard(child: Skeleton(height: 76)),
                              SizedBox(height: Space.md),
                              SurfaceCard(child: Skeleton(height: 140)),
                            ],
                          )
                        : doses.error != null
                        ? const EmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'Couldn’t load your medicines',
                            message: 'Check your connection and try again.',
                          )
                        : _view == _View.today
                        ? _TodayView(doses: doses, slots: slots, now: now, onAdd: _add)
                        : _AllView(doses: doses, onAdd: _add),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────── Today ──

class _TodayView extends StatelessWidget {
  const _TodayView({required this.doses, required this.slots, required this.now, required this.onAdd});
  final DoseSchedule doses;
  final List<DoseSlot> slots;
  final DateTime now;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final assistant = doses.activeCourses.where((c) => c.isAssistant).toList();
    if (doses.activeCourses.isEmpty) {
      return EmptyState(
        icon: Icons.medication_outlined,
        title: 'No medicines yet',
        message: 'Add a medicine to get reminders, track every dose and dispense from your Baymax.',
        actionLabel: 'Add a medicine',
        onAction: onAdd,
      );
    }

    // Consecutive groups: Morning, Afternoon, Evening…
    final groups = <(String, List<DoseSlot>)>[];
    for (final s in slots) {
      final part = partOfDay(s.time);
      if (groups.isEmpty || groups.last.$1 != part) groups.add((part, []));
      groups.last.$2.add(s);
    }
    final inDevice = doses.activeCourses.any((c) => c.deviceCompartment > 0);
    var i = 0;
    Widget item(Widget w) => FadeSlideIn(delay: FadeSlideIn.stagger(i++), child: w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slots.isNotEmpty) item(_DaySummary(slots: slots, now: now)),
        if (inDevice)
          DeviceConnectionBuilder(
            builder: (context, connected) => connected
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: InfoBanner(
                      icon: Icons.bluetooth_disabled_rounded,
                      message: 'Connect your Baymax to dispense doses from its compartments.',
                      action: TextButton(onPressed: () => showDeviceSheet(context), child: const Text('Connect')),
                    ),
                  ),
          ),
        if (slots.isEmpty && assistant.isEmpty)
          item(
            SurfaceCard(
              child: Row(
                children: [
                  const IconBadge(Icons.event_available_rounded),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nothing scheduled today', style: context.text.titleSmall),
                        Text('Your medicines have no reminder times for today.', style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final (part, list) in groups) ...[
          const SizedBox(height: Space.lg),
          SectionHeader(part, padding: const EdgeInsets.only(bottom: Space.xs)),
          item(
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                children: [
                  for (final (j, s) in list.indexed) ...[
                    if (j > 0) const Divider(indent: 72, endIndent: Space.md),
                    _DoseRow(slot: s, now: now),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (assistant.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          SectionHeader('From your check-ups', padding: const EdgeInsets.only(bottom: Space.xs)),
          for (final c in assistant)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: item(
                _AssistantCourseCard(
                  course: c,
                  taken24h: doses.takenWithin24h(c.id, now: now),
                  now: now,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.slots, required this.now});
  final List<DoseSlot> slots;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final taken = slots.where((s) => s.taken).length;
    final missed = slots.where((s) => s.missedAt(now)).length;
    final next = slots.where((s) => !s.taken && !s.missedAt(now)).firstOrNull;
    final done = taken == slots.length;
    final c = context.colors;
    return SurfaceCard(
      child: Row(
        children: [
          ProgressRing(
            progress: taken / slots.length,
            size: 84,
            stroke: 9,
            color: done ? c.success : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$taken/${slots.length}', style: AppTypography.style(20, 800, tabular: true)),
                Text('taken', style: context.text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? 'All done for today'
                      : next == null
                      ? 'Nothing left to take'
                      : 'Next at ${Fmt.time(next.time)}',
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Every dose is taken. Nicely done.'
                      : next == null
                      ? 'Check the doses marked missed below.'
                      : '${next.course.name} · ${next.course.doseLabel}',
                  style: context.text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (missed > 0) ...[
                  const SizedBox(height: Space.xs),
                  StatusPill(
                    label: '$missed missed',
                    tone: Tone.danger,
                    icon: Icons.error_outline_rounded,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.slot, required this.now});
  final DoseSlot slot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final course = slot.course;
    final canTake = slot.canTakeAt(now);
    final missed = slot.missedAt(now);
    final (Color ring, Color fill, IconData? icon) = slot.taken
        ? (c.success, c.success, Icons.check_rounded)
        : missed
        ? (c.danger, c.dangerSoft, Icons.priority_high_rounded)
        : canTake
        ? (c.primary, c.primarySoft, Icons.notifications_active_rounded)
        : (c.outlineStrong, Colors.transparent, null);

    Widget trailing;
    if (slot.taken) {
      trailing = const StatusPill(label: 'Taken', tone: Tone.success, dense: true);
    } else if (canTake) {
      trailing = LiquidButton(
        label: 'Take',
        icon: Icons.check_rounded,
        size: LiquidButtonSize.small,
        expand: false,
        onPressed: () => takeDose(context, course: course, at: slot.time),
      );
    } else if (missed) {
      trailing = TextButton(
        onPressed: () => takeDose(context, course: course, at: slot.time),
        child: const Text('I took it'),
      );
    } else {
      trailing = StatusPill(label: 'in ${Fmt.duration(slot.time.difference(now))}', dense: true);
    }

    final detail = [
      course.doseLabel,
      if (course.foodLabel != null) course.foodLabel!,
      if (course.deviceCompartment > 0) 'Baymax · slot ${course.deviceCompartment}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Semantics(
      container: true,
      label:
          '${Fmt.time(slot.time)}, ${course.name}, $detail, '
          '${slot.taken
              ? 'taken'
              : missed
              ? 'missed'
              : canTake
              ? 'due now'
              : 'upcoming'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 44,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: Motion.base,
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: fill,
                        shape: BoxShape.circle,
                        border: Border.all(color: ring, width: 2),
                      ),
                      child: icon == null ? null : Icon(icon, size: 17, color: slot.taken ? Colors.white : ring),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.time(slot.time).replaceAll(' ', ' '),
                      style: AppTypography.style(11, 650, tabular: true).copyWith(color: c.textSecondary),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: context.text.titleSmall!.copyWith(
                        decoration: slot.taken ? TextDecoration.lineThrough : null,
                        decorationColor: c.textTertiary,
                        color: slot.taken ? c.textSecondary : c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail.isNotEmpty)
                      Text(detail, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.xs),
            ExcludeSemantics(excluding: !canTake && !missed, child: trailing),
          ],
        ),
      ),
    );
  }
}

/// A course recommended by a check-up: taken as needed within the engine's
/// spacing and daily maximum.
class _AssistantCourseCard extends StatelessWidget {
  const _AssistantCourseCard({required this.course, required this.taken24h, required this.now});
  final MedicationCourse course;
  final List<DateTime> taken24h;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lock = DoseLock.forCourse(course, taken24h, now);
    final dosing = (course.engineMedication ?? Medication.none).standardAdultDosing;
    final max = dosing.maxDosesPerDay;
    final start = course.createdAt;
    final day = start == null ? null : (now.difference(start).inDays + 1).clamp(1, course.durationDays);
    final symptoms = (course.symptoms ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(symptomLabel);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(Icons.auto_awesome_rounded, color: c.accent),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: context.text.titleMedium),
                    Text(
                      [course.doseLabel, dosing.frequency].where((s) => s.isNotEmpty && s != 'N/A').join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Stop this medicine',
                icon: Icon(Icons.stop_circle_outlined, color: c.textSecondary),
                onPressed: () => stopCourse(context, course),
              ),
            ],
          ),
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text('For ${symptoms.join(', ').toLowerCase()}', style: context.text.bodySmall),
          ],
          const SizedBox(height: Space.sm),
          if (day != null && course.durationDays > 0) ...[
            Row(
              children: [
                Text('Day $day of ${course.durationDays}', style: context.text.labelMedium),
                const Spacer(),
                if (max > 0) Text('${taken24h.length} of $max in the last 24 h', style: context.text.labelMedium),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: course.courseProgress ?? 0,
                minHeight: 6,
                backgroundColor: c.surfaceMuted,
              ),
            ),
            const SizedBox(height: Space.md),
          ],
          if (lock.canTake)
            LiquidButton(
              label: course.deviceCompartment > 0 ? 'Dispense a dose' : 'Take a dose',
              icon: Icons.check_rounded,
              size: LiquidButtonSize.medium,
              onPressed: () => takeDose(context, course: course, at: DateTime.now()),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Row(
                children: [
                  Icon(Icons.lock_clock_rounded, size: 18, color: c.textSecondary),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(lock.reason ?? 'Not yet', style: context.text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── All ──

class _AllView extends StatelessWidget {
  const _AllView({required this.doses, required this.onAdd});
  final DoseSchedule doses;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = doses.courses.where((c) => c.isActiveAt(now)).toList();
    final finished = doses.courses.where((c) => !c.isActiveAt(now)).take(20).toList();
    if (doses.courses.isEmpty) {
      return EmptyState(
        icon: Icons.medication_outlined,
        title: 'No medicines yet',
        message: 'Medicines you add, and ones Baymax recommends, appear here.',
        actionLabel: 'Add a medicine',
        onAction: onAdd,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.isEmpty)
          SurfaceCard(
            onTap: onAdd,
            child: Row(
              children: [
                const IconBadge(Icons.add_rounded),
                const SizedBox(width: Space.sm),
                Expanded(child: Text('No active medicines. Add one?', style: context.text.titleSmall)),
              ],
            ),
          ),
        for (final (i, course) in active.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: FadeSlideIn(
              delay: FadeSlideIn.stagger(i),
              child: _CourseCard(course: course, times: doses.timesFor(course.id), now: now),
            ),
          ),
        if (finished.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          SectionHeader('Finished', padding: const EdgeInsets.only(bottom: Space.xs)),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                for (final (i, c) in finished.indexed) ...[
                  if (i > 0) const Divider(indent: Space.md, endIndent: Space.md),
                  ListRow(
                    icon: c.isAssistant ? Icons.auto_awesome_outlined : Icons.medication_outlined,
                    iconColor: context.colors.textTertiary,
                    title: c.name,
                    subtitle: [
                      c.doseLabel,
                      c.isStopped
                          ? 'Stopped'
                          : (c.endsAt != null ? 'Finished ${Fmt.shortDate(c.endsAt!)}' : 'Finished'),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    showChevron: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.times, required this.now});
  final MedicationCourse course;
  final List<TimeOfDay> times;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ends = course.endsAt;
    final progress = course.courseProgress;
    final compartment = course.deviceCompartment;
    return SurfaceCard(
      onTap: course.isAssistant
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddMedicationScreen(course: course))),
      semanticLabel: course.isAssistant ? null : 'Edit ${course.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                course.isAssistant ? Icons.auto_awesome_rounded : Icons.medication_rounded,
                color: course.isAssistant ? c.accent : null,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: context.text.titleMedium),
                    Text(
                      [
                        course.doseLabel,
                        if (course.foodLabel != null) course.foodLabel!,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (course.isAssistant)
                IconButton(
                  tooltip: 'Stop this medicine',
                  icon: Icon(Icons.stop_circle_outlined, color: c.textSecondary),
                  onPressed: () => stopCourse(context, course),
                )
              else
                Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (course.isAssistant)
                const StatusPill(
                  label: 'Recommended by Baymax',
                  icon: Icons.auto_awesome_rounded,
                  tone: Tone.primary,
                  dense: true,
                ),
              for (final t in times)
                StatusPill(
                  label: Fmt.time(DateTime(2000, 1, 1, t.hour, t.minute)),
                  icon: Icons.alarm_rounded,
                  dense: true,
                ),
              if (!course.isAssistant && times.isEmpty)
                const StatusPill(label: 'No reminders', icon: Icons.alarm_off_rounded, dense: true),
              if (compartment > 0)
                StatusPill(label: 'Slot $compartment', icon: Icons.inventory_2_outlined, tone: Tone.info, dense: true),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (ends == null)
            Text('Ongoing', style: context.text.labelMedium)
          else ...[
            Row(
              children: [
                Text('Ends ${Fmt.day(ends, now: now)}', style: context.text.labelMedium),
                const Spacer(),
                Text(_daysLeft(ends.difference(now)), style: context.text.labelMedium),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: progress ?? 0, minHeight: 6, backgroundColor: c.surfaceMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// "3 days left", "1 day left", "Ends today" — rounded up, so a course ending
/// Friday evening still reads 3 days on Tuesday evening.
String _daysLeft(Duration left) {
  final days = (left.inMinutes / (24 * 60)).ceil();
  if (days <= 0) return 'Ends today';
  return days == 1 ? '1 day left' : '$days days left';
}
