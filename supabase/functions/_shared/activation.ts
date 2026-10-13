// Ключ активации — та же формула, что в packages/activation_key (Dart) и server/src/activation.rs.
// Совпадение проверяет activation.test.ts по общему файлу packages/activation_key/test/vectors.json.
// Формула живёт только на сервере: в приложении её нет.

/** Секретное число школы в формуле ключа. Смена — все выданные ключи перестанут подходить. */
export const KEY_SECRET = 1985;
/** Сдвиг номера курса. */
export const KEY_COURSE_OFFSET = 3;

/** ID-код устройства — только цифры. */
export function isDeviceCode(code: unknown): code is string {
  return typeof code === 'string' && /^\d{1,64}$/.test(code);
}

/** Сумма «цифра × номер места» (места слева направо, с 1). */
export function weightedSum(code: string): number {
  let sum = 0;
  for (let i = 0; i < code.length; i++) sum += Number(code[i]) * (i + 1);
  return sum;
}

export function keyNumber(code: string, course: number): number {
  return weightedSum(code) * (course + KEY_COURSE_OFFSET) + KEY_SECRET;
}

/** После каждой цифры — её буква (1→A … 9→I), 0 → `0FFF`. */
export function encodeKeyNumber(n: number): string {
  let out = '';
  for (const ch of String(n)) {
    out += ch === '0' ? '0FFF' : ch + String.fromCharCode(64 + Number(ch));
  }
  return out;
}

export function expectedKey(code: string, course: number): string {
  return encodeKeyNumber(keyNumber(code, course));
}

/** Заглавные латинские буквы и цифры, без пробелов и дефисов. */
export function normalizeKey(input: string): string {
  return input.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function verifyKey(code: string, course: number, key: string): boolean {
  return isDeviceCode(code) && expectedKey(code, course) === normalizeKey(key);
}
