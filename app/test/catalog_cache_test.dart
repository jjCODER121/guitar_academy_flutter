import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/config/retry.dart';
import 'package:guitar_school/features/catalog/data/catalog_repository.dart';
import 'package:guitar_school/features/catalog/data/mock_catalog.dart';
import 'package:guitar_school/features/catalog/data/supabase_catalog.dart';
import 'package:guitar_school/features/catalog/domain/catalog_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Сервер, который отвечает тем, что ему дали (или не отвечает вовсе).
class _FakeRepo implements CatalogRepository {
  _FakeRepo({this.saved, required this.fresh});

  final List<Album>? saved;
  final Future<List<Album>> Function() fresh;

  @override
  Future<List<Album>> albums() => fresh();

  @override
  List<Album>? cached() => saved;
}

ProviderContainer _container(CatalogRepository repo) {
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [catalogRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'сохранённый каталог показывается сразу, даже если сервер молчит',
    () async {
      final never = Completer<List<Album>>();
      final c = _container(
        _FakeRepo(saved: mockAlbums, fresh: () => never.future),
      );
      expect(await c.read(catalogProvider.future), mockAlbums);
    },
  );

  test('свежий каталог с сервера заменяет сохранённый', () async {
    final fresh = mockAlbums.take(1).toList();
    final c = _container(
      _FakeRepo(saved: mockAlbums, fresh: () async => fresh),
    );
    c.listen(catalogProvider, (_, _) {});
    expect(await c.read(catalogProvider.future), mockAlbums);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(catalogProvider).value, fresh);
  });

  test('без сети остаётся сохранённый каталог', () async {
    final c = _container(
      _FakeRepo(
        saved: mockAlbums,
        fresh: () async => throw TimeoutException(''),
      ),
    );
    c.listen(catalogProvider, (_, _) {});
    await c.read(catalogProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(catalogProvider).value, mockAlbums);
    expect(c.read(catalogProvider).hasError, isFalse);
  });

  test('первый запуск без сети — ошибка (на экране «Повторить»)', () async {
    final c = _container(
      _FakeRepo(fresh: () async => throw TimeoutException('')),
    );
    await expectLater(
      c.read(catalogProvider.future),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('каталог читается из настроек телефона', () async {
    SharedPreferences.setMockInitialValues({
      'catalog_cache_v1': jsonEncode({
        'products': [
          {
            'id': 'p1',
            'type': 'course',
            'title': 'Гитара с нуля',
            'subtitle': '',
            'level': 'beginner',
            'activation_number': 1,
            'cover_path': null,
            'lessons': [],
            'materials': [],
          },
        ],
        'links': [],
      }),
    });
    final repo = SupabaseCatalogRepository(
      SupabaseClient('https://example.supabase.co', 'test'),
      await SharedPreferences.getInstance(),
    );
    expect(repo.cached()?.single.title, 'Гитара с нуля');
  });

  test('повреждённый кэш не ломает запуск', () async {
    SharedPreferences.setMockInitialValues({'catalog_cache_v1': '{oops'});
    final repo = SupabaseCatalogRepository(
      SupabaseClient('https://example.supabase.co', 'test'),
      await SharedPreferences.getInstance(),
    );
    expect(repo.cached(), isNull);
  });
}
