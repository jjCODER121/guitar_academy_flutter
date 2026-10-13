import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import 'auth.dart';

/// Вход и регистрация одним шагом: email + код или Google, без паролей.
/// Закрывается с результатом `true`, если вход удался.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _close(bool signedIn) {
    if (context.canPop()) {
      context.pop(signedIn);
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCode() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _error = l10n.emailInvalid);
      return;
    }
    var sent = false;
    await _run(() async {
      try {
        await ref.read(authProvider.notifier).requestOtp(email);
        sent = true;
      } on OtpSendException {
        _error = l10n.codeNotSent;
      }
    });
    if (!mounted || !sent) return;
    setState(() => _codeStep = true);
    _codeFocus.requestFocus();
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    var ok = false;
    await _run(() async {
      try {
        await ref
            .read(authProvider.notifier)
            .verifyOtp(_email.text.trim(), _code.text);
        ok = true;
      } on InvalidCodeException {
        _error = l10n.codeInvalid;
        _code.clear();
      }
    });
    if (ok && mounted) _close(true);
  }

  Future<void> _google() async {
    await _run(() => ref.read(authProvider.notifier).signInWithGoogle());
    if (mounted && ref.read(authProvider) != null) _close(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md - 8,
            AppSpace.xs,
            AppSpace.md,
            AppSpace.lg,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: l10n.close,
                onPressed: () => _close(false),
                icon: const Icon(AppIcons.x),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      // Место для логотипа школы.
                      child: Icon(AppIcons.guitar, color: c.accent),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _codeStep ? l10n.enterCode : l10n.loginTitle,
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    _codeStep
                        ? l10n.codeSent(_email.text.trim())
                        : l10n.loginSubtitle,
                    style: AppText.body.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (_codeStep) ..._codeForm(l10n) else ..._emailForm(l10n),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: AppText.caption.copyWith(color: c.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    l10n.noPasswordNote,
                    style: AppText.caption.copyWith(color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _busyOr(String label) => _busy
      ? SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.colors.textSecondary,
          ),
        )
      : Text(label);

  List<Widget> _emailForm(AppLocalizations l10n) {
    final c = context.colors;
    return [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _requestCode(),
        style: AppText.body,
        decoration: InputDecoration(
          labelText: l10n.emailLabel,
          hintText: 'name@mail.com',
        ),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy ? null : _requestCode,
        child: _busyOr(l10n.getCode),
      ),
      if (ref.watch(authRepositoryProvider).googleEnabled) ...[
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.or,
                style: AppText.caption.copyWith(color: c.textSecondary),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton.icon(
          onPressed: _busy ? null : _google,
          icon: Text(
            'G',
            style: AppText.sectionTitle.copyWith(color: c.textPrimary),
          ),
          label: Text(l10n.signInGoogle),
        ),
      ],
    ];
  }

  List<Widget> _codeForm(AppLocalizations l10n) {
    return [
      _CodeInput(
        controller: _code,
        focusNode: _codeFocus,
        length: otpLength,
        label: l10n.codeLabel,
        onCompleted: _verify,
      ),
      const SizedBox(height: AppSpace.md),
      FilledButton(
        onPressed: _busy ? null : _verify,
        child: _busyOr(l10n.signIn),
      ),
      const SizedBox(height: AppSpace.xs),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _codeStep = false;
                _error = null;
                _code.clear();
              }),
        child: Text(l10n.changeEmail),
      ),
    ];
  }
}

/// Четыре клетки для кода. Ввод идёт в одно поле поверх клеток —
/// так работают вставка из буфера и автоподстановка кода из SMS/почты.
class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.label,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final String label;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 68,
      child: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(
                          width: 1.5,
                          color: i == value.text.length
                              ? c.accent
                              : c.surfaceAlt,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        i < value.text.length ? value.text[i] : '',
                        style: AppText.screenTitle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: length,
                showCursor: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: label, counterText: ''),
                onChanged: (v) {
                  if (v.length == length) onCompleted();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
