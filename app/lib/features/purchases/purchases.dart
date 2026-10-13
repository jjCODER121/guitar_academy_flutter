import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:activation_key/activation_key.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/storage/preferences.dart';
import '../auth/auth.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';

class InvalidActivationKey implements Exception {
  const InvalidActivationKey();
}

class DeviceIdUnavailable implements Exception {
  const DeviceIdUnavailable();
}

/// Сервер временно не принимает ключи от этого ученика (защита от перебора).
class TooManyAttempts implements Exception {
  const TooManyAttempts();
}

/// Для активации нужен вход в аккаунт.
class NotSignedIn implements Exception {
  const NotSignedIn();
}

/// Постоянный номер устройства. На Android — Android ID: серийный номер
/// и IMEI с Android 10 обычным приложениям недоступны. В тестах подменяется.
abstract interface class DeviceIdSource {
  Future<String> rawId();
}

class PlatformDeviceIdSource implements DeviceIdSource {
  static const _channel = MethodChannel('guitar_school/device');

  @override
  Future<String> rawId() async {
    // iOS (identifierForVendor) — когда дойдём до App Store.
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw const DeviceIdUnavailable();
    }
    final id = await _channel.invokeMethod<String>('androidId');
    if (id == null || id.isEmpty) throw const DeviceIdUnavailable();
    return id;
  }
}

final deviceIdSourceProvider = Provider<DeviceIdSource>(
  (ref) => PlatformDeviceIdSource(),
);

/// Android ID, который система выдала именно этому приложению.
/// С Android 8 у каждого приложения (точнее, у каждого ключа подписи) он свой:
/// значение из настроек телефона или другой программы будет другим.
final rawDeviceIdProvider = FutureProvider<String>(
  (ref) => ref.watch(deviceIdSourceProvider).rawId(),
);

/// ID-код устройства для экрана активации (см. [deviceCode]).
/// Цифра в начале берётся из Android ID ([saltFor]), поэтому ID-код не меняется
/// ни между запусками, ни после переустановки — выданный ключ подходит снова.
/// Установки до 13.10.2026 выбрали цифру случайно и сохранили в настройках —
/// у них она остаётся прежней, чтобы не сломать уже выданные ключи.
final deviceCodeProvider = FutureProvider<String>((ref) async {
  final raw = await ref.watch(rawDeviceIdProvider.future);
  final saved = ref.watch(sharedPreferencesProvider).getInt('device_code_salt');
  return deviceCode(raw, saved ?? saltFor(raw));
});

