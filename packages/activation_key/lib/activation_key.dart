// Код устройства и ключ активации курсов.
//
// Общий модуль: им пользуются приложение (проверка ключа), генератор ключей
// для музыканта (keygen/) и консольный генератор app/tool/activation_key.dart.
// Чистый Dart без Flutter. Если формула меняется — только здесь.

/// ID-код устройства, который ученик копирует и отправляет школе.
///
/// [rawId] — Android ID (например `f3a9c1e07b5d2846`), [salt] — случайная
/// цифра 1–9, выбранная один раз при первом запуске:
/// 1. каждая латинская буква → её номер в алфавите (A=1 … Z=26), цифры как есть:
///    `R5CR319NT7N` → 18,5,3,18,3,1,9,14,20,7,14 → `1853183191420714`;
/// 2. в начало — [salt]: `61853183191420714`;
/// 3. строка разворачивается: `41702419138135816`.
String deviceCode(String rawId, int salt) {
  assert(salt >= 1 && salt <= 9);
  final digits = StringBuffer('$salt');
  for (final ch in rawId.toUpperCase().split('')) {
    final unit = ch.codeUnitAt(0);
    if (unit >= 0x41 && unit <= 0x5A) {
      digits.write(unit - 0x40); // A=1 … Z=26
    } else if (unit >= 0x30 && unit <= 0x39) {
      digits.write(ch);
    }
  }
  return digits.toString().split('').reversed.join();
}

/// Число → ключ: после каждой цифры её буква (1→A … 9→I), а 0 → `0FFF`.
/// 20986 → `2B0FFF9I8H6F`.
String encodeKeyNumber(int n) {
  final out = StringBuffer();
  for (final ch in n.toString().split('')) {
    final d = int.parse(ch);
    out
      ..write(ch)
      ..write(d == 0 ? 'FFF' : String.fromCharCode(0x40 + d));
  }
  return out.toString();
}

/// Ключ в одном виде: заглавные буквы и цифры без пробелов и дефисов.
String normalizeKey(String input) =>
    input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// Секретное число школы в формуле ключа. Если поменять — все выданные
/// ключи перестанут подходить.
const keySecret = 1985;

/// Сдвиг номера курса в формуле ключа.
const keyCourseOffset = 3;

/// Ключ активации (вариант A, выбран заказчиком 12.10.2026):
/// 1. каждая цифра ID-кода × номер её места слева направо (с 1), всё сложить;
/// 2. сумма × (номер курса + [keyCourseOffset]) + [keySecret];
/// 3. число → ключ через [encodeKeyNumber].
///
/// Пример: код `14140235536843855`, курс 1:
/// 1·1 + 4·2 + 1·3 + 4·4 + 0·5 + 2·6 + 3·7 + 5·8 + 5·9 + 3·10 + 6·11 + 8·12
/// + 4·13 + 3·14 + 8·15 + 5·16 + 5·17 = 717; 717 × 4 + 1985 = 4853 → `4D8H5E3C`.
String expectedKey(String deviceCode, int courseNumber) =>
    encodeKeyNumber(keyNumber(deviceCode, courseNumber));

/// Шаг 1: сумма «цифра × номер места» (места слева направо, с 1).
int weightedSum(String deviceCode) {
  var sum = 0;
  final digits = deviceCode.split('');
  for (var i = 0; i < digits.length; i++) {
    sum += int.parse(digits[i]) * (i + 1);
  }
  return sum;
}

/// Шаги 1–2: число, которое затем превращается в ключ.
int keyNumber(String deviceCode, int courseNumber) =>
    weightedSum(deviceCode) * (courseNumber + keyCourseOffset) + keySecret;

bool verifyKey({
  required String deviceCode,
  required int courseNumber,
  required String key,
}) => normalizeKey(key) == expectedKey(deviceCode, courseNumber);
