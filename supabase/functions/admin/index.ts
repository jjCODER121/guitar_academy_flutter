// POST /functions/v1/admin  { action, ... }  — только для администратора (таблица admins).
//   upload-url     { kind: 'video'|'pdf', filename }        → { key, url }   загрузка прямо в R2 (PUT)
//   preview-url    { key }                                  → { url }        посмотреть загруженное
//   delete-objects { keys: string[] }                       → { deleted }    убрать файлы из R2
//   generate-key   { device_code, product_id, student?, amount? } → { sale } ключ + запись в журнал продаж
import { expectedKey, isDeviceCode, KEY_COURSE_OFFSET, KEY_SECRET, weightedSum } from '../_shared/activation.ts';
import { adminClient, currentUser, isAdmin } from '../_shared/clients.ts';
import { body, error, json, preflight } from '../_shared/http.ts';
import {
  deleteObject,
  isOurKey,
  type MediaKind,
  newObjectKey,
  presign,
  UPLOAD_TTL_SECS,
  VIEW_TTL_SECS,
} from '../_shared/r2.ts';

type Payload = {
  action: string;
  kind: MediaKind;
  filename: string;
  key: string;
  keys: string[];
  device_code: string;
  product_id: string;
  student: string;
  amount: number | string | null;
};

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const user = await currentUser(req);
  if (!user) return error(401, 'unauthorized', 'требуется вход');
  const db = adminClient();
  if (!(await isAdmin(db, user.id))) return error(403, 'forbidden', 'нет доступа');

  const p = await body<Payload>(req);
  switch (p.action) {
    case 'upload-url': {
      if (p.kind !== 'video' && p.kind !== 'pdf') return error(400, 'bad_request', 'неизвестный тип файла');
      const key = newObjectKey(p.kind, String(p.filename ?? ''));
      if (!key) {
        return error(400, 'bad_request', p.kind === 'video' ? 'нужен файл MP4, MOV, M4V или WEBM' : 'нужен файл PDF');
      }
      return json({ key, url: await presign('PUT', key, UPLOAD_TTL_SECS) });
    }

    case 'preview-url': {
      if (!isOurKey(p.key)) return error(400, 'bad_request', 'неверный ключ файла');
      return json({ url: await presign('GET', p.key, VIEW_TTL_SECS) });
    }

    case 'delete-objects': {
      const keys = Array.isArray(p.keys) ? p.keys.filter(isOurKey) : [];
      await Promise.all(keys.map(deleteObject));
      return json({ deleted: keys.length });
    }

    case 'generate-key': {
      const code = String(p.device_code ?? '').replace(/\D/g, '');
      if (!isDeviceCode(code)) return error(400, 'bad_request', 'введите ID-код ученика — только цифры');
      const { data: product } = await db
        .from('products')
        .select('id, title, activation_number, price_somoni')
        .eq('id', p.product_id ?? '')
        .maybeSingle();
      if (!product) return error(400, 'bad_request', 'выберите продукт');

      let amount: number | null = product.price_somoni;
      if (p.amount !== undefined && p.amount !== null && String(p.amount).trim() !== '') {
        amount = Number(p.amount);
        if (!Number.isInteger(amount) || amount < 0) {
          return error(400, 'bad_request', 'сумма — целое число сомони');
        }
      }

      const key = expectedKey(code, product.activation_number);
      const { data: sale, error: insertError } = await db
        .from('sales')
        .insert({
          product_id: product.id,
          device_code: code,
          activation_key: key,
          student: String(p.student ?? '').trim().slice(0, 120),
          amount_somoni: amount,
        })
        .select()
        .single();
      if (insertError) return error(500, 'internal', 'внутренняя ошибка сервера');

      const sum = weightedSum(code);
      return json({
        sale,
        product_title: product.title,
        // Расчёт — чтобы сверить с ручным.
        calc: `${sum} × (${product.activation_number} + ${KEY_COURSE_OFFSET}) + ${KEY_SECRET}`,
      });
    }

    default:
      return error(400, 'bad_request', 'неизвестное действие');
  }
});
