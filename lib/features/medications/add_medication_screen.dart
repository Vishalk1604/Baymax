import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../baymax/models/baymax_models.dart';
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
import '../../services/medication_utils.dart';
import '../../services/notification_service.dart';
import '../profile/profile_form.dart';
import 'dose_actions.dart';

/// Adds a medicine, or edits one when [course] is given.
class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key, this.course});
  final MedicationCourse? course;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

enum _Length { day, week, month, ongoing, custom }

extension on _Length {
  String get label => switch (this) {
        _Length.day => 'Today only',
        _Length.week => '1 week',
        _Length.month => '1 month',
        _Length.ongoing => 'Ongoing',
        _Length.custom => 'Custom',
      };

  int? get days => switch (this) {
        _Length.day => 1,
        _Length.week => 7,
        _Length.month => 30,
        _Length.ongoing => 0,
        _Length.custom => null,
      };
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _form = GlobalKey<FormState>();
  late final MedicationCourse? _course = widget.course;
  bool get _editing => _course != null;

  late final _name = TextEditingController(text: _course?.name ?? '');
  late final _amount = TextEditingController(text: (_course?.dosage ?? 0) > 0 ? '${_course!.dosage}' : '');
  final _customDays = TextEditingController();

  String _unit = 'mg';
  String _food = FoodRelation.after;
  _Length _length = _Length.week;
  final List<TimeOfDay> _times = [];
  int _compartment = 0;
  Set<int> _occupied = const {};

  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  String? _timesError;

  @override
  void initState() {
    super.initState();
    final c = _course;
    if (c != null) {
      _unit = DoseUnits.all.contains(c.unit) ? c.unit! : 'mg';
      _food = FoodRelation.options.contains(c.foodRelation) ? c.foodRelation! : FoodRelation.after;
      final match = _Length.values.where((l) => l.days == c.durationDays && l != _Length.custom);
      if (match.isNotEmpty) {
        _length = match.first;
      } else {
        _length = _Length.custom;
        _customDays.text = c.durationDays > 0 ? '${c.durationDays}' : '';
      }
      _compartment = userCompartments.contains(c.deviceCompartment) ? c.deviceCompartment : 0;
      _loading = true;
    } else {
      _times.add(const TimeOfDay(hour: 9, minute: 0));
    }
    _load();
    for (final t in [_name, _amount, _customDays]) {
      t.addListener(_markDirty);
    }
  }

