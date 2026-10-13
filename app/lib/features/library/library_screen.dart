import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../progress/progress.dart';
import '../purchases/purchases.dart';

/// Моя библиотека: купленные продукты с прогрессом.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    final owned = ref.watch(ownedProvider).value ?? const <String>{};

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: catalog,
          onRetry: () => ref.invalidate(catalogProvider),
          builder: (albums) {
            final mine = [
              for (final a in albums)
                if (owned.owns(a)) a,
            ];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screen,
                    AppSpace.md,
                    AppSpace.screen,
                    AppSpace.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l10n.navLibrary,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                if (mine.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.screen,
                      0,
                      AppSpace.screen,
                      AppSpace.lg,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: AppSpace.md,
                            childAspectRatio: 0.66,
                          ),
                      itemCount: mine.length,
                      itemBuilder: (context, i) => _Item(album: mine[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Item extends ConsumerWidget {
  const _Item({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(progressProvider);
    final total = album.lessons.length;
    final done = progress.completedIn(album);

    final String meta;
    final double value;
    if (total == 1) {
      final lesson = album.lessons.single;
      final p = progress[lesson.id];
      value = p == null
          ? 0
          : (p.completed ? 1 : p.positionSec / lesson.durationSec);
      meta = switch (p) {
        null => l10n.notStarted,
        _ when p.completed => l10n.completed,
        _ =>
          '${formatDuration(p.positionSec)} / '
              '${formatDuration(lesson.durationSec)}',
      };
    } else {
      value = done / total;
      meta = done == total
          ? l10n.completed
          : !progress.startedAny(album)
          ? l10n.notStarted
          : album.type == AlbumType.course
          ? l10n.lessonsOf(done, total)
          : l10n.songsOf(done, total);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push(Routes.album(album.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArt(album: album, label: kindLabel(l10n, album.type)),
          ),
          const SizedBox(height: 10),
          ProgressLine(value: value),
          const SizedBox(height: 10),
          Text(
            album.title,
            style: AppText.lessonTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            meta,
            style: AppText.caption.copyWith(color: c.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Пустая библиотека: гитара и «В каталог».
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.screen),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.guitar, size: 96, color: c.locked),
          const SizedBox(height: AppSpace.md),
          Text(
            l10n.libraryEmpty,
            style: AppText.lessonTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: () => context.go(Routes.home),
            child: Text(l10n.toCatalog),
          ),
        ],
      ),
    );
  }
}
