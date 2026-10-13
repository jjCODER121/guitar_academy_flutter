import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../purchases/purchases.dart';

/// Курс не активирован на этом телефоне — сервер ссылку не дал.
class MediaLocked implements Exception {
  const MediaLocked();
}

/// Файла нет (урок не найден или видео ещё не загружено).
class MediaMissing implements Exception {
  const MediaMissing();
}

/// Временные ссылки на видео и PDF (живут 2 часа). Выдаёт сервер — функция
/// `media-url` — только если урок бесплатный или курс активирован на этом
/// телефоне (по аккаунту или по сохранённому ключу из [MediaPass]).
abstract interface class MediaRepository {
  Future<String> lessonUrl(String lessonId, MediaPass pass);
  Future<String> materialUrl(String materialId, MediaPass pass);
}

class SupabaseMediaRepository implements MediaRepository {
  SupabaseMediaRepository(this._client);

  final sb.SupabaseClient _client;

  Future<String> _url(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions
          .invoke('media-url', body: body)
          .timeout(const Duration(seconds: 20));
      return (res.data as Map<String, dynamic>)['url'] as String;
    } on sb.FunctionException catch (e) {
      throw switch (e.status) {
        401 || 403 => const MediaLocked(),
        404 => const MediaMissing(),
        _ => e,
      };
    }
  }

  @override
  Future<String> lessonUrl(String lessonId, MediaPass pass) => _url({
    'lesson_id': lessonId,
    'device_code': ?pass.deviceCode,
    'key': ?pass.key,
  });

  @override
  Future<String> materialUrl(String materialId, MediaPass pass) => _url({
    'material_id': materialId,
    'device_code': ?pass.deviceCode,
    'key': ?pass.key,
  });
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => SupabaseMediaRepository(sb.Supabase.instance.client),
);
