import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/platform/secure_screen.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../progress/progress.dart';
import '../purchases/activation_flow.dart';
import '../purchases/purchases.dart';
import 'playback.dart';

/// Плеер: видео, скорость, повтор A–B, ноты и следующий урок.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({
    super.key,
    required this.albumId,
    required this.lessonId,
  });

  final String albumId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumProvider(albumId));
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: album,
          onRetry: () => ref.invalidate(albumProvider(albumId)),
          builder: (album) {
            final lesson = album.lesson(lessonId);
            if (lesson == null) {
              return const Align(
                alignment: Alignment.topLeft,
                child: BackButtonRound(),
              );
            }
            return _Player(
              key: ValueKey(lesson.id),
              album: album,
              lesson: lesson,
            );
          },
        ),
      ),
    );
  }
}

class _Player extends ConsumerStatefulWidget {
  const _Player({super.key, required this.album, required this.lesson});

  final Album album;
  final Lesson lesson;

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> {
  static const _speeds = [0.5, 0.75, 1.0, 1.25];

  Playback? _playback;
  bool _loading = false;
  bool _failed = false;
  late final ProgressController _progress;
  double? _loopA;
  double? _loopB;
  bool _previewEnded = false;
  int _lastSavedSec = -1;

  Lesson get _lesson => widget.lesson;

  bool get _owned =>
      (ref.read(ownedProvider).value ?? const <String>{}).owns(widget.album);

  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
    _progress = ref.read(progressProvider.notifier);
    final canWatch = (ref.read(ownedProvider).value ?? const <String>{})
        .canWatch(widget.album, _lesson);
    if (canWatch) _load();
  }

