import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Запрет скриншотов и записи экрана (Android FLAG_SECURE) на экранах
/// с видео и PDF. Вне Android и в тестах просто ничего не делает.
abstract final class SecureScreen {
  static const _channel = MethodChannel('guitar_school/device');

  /// Только для проверки на эмуляторе: `--dart-define=ALLOW_SCREENSHOTS=true`.
  /// В сборках для учеников этот флаг не ставится.
  static const _allowScreenshots = bool.fromEnvironment('ALLOW_SCREENSHOTS');
  static int _holders = 0;

  /// Экран с платным контентом открыт.
  static Future<void> acquire() async {
    _holders += 1;
    if (_holders == 1) await _set(true);
  }

  /// Экран закрыт; флаг снимается, когда закрыт последний такой экран.
  static Future<void> release() async {
    if (_holders == 0) return;
    _holders -= 1;
    if (_holders == 0) await _set(false);
  }

  static Future<void> _set(bool on) async {
    if (_allowScreenshots) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } on MissingPluginException {
      // тесты
    } on PlatformException {
      // старая версия нативной части
    }
  }
}
