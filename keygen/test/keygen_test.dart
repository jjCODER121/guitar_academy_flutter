import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_keygen/main.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const KeygenApp());
}

void main() {
  testWidgets('ID-код + курс → ключ и расчёт', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), '14140235536843855');
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();

    expect(find.text('4D8H5E3C'), findsOneWidget);
    expect(find.textContaining('717 × (1 + 3) + 1985 = 4853'), findsOneWidget);
    expect(find.text('Отправить'), findsOneWidget);

    await tester.tap(find.text('Далер Назаров'));
    await tester.pumpAndSettle();
    expect(find.text('5E5E7G0FFF'), findsOneWidget);
  });

  testWidgets('без курса ключа нет; неполный код — подсказка', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), '1414023553');
    await tester.pump();

    expect(find.text('Отправить'), findsNothing);
    expect(find.textContaining('здесь 10'), findsOneWidget);
  });

  testWidgets('«Вставить» берёт из буфера только цифры', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'Мой код: 1414 0235 5368 43855'}
          : null,
    );
    await _pump(tester);

    await tester.tap(find.byTooltip('Вставить'));
    await tester.pump();

    expect(find.text('14140235536843855'), findsOneWidget);
  });

  testWidgets('«Скопировать» кладёт ключ в буфер', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await _pump(tester);
    await tester.enterText(find.byType(TextField), '14140235536843855');
    await tester.tap(find.text('Гитара с нуля'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Скопировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скопировать'));
    await tester.pump();

    expect(copied, '4D8H5E3C');
    expect(find.text('Скопировано'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
