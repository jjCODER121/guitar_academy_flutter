import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter не поставляет системные строки (Material/Cupertino/Widgets)
/// для таджикского. Для `tg` берём русские: текст наших экранов при этом
/// остаётся таджикским (он из app_tg.arb), а русскими будут только
/// служебные подсказки вроде «Назад» в accessibility и меню копирования.
const fallbackLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  _FallbackDelegate<MaterialLocalizations>(
    GlobalMaterialLocalizations.delegate,
  ),
  _FallbackDelegate<CupertinoLocalizations>(
    GlobalCupertinoLocalizations.delegate,
  ),
  _FallbackDelegate<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
];

const _fallbacks = {'tg': Locale('ru')};

class _FallbackDelegate<T> extends LocalizationsDelegate<T> {
  const _FallbackDelegate(this._inner);

  final LocalizationsDelegate<T> _inner;

  @override
  bool isSupported(Locale locale) =>
      _fallbacks.containsKey(locale.languageCode);

  @override
  Future<T> load(Locale locale) =>
      _inner.load(_fallbacks[locale.languageCode]!);

  @override
  bool shouldReload(_FallbackDelegate<T> old) => false;
}
