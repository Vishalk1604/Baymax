import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_overlays.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../services/health_device_service.dart';

/// Rebuilds when the Baymax device connects or disconnects.
class DeviceConnectionBuilder extends StatelessWidget {
  const DeviceConnectionBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, bool connected) builder;

  @override
  Widget build(BuildContext context) {
    final device = HealthDeviceService();
    return StreamBuilder<bool>(
      stream: device.connectionStream,
      initialData: device.isConnected,
      builder: (context, snap) => builder(context, snap.data ?? device.isConnected),
    );
  }
}

Future<void> showDeviceSheet(BuildContext context) =>
    showGlassSheet<void>(context, builder: (_) => const _DeviceSheet());

class _DeviceSheet extends StatefulWidget {
  const _DeviceSheet();

  @override
  State<_DeviceSheet> createState() => _DeviceSheetState();
}

class _DeviceSheetState extends State<_DeviceSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await HealthDeviceService().connectToBAYMAX();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : HealthDeviceService().measurementStatus;
    });
    if (ok) AppToast.show(context, 'Baymax connected', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DeviceConnectionBuilder(
      builder: (context, connected) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(
                  connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                  size: 56,
                  color: connected ? c.success : c.primary,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Baymax device', style: context.text.titleLarge),
                      const SizedBox(height: 4),
                      StatusPill(
                        label: connected ? 'Connected' : 'Not connected',
                        tone: connected ? Tone.success : Tone.neutral,
                        icon: connected ? Icons.check_rounded : Icons.link_off_rounded,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            if (connected)
              Text(
                'Ready to measure your vitals and dispense medicines from its compartments.',
                style: context.text.bodyMedium,
              )
            else ...[
              for (final (i, step) in const [
                'Switch on your Baymax.',
                'Pair it in your phone’s Bluetooth settings — it appears as “BAYMAX”.',
                'Come back and tap Connect.',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: c.primarySoft,
                        child: Text('${i + 1}', style: context.text.labelSmall!.copyWith(color: c.primary)),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(step, style: context.text.bodyMedium!.copyWith(color: c.textPrimary))),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                InfoBanner(message: _error!, tone: Tone.warning),
              ],
            ],
            const SizedBox(height: Space.lg),
            if (connected)
              LiquidButton(
                label: 'Disconnect',
                variant: LiquidButtonVariant.secondary,
                icon: Icons.link_off_rounded,
                onPressed: () => HealthDeviceService().disconnect(),
              )
            else ...[
              LiquidButton(label: 'Connect', icon: Icons.bluetooth_searching_rounded, onPressed: _connect, loading: _busy),
              const SizedBox(height: Space.xs),
              TextButton.icon(
                onPressed: () => FlutterBluetoothSerial.instance.openSettings(),
                icon: const Icon(Icons.settings_bluetooth_rounded),
                label: const Text('Open Bluetooth settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
