import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/images/cover_cache.dart';
import '../../../core/storage/preferences.dart';
import '../domain/catalog_models.dart';
import 'supabase_catalog.dart';

/// Источник каталога: Supabase ([SupabaseCatalogRepository]);
/// в тестах — тестовые данные (`MockCatalogRepository`).
abstract interface class CatalogRepository {
  /// Свежий каталог с сервера.
  Future<List<Album>> albums();

  /// Каталог, сохранённый на телефоне при прошлой загрузке (или null).
  List<Album>? cached();
}

class AlbumNotFound implements Exception {
  const AlbumNotFound(this.id);

  final String id;

  @override
  String toString() => 'AlbumNotFound($id)';
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => SupabaseCatalogRepository(
    Supabase.instance.client,
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Каталог. Если он уже сохранён на телефоне — показывается сразу (даже без
/// интернета), а свежий загружается в фоне. Первый запуск ждёт сервер
/// ограниченное время, затем — «Не удалось загрузить» и «Повторить».
final catalogProvider = AsyncNotifierProvider<CatalogController, List<Album>>(
  CatalogController.new,
);

class CatalogController extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() async {
    final repo = ref.watch(catalogRepositoryProvider);
    final saved = repo.cached();
    if (saved != null) {
      Future.microtask(() => _refreshQuietly(repo));
      return saved;
    }
    return _keepCovers(await repo.albums());
  }

  /// Свежий каталог: его обложки — заранее на телефон (для работы без сети).
  List<Album> _keepCovers(List<Album> albums) {
    unawaited(
      ref.read(coverCacheProvider).sync([
        for (final album in albums) ?album.coverUrl,
      ]),
    );
    return albums;
  }

  Future<void> _refreshQuietly(CatalogRepository repo) async {
    try {
      final fresh = _keepCovers(await repo.albums());
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      // Нет сети — остаёмся на сохранённом каталоге.
    }
  }

  /// «Потянуть вниз, чтобы обновить»: ждёт сервер, ошибку отдаёт вызывающему.
  Future<void> refresh() async {
    final fresh = _keepCovers(
      await ref.read(catalogRepositoryProvider).albums(),
    );
    if (ref.mounted) state = AsyncData(fresh);
  }
}

/// Продукт из уже загруженного каталога — экран открывается без нового запроса.
final albumProvider = FutureProvider.family<Album, String>((ref, id) async {
  final albums = await ref.watch(catalogProvider.future);
  return albums.firstWhere(
    (a) => a.id == id,
    orElse: () => throw AlbumNotFound(id),
  );
});
