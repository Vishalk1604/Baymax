import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/notification_service.dart';

/// Opens turn-by-turn directions in the maps app.
Future<void> openDirections(double lat, double lng) => launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );

/// Dials the first number of an OSM-style phone field ("+91 80 …; +91 …").
Future<void> callNumber(String phone) {
  final first = phone.split(RegExp(r'[;,]')).first.replaceAll(RegExp(r'[^0-9+]'), '');
  return launchUrl(Uri(scheme: 'tel', path: first));
}

Future<void> cancelVisit(BuildContext context, Appointment visit) async {
  final ok = await confirmAction(
    context,
    title: 'Cancel this visit?',
    message: '${visit.clinicName}, ${Fmt.dayTime(visit.time)}. Its reminder is removed too. '
        'If you booked with the clinic, let them know.',
    confirmLabel: 'Cancel visit',
    cancelLabel: 'Keep it',
    destructive: true,
    icon: Icons.event_busy_rounded,
  );
  if (!ok || !context.mounted) return;
  final uid = context.read<Session>().uid;
  if (uid == null) return;
  try {
    await context.read<AppointmentRepository>().cancel(uid, visit.id);
    await NotificationService().sync();
    if (context.mounted) AppToast.show(context, 'Visit cancelled', kind: ToastKind.success);
  } catch (_) {
    if (context.mounted) AppToast.show(context, "Couldn't cancel. Try again.", kind: ToastKind.error);
  }
}

/// Calendar-style date block: "NOV / 25".
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.date, this.muted = false});
  final DateTime date;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = muted ? c.textTertiary : c.info;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: muted ? c.surfaceMuted : c.infoSoft,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        children: [
          Text(DateFormat('MMM').format(date).toUpperCase(), style: context.text.labelSmall!.copyWith(color: accent)),
          Text(
            '${date.day}',
            style: AppTypography.style(22, 800, tabular: true).copyWith(color: muted ? c.textSecondary : c.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// An upcoming visit. [compact] shows just the summary row (Home).
class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.visit, this.compact = false});
  final Appointment visit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = visit;
    final hasPlace = v.latitude != null && v.longitude != null;
    final until = v.time.difference(DateTime.now());
    final soon = until.inHours < 24 && !until.isNegative;

    final summary = Row(
      children: [
        DateBlock(date: v.time),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.clinicName, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(Fmt.dayTime(v.time), style: context.text.bodySmall),
              if (soon) ...[
                const SizedBox(height: 4),
                StatusPill(label: 'In ${Fmt.duration(until)}', tone: Tone.info, icon: Icons.schedule_rounded, dense: true),
              ],
            ],
          ),
        ),
        if (compact && hasPlace)
          IconButton(
            tooltip: 'Directions',
            icon: Icon(Icons.directions_rounded, color: c.primary),
            onPressed: () => openDirections(v.latitude!, v.longitude!),
          ),
      ],
    );
    if (compact) return SurfaceCard(child: summary);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary,
          if ((v.reason ?? '').isNotEmpty || (v.address ?? '').isNotEmpty || (v.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            if ((v.reason ?? '').isNotEmpty)
              Align(alignment: Alignment.centerLeft, child: StatusPill(label: v.reason!, tone: Tone.primary, dense: true)),
            if ((v.address ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 16, color: c.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(v.address!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            if ((v.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('“${v.notes!}”', style: context.text.bodySmall!.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
          const SizedBox(height: Space.xs),
          const Divider(),
          Row(
            children: [
              if (hasPlace)
                TextButton.icon(
                  onPressed: () => openDirections(v.latitude!, v.longitude!),
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: const Text('Directions'),
                ),
              if ((v.phone ?? '').isNotEmpty)
                TextButton.icon(
                  onPressed: () => callNumber(v.phone!),
                  icon: const Icon(Icons.call_rounded, size: 20),
                  label: const Text('Call'),
                ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: c.danger),
                onPressed: () => cancelVisit(context, v),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