  Future<void> _load() async {
    final uid = context.read<Session>().uid;
    if (uid == null) return;
    final repo = context.read<MedicationRepository>();
    try {
      final occupied = await repo.occupiedCompartments(uid, exceptId: _course?.id);
      final times = _course == null ? null : await repo.reminders(uid, _course.id);
      if (!mounted) return;
      setState(() {
        _occupied = occupied;
        if (times != null) {
          _times
            ..clear()
            ..addAll(times);
        }
        if (_occupied.contains(_compartment)) _compartment = 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _set(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _customDays.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _setTimes(List<TimeOfDay> times) => _set(() {
        _times
          ..clear()
          ..addAll(times);
        _timesError = null;
      });

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isEmpty ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: (_times.last.hour + 4) % 24, minute: 0),
      helpText: 'Reminder time',
    );
    if (picked == null) return;
    if (_times.any((t) => _minutes(t) == _minutes(picked))) {
      if (mounted) AppToast.show(context, 'That time is already on the list');
      return;
    }
    _set(() {
      _times
        ..add(picked)
        ..sort((a, b) => _minutes(a).compareTo(_minutes(b)));
      _timesError = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final valid = _form.currentState!.validate();
    if (_times.isEmpty) setState(() => _timesError = 'Add at least one reminder time.');
    if (!valid || _times.isEmpty) {
      HapticFeedback.mediumImpact();
      return;
    }
    final uid = context.read<Session>().uid;
    if (uid == null) return;
    final repo = context.read<MedicationRepository>();
    setState(() => _saving = true);
    try {
      // Someone may have filled the slot since this screen opened.
      if (_compartment > 0) {
        final occupied = await repo.occupiedCompartments(uid, exceptId: _course?.id);
        if (occupied.contains(_compartment)) {
          if (!mounted) return;
          setState(() {
            _occupied = occupied;
            _compartment = 0;
            _saving = false;
          });
          AppToast.show(context, 'That compartment is now in use. Pick another.', kind: ToastKind.warning);
          return;
        }
      }
      final days = _length.days ?? int.parse(_customDays.text.trim());
      final amount = int.parse(_amount.text.trim());
      final c = _course;
      if (c == null) {
        await repo.add(uid,
            name: _name.text,
            dosage: amount,
            unit: _unit,
            foodRelation: _food,
            durationDays: days,
            compartment: _compartment,
            times: _times);
      } else {
        await repo.update(uid, c.id,
            name: _name.text,
            dosage: amount,
            unit: _unit,
            foodRelation: _food,
            durationDays: days,
            compartment: _compartment,
            times: _times);
      }
      await NotificationService().sync();
      if (!mounted) return;
      AppToast.show(context, c == null ? '${_name.text.trim()} added' : 'Changes saved', kind: ToastKind.success);
      _dirty = false;
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
      message: _editing ? 'Your edits to this medicine won’t be saved.' : 'This medicine won’t be added.',
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
    final c = context.colors;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: GlassPage(
        title: _editing ? 'Edit medicine' : 'Add medicine',
        subtitle: _editing ? null : 'Reminders, doses and your Baymax.',
        showBack: true,
        bottom: LiquidButton(
          label: _editing ? 'Save changes' : 'Add medicine',
          icon: _editing ? Icons.check_rounded : Icons.add_rounded,
          loading: _saving,
          onPressed: _loading ? null : _save,
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Medicine name',
                      hint: 'e.g. Metformin',
                      icon: Icons.medication_rounded,
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Enter the medicine’s name.';
                        if (t.length > 60) return 'Keep the name under 60 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: Space.lg),
                    const FieldLabel('Dose'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 128,
                          child: AppTextField(
                            label: 'Amount',
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter an amount';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final u in DoseUnits.all)
                                SelectChip(
                                  label: DoseUnits.label(u),
                                  selected: _unit == u,
                                  onChanged: (_) => _set(() => _unit = u),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    FieldLabel('Reminders', hint: _timesError == null ? 'Baymax reminds you at these times every day.' : null),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        for (final (label, times) in const [
                          ('Once a day', [TimeOfDay(hour: 9, minute: 0)]),
                          ('Twice', [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 21, minute: 0)]),
                          ('3 times', [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 14, minute: 0), TimeOfDay(hour: 20, minute: 0)]),
                        ])
                          SelectChip(
                            label: label,
                            icon: Icons.bolt_rounded,
                            selected: _times.length == times.length &&
                                [for (var i = 0; i < times.length; i++) _minutes(times[i]) == _minutes(_times[i])].every((x) => x),
                            onChanged: (_) => _setTimes(times),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Space.sm),
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    else
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          for (final t in _times)
                            _TimeChip(
                              time: t,
                              onRemove: () => _set(() => _times.remove(t)),
                            ),
                          _AddTimeChip(onTap: _addTime),
                        ],
                      ),
                    if (_timesError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Text(_timesError!, style: context.text.bodySmall!.copyWith(color: c.danger)),
                      ),
                    const SizedBox(height: Space.xl),
                    FieldLabel(
                      'How long',
                      hint: _editing && _course!.createdAt != null
                          ? 'Counted from ${Fmt.shortDate(_course.createdAt!)}, when you added it.'
                          : null,
                    ),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        for (final l in _Length.values)
                          SelectChip(label: l.label, selected: _length == l, onChanged: (_) => _set(() => _length = l)),
                      ],
                    ),
                    AnimatedSize(
                      duration: Motion.base,
                      curve: Motion.emphasized,
                      alignment: Alignment.topCenter,
                      child: _length != _Length.custom
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: Space.sm),
                              child: AppTextField(
                                label: 'Number of days',
                                controller: _customDays,
                                suffixText: 'days',
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                                validator: (v) {
                                  if (_length != _Length.custom) return null;
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n < 1 || n > 365) return 'Enter 1 to 365 days.';
                                  return null;
                                },
                              ),
                            ),
                    ),
                    const SizedBox(height: Space.xl),
                    const FieldLabel('With food?'),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        for (final f in FoodRelation.options)
                          SelectChip(label: FoodRelation.label(f)!, selected: _food == f, onChanged: (_) => _set(() => _food = f)),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    const FieldLabel('Dispense from your Baymax', hint: 'Load it into a free compartment and Baymax dispenses each dose.'),
                    _CompartmentPicker(
                      selected: _compartment,
                      occupied: _occupied,
                      onChanged: (v) => _set(() => _compartment = v),
                    ),
                    if (_editing) ...[
                      const SizedBox(height: Space.xxl),
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: c.danger),
                          onPressed: () async {
                            if (await stopCourse(context, _course!) && context.mounted) {
                              _dirty = false;
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop taking this medicine'),
                        ),
                      ),
                    ],
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onRemove});
  final TimeOfDay time;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = Fmt.time(DateTime(2000, 1, 1, time.hour, time.minute));
    return Semantics(
      button: true,
      label: 'Reminder at $label. Double tap to remove.',
      onTap: onRemove,
      excludeSemantics: true,
      child: JellyPress(
        onTap: onRemove,
        intensity: 0.8,
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_rounded, size: 18, color: c.onPrimarySoft),
              const SizedBox(width: 6),
              Text(label, style: AppTypography.style(15, 700, tabular: true).copyWith(color: c.onPrimarySoft)),
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 18, color: c.onPrimarySoft.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTimeChip extends StatelessWidget {
  const _AddTimeChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return JellyPress(
      onTap: onTap,
      semanticLabel: 'Add a reminder time',
      intensity: 0.8,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.outlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: c.primary),
            const SizedBox(width: 4),
            Text('Add time', style: context.text.labelLarge!.copyWith(color: c.primary)),
          ],
        ),
      ),
    );
  }
}

