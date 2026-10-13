// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Гитарная школа';

  @override
  String get navHome => 'Главная';

  @override
  String get navLibrary => 'Библиотека';

  @override
  String get navProfile => 'Профиль';

  @override
  String get onboardingTitle => 'Играй любимые песни на гитаре';

  @override
  String get start => 'Начать';

  @override
  String get greeting => 'Салом!';

  @override
  String get continueLearning => 'Продолжить';

  @override
  String get sectionCourse => 'Курс для новичков';

  @override
  String get sectionAlbums => 'Альбомы песен';

  @override
  String get sectionSingles => 'Отдельные песни';

  @override
  String get kindCourse => 'Курс';

  @override
  String get kindAlbum => 'Альбом';

  @override
  String get kindSingle => 'Песня';

  @override
  String get levelBeginner => 'начальный уровень';

  @override
  String get levelIntermediate => 'средний уровень';

  @override
  String get levelAdvanced => 'продвинутый уровень';

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count урока',
      many: '$count уроков',
      few: '$count урока',
      one: '$count урок',
    );
    return '$_temp0';
  }

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count песни',
      many: '$count песен',
      few: '$count песни',
      one: '$count песня',
    );
    return '$_temp0';
  }

  @override
  String lessonsOf(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done из $total уроков',
      one: '$done из $total урока',
    );
    return '$_temp0';
  }

  @override
  String songsOf(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done из $total песен',
      one: '$done из $total песни',
    );
    return '$_temp0';
  }

  @override
  String lessonsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'урока',
      many: 'уроков',
      few: 'урока',
      one: 'урок',
    );
    return '$_temp0';
  }

  @override
  String get notStarted => 'Не начато';

  @override
  String get completed => 'Пройдено';

  @override
  String get watch => 'Смотреть';

  @override
  String get free => 'бесплатно';

  @override
  String freeSeconds(int seconds) {
    return 'бесплатно $seconds сек';
  }

  @override
  String get locked => 'Закрыто';

  @override
  String get watchFree => 'Смотреть бесплатно';

  @override
  String get sheetMusic => 'Ноты';

  @override
  String get sheetMusicPdf => 'ноты PDF';

  @override
  String get materials => 'материалы';

  @override
  String get access => 'доступ';

  @override
  String get lessonsTitle => 'Уроки';

  @override
  String get songsTitle => 'Песни';

  @override
  String songOfTotal(int n, int total) {
    return 'Песня $n из $total';
  }

  @override
  String lessonOfTotal(int n, int total) {
    return 'Урок $n из $total';
  }

  @override
  String get back => 'Назад';

  @override
  String get close => 'Закрыть';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginSubtitle => 'Вход и регистрация — одним шагом';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Проверьте email';

  @override
  String get getCode => 'Получить код';

  @override
  String get or => 'или';

  @override
  String get signInGoogle => 'Войти через Google';

  @override
  String get enterCode => 'Введите код';

  @override
  String codeSent(String email) {
    return 'Мы отправили код из 6 цифр на $email';
  }

  @override
  String get codeLabel => 'Код из письма';

  @override
  String get codeInvalid => 'Неверный код';

  @override
  String get signIn => 'Войти';

  @override
  String get changeEmail => 'Изменить email';

  @override
  String get noPasswordNote =>
      'Без пароля. Покупки сохраняются в вашем аккаунте навсегда.';

  @override
  String get unlockWithCode => 'Активировать курс';

  @override
  String get unlockShort => 'Открыть';

  @override
  String get activate => 'Активировать';

  @override
  String get unlocked => 'Открыто!';

  @override
  String unlockedIn(String title) {
    return '«$title» — в вашей библиотеке';
  }

  @override
  String get activationTitle => 'Активация курса';

  @override
  String get deviceCodeLabel => 'ID-код устройства';

  @override
  String get copy => 'Скопировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get activationKeyLabel => 'Код активации';

  @override
  String get invalidActivationKey => 'Неверный код активации';

  @override
  String get deviceIdUnavailable => 'Не удалось получить ID устройства';

  @override
  String get buy => 'Купить';

  @override
  String get howToBuyHint =>
      'Как купить: отправьте этот ID-код музыканту — он пришлёт код активации.';

  @override
  String get call => 'Позвонить';

  @override
  String buyMessage(String title, String code) {
    return 'Здравствуйте! Хочу купить «$title». Мой ID-код: $code';
  }

  @override
  String buyMessageGeneric(String code) {
    return 'Здравствуйте! Хочу купить курс. Мой ID-код: $code';
  }

  @override
  String get contactFailed => 'Не удалось открыть приложение';

  @override
  String get codeNotSent =>
      'Не удалось отправить письмо. Попробуйте через минуту.';

  @override
  String get tooManyAttempts => 'Слишком много попыток. Попробуйте через час.';

  @override
  String get loginToUnlock => 'Войдите, чтобы активировать курс';

  @override
  String get videoUnavailable =>
      'Не удалось загрузить видео. Проверьте интернет.';

  @override
  String get pdfUnavailable => 'Не удалось открыть PDF. Проверьте интернет.';

  @override
  String get fullscreen => 'Во весь экран';

  @override
  String get exitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get speed => 'Скорость';

  @override
  String get loopAB => 'Повтор A–B';

  @override
  String get loopMarkB => 'Отметить B';

  @override
  String loopOn(String from, String to) {
    return 'A–B · $from–$to';
  }

  @override
  String get next => 'Дальше';

  @override
  String get nextLesson => 'Следующий урок';

  @override
  String get play => 'Смотреть';

  @override
  String get pause => 'Пауза';

  @override
  String get previewEnded => 'Бесплатный фрагмент закончился';

  @override
  String get zoomIn => 'Увеличить';

  @override
  String get zoomOut => 'Уменьшить';

  @override
  String purchasedBy(String email) {
    return 'Куплено: $email';
  }

  @override
  String pageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get libraryEmpty => 'Здесь появятся ваши покупки';

  @override
  String get toCatalog => 'В каталог';

  @override
  String get guest => 'Гость';

  @override
  String purchasesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'покупки',
      many: 'покупок',
      few: 'покупки',
      one: 'покупка',
    );
    return '$_temp0';
  }

  @override
  String lessonsDoneLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'урока пройдено',
      many: 'уроков пройдено',
      few: 'урока пройдено',
      one: 'урок пройден',
    );
    return '$_temp0';
  }

  @override
  String get practiceLabel => 'практики';

  @override
  String hours(int h) {
    return '$h ч';
  }

  @override
  String minutes(int m) {
    return '$m мин';
  }

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get theme => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get musicSchool => 'Музыкальная школа';

  @override
  String get contacts => 'Контакты';

  @override
  String get signOut => 'Выйти';

  @override
  String get loadError => 'Не удалось загрузить';

  @override
  String get retry => 'Повторить';

  @override
  String get offlineVideos => 'Видео на телефоне';

  @override
  String offlineSaving(int percent) {
    return 'Сохраняется · $percent%';
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
  String get offlineDeleteTitle => 'Удалить видео с телефона?';

  @override
  String get offlineDeleteBody => 'Уроки снова будут загружаться из интернета.';

  @override
  String get delete => 'Удалить';

  @override
  String get cancel => 'Отмена';
}
