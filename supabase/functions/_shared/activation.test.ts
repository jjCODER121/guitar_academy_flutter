// Запуск: node --test supabase/functions/_shared/activation.test.ts
// (Node 22+ понимает TypeScript сам.)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { encodeKeyNumber, expectedKey, normalizeKey, verifyKey } from './activation.ts';

const vectors = JSON.parse(
  readFileSync(new URL('../../../packages/activation_key/test/vectors.json', import.meta.url), 'utf8'),
) as {
  encode: { number: number; key: string }[];
  keys: { code: string; course: number; key: string }[];
};

test('совпадает с общими примерами (Dart, Rust)', () => {
  for (const e of vectors.encode) assert.equal(encodeKeyNumber(e.number), e.key);
  for (const k of vectors.keys) {
    assert.equal(expectedKey(k.code, k.course), k.key, `${k.code} / ${k.course}`);
    assert.ok(verifyKey(k.code, k.course, k.key.toLowerCase()));
  }
});

test('чужой курс и не цифры — не подходят', () => {
  assert.equal(verifyKey('14140235536843855', 2, '4D8H5E3C'), false);
  assert.equal(verifyKey('12a4', 1, '4D8H5E3C'), false);
});

test('ввод нормализуется', () => {
  assert.equal(normalizeKey(' 4d-8h 5e3c '), '4D8H5E3C');
});