/// The Baymax's six compartments: 1–4 hold the medicines Baymax recommends,
/// 5 and 6 are free for the person's own.
class _CompartmentPicker extends StatelessWidget {
  const _CompartmentPicker({required this.selected, required this.occupied, required this.onChanged});
  final int selected;
  final Set<int> occupied;
  final ValueChanged<int> onChanged;

  static String _reservedFor(int n) =>
      Medication.values.firstWhere((m) => m.deviceCompartment == n, orElse: () => Medication.none).simpleName.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget cell(int n) {
      final reserved = !userCompartments.contains(n);
      final inUse = !reserved && occupied.contains(n);
      final isSelected = selected == n;
      final enabled = !reserved && !inUse;
      final caption = reserved ? _reservedFor(n) : inUse ? 'In use' : isSelected ? 'Selected' : 'Free';
      return Expanded(
        child: Semantics(
          button: enabled,
          selected: isSelected,
          enabled: enabled,
          label: 'Compartment $n, $caption',
          onTap: enabled ? () => onChanged(isSelected ? 0 : n) : null,
          excludeSemantics: true,
          child: JellyPress(
            enabled: enabled,
            onTap: () => onChanged(isSelected ? 0 : n),
            intensity: 0.7,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.emphasized,
              height: 72,
              decoration: BoxDecoration(
                color: isSelected ? c.primary : (enabled ? c.surface : c.surfaceMuted),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: isSelected ? c.primary : c.outline, width: isSelected ? 2 : 1),
                boxShadow: isSelected
                    ? [BoxShadow(color: c.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$n',
                        style: AppTypography.style(20, 800, tabular: true)
                            .copyWith(color: isSelected ? c.onPrimary : (enabled ? c.textPrimary : c.textTertiary)),
                      ),
                      if (reserved) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.lock_rounded, size: 14, color: c.textTertiary),
                      ],
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded, size: 16, color: c.onPrimary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: context.text.labelSmall!.copyWith(color: isSelected ? c.onPrimary : c.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [cell(1), const SizedBox(width: Space.xs), cell(2), const SizedBox(width: Space.xs), cell(3)]),
        const SizedBox(height: Space.xs),
        Row(children: [cell(4), const SizedBox(width: Space.xs), cell(5), const SizedBox(width: Space.xs), cell(6)]),
        const SizedBox(height: Space.sm),
        SelectChip(
          label: 'Not in the device',
          icon: Icons.do_not_disturb_on_outlined,
          selected: selected == 0,
          onChanged: (_) => onChanged(0),
        ),
      ],
    );
  }
}
