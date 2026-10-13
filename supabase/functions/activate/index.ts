// POST /functions/v1/activate  { device_code, key, product_id? }  (нужен вход ученика)
// Проверяет ключ активации и записывает доступ в аккаунт: user + продукт + телефон.
// Ответ: { product_id } или ошибка invalid_key / too_many_attempts.
import { isDeviceCode, normalizeKey, verifyKey } from '../_shared/activation.ts';
import { adminClient, currentUser } from '../_shared/clients.ts';
import { body, error, json, preflight } from '../_shared/http.ts';

/** Неудачных попыток в час — дальше пауза (защита от перебора ключей). */
const MAX_FAILED_PER_HOUR = 10;

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const user = await currentUser(req);
  if (!user) return error(401, 'unauthorized', 'требуется вход');

  const { device_code, key, product_id } = await body<{
    device_code: string;
    key: string;
    product_id: string;
  }>(req);
  if (!isDeviceCode(device_code)) return error(400, 'bad_request', 'неверный ID-код устройства');
  if (typeof key !== 'string' || key.length > 64 || normalizeKey(key) === '') {
    return error(400, 'invalid_key', 'неверный код активации');
  }

  const db = adminClient();
  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await db
    .from('activation_attempts')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', hourAgo);
  if ((count ?? 0) >= MAX_FAILED_PER_HOUR) {
    return error(429, 'too_many_attempts', 'слишком много попыток — попробуйте через час');
  }

  const { data: products, error: dbError } = await db
    .from('products')
    .select('id, activation_number');
  if (dbError) return error(500, 'internal', 'внутренняя ошибка сервера');

  // Сначала курс, с экрана которого активируют, затем остальные.
  const ordered = [...products].sort(
    (a, b) => Number(b.id === product_id) - Number(a.id === product_id),
  );
  const match = ordered.find((p) => verifyKey(device_code, p.activation_number, key));
  if (!match) {
    await db.from('activation_attempts').insert({ user_id: user.id });
    return error(400, 'invalid_key', 'неверный код активации');
  }

  const { error: insertError } = await db.from('activations').upsert(
    {
      user_id: user.id,
      product_id: match.id,
      device_code,
      activation_key: normalizeKey(key),
    },
    { onConflict: 'user_id,product_id,device_code', ignoreDuplicates: true },
  );
  if (insertError) return error(500, 'internal', 'внутренняя ошибка сервера');

  return json({ product_id: match.id });
});
