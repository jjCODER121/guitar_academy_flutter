import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activation_key/activation_key.dart';

import 'package:guitar_school/app.dart';
import 'package:guitar_school/core/config/distribution.dart';
import 'package:guitar_school/features/catalog/data/mock_catalog.dart';
import 'package:guitar_school/features/purchases/purchases.dart';
import 'package:guitar_school/features/purchases/activation_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(BottomSheet), matching: finder);

Future<void> _enterKey(WidgetTester tester, String key) async {
  await tester.enterText(_inSheet(find.byType(TextField)), key);
  await tester.pump();
  await tester.tap(_inSheet(find.text('Активировать')));
  await tester.pumpAndSettle();
}

/// Нажимает кнопку активации; если просят войти — входит (код из 6 цифр).
Future<void> _openActivation(WidgetTester tester, Finder trigger) async {
  await tester.tap(trigger);
  await tester.pumpAndSettle();
  if (find.text('Получить код').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextField), 'student@mail.tj');
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
  }
}

/// Какие разделы сейчас открыты на телефоне.
Set<String> _openSections(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GuitarSchoolApp)),
  );
  final owned = container.read(ownedProvider).value ?? const <String>{};
  return {
    for (final album in mockAlbums)
      if (owned.owns(album)) album.id,
  };
}

/// Активации, сохранённые на телефоне с [testDeviceCode].
String _savedOnPhone(Map<String, String> activations) =>
    jsonEncode({testDeviceCode: activations});

