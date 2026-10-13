// Генератор design tokens.
//
// Читает design/tokens.json и пишет:
//   app/lib/core/theme/tokens.g.dart — цвета (ThemeExtension), шрифты, отступы для Flutter;
//   keygen/lib/tokens.g.dart         — те же значения для генератора ключей;
//   admin/static/tokens.css, admin-web/tokens.css — те же значения как CSS-переменные для админки.
// Заодно проверяет контраст текстовых пар по WCAG AA (4.5:1).
//
// Запуск из корня репозитория:
//   dart run tools/gen_tokens.dart          — перегенерировать файлы
//   dart run tools/gen_tokens.dart --check  — только проверить, что файлы актуальны (для CI)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _header =
    'GENERATED CODE — DO NOT EDIT.\n'
    'Source: design/tokens.json. Regenerate: dart run tools/gen_tokens.dart';

const _themes = ['dark', 'light'];

Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');
  final root = File.fromUri(Platform.script).parent.parent;
  final tokens =
      jsonDecode(File('${root.path}/design/tokens.json').readAsStringSync())
          as Map<String, dynamic>;

  final contrastOk = _checkContrast(tokens);

  final outputs = <String, String>{
    'app/lib/core/theme/tokens.g.dart': _dart(tokens),
    'keygen/lib/tokens.g.dart': _dart(tokens),
    'admin/static/tokens.css': _css(tokens),
    'admin-web/tokens.css': _css(tokens),
  };

  var stale = false;
  for (final MapEntry(key: rel, value: content) in outputs.entries) {
    final target = File('${root.path}/$rel');
    final generated = rel.endsWith('.dart')
        ? await _dartFormat(content)
        : content;
    if (checkOnly) {
      final current = target.existsSync()
          ? target.readAsStringSync().replaceAll('\r\n', '\n')
          : '';
      if (current != generated) {
        stderr.writeln('Устарел: $rel — запустите dart run tools/gen_tokens.dart');
        stale = true;
      }
    } else {
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(generated);
      stdout.writeln('Записан: $rel');
    }
  }

  if (!contrastOk || stale) exit(1);
}

// ---------------------------------------------------------------- контраст

bool _checkContrast(Map<String, dynamic> tokens) {
  final colors = tokens['color'] as Map<String, dynamic>;
  final pairs = (tokens['contrastChecks'] as List).cast<List<dynamic>>();
  var ok = true;
  stdout.writeln('Контраст WCAG (норма AA для текста — 4.5:1):');
  for (final theme in _themes) {
    for (final pair in pairs) {
      final fg = pair[0] as String;
      final bg = pair[1] as String;
      final ratio = _contrast(
        (colors[fg] as Map)[theme] as String,
        (colors[bg] as Map)[theme] as String,
      );
      final pass = ratio >= 4.5;
      ok &= pass;
      stdout.writeln(
        '  ${pass ? 'ok  ' : 'FAIL'} $theme  ${fg.padRight(14)} на '
        '${bg.padRight(11)} ${ratio.toStringAsFixed(2)}:1',
      );
    }
  }
  return ok;
}

