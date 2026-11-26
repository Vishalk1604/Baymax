import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion/jelly.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/liquid_button.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/repositories.dart';
import '../settings/legal_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  static final _rules = <(String, bool Function(String))>[
    ('At least 7 characters', (p) => p.length >= 7),
    ('An uppercase letter', (p) => p.contains(RegExp(r'[A-Z]'))),
    ('A number', (p) => p.contains(RegExp(r'[0-9]'))),
    ('A symbol (e.g. ! # %)', (p) => p.contains(RegExp(r'[^A-Za-z0-9\s]'))),
  ];

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _passwordOk => _rules.every((r) => r.$2(_password.text.trim()));

  Future<void> _create() async {
    setState(() => _error = null);
    final valid = _form.currentState!.validate();
    if (!valid || !_passwordOk) return;
    if (!_agreed) {
      setState(() => _error = 'Please confirm you understand how Baymax can and can’t help.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthRepository>().signUp(name: _name.text, email: _email.text, password: _password.text);
      // The auth gate now shows profile setup underneath; reveal it.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pw = _password.text.trim();
    return GlassPage(
      title: 'Create your account',
      subtitle: 'It takes about a minute.',
      bottom: LiquidButton(label: 'Create account', onPressed: _create, loading: _busy),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverToBoxAdapter(
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Full name',
                      controller: _name,
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: Space.md),
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) =>
                          (v == null || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) ? 'Enter a valid email address' : null,
                    ),
                    const SizedBox(height: Space.md),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: Space.sm),
                    for (final rule in _rules)
                      _RuleRow(label: rule.$1, met: rule.$2(pw), touched: pw.isNotEmpty),
                    const SizedBox(height: Space.lg),
                    JellyPress(
                      onTap: () => setState(() => _agreed = !_agreed),
                      intensity: 0.4,
                      semanticLabel: 'I understand Baymax is not a medical device',
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(Space.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'I understand Baymax gives general guidance, is not a medical device, and does not replace a doctor.',
                                    style: context.text.bodyMedium!.copyWith(color: c.textPrimary),
                                  ),
                                  Wrap(
                                    children: [
                                      TextButton(
                                        onPressed: () => LegalScreen.open(context, LegalDoc.terms),
                                        child: const Text('Terms of use'),
                                      ),
                                      TextButton(
                                        onPressed: () => LegalScreen.open(context, LegalDoc.privacy),
                                        child: const Text('Privacy policy'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: Motion.base,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: Space.md),
                              child: InfoBanner(message: _error!, tone: Tone.danger),
                            ),
                    ),
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

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.met, required this.touched});
  final String label;
  final bool met;
  final bool touched;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = met ? c.success : (touched ? c.textSecondary : c.textTertiary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: Motion.base,
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey(met),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: context.text.bodySmall!.copyWith(color: met ? c.textPrimary : null)),
        ],
      ),
    );
  }
}
