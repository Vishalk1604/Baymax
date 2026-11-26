import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/glass/liquid_glass.dart';
import '../../core/motion/fade_slide_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Sign-in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      // The auth gate moves on by itself once signed in.
      await context.read<AuthRepository>().signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final glass = context.glass.surface.copyWith(
      tint: c.surfaceRaised.withValues(alpha: context.isDark ? 0.58 : 0.5),
      frost: 1.5,
    );
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(emphasis: 1.3)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeSlideIn(child: Center(child: BrandMark(size: 78))),
                      const SizedBox(height: Space.lg),
                      FadeSlideIn(
                        delay: FadeSlideIn.stagger(1),
                        child: Column(
                          children: [
                            Text('Baymax', style: context.text.displaySmall, textAlign: TextAlign.center),
                            const SizedBox(height: 6),
                            Text(
                              'Your calm companion for everyday health.',
                              style: context.text.bodyLarge!.copyWith(color: c.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.xxl),
                      LiquidGlass(
                        radius: Radii.xl,
                        style: glass,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
                          child: AutofillGroup(
                            child: Form(
                              key: _form,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Sign in', style: context.text.headlineSmall),
                                  const SizedBox(height: Space.lg),
                                  AppTextField(
                                    label: 'Email',
                                    controller: _email,
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email address' : null,
                                  ),
                                  const SizedBox(height: Space.md),
                                  AppTextField(
                                    label: 'Password',
                                    controller: _password,
                                    icon: Icons.lock_outline_rounded,
                                    obscure: true,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.password],
                                    onSubmitted: (_) => _signIn(),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: _email.text)),
                                      ),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: Motion.base,
                                    curve: Motion.enter,
                                    child: _error == null
                                        ? const SizedBox(width: double.infinity)
                                        : Padding(
                                            padding: const EdgeInsets.only(bottom: Space.md),
                                            child: InfoBanner(message: _error!, tone: Tone.danger),
                                          ),
                                  ),
                                  LiquidButton(label: 'Sign in', onPressed: _signIn, loading: _busy),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New to Baymax?', style: context.text.bodyMedium),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      Text(
                        'Baymax gives general guidance and is not a medical device. In an emergency, call 112.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
