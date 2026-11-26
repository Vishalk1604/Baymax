import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthRepository>().sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Reset password',
      subtitle: _sent ? null : "We'll email you a link to choose a new one.",
      bottom: _sent
          ? LiquidButton(label: 'Back to sign in', onPressed: () => Navigator.of(context).pop())
          : LiquidButton(label: 'Send reset link', onPressed: _send, loading: _busy),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: Motion.slow,
              child: _sent
                  ? Column(
                      key: const ValueKey('sent'),
                      children: [
                        const SizedBox(height: Space.xl),
                        const LiquidOrb(
                          mood: OrbMood.success,
                          size: 170,
                          child: Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 46),
                        ),
                        const SizedBox(height: Space.lg),
                        Text('Check your inbox', style: context.text.headlineSmall),
                        const SizedBox(height: Space.xs),
                        Text(
                          'If an account exists for ${_email.text.trim()}, a reset link is on its way.',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium,
                        ),
                      ],
                    )
                  : Form(
                      key: _form,
                      child: Column(
                        key: const ValueKey('form'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'Email',
                            controller: _email,
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            onSubmitted: (_) => _send(),
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email address' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: Space.md),
                            InfoBanner(message: _error!, tone: Tone.danger),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
