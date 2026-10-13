import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../auth/auth.dart';
import '../progress/progress.dart';
import '../purchases/purchases.dart';
import 'data/catalog_repository.dart';
import 'domain/catalog_models.dart';

/// Главная: приветствие, «Продолжить» и три ряда обложек.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: catalog,
          onRetry: () => ref.invalidate(catalogProvider),
          builder: (albums) => _HomeContent(albums: albums),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authProvider);
    final owned = ref.watch(ownedProvider).value ?? const <String>{};
    final last = ref.watch(progressProvider).lastWatched(albums);

    List<Album> ofType(AlbumType t) => [
      for (final a in albums)
        if (a.type == t) a,
    ];
    final courses = ofType(AlbumType.course);
    final songAlbums = ofType(AlbumType.songAlbum);
    final singles = ofType(AlbumType.single);

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.read(catalogProvider.notifier).refresh();
        } catch (_) {
          // Нет сети — остаётся то, что уже на экране.
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.lg),
        children: [
          _Padded(
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.greeting, style: text.headlineMedium),
                ),
                _Avatar(
                  initial: user?.initial,
                  onTap: () => context.go(Routes.profile),
                ),
              ],
            ),
          ),
          if (last case (final album, final lesson)) ...[
            const SizedBox(height: AppSpace.lg),
            _Padded(
              child: _ContinueCard(album: album, lesson: lesson),
            ),
          ],
          for (final course in courses) ...[
            const SizedBox(height: AppSpace.lg),
            _Padded(child: Text(l10n.sectionCourse, style: text.titleLarge)),
            const SizedBox(height: 14),
            _Padded(
              child: _CourseCard(album: course, owned: owned.owns(course)),
            ),
          ],
          if (songAlbums.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            _Padded(child: Text(l10n.sectionAlbums, style: text.titleLarge)),
            const SizedBox(height: 14),
            _CoverRow(
              albums: songAlbums,
              size: 156,
              owned: owned,
              label: (a) => l10n.songsCount(a.lessons.length),
            ),
          ],
          if (singles.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            _Padded(child: Text(l10n.sectionSingles, style: text.titleLarge)),
            const SizedBox(height: 14),
            _CoverRow(albums: singles, size: 116, owned: owned),
          ],
        ],
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
    child: child,
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.onTap});

  final String? initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).navProfile,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: c.surfaceAlt,
          foregroundColor: c.textPrimary,
          child: initial == null
              ? const Icon(AppIcons.user, size: 20)
              : Text(initial!, style: AppText.lessonTitle),
        ),
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.album, required this.lesson});

  final Album album;
  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final p = ref.watch(progressProvider)[lesson.id];
    final value = p == null || p.completed
        ? 1.0
        : p.positionSec / lesson.durationSec;
    return Tile(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpace.sm),
      onTap: () => context.push(Routes.lesson(album.id, lesson.id)),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 64,
            child: CoverArt(
              album: album,
              radius: AppRadius.cover,
              centerIcon: true,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.continueLearning,
                  style: AppText.caption.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.title,
                  style: AppText.lessonTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpace.xs),
                ProgressLine(value: value),
              ],
            ),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 22,
            backgroundColor: c.accent,
            child: Icon(Icons.play_arrow_rounded, size: 26, color: c.accentOn),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.album, required this.owned});

  final Album album;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final p = album.cover;
    return Material(
      color: p.background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.album(album.id)),
        child: SizedBox(
          height: 168,
          child: Stack(
            children: [
              if (album.coverUrl != null)
                Positioned.fill(child: CoverPhoto(url: album.coverUrl!))
              else
                Positioned(
                  right: -18,
                  top: 8,
                  child: Icon(
                    AppIcons.music,
                    size: 150,
                    color: p.foreground.withValues(alpha: 0.18),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.lessonsCount(album.lessons.length),
                      style: AppText.caption.copyWith(
                        color: p.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            album.title,
                            style: AppText.albumTitle.copyWith(
                              color: AppColors.dark.textPrimary,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        if (owned) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              l10n.watch,
                              style: AppText.caption.copyWith(
                                color: c.accentOn,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _CoverRow extends ConsumerWidget {
  const _CoverRow({
    required this.albums,
    required this.size,
    required this.owned,
    this.label,
  });

  final List<Album> albums;
  final double size;
  final Set<String> owned;
  final String Function(Album)? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(progressProvider);
    return SizedBox(
      height: size + 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        itemCount: albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final album = albums[i];
          final isOwned = owned.owns(album);
          return SizedBox(
            width: size,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => context.push(Routes.album(album.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: size,
                    child: CoverArt(
                      album: album,
                      label: label?.call(album),
                      centerIcon: label == null,
                      radius: size > 140 ? AppRadius.card : AppRadius.button,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    album.title,
                    style: AppText.lessonTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (isOwned)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ProgressLine(
                        value:
                            progress.completedIn(album) / album.lessons.length,
                      ),
                    )
                  else
                    Text(
                      album.type == AlbumType.single
                          ? album.subtitle
                          : levelLabel(l10n, album.level),
                      style: AppText.caption.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
