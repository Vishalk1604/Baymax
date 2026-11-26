import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/motion/jelly.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/notification_service.dart';
import 'visit_widgets.dart';

/// Plans a visit to [clinic]: saved in Baymax with a reminder two hours
/// before. Baymax doesn't book with the clinic itself, so the screen says so
/// and offers a call to confirm.
class BookVisitScreen extends StatefulWidget {
  const BookVisitScreen({super.key, required this.clinic});
  final Clinic clinic;

  @override
  State<BookVisitScreen> createState() => _BookVisitScreenState();
}

class _BookVisitScreenState extends State<BookVisitScreen> {
  static const _days = 14;
  static const _reasons = ['General check-up', 'Fever or flu', 'Follow-up', 'Prescription', 'Test results', 'Other'];

  late final Stream<List<Appointment>> _visits =
      context.read<AppointmentRepository>().watch(context.read<Session>().uid!);
  final _notes = TextEditingController();

  late DateTime _day = _firstDay();
  DateTime? _slot;
  String? _reason;
  bool _saving = false;

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Today, unless today's slots are all gone.
  DateTime _firstDay() {
    final today = _today();
    return _slotsFor(today).isEmpty ? today.add(const Duration(days: 1)) : today;
  }

  /// 9:00–17:30 every 30 minutes, skipping 13:00–14:00 and the past.
  List<DateTime> _slotsFor(DateTime day) {
    final now = DateTime.now().add(const Duration(minutes: 30));
    return [
      for (var m = 9 * 60; m <= 17 * 60 + 30; m += 30)
        if (m < 13 * 60 || m >= 14 * 60) DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
    ].where((t) => t.isAfter(now)).toList();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    final slot = _slot;
    final uid = context.read<Session>().uid;
    if (slot == null || uid == null) return;
    final repo = context.read<AppointmentRepository>();
    setState(() => _saving = true);
    try {
      if (await repo.slotTaken(uid, slot)) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _slot = null;
        });
        AppToast.show(context, 'You already have a visit at that time. Pick another.', kind: ToastKind.warning);
        return;
      }
      await repo.book(uid, clinic: widget.clinic, time: slot, reason: _reason, notes: _notes.text);
      await NotificationService().sync();
      if (!mounted) return;
      AppToast.show(context, 'Visit planned for ${Fmt.day(slot)} at ${Fmt.time(slot)}', kind: ToastKind.success);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, "Couldn't save the visit. Try again.", kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinic = widget.clinic;
    final c = context.colors;
    final slot = _slot;
    return StreamBuilder<List<Appointment>>(
      stream: _visits,
      builder: (context, snap) {
        final booked = {for (final a in snap.data ?? const <Appointment>[]) a.time.millisecondsSinceEpoch};
        final slots = _slotsFor(_day);
        return GlassPage(
          title: 'Plan a visit',
          subtitle: clinic.name,
          showBack: true,
          bottom: LiquidButton(
            label: slot == null ? 'Pick a time' : 'Save · ${Fmt.shortDate(slot)}, ${Fmt.time(slot)}',
            icon: Icons.event_available_rounded,
            loading: _saving,
            onPressed: slot == null ? null : _book,
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverToBoxAdapter(
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconBadge(clinic.kind == ClinicKind.hospital ? Icons.local_hospital_rounded : Icons.medical_services_rounded),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(clinic.name, style: context.text.titleMedium),
                                Text('${clinic.kind.label} · ${clinic.distanceLabel} away', style: context.text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if ((clinic.address ?? '').isNotEmpty || (clinic.openingHours ?? '').isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        if ((clinic.address ?? '').isNotEmpty) Text(clinic.address!, style: context.text.bodySmall),
                        if ((clinic.openingHours ?? '').isNotEmpty)
                          Text('Hours: ${clinic.openingHours}', style: context.text.bodySmall),
                      ],
                      const SizedBox(height: Space.sm),
                      InfoBanner(
                        message: 'Baymax saves the visit and reminds you two hours before. '
                            'It doesn’t book with the clinic, so call them to confirm.',
                        action: (clinic.phone ?? '').isEmpty
                            ? null
                            : TextButton(onPressed: () => callNumber(clinic.phone!), child: const Text('Call')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverToBoxAdapter(child: Text('Day', style: context.text.titleMedium)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.sm)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  itemCount: _days,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                  itemBuilder: (context, i) {
                    final d = _today().add(Duration(days: i));
                    final available = _slotsFor(d).isNotEmpty;
                    return _DayChip(
                      day: d,
                      selected: d == _day,
                      enabled: available,
                      onTap: () => setState(() {
                        _day = d;
                        if (_slot != null && !_isSameDay(_slot!, d)) _slot = null;
                      }),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.list(
                children: [
                  Text('Time', style: context.text.titleMedium),
                  const SizedBox(height: Space.sm),
                  if (slots.isEmpty)
                    Text('No times left on this day.', style: context.text.bodyMedium)
                  else
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: Space.xs,
                      crossAxisSpacing: Space.xs,
                      childAspectRatio: 1.75,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final t in slots)
                          _SlotChip(
                            time: t,
                            selected: slot == t,
                            // The slot being saved shows as selected, not as taken.
                            taken: booked.contains(t.millisecondsSinceEpoch) && !(_saving && slot == t),
                            onTap: () => setState(() => _slot = t),
                          ),
                      ],
                    ),
                  const SizedBox(height: Space.xl),
                  Text('Reason', style: context.text.titleMedium),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final r in _reasons)
                        SelectChip(label: r, selected: _reason == r, onChanged: (on) => setState(() => _reason = on ? r : null)),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  AppTextField(
                    label: 'Notes (optional)',
                    hint: 'Anything to remember for the visit',
                    controller: _notes,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    'Times are a guide; check the clinic’s hours.',
                    style: context.text.bodySmall!.copyWith(color: c.textTertiary),
                  ),
                  const SizedBox(height: Space.lg),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.enabled, required this.onTap});
  final DateTime day;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimary : (enabled ? c.textPrimary : c.textTertiary);
    final label = Fmt.day(day);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$label, ${DateFormat('d MMMM').format(day)}${enabled ? '' : ', no times left'}',
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: JellyPress(
        enabled: enabled,
        onTap: onTap,
        intensity: 0.8,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.emphasized,
          width: 62,
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? c.primary : c.outline),
            boxShadow: selected ? [BoxShadow(color: c.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat('EEE').format(day).toUpperCase(), style: context.text.labelSmall!.copyWith(color: fg.withValues(alpha: 0.8))),
              const SizedBox(height: 2),
              Text('${day.day}', style: AppTypography.style(22, 800, tabular: true).copyWith(color: fg)),
              Text(DateFormat('MMM').format(day), style: context.text.labelSmall!.copyWith(color: fg.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.time, required this.selected, required this.taken, required this.onTap});
  final DateTime time;
  final bool selected;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = DateFormat.jm().format(time);
    final fg = selected ? c.onPrimary : (taken ? c.textTertiary : c.textPrimary);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !taken,
      label: '$label${taken ? ', you have a visit then' : ''}',
      onTap: taken ? null : onTap,
      excludeSemantics: true,
      child: JellyPress(
        enabled: !taken,
        onTap: onTap,
        intensity: 0.7,
        child: AnimatedContainer(
          duration: Motion.fast,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primary : (taken ? c.surfaceMuted : c.surface),
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: selected ? c.primary : c.outline),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: AppTypography.style(14, selected ? 760 : 620, tabular: true).copyWith(
                  color: fg,
                  decoration: taken ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
