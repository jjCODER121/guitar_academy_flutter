// Генератор ключей активации для проверки на телефоне, пока нет админки.
//
//   cd app
//   dart run tool/activation_key.dart <ID-код устройства> <номер курса>
//
// Номера курсов в тестовом каталоге: 1 — «Гитара с нуля», 2 — «Далер Назаров»,
// 3 — «Муборакшох», 4–6 — отдельные песни.

import 'dart:io';

import 'package:activation_key/activation_key.dart';

void main(List<String> args) {
  final course = args.length == 2 ? int.tryParse(args[1]) : null;
  if (course == null || !RegExp(r'^\d+$').hasMatch(args[0])) {
    stderr.writeln(
      'Использование: dart run tool/activation_key.dart <ID-код> <номер курса>',
    );
    exit(64);
  }
  final code = args[0];
  final sum = weightedSum(code);
  final n = keyNumber(code, course);
  stdout
    ..writeln('Сумма «цифра × место»: $sum')
    ..writeln('$sum × ($course + $keyCourseOffset) + $keySecret = $n')
    ..writeln('Ключ: ${expectedKey(code, course)}');
}