void main() {
  testWidgets('активация курса: ID-код → неверный ключ → верный → плеер', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    await _openActivation(tester, find.text('Активировать курс'));

    // Сначала вход (активация пишется в аккаунт), затем окно с кодом устройства.
    expect(find.text('Активация курса'), findsOneWidget);
    expect(find.text(testDeviceCode), findsOneWidget);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.tap(_inSheet(find.text('Скопировать')));
    await tester.pump();
    expect(clipboard, testDeviceCode);
    expect(_inSheet(find.text('Скопировано')), findsOneWidget);

    await _enterKey(tester, '9I9I9I');
    expect(find.text('Неверный код активации'), findsOneWidget);

    await _enterKey(tester, expectedKey(testDeviceCode, 1));
    expect(find.text('Открыто!'), findsOneWidget);
    expect(find.text('«Гитара с нуля» — в вашей библиотеке'), findsOneWidget);

    await tester.tap(_inSheet(find.text('Смотреть')));
    await pumpFrames(tester);
    expect(find.text('Урок 1 из 10 · Гитара с нуля'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад').first);
    await tester.pumpAndSettle();
    expect(find.text('Активировать курс'), findsNothing);
    expect(find.text('Смотреть'), findsOneWidget);
  });

  testWidgets('ключ из Профиля открывает свой курс', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await _openActivation(tester, find.text('Активировать курс'));

    await _enterKey(tester, expectedKey(testDeviceCode, 2)); // Далер Назаров
    await tester.tap(_inSheet(find.text('Смотреть')));
    await tester.pumpAndSettle();

    expect(find.text('10 песен · ноты PDF · средний уровень'), findsOneWidget);
    expect(find.text('Смотреть'), findsOneWidget);
  });

  testWidgets('ключ вводится один раз: после перезапуска курс открыт '
      'без интернета и без входа', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    await _openActivation(tester, find.text('Активировать курс'));
    await _enterKey(tester, expectedKey(testDeviceCode, 1));
    expect(find.text('Открыто!'), findsOneWidget);

    // Что приложение сохранило на телефоне.
    final saved = (await SharedPreferences.getInstance()).getString(
      'device_activations',
    )!;

    // Перезапуск: гость (вошедшего нет), сервер недоступен.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      prefs: {'device_activations': saved},
      activationServer: (_) => const OfflineActivationServer(),
    );
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    expect(find.text('Смотреть'), findsOneWidget);
    expect(find.text('Активировать курс'), findsNothing);
  });

  testWidgets('выход из аккаунта и ошибка сети не закрывают курс', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: {
        'mock_session_email': 'student@mail.tj',
        'device_activations': _savedOnPhone({
          'course-basics': expectedKey(testDeviceCode, 1),
        }),
      },
      activationServer: (_) => const OfflineActivationServer(),
    );
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Выйти'), 200);
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    expect(find.text('Смотреть'), findsOneWidget);
  });

  testWidgets('копия настроек на другом телефоне курс не открывает', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: {
        'device_activations': _savedOnPhone({
          'course-basics': expectedKey(testDeviceCode, 1),
        }),
      },
      deviceId: 'ffff9999', // те же настройки, другой Android ID
    );
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    expect(find.text('Активировать курс'), findsOneWidget);
  });

  testWidgets('после переустановки вход возвращает активации из аккаунта', (
    tester,
  ) async {
    // На телефоне пусто, в аккаунте — активация этого телефона.
    await pumpApp(
      tester,
      prefs: {
        'mock_session_email': 'student@mail.tj',
        'activations': jsonEncode({
          'course-basics': expectedKey(testDeviceCode, 1),
        }),
      },
    );
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    expect(find.text('Смотреть'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('device_activations'), contains('course-basics'));
  });

  testWidgets('ключ альбома не открывает его песню, проданную отдельно', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Далер Назаров').first);
    await tester.pumpAndSettle();
    await _openActivation(tester, find.text('Активировать курс'));
    await _enterKey(tester, expectedKey(testDeviceCode, 2));
    await tester.tapAt(const Offset(195, 40)); // закрыть окно
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Назад').first);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('[Песня 1]').first);
    await tester.pumpAndSettle();

    expect(find.text('Смотреть'), findsNothing);
    expect(find.text('Активировать курс'), findsOneWidget);
  });

  testWidgets('каждый раздел открывается только своим ключом — и навсегда', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(_openSections(tester), isEmpty);

    // Ключ альбома «Далер Назаров» (№ 2) — открыт только альбом.
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await _openActivation(tester, find.text('Активировать курс'));
    await _enterKey(tester, expectedKey(testDeviceCode, 2));
    expect(find.text('Открыто!'), findsOneWidget);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(_openSections(tester), {'album-daler'});

    // Ключ отдельной песни (№ 4) — добавилась только она.
    await _openActivation(tester, find.text('Активировать курс'));
    await _enterKey(tester, expectedKey(testDeviceCode, 4));
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(_openSections(tester), {'album-daler', 'single-1'});

    // Перезапуск без интернета и без входа: открыто ровно то же.
    final saved = (await SharedPreferences.getInstance()).getString(
      'device_activations',
    )!;
    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      prefs: {'device_activations': saved},
      activationServer: (_) => const OfflineActivationServer(),
    );
    expect(_openSections(tester), {'album-daler', 'single-1'});
  });

  testWidgets('плеер: скорость и повтор A–B', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Далер Назаров').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6:40 · бесплатно'));
    await pumpFrames(tester);

    expect(find.text('Песня 1 из 10 · Далер Назаров'), findsOneWidget);
    await tester.tap(find.text('0.5×'));
    await pumpFrames(tester);

    await tester.tap(find.text('Повтор A–B'));
    await pumpFrames(tester);
    expect(find.text('Отметить B'), findsOneWidget);
    await tester.tap(find.text('Отметить B'));
    await pumpFrames(tester);
    expect(find.textContaining('A–B ·'), findsOneWidget);
  });

  testWidgets('закрытый урок открывает окно активации', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();
    await _openActivation(tester, find.text('Настройка гитары'));

    expect(find.text('Активация курса'), findsOneWidget);
    expect(find.text(testDeviceCode), findsOneWidget);
  });

  testWidgets('Google Play: в окне активации нет подсказок об оплате', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();

    expect(find.text('Купить'), findsNothing);
    await _openActivation(tester, find.text('Активировать курс'));

    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Позвонить'), findsNothing);
    expect(find.textContaining('Как купить'), findsNothing);
  });

  testWidgets('прямая сборка: «Купить» → подсказка, WhatsApp и звонок', (
    tester,
  ) async {
    await pumpApp(tester, distribution: Distribution.direct);
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();

    await _openActivation(tester, find.text('Купить'));

    expect(
      find.textContaining('Как купить: отправьте этот ID-код'),
      findsOneWidget,
    );
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Позвонить'), findsOneWidget);
    // Ключ можно ввести тут же.
    await _enterKey(tester, expectedKey(testDeviceCode, 1));
    expect(find.text('Открыто!'), findsOneWidget);
  });

  test('ссылка WhatsApp: номер музыканта и готовое сообщение', () {
    const message =
        'Здравствуйте! Хочу купить «Гитара с нуля». Мой ID-код: 41702419138135816';
    final uri = whatsAppUri(message);
    expect(uri.host, 'wa.me');
    expect(uri.path, '/992000000000');
    expect(uri.queryParameters['text'], message);
    expect(phoneUri().toString(), 'tel:+992000000000');
  });
}
