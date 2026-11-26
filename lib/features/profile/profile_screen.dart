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
import '../../models/medical_profile.dart';
import '../../services/health_device_service.dart';
import '../../services/notification_service.dart';
import '../../services/pdf_service.dart';
import '../checkup/checkup_history_screen.dart';
import '../device/device_sheet.dart';
import '../settings/legal_screen.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String _uid = context.read<Session>().uid!;
  late Future<int?> _checkupCount = context.read<CheckupRepository>().count(_uid);
  bool _exporting = false;

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

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

  Future<void> _signOut() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'Reminders on this phone stop until you sign in again.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!ok || !mounted) return;
    final auth = context.read<AuthRepository>();
    final device = HealthDeviceService();
    if (device.isConnected) await device.disconnect();
    await NotificationService().cancelAll();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final p = session.profile;
    final doses = session.doses;
    if (p == null) return const GlassPage(inShell: true, title: 'Profile', slivers: []);

    return GlassPage(
      inShell: true,
      title: 'Profile',
      actions: [
        LiquidIconButton(icon: Icons.settings_rounded, tooltip: 'Settings', onPressed: () => _push(const SettingsScreen())),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              FadeSlideIn(child: _Header(profile: p, onEdit: () => _push(const EditProfileScreen()))),
              const SizedBox(height: Space.md),
              FadeSlideIn(
                delay: FadeSlideIn.stagger(1),
                child: _Stats(
                  checkups: _checkupCount,
                  medicines: doses == null ? null : ListenableBuilder(
                    listenable: doses,
                    builder: (_, _) => _StatValue('${doses.activeCourses.length}'),
                  ),
                  onCheckups: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckupHistoryScreen()));
                    if (mounted) setState(() => _checkupCount = context.read<CheckupRepository>().count(_uid));
                  },
                ),
              ),
              const SizedBox(height: Space.xl),
              FadeSlideIn(delay: FadeSlideIn.stagger(2), child: _HealthCard(profile: p, onEdit: () => _push(const EditProfileScreen()))),
              const SizedBox(height: Space.md),
              FadeSlideIn(delay: FadeSlideIn.stagger(3), child: _MedicalCard(profile: p, onEdit: () => _push(const EditProfileScreen()))),
              const SizedBox(height: Space.xl),
              FadeSlideIn(
                delay: FadeSlideIn.stagger(4),
                child: SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(
                    children: [
                      DeviceConnectionBuilder(
                        builder: (context, connected) => ListRow(
                          icon: connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                          iconColor: connected ? context.colors.success : null,
                          title: 'Baymax device',
                          subtitle: connected ? 'Connected' : 'Not connected',
                          onTap: () => showDeviceSheet(context),
                        ),
                      ),
                      const Divider(indent: 72),
                      ListRow(
                        icon: Icons.history_rounded,
                        title: 'Check-up history',
                        onTap: () => _push(const CheckupHistoryScreen()),
                      ),
                      const Divider(indent: 72),
                      ListRow(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Export health report',
                        subtitle: 'PDF of your profile, check-ups and medicines',
                        trailing: _exporting
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                            : null,
                        onTap: _exporting ? null : _export,
                      ),
                      const Divider(indent: 72),
                      ListRow(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Appearance, units, reminders, account',
                        onTap: () => _push(const SettingsScreen()),
                      ),
                      const Divider(indent: 72),
                      ListRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy',
                        onTap: () => LegalScreen.open(context, LegalDoc.privacy),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              LiquidButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                variant: LiquidButtonVariant.secondary,
                onPressed: _signOut,
              ),
              const SizedBox(height: Space.md),
              Text(
                'Signed in as ${p.email}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onEdit});
  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final since = p.createdAt;
    return SurfaceCard(
      onTap: onEdit,
      semanticLabel: 'Edit profile',
      child: Row(
        children: [
          InitialsAvatar(name: p.name, size: 64),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name.isEmpty ? 'Your profile' : p.name, style: context.text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (since != null)
                  Text('With Baymax since ${Fmt.monthYear(since)}', style: context.text.bodySmall)
                else
                  Text(p.email, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, size: 20, color: context.colors.textTertiary),
        ],
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue(this.value);
  final String value;

  @override
  Widget build(BuildContext context) =>
      Text(value, style: AppTypography.style(24, 800, tabular: true).copyWith(color: context.colors.textPrimary));
}

class _Stats extends StatelessWidget {
  const _Stats({required this.checkups, required this.medicines, required this.onCheckups});
  final Future<int?> checkups;
  final Widget? medicines;
  final VoidCallback onCheckups;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, Widget value, {VoidCallback? onTap}) => Expanded(
          child: SurfaceCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
            radius: Radii.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [value, Text(label, style: context.text.labelMedium)],
            ),
          ),
        );
    return Row(
      children: [
        tile(
          'Check-ups',
          FutureBuilder<int?>(
            future: checkups,
            builder: (_, snap) => _StatValue(snap.connectionState == ConnectionState.done ? '${snap.data ?? '–'}' : '…'),
          ),
          onTap: onCheckups,
        ),
        const SizedBox(width: Space.sm),
        tile('Active medicines', medicines ?? const _StatValue('–')),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.profile, required this.onEdit});
  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final bmi = p.bmi;
    Widget fact(String label, String? value, {String? note}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelMedium),
              const SizedBox(height: 2),
              Text(value ?? '–', style: AppTypography.style(18, 760, tabular: true).copyWith(color: context.colors.textPrimary)),
              if (note != null) Text(note, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
    return SurfaceCard(
      onTap: onEdit,
      semanticLabel: 'Health details. Tap to edit.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Health details', style: context.text.titleMedium)),
              Icon(Icons.chevron_right_rounded, color: context.colors.textTertiary),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact('Age', p.age == null ? null : '${p.age}'),
              fact('Sex', p.sex == 'Prefer not to say' ? '–' : p.sex),
              fact('Blood', p.bloodType),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact('Height', p.heightCm == null ? null : '${p.heightCm} cm'),
              fact('Weight', p.weightKg == null ? null : '${p.weightKg} kg'),
              fact('BMI', bmi?.toStringAsFixed(1), note: bmi == null ? null : bmiCategory(bmi)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicalCard extends StatelessWidget {
  const _MedicalCard({required this.profile, required this.onEdit});
  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final conditions = profile.conditions.map((c) => MedicalProfile.conditionLabels[c]).whereType<String>().toList();
    final allergies = profile.allergies.map((a) => MedicalProfile.allergyLabels[a]).whereType<String>().toList();
    return SurfaceCard(
      onTap: onEdit,
      semanticLabel: 'Medical history. Tap to edit.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(Icons.shield_outlined, size: 36, iconSize: 20),
              const SizedBox(width: Space.sm),
              Expanded(child: Text('Medical history', style: context.text.titleMedium)),
              Icon(Icons.chevron_right_rounded, color: context.colors.textTertiary),
            ],
          ),
          const SizedBox(height: Space.md),
          Text('Conditions', style: context.text.labelMedium),
          const SizedBox(height: 6),
          if (conditions.isEmpty)
            Text('None recorded', style: context.text.bodyMedium)
          else
            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in conditions) StatusPill(label: c, tone: Tone.info)]),
          const SizedBox(height: Space.md),
          Text('Medicine allergies', style: context.text.labelMedium),
          const SizedBox(height: 6),
          if (allergies.isEmpty)
            Text('None recorded', style: context.text.bodyMedium)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final a in allergies) StatusPill(label: a, tone: Tone.danger, icon: Icons.block_rounded)],
            ),
        ],
      ),
    );
  }
}
