import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/visuals.dart';
import '../../data/session.dart';
import '../shell/main_shell.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

/// The app's root: shows sign-in, profile setup or the app from the session
/// state alone, so signing out always lands on sign-in and an abandoned
/// sign-up resumes at profile setup.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final Widget child = switch (session.stage) {
      SessionStage.starting || SessionStage.loadingProfile => const _Splash(key: ValueKey('splash')),
      SessionStage.signedOut => const WelcomeScreen(key: ValueKey('welcome')),
      SessionStage.needsProfile => const OnboardingScreen(key: ValueKey('onboarding')),
      SessionStage.offlineNoProfile => const _Splash(key: ValueKey('offline'), waitingForConnection: true),
      SessionStage.ready => const MainShell(key: ValueKey('shell')),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: child);
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key, this.waitingForConnection = false});
  final bool waitingForConnection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(emphasis: 1.2)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 76),
                const SizedBox(height: 20),
                if (waitingForConnection) ...[
                  Text('Waiting for a connection…', style: context.text.titleMedium),
                  const SizedBox(height: 6),
                  Text('Your profile will load as soon as you are online.', style: context.text.bodyMedium),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => context.read<Session>().auth.signOut(),
                    child: const Text('Sign out'),
                  ),
                ] else
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: context.colors.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
