import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../services/settings_service.dart';

/// Shown when the app is built without a Firebase project and without the
/// local-emulator flag (see lib/firebase_options.dart).
class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key, required this.settings});
  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baymax',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const _FirebaseSetupScreen(),
    );
  }
}

class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget step(String n, String title, String body, String? code) => Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: SurfaceCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: c.primarySoft,
                  child: Text(n, style: context.text.labelMedium!.copyWith(color: c.primary)),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleSmall),
                      const SizedBox(height: 4),
                      Text(body, style: context.text.bodyMedium),
                      if (code != null) ...[
                        const SizedBox(height: Space.xs),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Radii.xs)),
                          child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(emphasis: 1.2)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Space.gutter),
              children: [
                const SizedBox(height: Space.xl),
                const Center(child: BrandMark(size: 72)),
                const SizedBox(height: Space.lg),
                Text('Firebase isn’t connected', textAlign: TextAlign.center, style: context.text.headlineMedium),
                const SizedBox(height: Space.xs),
                Text(
                  'This build has no Firebase project, so sign-in and saving are unavailable.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: Space.xl),
                step('1', 'Connect a project', 'In the app folder, run FlutterFire and rebuild.', 'flutterfire configure'),
                step('2', 'Or test locally', 'Start the Firebase emulators, then run the app against them.',
                    'firebase emulators:start --project demo-baymax\nflutter run --dart-define=USE_FIREBASE_EMULATOR=true'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