  /// Ссылка с сервера → видео → продолжить с места, где остановились.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final saved = ref.read(progressProvider)[_lesson.id];
    final resumeAt = saved == null || saved.completed ? 0 : saved.positionSec;
    try {
      final playback = await ref.read(playbackFactoryProvider)(
        _lesson,
        resumeAt.toDouble(),
      );
      if (!mounted) {
        playback.dispose();
        return;
      }
      playback.play();
      playback.addListener(_onTick);
      setState(() {
        _playback = playback;
        _loading = false;
      });
    } catch (_) {
      // В том числе MediaLocked: курс открыт на телефоне, но сервер ссылку
      // не дал (например, активацию отозвали) — «Повторить», без зацикливания.
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _onTick() {
    final playback = _playback!;
    final pos = playback.position;
    if (_loopA != null && _loopB != null && pos >= _loopB!) {
      playback.seek(_loopA!);
      return;
    }
    final limit = _lesson.previewLimitSec;
    if (limit != null && !_owned && pos >= limit) {
      playback
        ..pause()
        ..seek(limit.toDouble());
      setState(() => _previewEnded = true);
      return;
    }
    final sec = pos.floor();
    if (sec != _lastSavedSec && (sec % 5 == 0 || playback.atEnd)) {
      _save();
    }
    setState(() {});
  }

  void _save() {
    final playback = _playback;
    if (playback == null) return;
    _lastSavedSec = playback.position.floor();
    if (_lastSavedSec > 0) {
      ref.read(progressProvider.notifier).save(_lesson, _lastSavedSec);
    }
  }

  @override
  void dispose() {
    SecureScreen.release();
    final playback = _playback;
    if (playback != null) {
      // Дерево виджетов при dispose заблокировано: сохраняем после кадра.
      final sec = playback.position.floor();
      final lesson = _lesson;
      final progress = _progress;
      if (sec > 0) Future.microtask(() => progress.save(lesson, sec));
      playback
        ..removeListener(_onTick)
        ..dispose();
    }
    super.dispose();
  }

  void _toggleLoop() {
    final playback = _playback;
    if (playback == null) return;
    setState(() {
      if (_loopA == null) {
        _loopA = playback.position;
      } else if (_loopB == null) {
        final b = playback.position;
        if (b > _loopA!) {
          _loopB = b;
        } else {
          _loopA = b;
        }
      } else {
        _loopA = _loopB = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _unlock() {
    _playback?.pause();
    startActivation(context, ref, album: widget.album, openLesson: false);
  }

  Future<void> _fullscreen() async {
    final playback = _playback;
    if (playback == null) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _FullscreenPage(playback: playback, loopA: _loopA, loopB: _loopB),
      ),
    );
    if (mounted) setState(() {});
  }

  String _loopLabel(AppLocalizations l10n) {
    if (_loopA == null) return l10n.loopAB;
    if (_loopB == null) return l10n.loopMarkB;
    return l10n.loopOn(
      formatDuration(_loopA!.floor()),
      formatDuration(_loopB!.floor()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final owned = ref.watch(ownedProvider).value ?? const <String>{};
    final album = widget.album;
    final canWatch = owned.canWatch(album, _lesson);
    final isOwned = owned.owns(album);
    final isCourse = album.type == AlbumType.course;
    final materialId = _lesson.materialId ?? album.generalMaterial?.id;
    final next = album.lessonAfter(_lesson);
    final playback = _playback;

    // Курс только что активировали из этого экрана — загрузить видео.
    if (canWatch && playback == null && !_loading && !_failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playback == null && !_loading) _load();
      });
    }

    return Column(
      children: [
        _VideoArea(
          playback: playback,
          fallbackDuration: _lesson.durationSec.toDouble(),
          loading: _loading,
          failed: _failed,
          loopA: _loopA,
          loopB: _loopB,
          locked: !canWatch,
          previewEnded: _previewEnded && !isOwned,
          onUnlock: _unlock,
          onRetry: _load,
          onFullscreen: _fullscreen,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              AppSpace.md,
              AppSpace.screen,
              AppSpace.lg,
            ),
            children: [
              Text(
                [
                  if (album.lessons.length > 1)
                    isCourse
                        ? l10n.lessonOfTotal(
                            _lesson.order,
                            album.lessons.length,
                          )
                        : l10n.songOfTotal(_lesson.order, album.lessons.length),
                  album.type == AlbumType.single ? album.subtitle : album.title,
                ].join(' · '),
                style: AppText.caption.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(_lesson.title, style: AppText.albumTitle),
              const SizedBox(height: 28),
              Text(
                l10n.speed,
                style: AppText.caption.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, s) in _speeds.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: _Choice(
                        label:
                            '${s.toString().replaceFirst(RegExp(r'\.0$'), '')}×',
                        selected: (playback?.speed ?? 1.0) == s,
                        onTap: () => playback?.setSpeed(s),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: AppIcons.repeat,
                      label: _loopLabel(l10n),
                      active: _loopA != null,
                      onTap: playback != null ? _toggleLoop : null,
                    ),
                  ),
                  if (materialId != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: isOwned ? AppIcons.fileText : AppIcons.lock,
                        label: l10n.sheetMusic,
                        onTap: () => isOwned
                            ? context.push(
                                Routes.material(album.id, materialId),
                              )
                            : _unlock(),
                      ),
                    ),
                  ],
                ],
              ),
              if (next != null) ...[
                const SizedBox(height: AppSpace.lg),
                _NextCard(
                  album: album,
                  next: next,
                  unlocked: owned.canWatch(album, next),
                  onOpen: () =>
                      context.pushReplacement(Routes.lesson(album.id, next.id)),
                  onUnlock: () => _unlock(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoArea extends StatelessWidget {
  const _VideoArea({
    required this.playback,
    required this.fallbackDuration,
    required this.loading,
    required this.failed,
    required this.loopA,
    required this.loopB,
    required this.locked,
    required this.previewEnded,
    required this.onUnlock,
    required this.onRetry,
    required this.onFullscreen,
  });

  final Playback? playback;
  final double fallbackDuration;
  final bool loading;
  final bool failed;
  final double? loopA;
  final double? loopB;
  final bool locked;
  final bool previewEnded;
  final VoidCallback onUnlock;
  final VoidCallback onRetry;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = AppColors.dark; // видео всегда на тёмном
    final p = playback;
    final blocked = locked || previewEnded;
    final duration = (p?.duration ?? 0) > 0 ? p!.duration : fallbackDuration;

    final Widget center;
    if (blocked) {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.lock, color: c.textSecondary),
          if (previewEnded) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              l10n.previewEnded,
              style: AppText.caption.copyWith(color: c.textPrimary),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, AppSize.tapTarget),
            ),
            onPressed: onUnlock,
            child: Text(l10n.unlockShort),
          ),
        ],
      );
    } else if (failed) {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.videoUnavailable,
            style: AppText.caption.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.textPrimary,
              minimumSize: const Size(140, AppSize.tapTarget),
            ),
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      );
    } else if (loading || p == null || p.buffering) {
      center = SizedBox.square(
        dimension: 36,
        child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
      );
    } else {
      center = IconButton(
        tooltip: p.playing ? l10n.pause : l10n.play,
        onPressed: p.toggle,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(64),
          backgroundColor: c.background.withValues(alpha: 0.45),
        ),
        icon: Icon(
          p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: c.textPrimary,
          size: 32,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Stack(
          children: [
            if (p != null && !blocked) Positioned.fill(child: p.view()),
            // Касание — пауза/продолжить; двойное касание слева/справа — ±10 секунд.
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: blocked || p == null ? null : p.toggle,
                  onDoubleTapDown: blocked || p == null
                      ? null
                      : (d) => p.seek(
                          p.position +
                              (d.localPosition.dx < box.maxWidth / 2
                                  ? -10
                                  : 10),
                        ),
                ),
              ),
            ),
            Center(child: center),
            Theme(
              data: AppTheme.dark,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: BackButtonRound(),
              ),
            ),
            if (p != null && !blocked)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: l10n.fullscreen,
                  onPressed: onFullscreen,
                  icon: Icon(Icons.fullscreen_rounded, color: c.textPrimary),
                ),
              ),
            Positioned(
              left: AppSpace.sm,
              right: AppSpace.sm,
              bottom: 10,
              child: _Timeline(
                playback: p,
                duration: duration,
                loopA: loopA,
                loopB: loopB,
                enabled: !blocked && p != null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полоса перемотки и время под ней.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.playback,
    required this.duration,
    required this.loopA,
    required this.loopB,
    required this.enabled,
  });

  final Playback? playback;
  final double duration;
  final double? loopA;
  final double? loopB;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SeekBar(
          playback: playback,
          duration: duration,
          loopA: loopA,
          loopB: loopB,
          enabled: enabled,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final sec in [playback?.position ?? 0, duration])
              Text(
                formatDuration(sec.floor()),
                style: AppText.navLabel.copyWith(color: c.textSecondary),
              ),
          ],
        ),
      ],
    );
  }
}

