import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/config/retry.dart';
import 'package:guitar_school/core/storage/preferences.dart';
import 'package:guitar_school/features/auth/auth.dart';
import 'package:guitar_school/features/catalog/data/catalog_repository.dart';
import 'package:guitar_school/features/catalog/data/mock_catalog.dart';
import 'package:guitar_school/features/catalog/domain/catalog_models.dart';
import 'package:guitar_school/features/offline/offline_videos.dart';
import 'package:guitar_school/features/player/media.dart';
import 'package:guitar_school/features/progress/progress.dart';
import 'package:guitar_school/features/purchases/purchases.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Сервер ссылок: отдаёт адрес по id урока.
class _FakeMedia implements MediaRepository {
  const _FakeMedia();

  @override
  Future<String> lessonUrl(String lessonId, MediaPass pass) async =>
      'https://cdn/$lessonId';

  @override
  Future<String> materialUrl(String materialId, MediaPass pass) async =>
      'https://cdn/$materialId';
}

Lesson _lesson(String albumId, int order) =>
    mockAlbums.firstWhere((a) => a.id == albumId).lessons[order - 1];

/// Дать фоновой загрузке доработать.
Future<void> _idle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Приложение без экрана: курс «Гитара с нуля» активирован на телефоне.
Future<ProviderContainer> _app(
  FakeOfflineVideoStore store, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'device_code_salt': 6,
    'device_activations': jsonEncode({
      testDeviceCode: {'course-basics': 'KEY'},
    }),
    ...prefs,
  });
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      catalogRepositoryProvider.overrideWithValue(
        MockCatalogRepository(latency: Duration.zero),
      ),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(sp, latency: Duration.zero),
      ),
      deviceIdSourceProvider.overrideWithValue(
        const FakeDeviceIdSource(testDeviceId),
      ),
      activationRepositoryProvider.overrideWith(
        (ref) => LocalActivationRepository(sp),
      ),
      progressSyncProvider.overrideWithValue(const NoProgressSync()),
      mediaRepositoryProvider.overrideWithValue(const _FakeMedia()),
      offlineVideoStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(c.dispose);
  c.listen(offlineProvider, (_, _) {});
  await c.read(catalogProvider.future);
  await c.read(ownedProvider.future);
  await _idle();
  return c;
}

void _watchToEnd(ProviderContainer c, Lesson lesson) =>
    c.read(progressProvider.notifier).save(lesson, lesson.durationSec);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('досмотренный урок открытого курса сохраняется на телефон', () async {
    final store = FakeOfflineVideoStore();
    final c = await _app(store);
    final lesson = _lesson('course-basics', 2);

    _watchToEnd(c, lesson);
    await _idle();

    expect(store.downloads, ['https://cdn/course-basics-l2']);
    expect(c.read(offlineProvider).saved, {lesson.id: lesson.videoKey});
    expect(c.read(offlineProvider).bytes, 100 * 1024 * 1024);
    expect(
      await c.read(offlineProvider.notifier).playbackUri(lesson),
      'content://test.offline/v/course-basics-l2',
    );
  });

  test('недосмотренный урок и неоткрытый курс не скачиваются', () async {
    final store = FakeOfflineVideoStore();
    final c = await _app(store);

    c.read(progressProvider.notifier).save(_lesson('course-basics', 3), 60);
    _watchToEnd(
      c,
      _lesson('album-daler', 1),
    ); // бесплатная песня, альбом закрыт
    await _idle();

    expect(store.downloads, isEmpty);
    expect(
      await c
          .read(offlineProvider.notifier)
          .playbackUri(_lesson('course-basics', 3)),
      isNull,
    );
  });

  test('нет сети — урок ждёт в очереди и скачивается потом', () async {
    final store = FakeOfflineVideoStore()
      ..failWith = const SocketException('нет сети');
    final c = await _app(store);
    _watchToEnd(c, _lesson('course-basics', 1));
    await _idle();
    expect(store.files, isEmpty);

    store.failWith = null; // появился интернет (возврат в приложение)
    await c.read(offlineProvider.notifier).sync();
    await _idle();
    expect(store.files.keys, ['course-basics-l1']);
  });

  test('видео урока заменили — копия на телефоне обновляется', () async {
    final store = FakeOfflineVideoStore(files: {'course-basics-l1': 5});
    final c = await _app(
      store,
      prefs: {
        'offline_index': jsonEncode({'course-basics-l1': 'videos/old.mp4'}),
      },
    );

    expect(store.downloads, ['https://cdn/course-basics-l1']);
    expect(c.read(offlineProvider).saved, {
      'course-basics-l1': 'videos/course-basics-l1.mp4',
    });
  });

  test('«Удалить» стирает видео, и сами они не скачиваются', () async {
    final store = FakeOfflineVideoStore();
    final c = await _app(store);
    _watchToEnd(c, _lesson('course-basics', 1));
    await _idle();
    expect(store.files, isNotEmpty);

    await c.read(offlineProvider.notifier).deleteAll();
    await c.read(offlineProvider.notifier).sync();
    await _idle();

    expect(store.files, isEmpty);
    expect(store.downloads, hasLength(1));
    expect(c.read(offlineProvider).bytes, 0);
  });

  test('старый Android (до 8) — видео только из интернета', () async {
    final store = FakeOfflineVideoStore(isSupported: false);
    final c = await _app(store);
    _watchToEnd(c, _lesson('course-basics', 1));
    await _idle();
    expect(store.downloads, isEmpty);
  });

  testWidgets('Профиль: «Видео на телефоне» — размер и удаление', (
    tester,
  ) async {
    final store = FakeOfflineVideoStore(
      files: {'course-basics-l1': 350 * 1024 * 1024},
    );
    await pumpApp(
      tester,
      offlineStore: store,
      prefs: {
        'device_activations': jsonEncode({
          testDeviceCode: {'course-basics': 'KEY'},
        }),
        'offline_index': jsonEncode({
          'course-basics-l1': 'videos/course-basics-l1.mp4',
        }),
      },
    );
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Видео на телефоне'), findsOneWidget);
    expect(find.text('350 МБ'), findsOneWidget);

    await tester.tap(find.text('Видео на телефоне'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить видео с телефона?'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(store.files, isEmpty);
    expect(find.text('Видео на телефоне'), findsNothing);
  });
}