/// Цифра 1–9 из Android ID: выглядит случайной, но для телефона всегда одна.
int saltFor(String rawDeviceId) {
  var hash = 0x811C9DC5; // FNV-1a
  for (final unit in rawDeviceId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash % 9 + 1;
}

/// Где проверяется ключ: на сервере ([SupabaseActivationRepository]);
/// в тестах — на устройстве.
abstract interface class ActivationRepository {
  /// Активации этого телефона, записанные в аккаунт: id продукта → ключ.
  /// У гостя — пусто.
  Future<Map<String, String>> activated(String deviceCode, List<Album> catalog);

  /// Проверяет ключ по продуктам [candidates] по порядку;
  /// возвращает id открытого продукта.
  Future<String> activate(
    String deviceCode,
    String key,
    List<Album> candidates,
  );
}

/// Сервер: функция `activate` проверяет ключ (формулы в приложении нет)
/// и записывает активацию в аккаунт — ученик + продукт + этот телефон.
/// Список своих активаций читается из таблицы `activations` (RLS — только свои).
class SupabaseActivationRepository implements ActivationRepository {
  SupabaseActivationRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<Map<String, String>> activated(
    String deviceCode,
    List<Album> catalog,
  ) async {
    if (_client.auth.currentUser == null) return {};
    final rows = await _client
        .from('activations')
        .select('product_id, activation_key')
        .eq('device_code', deviceCode)
        .timeout(const Duration(seconds: 15));
    return {
      for (final r in rows)
        r['product_id'] as String: r['activation_key'] as String,
    };
  }

  @override
  Future<String> activate(
    String deviceCode,
    String key,
    List<Album> candidates,
  ) async {
    if (_client.auth.currentUser == null) throw const NotSignedIn();
    try {
      final res = await _client.functions
          .invoke(
            'activate',
            body: {
              'device_code': deviceCode,
              'key': key,
              if (candidates.isNotEmpty) 'product_id': candidates.first.id,
            },
          )
          .timeout(const Duration(seconds: 20));
      return (res.data as Map<String, dynamic>)['product_id'] as String;
    } on sb.FunctionException catch (e) {
      final code = switch (e.details) {
        {'error': {'code': final String c}} => c,
        _ => '',
      };
      throw switch ((e.status, code)) {
        (_, 'invalid_key') => const InvalidActivationKey(),
        (429, _) || (_, 'too_many_attempts') => const TooManyAttempts(),
        (401, _) => const NotSignedIn(),
        _ => e,
      };
    }
  }
}

/// Для тестов: «сервер» на устройстве. Ключ проверяется формулой,
/// принятые ключи — «аккаунт» — лежат в настройках под `activations`.
class LocalActivationRepository implements ActivationRepository {
  LocalActivationRepository(this._prefs);

  static const _key = 'activations';
  final SharedPreferences _prefs;

  Map<String, String> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  @override
  Future<Map<String, String>> activated(
    String deviceCode,
    List<Album> catalog,
  ) async {
    final stored = _load();
    return {
      for (final album in catalog)
        if (stored[album.id] case final key?
            when verifyKey(
              deviceCode: deviceCode,
              courseNumber: album.activationNumber,
              key: key,
            ))
          album.id: key,
    };
  }

  @override
  Future<String> activate(
    String deviceCode,
    String key,
    List<Album> candidates,
  ) async {
    for (final album in candidates) {
      if (verifyKey(
        deviceCode: deviceCode,
        courseNumber: album.activationNumber,
        key: key,
      )) {
        await _prefs.setString(
          _key,
          jsonEncode({..._load(), album.id: normalizeKey(key)}),
        );
        return album.id;
      }
    }
    throw const InvalidActivationKey();
  }
}

final activationRepositoryProvider = Provider<ActivationRepository>(
  (ref) => SupabaseActivationRepository(sb.Supabase.instance.client),
);

/// Активации, сохранённые на телефоне навсегда: id продукта → ключ.
/// Ключ вводится один раз — дальше курс открыт при каждом запуске, без
/// интернета и без входа в аккаунт; выход из аккаунта их не стирает.
/// Записи привязаны к ID-коду: копия настроек на другом телефоне
/// (например, из резервной копии) там ничего не откроет.
class ActivationStore {
  ActivationStore(this._prefs);

  static const _key = 'device_activations';
  final SharedPreferences _prefs;

  Map<String, Map<String, String>> _all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      return {
        for (final MapEntry(:key, :value)
            in (jsonDecode(raw) as Map<String, dynamic>).entries)
          key: (value as Map<String, dynamic>).cast<String, String>(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Активации телефона с этим ID-кодом.
  Map<String, String> load(String deviceCode) => _all()[deviceCode] ?? {};

  /// Дописывает активации и возвращает все активации этого телефона.
  Future<Map<String, String>> add(
    String deviceCode,
    Map<String, String> activations,
  ) async {
    final all = _all();
    final mine = {...?all[deviceCode], ...activations};
    all[deviceCode] = mine;
    await _prefs.setString(_key, jsonEncode(all));
    return mine;
  }
}

final activationStoreProvider = Provider<ActivationStore>(
  (ref) => ActivationStore(ref.watch(sharedPreferencesProvider)),
);

/// id продуктов, открытых на этом устройстве.
final ownedProvider = AsyncNotifierProvider<OwnedController, Set<String>>(
  OwnedController.new,
);

class OwnedController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final user = ref.watch(authProvider);
    final String code;
    try {
      code = await ref.watch(deviceCodeProvider.future);
    } on DeviceIdUnavailable {
      return {};
    }
    // Сразу — то, что сохранено на телефоне; сеть не нужна.
    final saved = ref.watch(activationStoreProvider).load(code);
    if (user != null) Future.microtask(restoreFromAccount);
    return saved.keys.toSet();
  }

  /// Дописывает на телефон активации этого телефона из аккаунта
  /// (например, после переустановки). Ничего не убирает. Без сети
  /// просто ничего не меняется.
  Future<void> restoreFromAccount() async {
    try {
      await future; // сначала — сохранённое на телефоне (build)
      final code = await ref.read(deviceCodeProvider.future);
      final catalog = await ref.read(catalogProvider.future);
      final remote = await ref
          .read(activationRepositoryProvider)
          .activated(code, catalog);
      if (remote.isEmpty || !ref.mounted) return;
      final all = await ref.read(activationStoreProvider).add(code, remote);
      if (ref.mounted) state = AsyncData(all.keys.toSet());
    } catch (_) {
      // Нет сети или сервер недоступен — остаётся сохранённое на телефоне.
    }
  }

  /// Проверяет ключ. Сначала — для [preferred] (курс, с экрана которого
  /// активируют), затем для остальных. Возвращает id открытого продукта.
  /// Принятый ключ сразу сохраняется на телефоне.
  Future<String> activate(String key, {Album? preferred}) async {
    final code = await ref.read(deviceCodeProvider.future);
    final catalog = await ref.read(catalogProvider.future);
    final candidates = [
      ?preferred,
      for (final a in catalog)
        if (a.id != preferred?.id) a,
    ];
    final id = await ref
        .read(activationRepositoryProvider)
        .activate(code, key, candidates);
    final all = await ref.read(activationStoreProvider).add(code, {
      id: normalizeKey(key),
    });
    state = AsyncData(all.keys.toSet());
    return id;
  }
}

/// С чем просить у сервера ссылку на видео или PDF: ID-код телефона и
/// сохранённый ключ этого продукта. По ключу сервер выдаёт файлы и без
/// входа в аккаунт.
typedef MediaPass = ({String? deviceCode, String? key});

Future<MediaPass> mediaPass(Ref ref, String albumId) async {
  final String code;
  try {
    code = await ref.read(deviceCodeProvider.future);
  } on DeviceIdUnavailable {
    return (deviceCode: null, key: null);
  }
  final key = ref.read(activationStoreProvider).load(code)[albumId];
  return (deviceCode: code, key: key);
}

extension Ownership on Set<String> {
  /// Продукт открыт своим ключом. Ключ одного раздела другие не открывает.
  bool owns(Album album) => contains(album.id);

  bool canWatch(Album album, Lesson lesson) => owns(album) || lesson.hasPreview;
}
