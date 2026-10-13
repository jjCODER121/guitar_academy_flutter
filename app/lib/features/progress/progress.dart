import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/storage/preferences.dart';
import '../auth/auth.dart';
import '../catalog/domain/catalog_models.dart';

class LessonProgress {
  const LessonProgress({
    required this.positionSec,
    required this.completed,
    required this.updatedAt,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
    positionSec: json['p'] as int,
    completed: json['c'] as bool,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['u'] as int),
  );

  final int positionSec;
  final bool completed;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'p': positionSec,
    'c': completed,
    'u': updatedAt.millisecondsSinceEpoch,
  };
}

/// Отправка прогресса в аккаунт (таблица `lesson_progress`, RLS — только свои строки).
abstract interface class ProgressSync {
  Future<void> push(String lessonId, int positionSec, bool completed);
}

class SupabaseProgressSync implements ProgressSync {
  SupabaseProgressSync(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<void> push(String lessonId, int positionSec, bool completed) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('lesson_progress').upsert({
      'user_id': user.id,
      'lesson_id': lessonId,
      'position_sec': positionSec,
      'completed': completed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// Для тестов и гостей: ничего не отправляет.
class NoProgressSync implements ProgressSync {
  const NoProgressSync();

  @override
  Future<void> push(String lessonId, int positionSec, bool completed) async {}
}

final progressSyncProvider = Provider<ProgressSync>(
  (ref) => SupabaseProgressSync(sb.Supabase.instance.client),
);

/// Прогресс просмотра по id урока: хранится на устройстве (работает без сети)
/// и отправляется в аккаунт, если ученик вошёл.
final progressProvider =
    NotifierProvider<ProgressController, Map<String, LessonProgress>>(
      ProgressController.new,
    );

class ProgressController extends Notifier<Map<String, LessonProgress>> {
  /// Урок считается пройденным, если до конца осталось меньше этого.
  static const tailSec = 5;

  /// Прогресс у каждого пользователя свой; у гостя — отдельный.
  late String _key;

  @override
  Map<String, LessonProgress> build() {
    _key = 'progress_${ref.watch(authProvider)?.email ?? 'guest'}';
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (id, v) =>
          MapEntry(id, LessonProgress.fromJson(v as Map<String, dynamic>)),
    );
  }

  void save(Lesson lesson, int positionSec) {
    // Плеер сохраняет позицию и при закрытии — к этому моменту провайдер
    // мог пересоздаться (смена пользователя) или приложение закрыться.
    if (!ref.mounted) return;
    final previous = state[lesson.id];
    final completed =
        (previous?.completed ?? false) ||
        positionSec >= lesson.durationSec - tailSec;
    state = {
      ...state,
      lesson.id: LessonProgress(
        positionSec: positionSec,
        completed: completed,
        updatedAt: DateTime.now(),
      ),
    };
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))),
        );
    // В аккаунт — без ожидания: нет сети — сохранится в следующий раз.
    ref
        .read(progressSyncProvider)
        .push(lesson.id, positionSec, completed)
        .catchError((Object _) {});
  }
}

extension ProgressStats on Map<String, LessonProgress> {
  int completedIn(Album album) =>
      album.lessons.where((l) => this[l.id]?.completed ?? false).length;

  bool startedAny(Album album) => album.lessons.any((l) => containsKey(l.id));

  /// Последний просмотренный урок среди переданных продуктов.
  (Album, Lesson)? lastWatched(List<Album> albums) {
    (Album, Lesson)? best;
    DateTime? bestAt;
    for (final album in albums) {
      for (final lesson in album.lessons) {
        final p = this[lesson.id];
        if (p != null && (bestAt == null || p.updatedAt.isAfter(bestAt))) {
          best = (album, lesson);
          bestAt = p.updatedAt;
        }
      }
    }
    return best;
  }

  /// Первый непройденный урок — с него «Смотреть» продолжает альбом.
  Lesson firstUnfinished(Album album) => album.lessons.firstWhere(
    (l) => !(this[l.id]?.completed ?? false),
    orElse: () => album.lessons.first,
  );

  /// Сколько секунд просмотрено всего — для «практики» в профиле.
  int watchedSeconds(List<Album> albums) {
    var total = 0;
    for (final album in albums) {
      for (final lesson in album.lessons) {
        final p = this[lesson.id];
        if (p == null) continue;
        total += p.completed ? lesson.durationSec : p.positionSec;
      }
    }
    return total;
  }
}