/// Во весь экран: телефон поворачивается горизонтально, системные панели скрыты.
class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({
    required this.playback,
    required this.loopA,
    required this.loopB,
  });

  final Playback playback;
  final double? loopA;
  final double? loopB;

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SecureScreen.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = AppColors.dark;
    final p = widget.playback;
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: ListenableBuilder(
          listenable: p,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(child: p.view()),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: p.toggle,
                    onDoubleTapDown: (d) => p.seek(
                      p.position +
                          (d.localPosition.dx < box.maxWidth / 2 ? -10 : 10),
                    ),
                  ),
                ),
              ),
              if (!p.playing)
                Center(
                  child: IconButton(
                    tooltip: l10n.play,
                    onPressed: p.play,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(72),
                      backgroundColor: c.background.withValues(alpha: 0.45),
                    ),
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: c.textPrimary,
                      size: 40,
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: l10n.exitFullscreen,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.fullscreen_exit_rounded,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: AppSpace.sm,
                child: SafeArea(
                  child: _Timeline(
                    playback: p,
                    duration: p.duration,
                    loopA: widget.loopA,
                    loopB: widget.loopB,
                    enabled: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Полоса перемотки: прогресс акцентом и рамка отрезка A–B.
class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.playback,
    required this.duration,
    required this.loopA,
    required this.loopB,
    required this.enabled,
  });

  final Playback? playback;
  final double duration;
  final double? loopA;
  final double? loopB;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = playback;
    final total = duration > 0 ? duration : 1.0;
    final position = p?.position ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seekTo(double dx) => p?.seek((dx / width).clamp(0, 1) * total);
        return Semantics(
          slider: true,
          value: formatDuration(position.floor()),
          increasedValue: formatDuration(
            (position + 10).clamp(0, total).floor(),
          ),
          decreasedValue: formatDuration(
            (position - 10).clamp(0, total).floor(),
          ),
          onIncrease: enabled ? () => p?.seek(position + 10) : null,
          onDecrease: enabled ? () => p?.seek(position - 10) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (d) => seekTo(d.localPosition.dx) : null,
            onHorizontalDragUpdate: enabled
                ? (d) => seekTo(d.localPosition.dx)
                : null,
            child: SizedBox(
              height: 24,
              child: CustomPaint(
                painter: _SeekPainter(
                  progress: position / total,
                  loopA: loopA == null ? null : loopA! / total,
                  loopB: loopB == null ? null : loopB! / total,
                  track: AppColors.dark.border,
                  accent: context.colors.accent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekPainter extends CustomPainter {
  _SeekPainter({
    required this.progress,
    required this.loopA,
    required this.loopB,
    required this.track,
    required this.accent,
  });

  final double progress;
  final double? loopA;
  final double? loopB;
  final Color track;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final bar = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(0, y), Offset(size.width, y), bar..color = track)
      ..drawLine(
        Offset(0, y),
        Offset(size.width * progress.clamp(0, 1), y),
        bar..color = accent,
      )
      ..drawCircle(
        Offset(size.width * progress.clamp(0, 1), y),
        6,
        Paint()..color = accent,
      );
    final a = loopA;
    if (a != null) {
      final outline = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final b = loopB;
      if (b == null) {
        canvas.drawLine(
          Offset(size.width * a, y - 7),
          Offset(size.width * a, y + 7),
          outline,
        );
      } else {
        canvas.drawRRect(
          RRect.fromLTRBR(
            size.width * a,
            y - 6,
            size.width * b,
            y + 6,
            const Radius.circular(3),
          ),
          outline,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.progress != progress || old.loopA != loopA || old.loopB != loopB;
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: AppSize.tapTarget,
            child: Center(
              child: Text(
                label,
                style: AppText.lessonTitle.copyWith(
                  color: selected ? c.accentOn : c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.accent : c.textPrimary;
    return Material(
      color: active
          ? Color.alphaBlend(c.accent.withValues(alpha: 0.16), c.surface)
          : c.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: SizedBox(
          height: AppSize.button,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: AppText.lessonTitle.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.album,
    required this.next,
    required this.unlocked,
    required this.onOpen,
    required this.onUnlock,
  });

  final Album album;
  final Lesson next;
  final bool unlocked;
  final VoidCallback onOpen;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Tile(
      radius: AppRadius.card,
      onTap: unlocked ? onOpen : onUnlock,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: album.cover.background,
              borderRadius: BorderRadius.circular(AppRadius.cover),
            ),
            child: Icon(
              unlocked ? AppIcons.play : AppIcons.lock,
              size: 22,
              color: album.cover.foreground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unlocked ? l10n.nextLesson : l10n.next,
                  style: AppText.caption.copyWith(color: c.textSecondary),
                ),
                Text(
                  next.title,
                  style: AppText.lessonTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!unlocked)
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSize.tapTarget),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: AppText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onUnlock,
              child: Text(l10n.unlockShort),
            )
          else
            Icon(AppIcons.chevronRight, color: c.textSecondary),
        ],
      ),
    );
  }
}
