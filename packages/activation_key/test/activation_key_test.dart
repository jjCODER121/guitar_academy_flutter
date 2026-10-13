import 'dart:convert';
import 'dart:io';

import 'package:activation_key/activation_key.dart';
import 'package:test/test.dart';

void main() {
  group('код устройства и ключ', () {
    test('пример из ТЗ: R5CR319NT7N и цифра 6 → 41702419138135816', () {
      expect(deviceCode('R5CR319NT7N', 6), '41702419138135816');
    });

    test('Android ID: строчные буквы a–f тоже становятся номерами', () {
      expect(deviceCode('f3a9c1e07b5d2846', 7), '64824527051391367');
    });

    test('число → ключ: цифра и её буква, 0 → 0FFF', () {
      expect(encodeKeyNumber(20986), '2B0FFF9I8H6F');
    });

    test('ввод ключа нормализуется', () {
      expect(normalizeKey(' 1a-2b 8h '), '1A2B8H');
    });

    test('вариант A: пример из обсуждения — 14140235536843855, курс 1', () {
      // 717 × 4 + 1985 = 4853
      expect(expectedKey('14140235536843855', 1), '4D8H5E3C');
      // 717 × 5 + 1985 = 5570
      expect(expectedKey('14140235536843855', 2), '5E5E7G0FFF');
      // 418 × 4 + 1985 = 3657 (код с эмулятора)
      expect(expectedKey('51911340410383015', 1), '3C6F5E7G');
    });

    test('вариант A: порядок цифр важен, сумма цифр — нет', () {
      // Те же цифры в другом порядке — другой ключ.
      expect(
        expectedKey('12345678901234567', 1),
        isNot(expectedKey('76543210987654321', 1)),
      );
    });

    test('ключ своего курса подходит, чужого курса и телефона — нет', () {
      expect(expectedKey('41702419138135816', 1), '4D4D8H9I'); // 626 × 4 + 1985
      expect(
        verifyKey(
          deviceCode: '41702419138135816',
          courseNumber: 1,
          key: '4d4d8h9i',
        ),
        isTrue,
      );
      expect(
        verifyKey(
          deviceCode: '41702419138135816',
          courseNumber: 2,
          key: '4D4D8H9I',
        ),
        isFalse,
      );
      expect(
        verifyKey(
          deviceCode: deviceCode('AAAA1111', 6),
          courseNumber: 1,
          key: '4D4D8H9I',
        ),
        isFalse,
      );
    });
  });

  test('общие примеры (их же проверяет сервер на Rust)', () {
    final v = jsonDecode(
      File('test/vectors.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final d in (v['deviceCodes'] as List).cast<Map<String, dynamic>>()) {
      expect(deviceCode(d['rawId'] as String, d['salt'] as int), d['code']);
    }
    for (final e in (v['encode'] as List).cast<Map<String, dynamic>>()) {
      expect(encodeKeyNumber(e['number'] as int), e['key']);
    }
    for (final k in (v['keys'] as List).cast<Map<String, dynamic>>()) {
      expect(expectedKey(k['code'] as String, k['course'] as int), k['key']);
    }
  });
}
