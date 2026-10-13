import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/preferences.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../player/media.dart';
import '../progress/progress.dart';
import '../purchases/purchases.dart';

/// Где лежат видео для просмотра без интернета. На Android — зашифрованные
/// файлы в закрытой папке приложения (`OfflineVideos.kt`), плеер читает их
/// через `content://` с расшифровкой на лету. В тестах — подмена.
abstract interface class OfflineVideoStore {
  /// На этом телефоне можно хранить видео (Android 8 и новее).
  Future<bool> supported();

  /// Сохранённые уроки: id → размер видео в байтах.
  Future<Map<String, int>> saved();

  /// Скачивает и шифрует видео; прерванная загрузка продолжается с того же места.
  Future<void> download(
    String lessonId,
    String url, {
    void Function(int received, int total)? onProgress,
  });

  /// Адрес сохранённого видео для плеера — открывается только внутри приложения.
  Future<String> playbackUri(String lessonId);

  Future<void> delete(String lessonId);
  Future<void> deleteAll();
}

class PlatformOfflineVideoStore implements OfflineVideoStore {
  PlatformOfflineVideoStore() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final args = (call.arguments as Map).cast<String, Object?>();
      _listeners[args['lessonId']]?.call(
        args['received'] as int,
        args['total'] as int,
      );
    });
  }

  static const _channel = MethodChannel('guitar_school/offline');
  final _listeners = <Object?, void Function(int, int)>{};

  @override
  Future<bool> supported() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Map<String, int>> saved() async =>
      await _channel.invokeMapMethod<String, int>('saved') ?? {};

  @override
  Future<void> download(
    String lessonId,
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (onProgress != null) _listeners[lessonId] = onProgress;
    try {
      await _channel.invokeMethod<void>('download', {
        'lessonId': lessonId,
        'url': url,
      });
    } finally {
      _listeners.remove(lessonId);
    }
  }

  @override
  Future<String> playbackUri(String lessonId) async =>
      (await _channel.invokeMethod<String>('uri', {'lessonId': lessonId}))!;

  @override
  Future<void> delete(String lessonId) =>
      _channel.invokeMethod<void>('delete', {'lessonId': lessonId});

  @override
  Future<void> deleteAll() => _channel.invokeMethod<void>('deleteAll');
}

final offlineVideoStoreProvider = Provider<OfflineVideoStore>(
  (ref) => PlatformOfflineVideoStore(),
);

@immutable
class OfflineState {
  const OfflineState({
    this.saved = const {},
    this.bytes = 0,
    this.downloading,
    this.progress = 0,
  });

  /// Сохранённые уроки: id → версия видео (`Lesson.videoKey`).
  final Map<String, String> saved;

  /// Сколько места занимают.
  final int bytes;

  /// Урок, который скачивается сейчас, и доля скачанного (0–1).
  final String? downloading;
  final double progress;
}

/// Видео без интернета. Досмотренный до конца урок открытого курса скачивается
/// в фоне (по любой сети) и дальше играет с телефона — без интернета и без
/// повторной загрузки. Видео заменили на сервере — копия обновится.
final offlineProvider = NotifierProvider<OfflineController, OfflineState>(
  OfflineController.new,
);

class OfflineController extends Notifier<OfflineState> {
  /// id урока → версия сохранённого видео.
  static const _indexKey = 'offline_index';

  /// Досмотренные уроки, которые ещё предстоит скачать (по порядку).
  static const _queueKey = 'offline_queue';

  bool _running = false;
  bool _again = false;

  /// Растёт при «Удалить всё»: загрузка, начатая до этого, не сохраняется.
  int _generation = 0;

  @override
  OfflineState build() {
    ref.listen(progressProvider, _onProgress);
    ref.listen(catalogProvider, (_, _) => sync());
    ref.listen(ownedProvider, (_, _) => sync());
    // Вернулись в приложение (возможно, уже с интернетом) — продолжить.
    final lifecycle = AppLifecycleListener(onResume: sync);
    ref.onDispose(lifecycle.dispose);
    Future.microtask(sync);
    return OfflineState(saved: _index());
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Map<String, String> _index() {
    final raw = _prefs.getString(_indexKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  List<String> _queue() => _prefs.getStringList(_queueKey) ?? [];

  Future<void> _store(Map<String, String> index, List<String> queue) async {
    await _prefs.setString(_indexKey, jsonEncode(index));
    await _prefs.setStringList(_queueKey, queue);
  }

  Map<String, Lesson>? _lessons() {
    final catalog = ref.read(catalogProvider).value;
    if (catalog == null) return null;
    return {
      for (final album in catalog)
        for (final lesson in album.lessons) lesson.id: lesson,
    };
  }

  /// Урок досмотрен до конца — поставить в очередь на скачивание.
  void _onProgress(
    Map<String, LessonProgress>? previous,
    Map<String, LessonProgress> next,
  ) {
    final lessons = _lessons();
    if (lessons == null) return;
    final finished = [
      for (final MapEntry(key: id, value: p) in next.entries)
        if (!identical(previous?[id], p))
          if (lessons[id] case final lesson?
              when lesson.durationSec > 0 &&
                  p.positionSec >=
                      lesson.durationSec - ProgressController.tailSec)
            id,
    ];
    final queue = _queue();
    final added = finished.where((id) => !queue.contains(id)).toList();
    if (added.isEmpty) return;
    _prefs.setStringList(_queueKey, [...queue, ...added]).then((_) => sync());
  }

  /// Скачивает очередь по одному уроку. Нет сети или места — останавливается
  /// и продолжает при следующем запуске, возврате в приложение или просмотре.
  Future<void> sync() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again && ref.mounted);
    } catch (_) {
      // Повторим позже.
    } finally {
      _running = false;
      if (ref.mounted && state.downloading != null) {
        state = OfflineState(saved: state.saved, bytes: state.bytes);
      }
    }
  }

