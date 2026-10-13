import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки устройства (тема, язык, онбординг). Экземпляр загружается
/// в main() до запуска приложения и подставляется через override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main()'),
);
