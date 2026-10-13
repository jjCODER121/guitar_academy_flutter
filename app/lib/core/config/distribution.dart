import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Как распространяется сборка. Задаётся при сборке:
///   flutter build apk ... --dart-define=DISTRIBUTION=direct
/// Без флага — версия для Google Play.
enum Distribution {
  /// Google Play: внутри приложения нельзя направлять к оплате в обход
  /// Google — никаких подсказок «напишите / позвоните, чтобы купить».
  googlePlay,

  /// APK для прямой раздачи (WhatsApp, Telegram, сайт): правила Google Play
  /// не действуют, в окне активации есть кнопки «WhatsApp» и «Позвонить».
  direct;

  static const current = String.fromEnvironment('DISTRIBUTION') == 'direct'
      ? direct
      : googlePlay;
}

/// Подменяется в тестах.
final distributionProvider = Provider<Distribution>(
  (ref) => Distribution.current,
);