  Future<void> _syncOnce() async {
    final store = ref.read(offlineVideoStoreProvider);
    if (!await store.supported()) return;
    final catalog = ref.read(catalogProvider).value;
    final owned = ref.read(ownedProvider).value;
    final lessons = _lessons();
    if (catalog == null || owned == null || lessons == null || !ref.mounted) {
      return;
    }
    final generation = _generation;

    // Сверить телефон с каталогом: видео заменили — скачать заново,
    // урок убрали — удалить копию.
    var files = await store.saved();
    final index = _index()..removeWhere((id, _) => !files.containsKey(id));
    final queue = _queue();
    for (final id in files.keys) {
      final lesson = lessons[id];
      final version = index[id];
      if (lesson?.videoKey != null && version == lesson!.videoKey) continue;
      await store.delete(id);
      index.remove(id);
      if (lesson?.videoKey != null && version != null && !queue.contains(id)) {
        queue.add(id);
      }
    }
    await _store(index, queue);
    files = await store.saved();
    _publish(index, files);

    for (final id in [...queue]) {
      if (!ref.mounted || generation != _generation) return;
      final lesson = lessons[id];
      final album = catalog.where((a) => a.id == lesson?.albumId).firstOrNull;
      final wanted =
          lesson?.videoKey != null &&
          album != null &&
          owned.owns(album) &&
          index[id] != lesson!.videoKey;
      if (!wanted) {
        queue.remove(id);
        await _store(index, queue);
        continue;
      }

      state = OfflineState(
        saved: state.saved,
        bytes: state.bytes,
        downloading: id,
      );
      try {
        final pass = await mediaPass(ref, lesson.albumId);
        final url = await ref.read(mediaRepositoryProvider).lessonUrl(id, pass);
        await store.download(
          id,
          url,
          onProgress: (received, total) {
            if (ref.mounted && total > 0 && state.downloading == id) {
              state = OfflineState(
                saved: state.saved,
                bytes: state.bytes,
                downloading: id,
                progress: received / total,
              );
            }
          },
        );
      } on MediaLocked {
        queue.remove(id); // сервер не выдаёт этот урок — не пытаться снова
        await _store(index, queue);
        continue;
      } on MediaMissing {
        queue.remove(id);
        await _store(index, queue);
        continue;
      }
      if (!ref.mounted) return;
      if (generation != _generation) {
        await store.delete(id); // пока качалось, нажали «Удалить»
        return;
      }
      index[id] = lesson.videoKey!;
      queue.remove(id);
      await _store(index, queue);
      _publish(index, await store.saved());
    }
  }

  void _publish(Map<String, String> index, Map<String, int> files) {
    if (!ref.mounted) return;
    state = OfflineState(
      saved: Map.unmodifiable(index),
      bytes: files.entries
          .where((e) => index.containsKey(e.key))
          .fold(0, (sum, e) => sum + e.value),
      downloading: state.downloading,
      progress: state.progress,
    );
  }

  /// Адрес видео урока на телефоне, если оно сохранено и не устарело.
  Future<String?> playbackUri(Lesson lesson) async {
    if (lesson.videoKey == null || state.saved[lesson.id] != lesson.videoKey) {
      return null;
    }
    return ref.read(offlineVideoStoreProvider).playbackUri(lesson.id);
  }

  /// Сохранённая копия не открылась — удалить и скачать заново.
  Future<void> forget(String lessonId) async {
    await ref.read(offlineVideoStoreProvider).delete(lessonId);
    final index = _index()..remove(lessonId);
    final queue = _queue();
    if (!queue.contains(lessonId)) queue.add(lessonId);
    await _store(index, queue);
    if (ref.mounted) {
      state = OfflineState(saved: Map.unmodifiable(index), bytes: state.bytes);
    }
  }

  /// «Удалить видео с телефона»: уроки снова будут идти из интернета
  /// и скачаются, только если досмотреть их до конца ещё раз.
  Future<void> deleteAll() async {
    _generation++;
    await ref.read(offlineVideoStoreProvider).deleteAll();
    await _store({}, []);
    if (ref.mounted) state = const OfflineState();
  }
}
