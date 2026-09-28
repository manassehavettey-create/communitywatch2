import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.signUp});
  final bool signUp;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _signUp = widget.signUp;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (_signUp) {
        await auth.signUp(_email.text, _password.text);
      } else {
        await auth.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      if (ref.read(authProvider).isCloud && context.canPop()) context.pop();
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await ref.read(authProvider.notifier).resetPassword(email);
      if (mounted) toast(context, 'Password reset link sent to $email');
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final auth = ref.watch(authProvider);
    final linking = auth.mode == AuthMode.local;
    final pending = auth.awaitingConfirmation;

    return BfPage(
      title: _signUp ? 'Create account' : 'Log in',
      children: [
        Text(_signUp ? 'Train anywhere.\nBack up everywhere.' : 'Welcome back.', style: t.headlineLarge).enter(context),
        const SizedBox(height: Space.xs),
        Text(
          linking
              ? 'Your workouts on this phone will be moved into your account and backed up.'
              : 'Your data syncs when you\'re online. Training always works offline.',
          style: t.bodyMedium?.copyWith(color: c.textMuted),
        ).enter(context, index: 1),
        const SizedBox(height: Space.xl),
        if (pending != null)
          BfCard(
            color: c.secondary,
            child: Row(children: [
              const Icon(BfIcons.bell, color: BfPalette.ink),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text('Check $pending to confirm your email, then log in.',
                    style: t.bodyMedium?.copyWith(color: BfPalette.ink)),
              ),
            ]),
          ).pop(context),
        if (pending != null) const SizedBox(height: Space.lg),
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
          ]),
        ).enter(context, index: 2),
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          Text(_error!, style: t.bodyMedium?.copyWith(color: c.danger)),
        ],
        const SizedBox(height: Space.xl),
        BfButton(label: _signUp ? 'Create account' : 'Log in', loading: _busy, onPressed: _submit),
        const SizedBox(height: Space.sm),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => setState(() {
              _signUp = !_signUp;
              _error = null;
            }),
            child: Text(_signUp ? 'I already have an account' : 'Create a new account'),
          ),
          if (!_signUp) TextButton(onPressed: _reset, child: const Text('Forgot password?')),
        ]),
      ],
    );
  }
}
