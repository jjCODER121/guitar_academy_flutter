import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog_models.dart';
import 'catalog_repository.dart';

/// Каталог из Supabase: только опубликованные продукты (так же ограничивает RLS).
/// Цен здесь нет — в приложении их не показываем.
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client, this._prefs);

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  /// Сколько ждать сервер, прежде чем показать ошибку.
  static const timeout = Duration(seconds: 15);
  static const _cacheKey = 'catalog_cache_v1';

  static const _select =
      'id, type, title, subtitle, level, activation_number, cover_path, '
      'lessons(id, position, title, duration_sec, is_free_preview, preview_limit_sec, video_key), '
      'materials(id, title, lesson_id, position)';

  @override
  Future<List<Album>> albums() async {
    final rows = await _client
        .from('products')
        .select(_select)
        .eq('is_published', true)
        .order('sort_order', ascending: true)
        .order('position', ascending: true, referencedTable: 'lessons')
        .order('position', ascending: true, referencedTable: 'materials')
        .timeout(timeout);
    final albums = _map(rows);
    await _prefs.setString(_cacheKey, jsonEncode({'products': rows}));
    return albums;
  }

  @override
  List<Album>? cached() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _map((json['products'] as List).cast<Map<String, dynamic>>());
    } catch (_) {
      return null; // повреждён или старый формат — загрузим заново
    }
  }

  List<Album> _map(List<Map<String, dynamic>> rows) => [
    for (final row in rows) albumFromRow(row, _coverUrl),
  ];

  String? _coverUrl(String? path) =>
      path == null ? null : _client.storage.from('covers').getPublicUrl(path);
}

/// Цвета обложки-заглушки, пока у продукта нет фото: свои для каждого номера.
const _placeholders = [
  CoverPlaceholder(Color(0xFF2B3A35), Color(0xFFA9C7BC)),
  CoverPlaceholder(Color(0xFF3A2A1A), Color(0xFFE8C08A)),
  CoverPlaceholder(Color(0xFF3B2430), Color(0xFFE3AFC4)),
  CoverPlaceholder(Color(0xFF33291F), Color(0xFFE0A040)),
  CoverPlaceholder(Color(0xFF2A2F24), Color(0xFFB7C98A)),
  CoverPlaceholder(Color(0xFF2E2638), Color(0xFFC3AEE0)),
];

AlbumType _type(String s) => switch (s) {
  'song_album' => AlbumType.songAlbum,
  'single' => AlbumType.single,
  _ => AlbumType.course,
};

Level _level(String s) => switch (s) {
  'intermediate' => Level.intermediate,
  'advanced' => Level.advanced,
  _ => Level.beginner,
};

/// Строка из Supabase → модель приложения. Отдельно — чтобы проверить тестом без сети.
Album albumFromRow(
  Map<String, dynamic> row,
  String? Function(String? path) coverUrl,
) {
  final id = row['id'] as String;
  final number = row['activation_number'] as int;
  final materialRows = (row['materials'] as List).cast<Map<String, dynamic>>();
  final lessonRows = (row['lessons'] as List).cast<Map<String, dynamic>>();
  return Album(
    id: id,
    type: _type(row['type'] as String),
    title: row['title'] as String,
    subtitle: row['subtitle'] as String? ?? '',
    level: _level(row['level'] as String? ?? ''),
    activationNumber: number,
    coverUrl: coverUrl(row['cover_path'] as String?),
    cover: _placeholders[number % _placeholders.length],
    lessons: [
      for (final l in lessonRows)
        Lesson(
          id: l['id'] as String,
          albumId: id,
          order: l['position'] as int,
          title: l['title'] as String,
          durationSec: l['duration_sec'] as int? ?? 0,
          isFreePreview: l['is_free_preview'] as bool? ?? false,
          previewLimitSec: l['preview_limit_sec'] as int?,
          videoKey: l['video_key'] as String?,
          materialId: materialRows
              .where((m) => m['lesson_id'] == l['id'])
              .map((m) => m['id'] as String)
              .firstOrNull,
        ),
    ],
    materials: [
      for (final m in materialRows)
        StudyMaterial(
          id: m['id'] as String,
          albumId: id,
          title: m['title'] as String,
          lessonId: m['lesson_id'] as String?,
          pages: 0,
        ),
    ],
  );
}
