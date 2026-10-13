import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/domain/catalog_models.dart';
import '../images/cover_cache.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// 6:40, 1:02:05.
String formatDuration(int totalSec) {
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = (totalSec % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String kindLabel(AppLocalizations l10n, AlbumType type) => switch (type) {
  AlbumType.course => l10n.kindCourse,
  AlbumType.songAlbum => l10n.kindAlbum,
  AlbumType.single => l10n.kindSingle,
};

String levelLabel(AppLocalizations l10n, Level level) => switch (level) {
  Level.beginner => l10n.levelBeginner,
  Level.intermediate => l10n.levelIntermediate,
  Level.advanced => l10n.levelAdvanced,
};

/// «10 уроков» для курса, «10 песен» для альбома.
String unitsCount(AppLocalizations l10n, Album album) =>
    album.type == AlbumType.course
    ? l10n.lessonsCount(album.lessons.length)
    : l10n.songsCount(album.lessons.length);

/// Обложка продукта: фото (сохраняется на телефоне — видно и без интернета),
/// а пока его нет — цветная заглушка с иконкой.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.album,
    this.radius = AppRadius.card,
    this.iconSize = 28,
    this.label,
    this.centerIcon = false,
  });

  final Album album;
  final double radius;
  final double iconSize;

  /// Короткая подпись в нижнем углу («10 песен»).
  final String? label;
  final bool centerIcon;

  @override
  Widget build(BuildContext context) {
    final p = album.cover;
    final url = album.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: p.background,
        child: url != null
            ? Image(
                image: CachedCoverImage(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            : Padding(
                padding: const EdgeInsets.all(14),
                child: centerIcon
                    ? Center(
                        child: Icon(
                          AppIcons.music,
                          size: iconSize,
                          color: p.foreground,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            AppIcons.music,
                            size: iconSize,
                            color: p.foreground,
                          ),
                          if (label != null)
                            Text(
                              label!,
                              style: AppText.caption.copyWith(
                                color: p.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
              ),
      ),
    );
  }
}

/// Фото обложки на всю карточку с затемнением снизу — чтобы светлый текст
/// поверх оставался читаемым на любом фото.
class CoverPhoto extends StatelessWidget {
  const CoverPhoto({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: CachedCoverImage(url),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x14000000), Color(0xB3000000)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Тонкая полоска прогресса акцентным цветом.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 4,
      borderRadius: const BorderRadius.all(Radius.circular(2)),
    );
  }
}

/// Круглая кнопка-иконка с зоной касания 48.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: c.textPrimary,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppSize.tapTarget),
        backgroundColor: filled ? c.background : null,
      ),
    );
  }
}

/// Кнопка «назад»: закрывает экран, а если он открыт по прямой ссылке —
/// ведёт на Главную.
class BackButtonRound extends StatelessWidget {
  const BackButtonRound({super.key, this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return RoundIconButton(
      icon: AppIcons.chevronLeft,
      tooltip: AppLocalizations.of(context).back,
      filled: filled,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// Загрузка, ошибка с «Повторить» или содержимое.
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError() => _ErrorView(onRetry: onRetry),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.cloudOff, size: 40, color: context.colors.locked),
            const SizedBox(height: AppSpace.sm),
            Text(l10n.loadError, style: AppText.lessonTitle),
            const SizedBox(height: AppSpace.md),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

/// Карточка-плашка: фон surface, скругление 16, касание по всей площади.
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = AppRadius.button,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