double _contrast(String a, String b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  double channel(int c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((v >> 16) & 0xFF) +
      0.7152 * channel((v >> 8) & 0xFF) +
      0.0722 * channel(v & 0xFF);
}

// ---------------------------------------------------------------- Dart

String _dart(Map<String, dynamic> tokens) {
  final colors = tokens['color'] as Map<String, dynamic>;
  final font = tokens['font'] as Map<String, dynamic>;
  final text = tokens['text'] as Map<String, dynamic>;
  final names = colors.keys.toList();
  String argb(String hex) => 'Color(0xFF${hex.substring(1).toUpperCase()})';

  final b = StringBuffer()
    ..writeln(_header.split('\n').map((l) => '// $l').join('\n'))
    ..writeln()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('/// Цвета темы. В виджетах: `context.colors` (см. app_theme.dart).')
    ..writeln('@immutable')
    ..writeln('class AppColors extends ThemeExtension<AppColors> {')
    ..writeln('  const AppColors({')
    ..writeln(names.map((n) => '    required this.$n,').join('\n'))
    ..writeln('  });')
    ..writeln();
  for (final n in names) {
    b
      ..writeln('  /// ${(colors[n] as Map)['usage']}')
      ..writeln('  final Color $n;')
      ..writeln();
  }
  for (final theme in _themes) {
    b.writeln('  static const $theme = AppColors(');
    for (final n in names) {
      b.writeln('    $n: ${argb((colors[n] as Map)[theme] as String)},');
    }
    b
      ..writeln('  );')
      ..writeln();
  }
  b
    ..writeln('  @override')
    ..writeln('  AppColors copyWith({')
    ..writeln(names.map((n) => '    Color? $n,').join('\n'))
    ..writeln('  }) {')
    ..writeln('    return AppColors(')
    ..writeln(names.map((n) => '      $n: $n ?? this.$n,').join('\n'))
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  AppColors lerp(AppColors? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return AppColors(')
    ..writeln(
      names.map((n) => '      $n: Color.lerp($n, other.$n, t)!,').join('\n'),
    )
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class AppFonts {')
    ..writeln("  static const family = '${font['family']}';")
    ..writeln(
      '  static const fallback = <String>['
      "${(font['fallback'] as List).map((f) => "'$f'").join(', ')}];",
    )
    ..writeln('}')
    ..writeln()
    ..writeln('/// Текстовые стили без цвета: цвет задаёт тема.')
    ..writeln('abstract final class AppText {');
  for (final MapEntry(key: name, value: raw) in text.entries) {
    final s = raw as Map<String, dynamic>;
    b
      ..writeln('  /// ${s['usage']}')
      ..writeln('  static const $name = TextStyle(')
      ..writeln('    fontFamily: AppFonts.family,')
      ..writeln('    fontFamilyFallback: AppFonts.fallback,')
      ..writeln('    fontSize: ${_num(s['size'])},')
      ..writeln('    fontWeight: FontWeight.w${s['weight']},')
      ..writeln('    height: ${_num(s['height'])},')
      ..writeln('    letterSpacing: ${_num(s['letterSpacing'])},')
      ..writeln('  );')
      ..writeln();
  }
  b.writeln('}');
  for (final (group, cls) in [
    ('space', 'AppSpace'),
    ('radius', 'AppRadius'),
    ('size', 'AppSize'),
  ]) {
    b
      ..writeln()
      ..writeln('abstract final class $cls {');
    for (final MapEntry(key: name, value: v) in (tokens[group] as Map).entries) {
      b.writeln('  static const double $name = ${_num(v)};');
    }
    b.writeln('}');
  }
  return b.toString();
}

String _num(Object? v) {
  final d = (v as num).toDouble();
  return d == d.roundToDouble() ? d.toStringAsFixed(1) : d.toString();
}

Future<String> _dartFormat(String source) async {
  final tmp = await Directory.systemTemp.createTemp('tokens');
  try {
    final file = File('${tmp.path}/tokens.g.dart')..writeAsStringSync(source);
    final result = await Process.run('dart', [
      'format',
      file.path,
    ], runInShell: true);
    if (result.exitCode != 0) {
      throw StateError('dart format failed: ${result.stderr}');
    }
    return file.readAsStringSync().replaceAll('\r\n', '\n');
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

// ---------------------------------------------------------------- CSS

String _css(Map<String, dynamic> tokens) {
  final colors = tokens['color'] as Map<String, dynamic>;
  final font = tokens['font'] as Map<String, dynamic>;
  final text = tokens['text'] as Map<String, dynamic>;
  String kebab(String s) =>
      s.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');
  String colorVars(String theme) => colors.entries
      .map((e) => '  --color-${kebab(e.key)}: ${(e.value as Map)[theme]};')
      .join('\n');

  final b = StringBuffer()
    ..writeln('/* ${_header.replaceAll('\n', '\n   ')} */')
    ..writeln()
    ..writeln('/* Админка по умолчанию светлая (как в макетах), тёмная — data-theme="dark". */')
    ..writeln(':root {')
    ..writeln(
      "  --font-family: '${font['family']}', "
      "${(font['fallback'] as List).map((f) => "'$f'").join(', ')}, "
      "'Inter', system-ui, sans-serif;",
    );
  for (final MapEntry(key: name, value: raw) in text.entries) {
    final s = raw as Map<String, dynamic>;
    b
      ..writeln(
        '  --font-${kebab(name)}: ${s['weight']} ${s['size']}px/${s['height']} var(--font-family);',
      )
      ..writeln('  --tracking-${kebab(name)}: ${s['letterSpacing']}px;');
  }
  for (final group in ['space', 'radius', 'size']) {
    for (final MapEntry(key: name, value: v) in (tokens[group] as Map).entries) {
      b.writeln('  --$group-${kebab(name)}: ${v}px;');
    }
  }
  b
    ..writeln(colorVars('light'))
    ..writeln('}')
    ..writeln()
    ..writeln('[data-theme="dark"] {')
    ..writeln(colorVars('dark'))
    ..writeln('}');
  return b.toString();
}
