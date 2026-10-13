import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tg.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('tg'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Гитарная школа'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In ru, this message translates to:
  /// **'Библиотека'**
  String get navLibrary;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @onboardingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Играй любимые песни на гитаре'**
  String get onboardingTitle;

  /// No description provided for @start.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get start;

  /// No description provided for @greeting.
  ///
  /// In ru, this message translates to:
  /// **'Салом!'**
  String get greeting;

  /// No description provided for @continueLearning.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get continueLearning;

  /// No description provided for @sectionCourse.
  ///
  /// In ru, this message translates to:
  /// **'Курс для новичков'**
  String get sectionCourse;

  /// No description provided for @sectionAlbums.
  ///
  /// In ru, this message translates to:
  /// **'Альбомы песен'**
  String get sectionAlbums;

  /// No description provided for @sectionSingles.
  ///
  /// In ru, this message translates to:
  /// **'Отдельные песни'**
  String get sectionSingles;

  /// No description provided for @kindCourse.
  ///
  /// In ru, this message translates to:
  /// **'Курс'**
  String get kindCourse;

  /// No description provided for @kindAlbum.
  ///
  /// In ru, this message translates to:
  /// **'Альбом'**
  String get kindAlbum;

  /// No description provided for @kindSingle.
  ///
  /// In ru, this message translates to:
  /// **'Песня'**
  String get kindSingle;

  /// No description provided for @levelBeginner.
  ///
  /// In ru, this message translates to:
  /// **'начальный уровень'**
  String get levelBeginner;

  /// No description provided for @levelIntermediate.
  ///
  /// In ru, this message translates to:
  /// **'средний уровень'**
  String get levelIntermediate;

  /// No description provided for @levelAdvanced.
  ///
  /// In ru, this message translates to:
  /// **'продвинутый уровень'**
  String get levelAdvanced;

  /// No description provided for @lessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} урок} few{{count} урока} many{{count} уроков} other{{count} урока}}'**
  String lessonsCount(int count);

  /// No description provided for @songsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} песня} few{{count} песни} many{{count} песен} other{{count} песни}}'**
  String songsCount(int count);

  /// No description provided for @lessonsOf.
  ///
  /// In ru, this message translates to:
  /// **'{total, plural, one{{done} из {total} урока} other{{done} из {total} уроков}}'**
  String lessonsOf(int done, int total);

  /// No description provided for @songsOf.
  ///
  /// In ru, this message translates to:
  /// **'{total, plural, one{{done} из {total} песни} other{{done} из {total} песен}}'**
  String songsOf(int done, int total);

  /// No description provided for @lessonsUnit.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{урок} few{урока} many{уроков} other{урока}}'**
  String lessonsUnit(int count);

  /// No description provided for @notStarted.
  ///
  /// In ru, this message translates to:
  /// **'Не начато'**
  String get notStarted;

  /// No description provided for @completed.
  ///
  /// In ru, this message translates to:
  /// **'Пройдено'**
  String get completed;

  /// No description provided for @watch.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть'**
  String get watch;

  /// No description provided for @free.
  ///
  /// In ru, this message translates to:
  /// **'бесплатно'**
  String get free;

  /// No description provided for @freeSeconds.
  ///
  /// In ru, this message translates to:
  /// **'бесплатно {seconds} сек'**
  String freeSeconds(int seconds);

  /// No description provided for @locked.
  ///
  /// In ru, this message translates to:
  /// **'Закрыто'**
  String get locked;

  /// No description provided for @watchFree.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть бесплатно'**
  String get watchFree;

  /// No description provided for @sheetMusic.
  ///
  /// In ru, this message translates to:
  /// **'Ноты'**
  String get sheetMusic;

  /// No description provided for @sheetMusicPdf.
  ///
  /// In ru, this message translates to:
  /// **'ноты PDF'**
  String get sheetMusicPdf;

  /// No description provided for @materials.
  ///
  /// In ru, this message translates to:
  /// **'материалы'**
  String get materials;

  /// No description provided for @access.
  ///
  /// In ru, this message translates to:
  /// **'доступ'**
  String get access;

  /// No description provided for @lessonsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уроки'**
  String get lessonsTitle;

  /// No description provided for @songsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Песни'**
  String get songsTitle;

  /// No description provided for @songOfTotal.
  ///
  /// In ru, this message translates to:
  /// **'Песня {n} из {total}'**
  String songOfTotal(int n, int total);

  /// No description provided for @lessonOfTotal.
  ///
  /// In ru, this message translates to:
  /// **'Урок {n} из {total}'**
  String lessonOfTotal(int n, int total);

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход и регистрация — одним шагом'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте email'**
  String get emailInvalid;

  /// No description provided for @getCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get getCode;

  /// No description provided for @or.
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get or;

  /// No description provided for @signInGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get signInGoogle;

  /// No description provided for @enterCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код'**
  String get enterCode;

  /// No description provided for @codeSent.
  ///
  /// In ru, this message translates to:
  /// **'Мы отправили код из 6 цифр на {email}'**
  String codeSent(String email);

  /// No description provided for @codeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код из письма'**
  String get codeLabel;

  /// No description provided for @codeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код'**
  String get codeInvalid;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @changeEmail.
  ///
  /// In ru, this message translates to:
  /// **'Изменить email'**
  String get changeEmail;

  /// No description provided for @noPasswordNote.
  ///
  /// In ru, this message translates to:
  /// **'Без пароля. Покупки сохраняются в вашем аккаунте навсегда.'**
  String get noPasswordNote;

  /// No description provided for @unlockWithCode.
  ///
  /// In ru, this message translates to:
  /// **'Активировать курс'**
  String get unlockWithCode;

  /// No description provided for @unlockShort.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get unlockShort;

  /// No description provided for @activate.
  ///
  /// In ru, this message translates to:
  /// **'Активировать'**
  String get activate;

  /// No description provided for @unlocked.
  ///
  /// In ru, this message translates to:
  /// **'Открыто!'**
  String get unlocked;

  /// No description provided for @unlockedIn.
  ///
  /// In ru, this message translates to:
  /// **'«{title}» — в вашей библиотеке'**
  String unlockedIn(String title);

  /// No description provided for @activationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Активация курса'**
  String get activationTitle;

  /// No description provided for @deviceCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'ID-код устройства'**
  String get deviceCodeLabel;

  /// No description provided for @copy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get copied;

  /// No description provided for @activationKeyLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код активации'**
  String get activationKeyLabel;

  /// No description provided for @invalidActivationKey.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код активации'**
  String get invalidActivationKey;

  /// No description provided for @deviceIdUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить ID устройства'**
  String get deviceIdUnavailable;

  /// No description provided for @buy.
  ///
  /// In ru, this message translates to:
  /// **'Купить'**
  String get buy;

  /// No description provided for @howToBuyHint.
  ///
  /// In ru, this message translates to:
  /// **'Как купить: отправьте этот ID-код музыканту — он пришлёт код активации.'**
  String get howToBuyHint;

  /// No description provided for @call.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get call;

  /// No description provided for @buyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Здравствуйте! Хочу купить «{title}». Мой ID-код: {code}'**
  String buyMessage(String title, String code);

  /// No description provided for @buyMessageGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Здравствуйте! Хочу купить курс. Мой ID-код: {code}'**
  String buyMessageGeneric(String code);

  /// No description provided for @contactFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть приложение'**
  String get contactFailed;

  /// No description provided for @codeNotSent.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить письмо. Попробуйте через минуту.'**
  String get codeNotSent;

  /// No description provided for @tooManyAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Попробуйте через час.'**
  String get tooManyAttempts;

  /// No description provided for @loginToUnlock.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы активировать курс'**
  String get loginToUnlock;

  /// No description provided for @videoUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить видео. Проверьте интернет.'**
  String get videoUnavailable;

  /// No description provided for @pdfUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть PDF. Проверьте интернет.'**
  String get pdfUnavailable;

  /// No description provided for @fullscreen.
  ///
  /// In ru, this message translates to:
  /// **'Во весь экран'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из полноэкранного режима'**
  String get exitFullscreen;

  /// No description provided for @speed.
  ///
  /// In ru, this message translates to:
  /// **'Скорость'**
  String get speed;

  /// No description provided for @loopAB.
  ///
  /// In ru, this message translates to:
  /// **'Повтор A–B'**
  String get loopAB;

  /// No description provided for @loopMarkB.
  ///
  /// In ru, this message translates to:
  /// **'Отметить B'**
  String get loopMarkB;

  /// No description provided for @loopOn.
  ///
  /// In ru, this message translates to:
  /// **'A–B · {from}–{to}'**
  String loopOn(String from, String to);

  /// No description provided for @next.
  ///
  /// In ru, this message translates to:
  /// **'Дальше'**
  String get next;

  /// No description provided for @nextLesson.
  ///
  /// In ru, this message translates to:
  /// **'Следующий урок'**
  String get nextLesson;

  /// No description provided for @play.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get pause;

  /// No description provided for @previewEnded.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатный фрагмент закончился'**
  String get previewEnded;

  /// No description provided for @zoomIn.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить'**
  String get zoomOut;

  /// No description provided for @purchasedBy.
  ///
  /// In ru, this message translates to:
  /// **'Куплено: {email}'**
  String purchasedBy(String email);

  /// No description provided for @pageOf.
  ///
  /// In ru, this message translates to:
  /// **'{page} / {total}'**
  String pageOf(int page, int total);

  /// No description provided for @libraryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся ваши покупки'**
  String get libraryEmpty;

  /// No description provided for @toCatalog.
  ///
  /// In ru, this message translates to:
  /// **'В каталог'**
  String get toCatalog;

  /// No description provided for @guest.
  ///
  /// In ru, this message translates to:
  /// **'Гость'**
  String get guest;

  /// No description provided for @purchasesLabel.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{покупка} few{покупки} many{покупок} other{покупки}}'**
  String purchasesLabel(int count);

  /// No description provided for @lessonsDoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{урок пройден} few{урока пройдено} many{уроков пройдено} other{урока пройдено}}'**
  String lessonsDoneLabel(int count);

  /// No description provided for @practiceLabel.
  ///
  /// In ru, this message translates to:
  /// **'практики'**
  String get practiceLabel;

  /// No description provided for @hours.
  ///
  /// In ru, this message translates to:
  /// **'{h} ч'**
  String hours(int h);

  /// No description provided for @minutes.
  ///
  /// In ru, this message translates to:
  /// **'{m} мин'**
  String minutes(int m);

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get languageSystem;

  /// No description provided for @theme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @musicSchool.
  ///
  /// In ru, this message translates to:
  /// **'Музыкальная школа'**
  String get musicSchool;

  /// No description provided for @contacts.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get contacts;

  /// No description provided for @signOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get signOut;

  /// No description provided for @loadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить'**
  String get loadError;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @offlineVideos.
  ///
  /// In ru, this message translates to:
  /// **'Видео на телефоне'**
  String get offlineVideos;

  /// No description provided for @offlineSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняется · {percent}%'**
  String offlineSaving(int percent);

  /// No description provided for @sizeMb.
  ///
  /// In ru, this message translates to:
  /// **'{size} МБ'**
  String sizeMb(String size);

  /// No description provided for @sizeGb.
  ///
  /// In ru, this message translates to:
  /// **'{size} ГБ'**
  String sizeGb(String size);

  /// No description provided for @offlineDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить видео с телефона?'**
  String get offlineDeleteTitle;

  /// No description provided for @offlineDeleteBody.
  ///
  /// In ru, this message translates to:
  /// **'Уроки снова будут загружаться из интернета.'**
  String get offlineDeleteBody;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'tg'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'tg':
      return AppLocalizationsTg();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
