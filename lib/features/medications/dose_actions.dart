import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../baymax/models/baymax_models.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/liquid_button.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/health_device_service.dart';
import '../../services/notification_service.dart';

enum _DeviceChoice { connect, manual }

/// Dispenses the dose when the medicine is stocked in the Baymax, then records
/// it. Returns true once the dose is recorded; nothing is recorded if
/// dispensing fails.
Future<bool> takeDose(BuildContext context, {required MedicationCourse course, required DateTime at}) async {
  final uid = context.read<Session>().uid;
  final repo = context.read<MedicationRepository>();
  if (uid == null) return false;
  final device = HealthDeviceService();
  final compartment = course.deviceCompartment;

  if (compartment > 0) {
    if (!device.isConnected) {
      final choice = await showGlassDialog<_DeviceChoice>(
        context,
        builder: (ctx) => GlassDialog(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'Baymax isn’t connected',
          message: 'Connect to dispense ${course.name} from compartment $compartment, or record that you took it yourself.',
          actions: [
            LiquidButton(
              label: 'Connect & dispense',
              icon: Icons.bluetooth_searching_rounded,
              size: LiquidButtonSize.medium,
              onPressed: () => Navigator.of(ctx).pop(_DeviceChoice.connect),
            ),
            LiquidButton(
              label: 'I took it myself',
              variant: LiquidButtonVariant.secondary,
              size: LiquidButtonSize.medium,
              onPressed: () => Navigator.of(ctx).pop(_DeviceChoice.manual),
            ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ],
        ),
      );
      if (choice == null || !context.mounted) return false;
      if (choice == _DeviceChoice.connect) {
        final ok = await device.connectToBAYMAX();
        if (!ok) {
          if (context.mounted) {
            AppToast.show(context, "Couldn't connect to Baymax. Nothing was recorded.", kind: ToastKind.error);
          }
          return false;
        }
      }
    }
    if (device.isConnected) {
      final sent = await device.sendMedicationSignal(compartment);
      if (!sent) {
        if (context.mounted) {
          AppToast.show(context, "Couldn't reach Baymax. Nothing was recorded.", kind: ToastKind.error);
        }
        return false;
      }
    }
  }

  try {
    await repo.recordDose(uid, course.id, at);
  } catch (_) {
    if (context.mounted) AppToast.show(context, "Couldn't save the dose. Try again.", kind: ToastKind.error);
    return false;
  }
  HapticFeedback.mediumImpact();
  if (context.mounted) AppToast.show(context, '${course.name} marked as taken', kind: ToastKind.success);
  return true;
}

/// Whether an assistant-recommended medicine can be taken now, from the
/// engine's dosing table: minimum spacing and a daily maximum.
class DoseLock {
  const DoseLock({required this.canTake, this.reason});
  final bool canTake;
  final String? reason;

  static DoseLock forCourse(MedicationCourse course, List<DateTime> takenWithin24h, DateTime now) {
    final dosing = (course.engineMedication ?? Medication.none).standardAdultDosing;
    final interval = Duration(hours: dosing.minIntervalHours > 0 ? dosing.minIntervalHours : 24);
    if (takenWithin24h.isNotEmpty) {
      final next = takenWithin24h.first.add(interval);
      if (now.isBefore(next)) return DoseLock(canTake: false, reason: 'Next dose in ${Fmt.duration(next.difference(now))}');
    }
    final max = dosing.maxDosesPerDay;
    if (max > 0 && takenWithin24h.length >= max) {
      final frees = takenWithin24h[max - 1].add(const Duration(hours: 24));
      return DoseLock(canTake: false, reason: 'Daily limit reached · ${Fmt.duration(frees.difference(now))}');
    }
    return const DoseLock(canTake: true);
  }
}

/// Asks, then stops a course and rebuilds reminders. Returns true if stopped.
Future<bool> stopCourse(BuildContext context, MedicationCourse course) async {
  final ok = await confirmAction(
    context,
    title: 'Stop ${course.name}?',
    message: 'Its reminders stop and it moves to your finished medicines. You can add it again any time.',
    confirmLabel: 'Stop',
    destructive: true,
    icon: Icons.stop_circle_outlined,
  );
  if (!ok || !context.mounted) return false;
  final uid = context.read<Session>().uid;
  if (uid == null) return false;
  try {
    await context.read<MedicationRepository>().stop(uid, course.id);
  } catch (_) {
    if (context.mounted) AppToast.show(context, "Couldn't stop it. Try again.", kind: ToastKind.error);
    return false;
  }
  await NotificationService().sync();
  if (context.mounted) AppToast.show(context, 'Stopped ${course.name}', kind: ToastKind.success);
  return true;
}

/// "Morning", "Afternoon"… for grouping a day's doses.
String partOfDay(DateTime t) => switch (t.hour) {
      < 5 => 'Early hours',
      < 12 => 'Morning',
      < 17 => 'Afternoon',
      < 21 => 'Evening',
      _ => 'Night',
    };
