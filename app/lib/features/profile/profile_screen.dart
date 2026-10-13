import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/school.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/common.dart';
import '../auth/auth.dart';
import '../catalog/data/catalog_repository.dart';
import '../offline/offline_videos.dart';
import '../progress/progress.dart';
import '../purchases/purchases.dart';
import '../purchases/activation_flow.dart';

/// Названия языков — каждое на своём языке, как принято в переключателях.
const _languages = {'ru': 'Русский', 'tg': 'Тоҷикӣ', 'en': 'English'};

/// Профиль: аватар, статистика, язык, тема, восстановить покупки,
/// контакты школы, выход.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final offline = ref.watch(offlineProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.md,
            AppSpace.screen,
            AppSpace.lg,
          ),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: c.accent.withValues(alpha: 0.16),
                  foregroundColor: c.accent,
                  child: user == null
                      ? const Icon(AppIcons.user, size: 30)
                      : Text(user.initial, style: AppText.screenTitle),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user == null ? l10n.guest : user.name ?? user.email,
                        style: AppText.albumTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user?.name != null)
                        Text(
                          user!.email,
                          style: AppText.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            const _Stats(),
            const SizedBox(height: AppSpace.md),
            Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _Row(
                    icon: AppIcons.languages,
                    label: l10n.language,
                    value: locale == null
                        ? l10n.languageSystem
                        : _languages[locale.languageCode],
                    onTap: () => _pickLanguage(context, ref),
                  ),
                  const Divider(),
                  _Row(
                    icon: AppIcons.sunMoon,
                    label: l10n.theme,
                    value: themeMode == ThemeMode.light
                        ? l10n.themeLight
                        : l10n.themeDark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(
                          themeMode == ThemeMode.light
                              ? ThemeMode.dark
                              : ThemeMode.light,
                        ),
                  ),
                  const Divider(),
                  _Row(
                    icon: AppIcons.ticket,
                    label: l10n.unlockWithCode,
                    onTap: () => startActivation(context, ref),
                  ),
                  const Divider(),
                  if (offline.bytes > 0 || offline.downloading != null) ...[
                    _Row(
                      icon: AppIcons.hardDriveDownload,
                      label: l10n.offlineVideos,
                      value: offline.downloading != null
                          ? l10n.offlineSaving((offline.progress * 100).round())
                          : _size(l10n, offline.bytes),
                      onTap: () => _deleteOffline(context, ref),
                    ),
                    const Divider(),
                  ],
                  _Row(
                    icon: AppIcons.music,
                    label: l10n.musicSchool,
                    value: l10n.contacts,
                    onTap: () => _showContacts(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (user == null)
              FilledButton(
                onPressed: () => context.push<bool>(Routes.login),
                child: Text(l10n.signIn),
              )
            else
              OutlinedButton(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                child: Text(l10n.signOut),
              ),
          ],
        ),
      ),
    );
  }

  /// «Видео на телефоне» → подтверждение → удалить все сохранённые видео.
  Future<void> _deleteOffline(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.offlineDeleteTitle),
        content: Text(l10n.offlineDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(offlineProvider.notifier).deleteAll();
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(localeProvider)?.languageCode;
    return showModalBottomSheet<void>(
      context: context,
      // Поверх нижней панели, а не под ней.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        void pick(String? code) {
          ref
              .read(localeProvider.notifier)
              .set(code == null ? null : Locale(code));
          Navigator.of(sheetContext).pop();
        }

        return SafeArea(
          child: RadioGroup<String?>(
            groupValue: current,
            onChanged: pick,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(l10n.languageSystem),
                ),
                for (final MapEntry(key: code, value: name)
                    in _languages.entries)
                  RadioListTile<String?>(value: code, title: Text(name)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showContacts(BuildContext context) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      // Поверх нижней панели, а не под ней.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            0,
            AppSpace.screen,
            AppSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(School.name, style: AppText.albumTitle),
              const SizedBox(height: 4),
              Text(
                School.musician,
                style: AppText.caption.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpace.sm),
              for (final (icon, value) in [
                (AppIcons.phone, School.phone),
                (AppIcons.mapPin, School.address),
                (AppIcons.atSign, School.instagram),
              ])
                SizedBox(
                  height: AppSize.tapTarget,
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: c.textSecondary),
                      const SizedBox(width: 14),
                      Text(value, style: AppText.body),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final albums = ref.watch(catalogProvider).value ?? const [];
    final owned = ref.watch(ownedProvider).value ?? const <String>{};
    final progress = ref.watch(progressProvider);

    final purchases = albums.where((a) => owned.contains(a.id)).length;
    final lessonsDone = progress.values.where((p) => p.completed).length;
    final minutes = progress.watchedSeconds(albums) ~/ 60;
    final practice = minutes >= 60
        ? l10n.hours(minutes ~/ 60)
        : l10n.minutes(minutes);

    Widget stat(String value, String label, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.albumTitle.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.caption.copyWith(color: c.textSecondary),
            maxLines: 2,
          ),
        ],
      ),
    );

    return Tile(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpace.sm),
      onTap: () => context.go(Routes.library),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stat('$purchases', l10n.purchasesLabel(purchases), color: c.accent),
          const SizedBox(width: AppSpace.xs),
          stat('$lessonsDone', l10n.lessonsDoneLabel(lessonsDone)),
          const SizedBox(width: AppSpace.xs),
          stat(practice, l10n.practiceLabel),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c.textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.lessonTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: AppText.caption.copyWith(color: c.textSecondary),
                ),
              const SizedBox(width: 4),
              Icon(AppIcons.chevronRight, size: 18, color: c.locked),
            ],
          ),
        ),
      ),
    );
  }
}

/// Размер сохранённых видео: «350 МБ», «1,2 ГБ».
String _size(AppLocalizations l10n, int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb < 1000) return l10n.sizeMb(mb < 1 ? '1' : mb.round().toString());
  final gb = (mb / 1024).toStringAsFixed(1);
  return l10n.sizeGb(l10n.localeName == 'en' ? gb : gb.replaceAll('.', ','));
}
