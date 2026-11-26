import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../core/motion/fade_slide_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/location_service.dart';
import 'book_visit_screen.dart';
import 'visit_widgets.dart';

enum _SearchState { idle, locating, searching, done, failed }

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  late final Stream<List<Appointment>> _visits =
      context.read<AppointmentRepository>().watch(context.read<Session>().uid!);

  static const _radii = [2.0, 5.0, 10.0];
  static const _kindOptions = [ClinicKind.hospital, ClinicKind.clinic, ClinicKind.doctors, ClinicKind.dentist, ClinicKind.pharmacy];

  double _radius = 5;
  Set<ClinicKind> _kinds = {ClinicKind.hospital, ClinicKind.clinic, ClinicKind.doctors};
  _SearchState _state = _SearchState.idle;
  List<Clinic> _clinics = const [];
  String? _error;
  LocationException? _locationError;
  ({double lat, double lng})? _position;
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    // Search straight away only if that won't prompt for anything.
    LocationService.isReady().then((ready) {
      if (ready && mounted && _state == _SearchState.idle) _search();
    });
  }

  Future<void> _search({bool relocate = false}) async {
    final id = ++_searchId;
    setState(() {
      _error = null;
      _locationError = null;
      _state = _position == null || relocate ? _SearchState.locating : _SearchState.searching;
    });
    try {
      if (_position == null || relocate) {
        final p = await LocationService.current();
        _position = (lat: p.latitude, lng: p.longitude);
        if (!mounted || id != _searchId) return;
        setState(() => _state = _SearchState.searching);
      }
      final pos = _position!;
      final results = await context.read<ClinicRepository>().nearby(
            latitude: pos.lat,
            longitude: pos.lng,
            radiusKm: _radius,
            kinds: _kinds,
          );
      if (!mounted || id != _searchId) return;
      setState(() {
        _clinics = results;
        _state = _SearchState.done;
      });
    } on LocationException catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _locationError = e;
        _error = e.message;
        _state = _SearchState.failed;
      });
    } catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _error = e is ClinicSearchException ? e.message : 'Couldn’t search right now. Check your connection and try again.';
        _state = _SearchState.failed;
      });
    }
  }

  Future<void> _openMaps() {
    final what = _kinds.contains(ClinicKind.hospital) ? 'hospital' : 'clinic';
    return launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$what near me')}'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _setRadius(double r) {
    setState(() => _radius = r);
    if (_state != _SearchState.idle) _search();
  }

  void _toggleKind(ClinicKind k) {
    final next = {..._kinds};
    if (!next.remove(k)) next.add(k);
    if (next.isEmpty) return;
    setState(() => _kinds = next);
    if (_state != _SearchState.idle) _search();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: _visits,
      builder: (context, snap) {
        final all = snap.data ?? const <Appointment>[];
        final now = DateTime.now();
        final upcoming = all.where((a) => a.time.isAfter(now)).toList();
        final past = all.where((a) => !a.time.isAfter(now)).toList().reversed.take(10).toList();
        return GlassPage(
          inShell: true,
          title: 'Visits',
          subtitle: upcoming.isEmpty
              ? 'Find care near you and plan visits.'
              : '${upcoming.length} upcoming visit${upcoming.length == 1 ? '' : 's'}',
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.list(
                children: [
                  if (upcoming.isNotEmpty) ...[
                    for (final (i, v) in upcoming.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: FadeSlideIn(delay: FadeSlideIn.stagger(i), child: VisitCard(visit: v)),
                      ),
                    const SizedBox(height: Space.lg),
                  ],
                  const _EmergencyStrip(),
                  const SizedBox(height: Space.xl),
                  Text('Find care nearby', style: context.text.titleLarge),
                  const SizedBox(height: Space.xs),
                  Text(
                    AppConfig.hasGeoapifyKey
                        ? 'OpenStreetMap data · Powered by Geoapify'
                        : 'Hospitals, clinics and doctors from OpenStreetMap.',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: Space.md),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        for (final k in _kindOptions) ...[
                          SelectChip(
                            label: k.plural,
                            icon: k.icon,
                            selected: _kinds.contains(k),
                            onChanged: (_) => _toggleKind(k),
                          ),
                          const SizedBox(width: Space.xs),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Row(
                    children: [
                      Text('Within', style: context.text.labelLarge),
                      const SizedBox(width: Space.sm),
                      for (final r in _radii) ...[
                        SelectChip(label: '${r.round()} km', selected: _radius == r, onChanged: (_) => _setRadius(r)),
                        const SizedBox(width: Space.xs),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  AnimatedSwitcher(
                    duration: Motion.base,
                    child: KeyedSubtree(key: ValueKey(_state), child: _results(context)),
                  ),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: Space.xl),
                    SectionHeader('Past visits', padding: const EdgeInsets.only(bottom: Space.xs)),
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: Column(
                        children: [
                          for (final (i, v) in past.indexed) ...[
                            if (i > 0) const Divider(indent: Space.md, endIndent: Space.md),
                            ListRow(
                              icon: Icons.history_rounded,
                              iconColor: context.colors.textTertiary,
                              title: v.clinicName,
                              subtitle: [Fmt.dayTime(v.time), if ((v.reason ?? '').isNotEmpty) v.reason!].join(' · '),
                              showChevron: false,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _results(BuildContext context) {
    switch (_state) {
      case _SearchState.idle:
        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.near_me_rounded),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Baymax uses your location only for this search. It isn’t saved.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              LiquidButton(label: 'Search near me', icon: Icons.my_location_rounded, size: LiquidButtonSize.medium, onPressed: _search),
            ],
          ),
        );
      case _SearchState.locating:
      case _SearchState.searching:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: Space.xs),
                Text(_state == _SearchState.locating ? 'Finding your location…' : 'Searching nearby…', style: context.text.bodySmall),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (var i = 0; i < 3; i++) ...[
              const SurfaceCard(
                child: Row(
                  children: [
                    Skeleton(width: 44, height: 44, radius: 14),
                    SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Skeleton(width: 170, height: 14), SizedBox(height: 8), Skeleton(width: 110, height: 12)],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        );
      case _SearchState.failed:
        final loc = _locationError;
        return InfoBanner(
          tone: Tone.warning,
          icon: loc != null ? Icons.location_off_rounded : Icons.cloud_off_rounded,
          title: loc != null ? 'Location needed' : 'Search didn’t work',
          message: _error ?? 'Something went wrong.',
          action: loc != null && loc.needsSettings
              ? TextButton(onPressed: () => LocationService.openSettings(loc), child: const Text('Open settings'))
              : Wrap(
                  spacing: Space.xs,
                  children: [
                    TextButton(onPressed: () => _search(relocate: loc != null), child: const Text('Try again')),
                    // The maps app finds care with its own location access.
                    TextButton(onPressed: _openMaps, child: const Text('Open Maps')),
                  ],
                ),
        );
      case _SearchState.done:
        if (_clinics.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nothing found within ${_radius.round()} km',
            message: 'Try a wider area or include more kinds of places.',
            actionLabel: _radius < _radii.last ? 'Search ${_radii.last.round()} km' : 'Search again',
            onAction: () => _radius < _radii.last ? _setRadius(_radii.last) : _search(relocate: true),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${_clinics.length} places, nearest first', style: context.text.labelMedium)),
                TextButton.icon(
                  onPressed: () => _search(relocate: true),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            for (final (i, clinic) in _clinics.take(40).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: i < 8 ? FadeSlideIn(delay: FadeSlideIn.stagger(i), child: _ClinicCard(clinic: clinic)) : _ClinicCard(clinic: clinic),
              ),
          ],
        );
    }
  }
}

extension on ClinicKind {
  String get plural => switch (this) {
        ClinicKind.hospital => 'Hospitals',
        ClinicKind.clinic => 'Clinics',
        ClinicKind.doctors => 'Doctors',
        ClinicKind.dentist => 'Dentists',
        ClinicKind.pharmacy => 'Pharmacies',
      };

  IconData get icon => switch (this) {
        ClinicKind.hospital => Icons.local_hospital_rounded,
        ClinicKind.clinic => Icons.medical_services_rounded,
        ClinicKind.doctors => Icons.person_search_rounded,
        ClinicKind.dentist => Icons.sentiment_satisfied_alt_rounded,
        ClinicKind.pharmacy => Icons.local_pharmacy_rounded,
      };
}

class _EmergencyStrip extends StatelessWidget {
  const _EmergencyStrip();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SurfaceCard(
      color: c.dangerSoft,
      borderColor: c.danger.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
      child: Row(
        children: [
          Icon(Icons.emergency_rounded, color: c.danger),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text('In an emergency, call 112 right away.', style: context.text.titleSmall!.copyWith(color: c.textPrimary)),
          ),
          LiquidButton(
            label: 'Call 112',
            icon: Icons.call_rounded,
            variant: LiquidButtonVariant.danger,
            size: LiquidButtonSize.small,
            expand: false,
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
          ),
        ],
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.clinic});
  final Clinic clinic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = clinic.kind;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.sm, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(k.icon, color: k == ClinicKind.hospital ? c.danger : c.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clinic.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${k.label} · ${clinic.distanceLabel} away', style: context.text.bodySmall),
                    if ((clinic.address ?? '').isNotEmpty)
                      Text(clinic.address!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (clinic.emergency || (clinic.openingHours ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (clinic.emergency)
                            const StatusPill(label: 'Emergency care', tone: Tone.danger, icon: Icons.emergency_rounded, dense: true),
                          if ((clinic.openingHours ?? '').isNotEmpty)
                            StatusPill(
                              label: clinic.openingHours == '24/7' ? 'Open 24/7' : clinic.openingHours!,
                              icon: Icons.schedule_rounded,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              IconButton(
                tooltip: 'Directions',
                icon: Icon(Icons.directions_rounded, color: c.primary),
                onPressed: () => openDirections(clinic.latitude, clinic.longitude),
              ),
              if ((clinic.phone ?? '').isNotEmpty)
                IconButton(
                  tooltip: 'Call',
                  icon: Icon(Icons.call_rounded, color: c.primary),
                  onPressed: () => callNumber(clinic.phone!),
                ),
              const Spacer(),
              if (k != ClinicKind.pharmacy)
                LiquidButton(
                  label: 'Plan a visit',
                  icon: Icons.event_available_rounded,
                  size: LiquidButtonSize.small,
                  expand: false,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookVisitScreen(clinic: clinic))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
