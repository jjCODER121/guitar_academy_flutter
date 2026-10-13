// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tajik (`tg`).
class AppLocalizationsTg extends AppLocalizations {
  AppLocalizationsTg([String locale = 'tg']) : super(locale);

  @override
  String get appTitle => 'Мактаби гитара';

  @override
  String get navHome => 'Асосӣ';

  @override
  String get navLibrary => 'Китобхона';

  @override
  String get navProfile => 'Профил';

  @override
  String get onboardingTitle => 'Сурудҳои дӯстдоштаатонро бо гитара навозед';

  @override
  String get start => 'Оғоз';

  @override
  String get greeting => 'Салом!';

  @override
  String get continueLearning => 'Давом додан';

  @override
  String get sectionCourse => 'Курс барои навкорон';

  @override
  String get sectionAlbums => 'Албомҳои сурудҳо';

  @override
  String get sectionSingles => 'Сурудҳои алоҳида';

  @override
  String get kindCourse => 'Курс';

  @override
  String get kindAlbum => 'Албом';

  @override
  String get kindSingle => 'Суруд';

  @override
  String get levelBeginner => 'сатҳи ибтидоӣ';

  @override
  String get levelIntermediate => 'сатҳи миёна';

  @override
  String get levelAdvanced => 'сатҳи баланд';

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дарс',
    );
    return '$_temp0';
  }

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count суруд',
    );
    return '$_temp0';
  }

  @override
  String lessonsOf(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done аз $total дарс',
    );
    return '$_temp0';
  }

  @override
  String songsOf(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done аз $total суруд',
    );
    return '$_temp0';
  }

  @override
  String lessonsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'дарс',
    );
    return '$_temp0';
  }

  @override
  String get notStarted => 'Оғоз нашудааст';

  @override
  String get completed => 'Анҷом ёфт';

  @override
  String get watch => 'Тамошо';

  @override
  String get free => 'ройгон';

  @override
  String freeSeconds(int seconds) {
    return '$seconds сония ройгон';
  }

  @override
  String get locked => 'Пӯшида';

  @override
  String get watchFree => 'Ройгон тамошо кардан';

  @override
  String get sheetMusic => 'Нотаҳо';

  @override
  String get sheetMusicPdf => 'нотаҳои PDF';

  @override
  String get materials => 'мавод';

  @override
  String get access => 'дастрасӣ';

  @override
  String get lessonsTitle => 'Дарсҳо';

  @override
  String get songsTitle => 'Сурудҳо';

  @override
  String songOfTotal(int n, int total) {
    return 'Суруди $n аз $total';
  }

  @override
  String lessonOfTotal(int n, int total) {
    return 'Дарси $n аз $total';
  }

  @override
  String get back => 'Бозгашт';

  @override
  String get close => 'Пӯшидан';

  @override
  String get loginTitle => 'Воридшавӣ';

  @override
  String get loginSubtitle => 'Воридшавӣ ва бақайдгирӣ — дар як қадам';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Email-ро санҷед';

  @override
  String get getCode => 'Гирифтани код';

  @override
  String get or => 'ё';

  @override
  String get signInGoogle => 'Ворид шудан бо Google';

  @override
  String get enterCode => 'Кодро ворид кунед';

  @override
  String codeSent(String email) {
    return 'Мо коди 6-рақама ба $email фиристодем';
  }

  @override
  String get codeLabel => 'Код аз мактуб';

  @override
  String get codeInvalid => 'Код нодуруст аст';

  @override
  String get signIn => 'Ворид шудан';

  @override
  String get changeEmail => 'Иваз кардани email';

  @override
  String get noPasswordNote =>
      'Бе парол. Харидҳо дар ҳисоби шумо абадан нигоҳ дошта мешаванд.';

  @override
  String get unlockWithCode => 'Фаъол кардани курс';

  @override
  String get unlockShort => 'Кушодан';

  @override
  String get activate => 'Фаъол кардан';

  @override
  String get unlocked => 'Кушода шуд!';

  @override
  String unlockedIn(String title) {
    return '«$title» — дар китобхонаи шумо';
  }

  @override
  String get activationTitle => 'Фаъолсозии курс';

  @override
  String get deviceCodeLabel => 'ID-коди дастгоҳ';

  @override
  String get copy => 'Нусха бардоштан';

  @override
  String get copied => 'Нусха бардошта шуд';

  @override
  String get activationKeyLabel => 'Коди фаъолсозӣ';

  @override
  String get invalidActivationKey => 'Коди фаъолсозӣ нодуруст аст';

  @override
  String get deviceIdUnavailable => 'ID-и дастгоҳро гирифтан нашуд';

  @override
  String get buy => 'Харидан';

  @override
  String get howToBuyHint =>
      'Чӣ тавр харидан мумкин: ин ID-кодро ба мусиқинавоз фиристед — ӯ коди фаъолсозиро мефиристад.';

  @override
  String get call => 'Занг задан';

  @override
  String buyMessage(String title, String code) {
    return 'Салом! Мехоҳам «$title»-ро харам. ID-коди ман: $code';
  }

  @override
  String buyMessageGeneric(String code) {
    return 'Салом! Мехоҳам курс харам. ID-коди ман: $code';
  }

  @override
  String get contactFailed => 'Барномаро кушодан нашуд';

  @override
  String get codeNotSent =>
      'Мактуб фиристода нашуд. Баъд аз як дақиқа боз кӯшиш кунед.';

  @override
  String get tooManyAttempts =>
      'Кӯшишҳо аз ҳад зиёд. Баъд аз як соат боз кӯшиш кунед.';

  @override
  String get loginToUnlock => 'Барои фаъол кардани курс ворид шавед';

  @override
  String get videoUnavailable => 'Видеоро бор кардан нашуд. Интернетро санҷед.';

  @override
  String get pdfUnavailable => 'PDF-ро кушодан нашуд. Интернетро санҷед.';

  @override
  String get fullscreen => 'Пурра дар экран';

  @override
  String get exitFullscreen => 'Баромадан аз реҷаи пурраэкран';

  @override
  String get speed => 'Суръат';

  @override
  String get loopAB => 'Такрори A–B';

  @override
  String get loopMarkB => 'Нуқтаи B';

  @override
  String loopOn(String from, String to) {
    return 'A–B · $from–$to';
  }

  @override
  String get next => 'Навбатӣ';

  @override
  String get nextLesson => 'Дарси навбатӣ';

  @override
  String get play => 'Пахш';

  @override
  String get pause => 'Таваққуф';

  @override
  String get previewEnded => 'Қисми ройгон ба охир расид';

  @override
  String get zoomIn => 'Калон кардан';

  @override
  String get zoomOut => 'Хурд кардан';

  @override
  String purchasedBy(String email) {
    return 'Харидор: $email';
  }

  @override
  String pageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get libraryEmpty => 'Харидҳои шумо дар ин ҷо пайдо мешаванд';

  @override
  String get toCatalog => 'Ба каталог';

  @override
  String get guest => 'Меҳмон';

  @override
  String purchasesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'харид',
    );
    return '$_temp0';
  }

  @override
  String lessonsDoneLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'дарс анҷом ёфт',
    );
    return '$_temp0';
  }

  @override
  String get practiceLabel => 'машқ';

  @override
  String hours(int h) {
    return '$h соат';
  }

  @override
  String minutes(int m) {
    return '$m дақ';
  }

  @override
  String get language => 'Забон';

  @override
  String get languageSystem => 'Мисли система';

  @override
  String get theme => 'Мавзӯъ';

  @override
  String get themeDark => 'Торик';

  @override
  String get themeLight => 'Равшан';

  @override
  String get musicSchool => 'Мактаби мусиқӣ';

  @override
  String get contacts => 'Тамос';

  @override
  String get signOut => 'Баромадан';

  @override
  String get loadError => 'Бор кардан нашуд';

  @override
  String get retry => 'Такрор';

  @override
  String get offlineVideos => 'Видеоҳо дар телефон';

  @override
  String offlineSaving(int percent) {
    return 'Нигоҳ дошта мешавад · $percent%';
  }

  @override
  String sizeMb(String size) {
    return '$size МБ';
  }

  @override
  String sizeGb(String size) {
    return '$size ГБ';
  }

  @override
  String get offlineDeleteTitle => 'Видеоҳоро аз телефон нест кунем?';

  @override
  String get offlineDeleteBody => 'Дарсҳо боз аз интернет бор карда мешаванд.';

  @override
  String get delete => 'Нест кардан';

  @override
  String get cancel => 'Бекор кардан';
}
