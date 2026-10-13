import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/distribution.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../progress/progress.dart';
import '../purchases/purchases.dart';
import '../purchases/activation_flow.dart';
import 'lesson_row.dart';

/// Продукт: курс, альбом песен или отдельная песня.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumProvider(albumId));
    return Scaffold(
      body: AsyncView(
        value: album,
        onRetry: () => ref.invalidate(albumProvider(albumId)),
        builder: (album) => _AlbumContent(album: album),
      ),
    );
  }
}

class _AlbumContent extends ConsumerWidget {
  const _AlbumContent({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final owned = ref.watch(ownedProvider).value ?? const <String>{};
    final progress = ref.watch(progressProvider);
    final isOwned = owned.owns(album);
    final isCourse = album.type == AlbumType.course;

    void unlock() => startActivation(context, ref, album: album);
    void openLesson(Lesson l) => context.push(Routes.lesson(album.id, l.id));
    void openMaterial(StudyMaterial m) =>
        isOwned ? context.push(Routes.material(album.id, m.id)) : unlock();

    LessonState stateOf(Lesson l) {
      if (isOwned) {
        return (progress[l.id]?.completed ?? false)
            ? LessonState.done
            : LessonState.available;
      }
      return l.hasPreview ? LessonState.freePreview : LessonState.locked;
    }

    final mainButton = FilledButton(
      onPressed: isOwned
          ? () => openLesson(progress.firstUnfinished(album))
          : unlock,
      child: Text(
        isOwned
            ? l10n.watch
            : ref.watch(distributionProvider) == Distribution.direct
            ? l10n.buy
            : l10n.unlockWithCode,
      ),
    );

    final general = album.generalMaterial;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        isCourse ? _CourseHeader(album: album) : _CoverHeader(album: album),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.md,
            AppSpace.screen,
            AppSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCourse)
                _CourseStats(album: album)
              else ...[
                Text(album.title, style: AppText.albumTitle),
                const SizedBox(height: 6),
                Text(
                  [
                    if (album.type == AlbumType.single)
                      album.subtitle
                    else
                      unitsCount(l10n, album),
                    l10n.sheetMusicPdf,
                    levelLabel(l10n, album.level),
                  ].join(' · '),
                  style: AppText.caption.copyWith(color: c.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              mainButton,
              if (general != null) ...[
                const SizedBox(height: AppSpace.md),
                _MaterialPlate(
                  material: general,
                  unlocked: isOwned,
                  onTap: () => openMaterial(general),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              if (isCourse) ...[
                Text(l10n.lessonsTitle, style: AppText.sectionTitle),
                const SizedBox(height: 12),
              ],
              for (final lesson in album.lessons)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.xs),
                  child: LessonRow(
                    lesson: lesson,
                    state: stateOf(lesson),
                    onTap: () => owned.canWatch(album, lesson)
                        ? openLesson(lesson)
                        : unlock(),
                    pdfAvailable: isOwned,
                    onPdfTap: switch (lesson.materialId) {
                      final String id => () => openMaterial(
                        album.material(id)!,
                      ),
                      null => null,
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Курс: цветная шапка с названием.
class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = album.cover;
    return Container(
      height: 280,
      color: p.background,
      child: Stack(
        children: [
          if (album.coverUrl != null)
            Positioned.fill(child: CoverPhoto(url: album.coverUrl!))
          else
            Positioned(
              right: -30,
              top: 30,
              child: Icon(
                AppIcons.music,
                size: 230,
                color: p.foreground.withValues(alpha: 0.16),
              ),
            ),
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: BackButtonRound(filled: true),
            ),
          ),
          Positioned(
            left: AppSpace.screen,
            right: AppSpace.screen,
            bottom: AppSpace.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sectionCourse.toUpperCase(),
                  style: AppText.caption.copyWith(
                    color: p.foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  album.title,
                  style: AppText.screenTitle.copyWith(
                    color: AppColors.dark.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Альбом и песня: обложка на размытом фоне.
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: CoverArt(album: album, radius: 0, iconSize: 0),
          ),
          const ColoredBox(color: Color(0x59000000)),
          SafeArea(
            child: Stack(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: BackButtonRound(filled: true),
                ),
                Align(
                  alignment: const Alignment(0, 0.4),
                  child: SizedBox.square(
                    dimension: 184,
                    child: CoverArt(album: album, iconSize: 34),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseStats extends StatelessWidget {
  const _CourseStats({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    Widget stat(String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.sectionTitle),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.caption.copyWith(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        stat('${album.lessons.length}', l10n.lessonsUnit(album.lessons.length)),
        const SizedBox(width: AppSpace.xs),
        stat('PDF', l10n.materials),
        const SizedBox(width: AppSpace.xs),
        stat('∞', l10n.access),
      ],
    );
  }
}

/// Плашка PDF: иконка документа и название, открывается одним касанием.
class _MaterialPlate extends StatelessWidget {
  const _MaterialPlate({
    required this.material,
    required this.unlocked,
    required this.onTap,
  });

  final StudyMaterial material;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Tile(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.cover),
            ),
            child: Icon(AppIcons.fileText, color: c.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title, style: AppText.lessonTitle),
                if (material.subtitle != null)
                  Text(
                    material.subtitle!,
                    style: AppText.caption.copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(
            unlocked ? AppIcons.chevronRight : AppIcons.lock,
            size: 20,
            color: unlocked ? c.textSecondary : c.locked,
            semanticLabel: unlocked ? l10n.sheetMusic : l10n.locked,
          ),
        ],
      ),
    );
  }
}
