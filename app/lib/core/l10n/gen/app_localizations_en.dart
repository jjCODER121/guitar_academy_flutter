// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Guitar School';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navProfile => 'Profile';

  @override
  String get onboardingTitle => 'Play your favourite songs on guitar';

  @override
  String get start => 'Start';

  @override
  String get greeting => 'Hello!';

  @override
  String get continueLearning => 'Continue';

  @override
  String get sectionCourse => 'Beginner course';

  @override
  String get sectionAlbums => 'Song albums';

  @override
  String get sectionSingles => 'Single songs';

  @override
  String get kindCourse => 'Course';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindSingle => 'Song';

  @override
  String get levelBeginner => 'beginner';

  @override
  String get levelIntermediate => 'intermediate';

  @override
  String get levelAdvanced => 'advanced';

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '$count lesson',
    );
    return '$_temp0';
  }

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '$count song',
    );
    return '$_temp0';
  }

  @override
  String lessonsOf(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done of $total lessons',
      one: '$done of $total lesson',
    );
    return '$_temp0';
  }

  @override
  String songsOf(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done of $total songs',
      one: '$done of $total song',
    );
    return '$_temp0';
  }

  @override
  String lessonsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lessons',
      one: 'lesson',
    );
    return '$_temp0';
  }

  @override
  String get notStarted => 'Not started';

  @override
  String get completed => 'Completed';

  @override
  String get watch => 'Watch';

  @override
  String get free => 'free';

  @override
  String freeSeconds(int seconds) {
    return '$seconds sec free';
  }

  @override
  String get locked => 'Locked';

  @override
  String get watchFree => 'Watch for free';

  @override
  String get sheetMusic => 'Sheet music';

  @override
  String get sheetMusicPdf => 'sheet music PDF';

  @override
  String get materials => 'materials';

  @override
  String get access => 'access';

  @override
  String get lessonsTitle => 'Lessons';

  @override
  String get songsTitle => 'Songs';

  @override
  String songOfTotal(int n, int total) {
    return 'Song $n of $total';
  }

  @override
  String lessonOfTotal(int n, int total) {
    return 'Lesson $n of $total';
  }

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Sign in and sign up in one step';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Check your email';

  @override
  String get getCode => 'Get code';

  @override
  String get or => 'or';

  @override
  String get signInGoogle => 'Sign in with Google';

  @override
  String get enterCode => 'Enter the code';

  @override
  String codeSent(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get codeLabel => 'Code from the email';

  @override
  String get codeInvalid => 'Wrong code';

  @override
  String get signIn => 'Sign in';

  @override
  String get changeEmail => 'Change email';

  @override
  String get noPasswordNote =>
      'No password. Purchases stay in your account forever.';

  @override
  String get unlockWithCode => 'Activate course';

  @override
  String get unlockShort => 'Unlock';

  @override
  String get activate => 'Activate';

  @override
  String get unlocked => 'Unlocked!';

  @override
  String unlockedIn(String title) {
    return '“$title” is in your library';
  }

  @override
  String get activationTitle => 'Course activation';

  @override
  String get deviceCodeLabel => 'Device ID code';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get activationKeyLabel => 'Activation code';

  @override
  String get invalidActivationKey => 'Invalid activation code';

  @override
  String get deviceIdUnavailable => 'Couldn\'t get the device ID';

  @override
  String get buy => 'Buy';

  @override
  String get howToBuyHint =>
      'How to buy: send this ID code to the musician — they will send you an activation code.';

  @override
  String get call => 'Call';

  @override
  String buyMessage(String title, String code) {
    return 'Hello! I\'d like to buy “$title”. My ID code: $code';
  }

  @override
  String buyMessageGeneric(String code) {
    return 'Hello! I\'d like to buy a course. My ID code: $code';
  }

  @override
  String get contactFailed => 'Couldn\'t open the app';

  @override
  String get codeNotSent => 'Couldn\'t send the email. Try again in a minute.';

  @override
  String get tooManyAttempts => 'Too many attempts. Try again in an hour.';

  @override
  String get loginToUnlock => 'Sign in to activate the course';

  @override
  String get videoUnavailable =>
      'Couldn\'t load the video. Check your connection.';

  @override
  String get pdfUnavailable => 'Couldn\'t open the PDF. Check your connection.';

  @override
  String get fullscreen => 'Full screen';

  @override
  String get exitFullscreen => 'Exit full screen';

  @override
  String get speed => 'Speed';

  @override
  String get loopAB => 'Loop A–B';

  @override
  String get loopMarkB => 'Mark B';

  @override
  String loopOn(String from, String to) {
    return 'A–B · $from–$to';
  }

  @override
  String get next => 'Next';

  @override
  String get nextLesson => 'Next lesson';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get previewEnded => 'The free preview has ended';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String purchasedBy(String email) {
    return 'Purchased by $email';
  }

  @override
  String pageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get libraryEmpty => 'Your purchases will appear here';

  @override
  String get toCatalog => 'Go to catalog';

  @override
  String get guest => 'Guest';

  @override
  String purchasesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'purchases',
      one: 'purchase',
    );
    return '$_temp0';
  }

  @override
  String lessonsDoneLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lessons done',
      one: 'lesson done',
    );
    return '$_temp0';
  }

  @override
  String get practiceLabel => 'practice';

  @override
  String hours(int h) {
    return '$h h';
  }

  @override
  String minutes(int m) {
    return '$m min';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get musicSchool => 'Music school';

  @override
  String get contacts => 'Contacts';

  @override
  String get signOut => 'Sign out';

  @override
  String get loadError => 'Couldn\'t load';

  @override
  String get retry => 'Retry';

  @override
  String get offlineVideos => 'Videos on phone';

  @override
  String offlineSaving(int percent) {
    return 'Saving · $percent%';
  }

  @override
  String sizeMb(String size) {
    return '$size MB';
  }

  @override
  String sizeGb(String size) {
    return '$size GB';
  }

  @override
  String get offlineDeleteTitle => 'Delete videos from phone?';

  @override
  String get offlineDeleteBody =>
      'Lessons will stream from the internet again.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';
}
