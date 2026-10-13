import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/config/retry.dart';
import 'package:guitar_school/core/storage/preferences.dart';
import 'package:guitar_school/features/catalog/data/catalog_repository.dart';
import 'package:guitar_school/features/catalog/data/mock_catalog.dart';
import 'package:guitar_school/features/purchases/purchases.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Ключ, который приложение отправит серверу вместе с запросом видео.
Future<MediaPass> _passFor(String albumId, Map<String, String> saved) async {
  SharedPreferences.setMockInitialValues({
    'device_code_salt': 6,
    'device_activations': jsonEncode({testDeviceCode: saved}),
  });
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      catalogRepositoryProvider.overrideWithValue(
        MockCatalogRepository(latency: Duration.zero),
      ),
      deviceIdSourceProvider.overrideWithValue(
        const FakeDeviceIdSource(testDeviceId),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c.read(_passProvider(albumId).future);
}

final _passProvider = FutureProvider.family<MediaPass, String>(
  (ref, albumId) => mediaPass(ref, albumId),
);

void main() {
  test('видео курса — с ID-кодом и ключом этого курса', () async {
    final pass = await _passFor('course-basics', {'course-basics': 'KEY1'});
    expect(pass.deviceCode, testDeviceCode);
    expect(pass.key, 'KEY1');
  });

  test('ключ альбома не подходит для песни, проданной отдельно', () async {
    final pass = await _passFor('single-1', {'album-daler': 'KEY2'});
    expect(pass.key, isNull);
  });

  test('не активировано — без ключа', () async {
    final pass = await _passFor('single-3', {'album-daler': 'KEY2'});
    expect(pass.deviceCode, testDeviceCode);
    expect(pass.key, isNull);
  });
}
