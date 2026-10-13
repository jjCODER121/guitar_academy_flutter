import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../catalog/domain/catalog_models.dart';
import '../offline/offline_videos.dart';
import '../purchases/purchases.dart';
import 'media.dart';

/// Воспроизведение урока — то, что нужно экрану плеера.
/// [VideoPlayback] — настоящее видео; [TimerPlayback] — имитация для тестов.
abstract class Playback extends ChangeNotifier {
  /// Секунды от начала.
  double get position;

  /// Длительность в секундах (0 — пока неизвестна).
  double get duration;
  bool get playing;
  double get speed;
  bool get buffering => false;
  bool get atEnd => duration > 0 && position >= duration - 0.25;

  void play();
  void pause();
  void toggle() => playing ? pause() : play();
  void seek(double sec);
  void setSpeed(double value);

  /// Картинка видео.
  Widget view();
}

/// Видео по ссылке (HLS или MP4) через системный плеер (ExoPlayer на Android).
class VideoPlayback extends Playback {
  VideoPlayback._(this._c) {
    _c.addListener(notifyListeners);
  }

  static Future<VideoPlayback> network(String url) =>
      _open(VideoPlayerController.networkUrl(Uri.parse(url)));

  /// Видео, сохранённое на телефоне (расшифровывается на лету, только в приложении).
  static Future<VideoPlayback> saved(String uri) =>
      _open(VideoPlayerController.contentUri(Uri.parse(uri)));

  static Future<VideoPlayback> _open(VideoPlayerController c) async {
    try {
      await c.initialize().timeout(const Duration(seconds: 30));
    } catch (_) {
      await c.dispose();
      rethrow;
    }
    return VideoPlayback._(c);
  }

  final VideoPlayerController _c;

  @override
  double get position => _c.value.position.inMilliseconds / 1000;
  @override
  double get duration => _c.value.duration.inMilliseconds / 1000;
  @override
  bool get playing => _c.value.isPlaying;
  @override
  bool get buffering => _c.value.isBuffering;
  @override
  double get speed => _c.value.playbackSpeed;

  @override
  void play() {
    if (atEnd) _c.seekTo(Duration.zero);
    _c.play();
  }

  @override
  void pause() => _c.pause();

  @override
  void seek(double sec) => _c.seekTo(
    Duration(milliseconds: (sec.clamp(0, duration) * 1000).round()),
  );

  @override
  void setSpeed(double value) => _c.setPlaybackSpeed(value);

  @override
  Widget view() => Center(
    child: AspectRatio(
      aspectRatio: _c.value.aspectRatio,
      child: VideoPlayer(_c),
    ),
  );

  @override
  void dispose() {
    _c
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

/// Имитация по таймеру — для тестов и разработки без сети.
class TimerPlayback extends Playback {
  TimerPlayback({required int durationSec, double startAt = 0})
    : _duration = durationSec.toDouble(),
      _position = startAt.clamp(0, durationSec.toDouble());

  static const _tick = Duration(milliseconds: 250);

  final double _duration;
  double _position;
  bool _playing = false;
  double _speed = 1;
  Timer? _timer;

  @override
  double get position => _position;
  @override
  double get duration => _duration;
  @override
  bool get playing => _playing;
  @override
  double get speed => _speed;
  @override
  bool get atEnd => _position >= _duration;

  @override
  void play() {
    if (atEnd) _position = 0;
    _playing = true;
    _timer ??= Timer.periodic(_tick, (_) => _advance());
    notifyListeners();
  }

  @override
  void pause() {
    _playing = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void seek(double sec) {
    _position = sec.clamp(0, _duration);
    notifyListeners();
  }

  @override
  void setSpeed(double value) {
    _speed = value;
    notifyListeners();
  }

  void _advance() {
    _position += _tick.inMilliseconds / 1000 * _speed;
    if (atEnd) {
      _position = _duration;
      pause();
    } else {
      notifyListeners();
    }
  }

  @override
  Widget view() => const ColoredBox(color: Color(0xFF000000));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Как получить воспроизведение урока: копия на телефоне или ссылка с сервера.
/// В тестах подменяется на [TimerPlayback].
typedef PlaybackFactory = Future<Playback> Function(
  Lesson lesson,
  double startAt,
);

final playbackFactoryProvider = Provider<PlaybackFactory>((ref) {
  return (lesson, startAt) async {
    // Урок уже на телефоне — играем оттуда: без интернета и без трафика.
    final offline = ref.read(offlineProvider.notifier);
    if (await offline.playbackUri(lesson) case final uri?) {
      try {
        final playback = await VideoPlayback.saved(uri);
        if (startAt > 0) playback.seek(startAt);
        return playback;
      } catch (_) {
        await offline.forget(lesson.id); // копия повреждена — скачается заново
      }
    }
    final pass = await mediaPass(ref, lesson.albumId);
    final url = await ref
        .read(mediaRepositoryProvider)
        .lessonUrl(lesson.id, pass);
    final playback = await VideoPlayback.network(url);
    if (startAt > 0) playback.seek(startAt);
    return playback;
  };
});
