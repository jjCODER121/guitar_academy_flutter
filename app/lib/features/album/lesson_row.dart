import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../catalog/domain/catalog_models.dart';

enum LessonState {
  /// Куплено, ещё не пройдено.
  available,

  /// Не куплено, но есть бесплатное превью.
  freePreview,

  /// Не куплено.
  locked,

  /// Пройдено.
  done,
}

/// Строка урока: номер в круге, название, длительность и иконка состояния.
/// В альбоме песен — ещё иконка PDF с нотами этой песни.
class LessonRow extends StatelessWidget {
  const LessonRow({
    super.key,
    required this.lesson,
    required this.state,
    required this.onTap,
    this.onPdfTap,
    this.pdfAvailable = false,
  });

  final Lesson lesson;
  final LessonState state;
  final VoidCallback onTap;

  /// Если задан — в строке есть кнопка «Ноты».
  final VoidCallback? onPdfTap;
  final bool pdfAvailable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final duration = formatDuration(lesson.durationSec);
    final caption = switch ((state, lesson.previewLimitSec)) {
      (LessonState.freePreview, final int limit) =>
        '$duration · ${l10n.freeSeconds(limit)}',
      (LessonState.freePreview, null) => '$duration · ${l10n.free}',
      _ => duration,
    };

    return Tile(
      onTap: onTap,
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: c.surfaceAlt,
              child: Text(
                '${lesson.order}',
                style: AppText.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: AppText.lessonTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    caption,
                    style: AppText.caption.copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onPdfTap != null)
              IconButton(
                tooltip: l10n.sheetMusic,
                onPressed: onPdfTap,
                icon: Icon(
                  AppIcons.fileText,
                  size: 20,
                  color: pdfAvailable ? c.textSecondary : c.locked,
                ),
              ),
            SizedBox(
              width: AppSize.tapTarget,
              child: Center(child: _StateIcon(state: state)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.state});

  final LessonState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      LessonState.freePreview => Semantics(
        label: l10n.watchFree,
        child: CircleAvatar(
          radius: 20,
          backgroundColor: c.accent,
          child: Icon(Icons.play_arrow_rounded, size: 24, color: c.accentOn),
        ),
      ),
      LessonState.available => Icon(
        AppIcons.play,
        color: c.accent,
        semanticLabel: l10n.play,
      ),
      LessonState.done => Icon(
        AppIcons.check,
        color: c.success,
        semanticLabel: l10n.completed,
      ),
      LessonState.locked => Icon(
        AppIcons.lock,
        size: 20,
        color: c.locked,
        semanticLabel: l10n.locked,
      ),
    };
  }
}
