// GENERATED CODE — DO NOT EDIT.
// Source: design/tokens.json. Regenerate: dart run tools/gen_tokens.dart

import 'package:flutter/material.dart';

/// Цвета темы. В виджетах: `context.colors` (см. app_theme.dart).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentOn,
    required this.success,
    required this.danger,
    required this.locked,
  });

  /// Фон экранов
  final Color background;

  /// Карточки, плеер, нижняя панель
  final Color surface;

  /// Строки уроков, поля ввода
  final Color surfaceAlt;

  /// Контурные кнопки, трек ползунка (нет в брифе, из макетов)
  final Color border;

  /// Заголовки, основной текст
  final Color textPrimary;

  /// Длительность, подписи
  final Color textSecondary;

  /// Кнопка «Купить», прогресс, активные иконки
  final Color accent;

  /// Текст на акцентной кнопке (light: в брифе #FFFFFF, не проходит AA)
  final Color accentOn;

  /// Галочка «пройдено»
  final Color success;

  /// Ошибки, возвраты (нет в брифе, из макетов)
  final Color danger;

  /// Замок на закрытых уроках
  final Color locked;

  static const dark = AppColors(
    background: Color(0xFF0F0E0D),
    surface: Color(0xFF1B1917),
    surfaceAlt: Color(0xFF262320),
    border: Color(0xFF3A3631),
    textPrimary: Color(0xFFF5F1EA),
    textSecondary: Color(0xFF9A948B),
    accent: Color(0xFFE0A040),
    accentOn: Color(0xFF1A1206),
    success: Color(0xFF6FBF73),
    danger: Color(0xFFE8846A),
    locked: Color(0xFF5C5650),
  );

  static const light = AppColors(
    background: Color(0xFFFAF8F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1EDE7),
    border: Color(0xFFE7E1D8),
    textPrimary: Color(0xFF1A1714),
    textSecondary: Color(0xFF6E675E),
    accent: Color(0xFFC9822A),
    accentOn: Color(0xFF1A1206),
    success: Color(0xFF3E8E43),
    danger: Color(0xFF9A3B1F),
    locked: Color(0xFFB5ADA3),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentOn,
    Color? success,
    Color? danger,
    Color? locked,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentOn: accentOn ?? this.accentOn,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      locked: locked ?? this.locked,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      locked: Color.lerp(locked, other.locked, t)!,
    );
  }
}

abstract final class AppFonts {
  static const family = 'Manrope';
  static const fallback = <String>['InterTajik'];
}

/// Текстовые стили без цвета: цвет задаёт тема.
abstract final class AppText {
  /// Заголовок экрана
  static const screenTitle = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Название альбома
  static const albumTitle = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Заголовок ряда на Главной
  static const sectionTitle = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0.0,
  );

  /// Название урока
  static const lessonTitle = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.0,
  );

  /// Основной текст, поля ввода
  static const body = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.0,
  );

  /// Главная кнопка
  static const button = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 17.0,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.0,
  );

  /// Подписи, длительность
  static const caption = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.0,
  );

  /// Подписи нижней панели
  static const navLabel = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.0,
  );
}

abstract final class AppSpace {
  static const double xs = 8.0;
  static const double sm = 16.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double screen = 20.0;
}

abstract final class AppRadius {
  static const double card = 20.0;
  static const double button = 16.0;
  static const double cover = 12.0;
}

abstract final class AppSize {
  static const double tapTarget = 48.0;
  static const double button = 56.0;
  static const double icon = 24.0;
  static const double iconStroke = 2.0;
}
