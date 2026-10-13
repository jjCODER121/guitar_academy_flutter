import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/app.dart';
import 'package:guitar_school/core/config/distribution.dart';
import 'package:guitar_school/core/config/retry.dart';
import 'package:guitar_school/core/storage/preferences.dart';
import 'package:guitar_school/features/auth/auth.dart';
import 'package:guitar_school/features/catalog/data/catalog_repository.dart';
import 'package:guitar_school/features/catalog/data/mock_catalog.dart';
import 'package:guitar_school/features/catalog/domain/catalog_models.dart';
import 'package:guitar_school/features/offline/offline_videos.dart';
import 'package:guitar_school/features/player/playback.dart';
import 'package:guitar_school/features/progress/progress.dart';
import 'package:guitar_school/features/purchases/purchases.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android ID тестового телефона — пример серийного номера из ТЗ.
const testDeviceId = 'R5CR319NT7N';

/// С солью 6 код устройства — `41702419138135816` (пример из ТЗ).
const testDeviceCode = '41702419138135816';

class FakeDeviceIdSource implements DeviceIdSource {
  const FakeDeviceIdSource(this.id);

  final String id;

  @override
  Future<String> rawId() async => id;
}

/// «Сервер» активаций без сети: любой запрос падает по таймауту.
class OfflineActivationServer implements ActivationRepository {
  const OfflineActivationServer();

  @override
  Future<Map<String, String>> activated(
    String deviceCode,
    List<Album> catalog,
  ) => Future.error(TimeoutException('нет сети'));

  @override
  Future<String> activate(
    String deviceCode,
    String key,
    List<Album> candidates,
  ) => Future.error(TimeoutException('нет сети'));
}

/// Хранилище видео на телефоне в памяти.
class FakeOfflineVideoStore implements OfflineVideoStore {
  FakeOfflineVideoStore({this.isSupported = true, Map<String, int>? files})
    : files = files ?? {};

  final bool isSupported;

  /// Сохранённые уроки: id → размер.
  final Map<String, int> files;

  /// Ссылки, по которым скачивали.
  final downloads = <String>[];

  /// Если задано — загрузка падает с этой ошибкой (нет сети).
  Object? failWith;

  @override
  Future<bool> supported() async => isSupported;

  @override
  Future<Map<String, int>> saved() async => Map.of(files);

  @override
  Future<void> download(
    String lessonId,
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (failWith case final error?) throw error;
    onProgress?.call(50, 100);
    downloads.add(url);
    files[lessonId] = 100 * 1024 * 1024;
  }

  @override
  Future<String> playbackUri(String lessonId) async =>
      'content://test.offline/v/$lessonId';

  @override
  Future<void> delete(String lessonId) async => files.remove(lessonId);

  @override
  Future<void> deleteAll() async => files.clear();
}

/// Запускает приложение на экране телефона 390×844 с тестовыми данными
/// без задержек. По умолчанию онбординг пройден, код устройства —
/// [testDeviceCode]. [prefs] дополняют настройки по умолчанию.
Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('ru'),
  Map<String, Object> prefs = const {},
  bool onboardingSeen = true,
  String deviceId = testDeviceId,
  Distribution distribution = Distribution.googlePlay,
  ActivationRepository Function(SharedPreferences prefs)? activationServer,
  OfflineVideoStore? offlineStore,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  SharedPreferences.setMockInitialValues({
    'onboarding_seen': onboardingSeen,
    'device_code_salt': 6,
    ...prefs,
  });
  final sp = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        catalogRepositoryProvider.overrideWithValue(
          MockCatalogRepository(latency: Duration.zero),
        ),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(sp, latency: Duration.zero),
        ),
        deviceIdSourceProvider.overrideWithValue(FakeDeviceIdSource(deviceId)),
        distributionProvider.overrideWithValue(distribution),
        activationRepositoryProvider.overrideWith(
          (ref) => (activationServer ?? LocalActivationRepository.new)(sp),
        ),
        playbackFactoryProvider.overrideWithValue(
          (lesson, startAt) async =>
              TimerPlayback(durationSec: lesson.durationSec, startAt: startAt),
        ),
        progressSyncProvider.overrideWithValue(const NoProgressSync()),
        offlineVideoStoreProvider.overrideWithValue(
          offlineStore ?? FakeOfflineVideoStore(isSupported: false),
        ),
      ],
      child: const GuitarSchoolApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Плеер крутит таймер, поэтому pumpAndSettle на нём не завершится.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
