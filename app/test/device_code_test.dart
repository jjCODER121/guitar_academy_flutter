import 'package:activation_key/activation_key.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/config/retry.dart';
import 'package:guitar_school/core/storage/preferences.dart';
import 'package:guitar_school/features/purchases/purchases.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// ID-код на «свежей установке» с такими настройками.
Future<String> _codeAfterInstall(
  String rawId, [
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      deviceIdSourceProvider.overrideWithValue(FakeDeviceIdSource(rawId)),
    ],
  );
  addTearDown(c.dispose);
  return c.read(deviceCodeProvider.future);
}

void main() {
  test('после переустановки ID-код тот же — старый ключ подходит', () async {
    final first = await _codeAfterInstall('1e6aea8ff209dabf');
    final again = await _codeAfterInstall('1e6aea8ff209dabf');
    expect(again, first);
    expect(first, deviceCode('1e6aea8ff209dabf', saltFor('1e6aea8ff209dabf')));
  });

  test('цифра из Android ID — от 1 до 9 и разная у разных телефонов', () {
    final salts = {for (var i = 0; i < 200; i++) saltFor('android-$i')};
    expect(salts.every((s) => s >= 1 && s <= 9), isTrue);
    expect(salts.length, 9);
  });

  test('цифра, выбранная раньше случайно, сохраняется (пример ТЗ)', () async {
    expect(
      await _codeAfterInstall(testDeviceId, {'device_code_salt': 6}),
      testDeviceCode,
    );
  });
}
