// POST /functions/v1/media-url  { lesson_id | material_id, device_code?, key? }
// Временная ссылка (2 часа) на видео урока или PDF в R2.
// Бесплатный урок — всем, даже гостю. Остальное — если ЭТОТ продукт активирован
// на этом телефоне своим ключом: в аккаунте ученика или по ключу, сохранённому
// в приложении (тогда вход не нужен — активация навсегда остаётся на телефоне).
// Ключ одного раздела другие не открывает (даже песню из альбома, проданную
// отдельно). Отзыв активации в админке закрывает оба пути.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

import { isDeviceCode, normalizeKey } from '../_shared/activation.ts';
import { adminClient, currentUser } from '../_shared/clients.ts';
import { body, error, json, preflight } from '../_shared/http.ts';
import { presign, VIEW_TTL_SECS } from '../_shared/r2.ts';

async function hasAccess(
  db: SupabaseClient,
  productId: string,
  deviceCode: string,
  userId: string | null,
  key: string | null,
): Promise<boolean> {
  const activations = () =>
    db
      .from('activations')
      .select('id', { count: 'exact', head: true })
      .eq('device_code', deviceCode)
      .eq('product_id', productId);

  if (userId) {
    const { count } = await activations().eq('user_id', userId);
    if ((count ?? 0) > 0) return true;
  }
  if (key) {
    const { count } = await activations().eq('activation_key', key);
    if ((count ?? 0) > 0) return true;
  }
  return false;
}

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const { lesson_id, material_id, device_code, key } = await body<{
    lesson_id: string;
    material_id: string;
    device_code: string;
    key: string;
  }>(req);
  const db = adminClient();

  let objectKey: string | null = null;
  let productId: string;
  let free = false;

  if (typeof lesson_id === 'string') {
    const { data: lesson } = await db
      .from('lessons')
      .select('video_key, is_free_preview, preview_limit_sec, product_id, products!inner(is_published)')
      .eq('id', lesson_id)
      .eq('products.is_published', true)
      .maybeSingle();
    if (!lesson) return error(404, 'not_found', 'урок не найден');
    objectKey = lesson.video_key;
    productId = lesson.product_id;
    free = lesson.is_free_preview || lesson.preview_limit_sec !== null;
  } else if (typeof material_id === 'string') {
    const { data: material } = await db
      .from('materials')
      .select('file_key, product_id, products!inner(is_published)')
      .eq('id', material_id)
      .eq('products.is_published', true)
      .maybeSingle();
    if (!material) return error(404, 'not_found', 'материал не найден');
    objectKey = material.file_key;
    productId = material.product_id;
  } else {
    return error(400, 'bad_request', 'нужен lesson_id или material_id');
  }

  if (!objectKey) return error(404, 'not_found', 'файл ещё не загружен');

  if (!free) {
    const user = await currentUser(req);
    const savedKey =
      typeof key === 'string' && key.length <= 64 && normalizeKey(key) !== ''
        ? normalizeKey(key)
        : null;
    if (!user && !savedKey) return error(401, 'unauthorized', 'требуется вход');
    if (
      !isDeviceCode(device_code) ||
      !(await hasAccess(db, productId, device_code, user?.id ?? null, savedKey))
    ) {
      return error(403, 'forbidden', 'курс не активирован на этом телефоне');
    }
  }

  return json({ url: await presign('GET', objectKey, VIEW_TTL_SECS), expires_in: VIEW_TTL_SECS });
});
