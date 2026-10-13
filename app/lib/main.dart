import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/backend.dart';
import 'core/config/retry.dart';
import 'core/storage/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Приложение — вертикальное; горизонтально — только видео во весь экран.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: Backend.supabaseUrl,
    publishableKey: Backend.supabaseKey,
  );
  runApp(
    ProviderScope(
      retry: noRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const GuitarSchoolApp(),
    ),
  );
}
