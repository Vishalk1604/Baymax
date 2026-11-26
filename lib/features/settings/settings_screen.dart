import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/glass/glass_runtime.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_nav_bar.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories.dart';
import '../../data/session.dart';
import '../../services/health_device_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import 'legal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  bool? _osAllowsNotifications;

  @override
  void initState() {
    super.initState();
    NotificationService().notificationsAllowed().then((v) {
      if (mounted) setState(() => _osAllowsNotifications = v);
    });
  }

  Future<void> _setReminders(bool on) async {
    final settings = context.read<SettingsService>();
    await settings.setNotifications(on);
    if (on) {
      final allowed = await NotificationService().requestPermissions();
      if (mounted) setState(() => _osAllowsNotifications = allowed);
    }
    await NotificationService().sync();
  }

  Future<void> _resetPassword() async {
    final email = context.read<Session>().user?.email;
    if (email == null) return;
    try {
      await context.read<AuthRepository>().sendPasswordReset(email);
      if (mounted) AppToast.show(context, 'We sent a reset link to $email', kind: ToastKind.success);
    } catch (e) {
      if (mounted) AppToast.show(context, AuthRepository.messageFor(e), kind: ToastKind.error);
    }
  }

  Future<void> _deleteAccount() async {
    final deleted = await showGlassDialog<bool>(context, builder: (_) => const _DeleteAccountDialog());
    if (deleted != true || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final c = context.colors;
    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title, padding: const EdgeInsets.only(bottom: Space.xs)),
              SurfaceCard(padding: const EdgeInsets.all(Space.md), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
            ],
          ),
        );

    return GlassPage(
      title: 'Settings',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              group('Appearance', [
                Text('Theme', style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                GlassSegmented<ThemeMode>(
                  values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                  labels: const ['System', 'Light', 'Dark'],
                  selected: settings.themeMode,
                  onChanged: settings.setThemeMode,
                ),
                const SizedBox(height: Space.lg),
                ValueListenableBuilder<bool>(
                  valueListenable: GlassRuntime.liquid,
                  builder: (context, on, _) => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Liquid glass'),
                    subtitle: Text(
                      !GlassRuntime.deviceSupported
                          ? 'This device can’t run the effect, so Baymax uses frosted glass.'
                          : GlassRuntime.disabledAfterCrash && !on
                              ? 'Turned off after a graphics problem. Turn on to try again.'
                              : 'Real-time refraction on bars and buttons. Turn off to save battery.',
                    ),
                    value: on,
                    onChanged: GlassRuntime.deviceSupported ? (v) => setState(() => GlassRuntime.setUserEnabled(v)) : null,
                  ),
                ),
                const SizedBox(height: Space.sm),
                const _GlassPreview(),
              ]),
              group('Units', [
                Text('Temperature', style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                GlassSegmented<bool>(
                  values: const [false, true],
                  labels: const ['Celsius (°C)', 'Fahrenheit (°F)'],
                  selected: settings.fahrenheit,
                  onChanged: settings.setFahrenheit,
                ),
              ]),
              group('Reminders', [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Medicine and visit reminders'),
                  subtitle: const Text('Doses at their times, visits two hours before.'),
                  value: settings.notificationsEnabled,
                  onChanged: _setReminders,
                ),
                if (settings.notificationsEnabled && _osAllowsNotifications == false)
                  InfoBanner(
                    tone: Tone.warning,
                    message: 'Notifications are blocked for Baymax on this phone.',
                    action: TextButton(onPressed: () => _setReminders(true), child: const Text('Allow')),
                  ),
              ]),
              group('Privacy and information', [
                ListRow(icon: Icons.privacy_tip_outlined, title: 'Privacy', onTap: () => LegalScreen.open(context, LegalDoc.privacy)),
                ListRow(icon: Icons.description_outlined, title: 'Terms of use', onTap: () => LegalScreen.open(context, LegalDoc.terms)),
                ListRow(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Medical disclaimer',
                  onTap: () => LegalScreen.open(context, LegalDoc.disclaimer),
                ),
                FutureBuilder<PackageInfo>(
                  future: _info,
                  builder: (context, snap) => ListRow(
                    icon: Icons.info_outline_rounded,
                    title: 'Open-source licences',
                    subtitle: snap.hasData ? 'Baymax ${snap.data!.version} (${snap.data!.buildNumber})' : null,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Baymax',
                      applicationVersion: snap.data?.version,
                      applicationIcon: const Padding(padding: EdgeInsets.all(8), child: BrandMark(size: 56)),
                    ),
                  ),
                ),
              ]),
              group('Account', [
                ListRow(icon: Icons.lock_reset_rounded, title: 'Reset password', subtitle: 'We’ll email you a link', onTap: _resetPassword),
                ListRow(
                  icon: Icons.delete_forever_rounded,
                  iconColor: c.danger,
                  title: 'Delete account',
                  subtitle: 'Erases your profile, check-ups, medicines and visits',
                  destructive: true,
                  onTap: _deleteAccount,
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// A strip of colour under a liquid button, so the glass toggle shows its effect.
class _GlassPreview extends StatelessWidget {
  const _GlassPreview();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: SizedBox(
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Row(
                // Childless ColoredBoxes take the smallest size they're
                // allowed, so stretch them to the strip's height.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final color in [c.primary, c.accent, c.success, c.warning, c.info, c.danger])
                    Expanded(child: ColoredBox(color: color.withValues(alpha: 0.85))),
                ],
              ),
            ),
            const SizedBox(width: 180, child: LiquidButton(label: 'Preview', variant: LiquidButtonVariant.secondary, onPressed: _noop)),
          ],
        ),
      ),
    );
  }

  static void _noop() {}
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = HealthDeviceService();
      await context.read<AuthRepository>().deleteAccount(_password.text);
      await NotificationService().cancelAll();
      if (device.isConnected) await device.disconnect();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthRepository.messageFor(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      icon: Icons.delete_forever_rounded,
      iconColor: context.colors.danger,
      title: 'Delete your account?',
      message: 'This permanently erases your profile, check-ups, medicines and visits. It can’t be undone.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Password',
            controller: _password,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _delete(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(_error!, style: context.text.bodySmall!.copyWith(color: context.colors.danger)),
            ),
        ],
      ),
      actions: [
        LiquidButton(
          label: 'Delete forever',
          variant: LiquidButtonVariant.danger,
          size: LiquidButtonSize.medium,
          loading: _busy,
          onPressed: _delete,
        ),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
      ],
    );
  }
}
