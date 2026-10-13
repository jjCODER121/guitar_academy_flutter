import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:activation_key/activation_key.dart';

import '../../core/config/distribution.dart';
import '../../core/config/school.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import 'purchases.dart';

/// «Активировать курс»: окно с ID-кодом устройства и полем для ключа.
/// [album] — курс, с экрана которого начали; ключ может оказаться и от
/// другого курса — тогда откроется тот курс. Из плеера урок уже открыт —
/// там [openLesson] = false.
Future<void> startActivation(
  BuildContext context,
  WidgetRef ref, {
  Album? album,
  bool openLesson = true,
}) async {
  // Активация записывается в аккаунт — сначала вход.
  if (ref.read(authProvider) == null) {
    final signedIn = await context.push<bool>(Routes.login);
    if (signedIn != true || !context.mounted) return;
    // После входа курс мог оказаться уже активированным на этом телефоне.
    if (album != null) {
      await ref.read(ownedProvider.notifier).restoreFromAccount();
      final owned = await ref.read(ownedProvider.future);
      if (owned.owns(album) || !context.mounted) return;
    }
  }
  final albumId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => ActivationSheet(preferred: album),
  );
  if (albumId == null || !context.mounted) return;

  if (album == null || albumId != album.id) {
    context.push(Routes.album(albumId));
  } else if (openLesson) {
    context.push(Routes.lesson(album.id, album.lessons.first.id));
  }
}

/// Окно активации. Закрывается с id открытого продукта по «Смотреть».
class ActivationSheet extends ConsumerStatefulWidget {
  const ActivationSheet({super.key, this.preferred});

  final Album? preferred;

  @override
  ConsumerState<ActivationSheet> createState() => _ActivationSheetState();
}

class _ActivationSheetState extends ConsumerState<ActivationSheet> {
  final _key = TextEditingController();
  bool _busy = false;
  bool _copied = false;
  String? _error;
  String? _openedId;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    _key.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _key.dispose();
    super.dispose();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _activate() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(ownedProvider.notifier)
          .activate(_key.text, preferred: widget.preferred);
      if (mounted) setState(() => _openedId = id);
    } on InvalidActivationKey {
      _error = l10n.invalidActivationKey;
    } on DeviceIdUnavailable {
      _error = l10n.deviceIdUnavailable;
    } on TooManyAttempts {
      _error = l10n.tooManyAttempts;
    } on NotSignedIn {
      _error = l10n.loginToUnlock;
    } catch (_) {
      _error = l10n.loadError;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        0,
        AppSpace.screen,
        // Поле не прячется под клавиатурой.
        AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _openedId == null ? _form(context) : _done(context, _openedId!),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final ready = normalizeKey(_key.text).isNotEmpty && !_busy;
    final preferred = widget.preferred;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.activationTitle, style: AppText.albumTitle),
        if (preferred != null) ...[
          const SizedBox(height: 4),
          Text(
            preferred.title,
            style: AppText.body.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        Text(
          l10n.deviceCodeLabel,
          style: AppText.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.xs),
        _DeviceCodeBox(copied: _copied, onCopy: _copy),
        if (kDebugMode) const _DebugDeviceInfo(),
        if (ref.watch(distributionProvider) == Distribution.direct)
          _ContactMusician(course: preferred),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _key,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_KeyFormatter()],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => ready ? _activate() : null,
          style: AppText.sectionTitle.copyWith(letterSpacing: 1.5),
          decoration: InputDecoration(labelText: l10n.activationKeyLabel),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: AppText.caption.copyWith(color: c.danger),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpace.md),
        FilledButton(
          onPressed: ready ? _activate : null,
          child: _busy
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: c.textSecondary,
                  ),
                )
              : Text(l10n.activate),
        ),
      ],
    );
  }

  Widget _done(BuildContext context, String albumId) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final title = ref.watch(albumProvider(albumId)).value?.title ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: c.success.withValues(alpha: 0.16),
            child: Icon(AppIcons.check, size: 40, color: c.success),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.unlocked,
          style: AppText.screenTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.unlockedIn(title),
          style: AppText.body.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.md),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(albumId),
          child: Text(l10n.watch),
        ),
      ],
    );
  }
}

/// ID-код устройства и кнопка «Скопировать».
class _DeviceCodeBox extends ConsumerWidget {
  const _DeviceCodeBox({required this.copied, required this.onCopy});

  final bool copied;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final code = ref.watch(deviceCodeProvider);

    return Container(
      padding: const EdgeInsets.only(left: AppSpace.sm, right: 4),
      constraints: const BoxConstraints(minHeight: AppSize.button),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: switch (code) {
        AsyncData(:final value) => Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: AppText.lessonTitle.copyWith(letterSpacing: 1),
              ),
            ),
            TextButton.icon(
              onPressed: () => onCopy(value),
              style: TextButton.styleFrom(foregroundColor: c.accent),
              icon: Icon(copied ? AppIcons.check : AppIcons.copy, size: 18),
              label: Text(copied ? l10n.copied : l10n.copy),
            ),
          ],
        ),
        AsyncError() => Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.deviceIdUnavailable,
            style: AppText.caption.copyWith(color: c.danger),
          ),
        ),
        _ => const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      },
    );
  }
}

/// Только в отладочной сборке: из чего получился ID-код, чтобы проверить
/// преобразование вручную. В release этого виджета нет.
class _DebugDeviceInfo extends ConsumerWidget {
  const _DebugDeviceInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(rawDeviceIdProvider).value;
    final code = ref.watch(deviceCodeProvider).value;
    if (raw == null || code == null) return const SizedBox.shrink();
    final beforeReverse = code.split('').reversed.join();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: SelectableText(
        [
          'Отладка. Android ID этого приложения: $raw',
          'Буквы → цифры и случайная цифра в начале: $beforeReverse',
          'После разворота: $code',
        ].join('\n'),
        style: AppText.caption.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// Чат WhatsApp с музыкантом и уже набранным сообщением.
Uri whatsAppUri(String message) =>
    Uri.https('wa.me', '/${School.contactNumber}', {'text': message});

Uri phoneUri() => Uri(scheme: 'tel', path: '+${School.contactNumber}');

/// Только в сборке для прямой раздачи: как купить — отправить ID-код
/// музыканту в WhatsApp (сообщение уже набрано) или позвонить.
class _ContactMusician extends ConsumerStatefulWidget {
  const _ContactMusician({required this.course});

  final Album? course;

  @override
  ConsumerState<_ContactMusician> createState() => _ContactMusicianState();
}

class _ContactMusicianState extends ConsumerState<_ContactMusician> {
  bool _failed = false;

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _failed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final code = ref.watch(deviceCodeProvider).value;
    final course = widget.course;
    final message = code == null
        ? null
        : course == null
        ? l10n.buyMessageGeneric(code)
        : l10n.buyMessage(course.title, code);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.howToBuyHint, style: AppText.body),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: message == null
                      ? null
                      : () => _open(whatsAppUri(message)),
                  icon: const Icon(AppIcons.messageCircle, size: 20),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(phoneUri()),
                  icon: const Icon(AppIcons.phone, size: 20),
                  label: Text(l10n.call),
                ),
              ),
            ],
          ),
          if (_failed) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              l10n.contactFailed,
              style: AppText.caption.copyWith(color: c.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ключ: только латиница и цифры, в верхнем регистре.
class _KeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalizeKey(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
