import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/theme/app_icons.dart';
import 'package:guitar_school/core/theme/app_theme.dart';

import 'helpers.dart';

Color _background(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).last))
        .scaffoldBackgroundColor;

void main() {
  testWidgets('первый запуск: онбординг → Главная', (tester) async {
    await pumpApp(tester, onboardingSeen: false);

    expect(find.text('Играй любимые песни на гитаре'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.text('Салом!'), findsOneWidget);
    expect(find.text('Курс для новичков'), findsOneWidget);
    expect(find.text('Альбомы песен'), findsOneWidget);
    expect(_background(tester), AppColors.dark.background);
  });

  testWidgets('нижняя панель переключает Главную, Библиотеку и Профиль', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Библиотека'));
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся ваши покупки'), findsOneWidget);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Гость'), findsOneWidget);
    expect(find.text('Активировать курс'), findsOneWidget);

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();
    expect(find.text('Салом!'), findsOneWidget);
  });

  testWidgets('«В каталог» из пустой библиотеки ведёт на Главную', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Библиотека'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В каталог'));
    await tester.pumpAndSettle();

    expect(find.text('Салом!'), findsOneWidget);
  });

  testWidgets('альбом: без цен, бесплатная первая песня, остальные закрыты', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Далер Назаров').first);
    await tester.pumpAndSettle();

    expect(find.text('Активировать курс'), findsOneWidget);
    expect(find.textContaining('сомони'), findsNothing);
    expect(find.text('6:40 · бесплатно'), findsOneWidget);
    expect(find.byIcon(AppIcons.lock), findsNWidgets(9));
  });

  testWidgets('смена языка и темы в Профиле сохраняется', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Тема'));
    await tester.pumpAndSettle();
    expect(_background(tester), AppColors.light.background);

    await tester.tap(find.text('Язык'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тоҷикӣ'));
    await tester.pumpAndSettle();

    expect(find.text('Китобхона'), findsOneWidget);
    expect(find.text('Забон'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('английский интерфейс', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));

    expect(find.text('Hello!'), findsOneWidget);
    expect(find.text('Beginner course'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });
}
