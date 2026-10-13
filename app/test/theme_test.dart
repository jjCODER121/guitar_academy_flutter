import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, theme, tokens) in [
    ('dark', AppTheme.dark, AppColors.dark),
    ('light', AppTheme.light, AppColors.light),
  ]) {
    group('$name theme', () {
      test('берёт цвета из design tokens', () {
        expect(theme.extension<AppColors>(), same(tokens));
        expect(theme.scaffoldBackgroundColor, tokens.background);
        expect(theme.colorScheme.primary, tokens.accent);
        expect(theme.colorScheme.onPrimary, tokens.accentOn);
      });

      test('текст проходит WCAG AA (4.5:1)', () {
        final s = theme.colorScheme;
        final pairs = {
          'onSurface / surface': (s.onSurface, s.surface),
          'onSurfaceVariant / surface': (s.onSurfaceVariant, s.surface),
          'onSurfaceVariant / surfaceContainerHighest': (
            s.onSurfaceVariant,
            s.surfaceContainerHighest,
          ),
          'onPrimary / primary': (s.onPrimary, s.primary),
        };
        for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
          expect(
            _contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: $label',
          );
        }
      });

      test('главная кнопка: высота 56, скругление 16', () {
        final style = theme.filledButtonTheme.style!;
        expect(style.minimumSize!.resolve({})!.height, AppSize.button);
        final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          const BorderRadius.all(Radius.circular(AppRadius.button)),
        );
      });

      test('шрифт Manrope с запасным для таджикских букв', () {
        final style = theme.textTheme.titleMedium!;
        expect(style.fontFamily, AppFonts.family);
        expect(style.fontFamilyFallback, AppFonts.fallback);
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w600);
      });
    });
  }
}
