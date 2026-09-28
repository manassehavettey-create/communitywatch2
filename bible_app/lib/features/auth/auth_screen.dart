import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../core/config/app_config.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../data/auth/auth_service.dart';

/// Email/password and Google sign-in. Accounts are optional: everything
/// works on the device without one.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _create = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _done() {
    if (widget.fromOnboarding) {
      context.go('/home');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } on Object {
      setState(
        () => _error =
            'Something went wrong. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = ref.read(authServiceProvider);
    await _run(() async {
      if (_create) {
        final needsConfirm = await auth.signUpWithEmail(
          _email.text,
          _password.text,
          name: _name.text,
        );
        if (needsConfirm) {
          setState(
            () => _info =
                'Check your email to confirm your account, then sign in.',
          );
          _create = false;
          return;
        }
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
      if (mounted) _done();
    });
  }

  Future<void> _google() => _run(() async {
    await ref.read(authServiceProvider).signInWithGoogle();
    if (mounted && ref.read(authServiceProvider).currentUser != null) _done();
  });

  Future<void> _reset() async {
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim())) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    await _run(() async {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      setState(() => _info = 'We sent a link to reset your password.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final auth = ref.watch(authServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x3,
            Space.gutter,
            Space.x10,
          ),
          children: [
            Row(
              children: [
                CircleIconButton(
                  icon: PhosphorIconsBold.x,
                  tooltip: 'Close',
                  onPressed: _done,
                ),
                const Spacer(),
                if (widget.fromOnboarding)
                  TextButton(onPressed: _done, child: const Text('Not now')),
              ],
            ),
            Reveal(
              child: ClipRRect(
                borderRadius: Radii.lgAll,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.asset(
                    'assets/images/onboarding/welcome_reader.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.x6),
            Text(
              _create ? 'Create your account' : 'Welcome back',
              style: AppType.displayM.copyWith(color: p.ink),
            ),
            const SizedBox(height: Space.x2),
            Text(
              'Sync your highlights, notes, journal, prayers and plans across devices. '
              'Everything also stays available offline.',
              style: AppType.body.copyWith(color: p.inkSoft),
            ),
            const SizedBox(height: Space.x6),
            if (!auth.available)
              Text(
                'Accounts aren’t set up in this build yet, so everything is saved on this device.',
                style: AppType.body.copyWith(color: p.ink),
              )
            else ...[
              if (kIsWeb || AppConfig.hasGoogle)
                PillButton(
                  label: 'Continue with Google',
                  icon: PhosphorIconsBold.googleLogo,
                  variant: PillVariant.secondary,
                  expand: true,
                  onPressed: _busy ? null : _google,
                ),
              const SizedBox(height: Space.x5),
              Row(
                children: [
                  Expanded(child: Divider(color: p.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                    child: Text(
                      'or with email',
                      style: AppType.caption.copyWith(color: p.inkMute),
                    ),
                  ),
                  Expanded(child: Divider(color: p.line)),
                ],
              ),
              const SizedBox(height: Space.x5),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      AnimatedSize(
                        duration: m.base,
                        child: _create
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.x3,
                                ),
                                child: TextFormField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: const InputDecoration(
                                    hintText: 'Your first name (optional)',
                                  ),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(hintText: 'Email'),
                        validator: (v) =>
                            RegExp(r'^\S+@\S+\.\S+$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Enter a valid email',
                      ),
                      const SizedBox(height: Space.x3),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        autofillHints: [
                          _create
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _hide ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _hide
                                  ? PhosphorIconsRegular.eye
                                  : PhosphorIconsRegular.eyeSlash,
                            ),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < (_create ? 8 : 1)
                            ? (_create
                                  ? 'Use at least 8 characters'
                                  : 'Enter your password')
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: m.fast,
                child: _error != null || _info != null
                    ? Padding(
                        key: ValueKey('$_error$_info'),
                        padding: const EdgeInsets.only(top: Space.x3),
                        child: Text(
                          _error ?? _info!,
                          style: AppType.bodySmall.copyWith(
                            color: _error != null
                                ? Theme.of(context).colorScheme.error
                                : p.inkSoft,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: Space.x5),
              PillButton(
                label: _create ? 'Create account' : 'Sign in',
                expand: true,
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: Space.x3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _create = !_create;
                      _error = null;
                    }),
                    child: Text(
                      _create ? 'I have an account' : 'Create an account',
                    ),
                  ),
                  if (!_create)
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Forgot password?'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
