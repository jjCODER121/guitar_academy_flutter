import 'package:flutter/widgets.dart';

/// Иконки Lucide (lucide.dev, лицензия ISC — assets/fonts/LICENSE-Lucide.txt).
///
/// Шрифт лежит в приложении целиком, а при release-сборке Flutter оставляет
/// в нём только используемые значки (~8 КБ). Пакет lucide_icons_flutter
/// не используем: он тянет ещё шесть шрифтов (~1,4 МБ), которые не вырезаются.
///
/// Новая иконка: найти её на lucide.dev, взять код символа из
/// lucide-static (font/info.json) и добавить сюда.
abstract final class AppIcons {
  static const _family = 'Lucide';

  static const atSign = IconData(0xE04E, fontFamily: _family);
  static const check = IconData(0xE06C, fontFamily: _family);
  static const chevronLeft = IconData(0xE06E, fontFamily: _family);
  static const chevronRight = IconData(0xE06F, fontFamily: _family);
  static const cloudOff = IconData(0xE08D, fontFamily: _family);
  static const copy = IconData(0xE09E, fontFamily: _family);
  static const fileText = IconData(0xE0CC, fontFamily: _family);
  static const guitar = IconData(0xE55F, fontFamily: _family);
  static const hardDriveDownload = IconData(0xE4E5, fontFamily: _family);
  static const house = IconData(0xE0F5, fontFamily: _family);
  static const languages = IconData(0xE0FE, fontFamily: _family);
  static const libraryBig = IconData(0xE54E, fontFamily: _family);
  static const lock = IconData(0xE10B, fontFamily: _family);
  static const mapPin = IconData(0xE111, fontFamily: _family);
  static const messageCircle = IconData(0xE116, fontFamily: _family);
  static const music = IconData(0xE122, fontFamily: _family);
  static const phone = IconData(0xE133, fontFamily: _family);
  static const play = IconData(0xE13C, fontFamily: _family);
  static const refreshCw = IconData(0xE145, fontFamily: _family);
  static const repeat = IconData(0xE146, fontFamily: _family);
  static const ticket = IconData(0xE20F, fontFamily: _family);
  static const sunMoon = IconData(0xE2B2, fontFamily: _family);
  static const user = IconData(0xE19F, fontFamily: _family);
  static const x = IconData(0xE1B2, fontFamily: _family);
  static const zoomIn = IconData(0xE1B6, fontFamily: _family);
  static const zoomOut = IconData(0xE1B7, fontFamily: _family);
}
