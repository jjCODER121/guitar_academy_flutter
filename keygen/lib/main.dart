import 'package:flutter/material.dart';

import 'keygen_screen.dart';
import 'tokens.g.dart';

void main() => runApp(const KeygenApp());

/// Генератор ключей активации — только для музыканта.
/// Не публиковать в Google Play: в нём формула ключа.
class KeygenApp extends StatelessWidget {
  const KeygenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    return MaterialApp(
      title: 'Генератор ключей',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: c.background,
        colorScheme: ColorScheme.dark(
          primary: c.accent,
          onPrimary: c.accentOn,
          surface: c.background,
          onSurface: c.textPrimary,
          onSurfaceVariant: c.textSecondary,
          surfaceContainer: c.surface,
          surfaceContainerHighest: c.surfaceAlt,
          outline: c.border,
          error: c.danger,
        ),
        extensions: const [c],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surfaceAlt,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSize.button),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
            ),
            textStyle: AppText.button,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            minimumSize: const Size.fromHeight(AppSize.button),
            side: BorderSide(color: c.border, width: 1.5),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
            ),
            textStyle: AppText.button,
          ),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.accent : c.textSecondary,
          ),
        ),
      ),
      home: const KeygenScreen(),
    );
  }
}
