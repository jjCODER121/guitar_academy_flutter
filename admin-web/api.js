// Данные админки: Supabase (база, обложки, функции) и Cloudflare R2 (видео, PDF).
// Права проверяет сервер: правила RLS пускают к записи только администратора,
// функция «admin» — тоже. Здесь только вызовы.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.3/+esm';

import { SUPABASE_KEY, SUPABASE_URL } from './config.js';

export const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

/** Понятный текст ошибки Supabase / функции. */
export class ApiError extends Error {}

function fail(error, fallback = 'Не получилось — попробуйте ещё раз') {
  if (!error) return;
  const msg = error.message || fallback;
  if (error.code === '23503') {
    throw new ApiError('По этому продукту уже есть продажи или активации — его можно снять с публикации, но не удалить');
  }
  if (error.code === '42501' || /row-level security/i.test(msg)) {
    throw new ApiError('Нет прав. Войдите как администратор.');
  }
  throw new ApiError(msg);
}

// ------------------------------------------------------------------ вход

export async function signIn(email, password) {
  const { error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw new ApiError('Неверная почта или пароль');
  if (!(await isAdmin())) {
    await sb.auth.signOut();
    throw new ApiError('У этой учётной записи нет прав администратора');
  }
}

export const signOut = () => sb.auth.signOut();

export async function currentUser() {
  const { data } = await sb.auth.getSession();
  return data.session?.user ?? null;
}

export async function isAdmin() {
  const user = await currentUser();
  if (!user) return false;
  const { data } = await sb.from('admins').select('user_id').eq('user_id', user.id).maybeSingle();
  return data !== null;
}

// ------------------------------------------------------------------ функция admin

async function adminFn(body) {
  const { data, error } = await sb.functions.invoke('admin', { body });
  if (error) {
    let message = 'Ошибка сервера';
    try {
      message = (await error.context.json()).error.message;
    } catch { /* не JSON */ }
    throw new ApiError(message);
  }
  return data;
}

export const previewUrl = (key) => adminFn({ action: 'preview-url', key }).then((d) => d.url);

export async function deleteObjects(keys) {
  const list = keys.filter(Boolean);
  if (list.length) await adminFn({ action: 'delete-objects', keys: list });
}

/**
 * Загрузка файла прямо в R2 по подписанной ссылке, с прогрессом.
 * onProgress(доля 0..1, загружено байт). Возвращает ключ объекта.
 */
export async function uploadToR2(kind, file, onProgress) {
  const { key, url } = await adminFn({ action: 'upload-url', kind, filename: file.name });
  await new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', url);
    xhr.setRequestHeader('Content-Type', file.type || (kind === 'pdf' ? 'application/pdf' : 'video/mp4'));
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) onProgress?.(e.loaded / e.total, e.loaded);
    });
    xhr.addEventListener('load', () => (xhr.status >= 200 && xhr.status < 300
      ? resolve()
      : reject(new ApiError(`Хранилище ответило ${xhr.status}. Проверьте CORS бакета R2.`))));
    xhr.addEventListener('error', () => reject(new ApiError(
      'Связь с хранилищем прервалась. Если ошибка повторяется — проверьте CORS бакета R2 (нужен PUT).',
    )));
    xhr.send(file);
  });
  return key;
}

// ------------------------------------------------------------------ продукты

export async function listProducts(type) {
  let q = sb
    .from('products')
    .select('id, type, title, subtitle, level, price_somoni, activation_number, cover_path, is_published, lessons(id, video_key), sales(count)')
    .order('sort_order')
    .order('created_at');
  if (type) q = q.eq('type', type);
  const { data, error } = await q;
  fail(error);
  return data;
}

export async function getProduct(id) {
  const { data, error } = await sb
    .from('products')
    .select('*, lessons(*), materials(*)')
    .eq('id', id)
    .order('position', { referencedTable: 'lessons' })
    .order('position', { referencedTable: 'materials' })
    .single();
  fail(error, 'Продукт не найден');
  return data;
}

export async function createProduct(type, title) {
  const { data, error } = await sb.from('products').insert({ type, title }).select('id').single();
  fail(error);
  return data.id;
}

export async function updateProduct(id, fields) {
  const { error } = await sb.from('products').update(fields).eq('id', id);
  fail(error);
}

export async function deleteProduct(product) {
  const keys = [
    ...product.lessons.map((l) => l.video_key),
    ...product.materials.map((m) => m.file_key),
  ];
  const { error } = await sb.from('products').delete().eq('id', product.id);
  fail(error);
  await deleteObjects(keys);
  if (product.cover_path) await sb.storage.from('covers').remove([product.cover_path]);
}


export function coverUrl(path) {
  return path ? sb.storage.from('covers').getPublicUrl(path).data.publicUrl : null;
}

export async function uploadCover(product, file) {
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const path = `${product.id}/${crypto.randomUUID()}.${ext}`;
  const { error } = await sb.storage.from('covers').upload(path, file, { contentType: file.type });
  fail(error);
  await updateProduct(product.id, { cover_path: path });
  if (product.cover_path) await sb.storage.from('covers').remove([product.cover_path]);
}

// ------------------------------------------------------------------ уроки и PDF

export async function addLesson(productId, title) {
  const { error } = await sb.from('lessons').insert({ product_id: productId, title });
  fail(error);
}

export async function updateLesson(id, fields) {
  const { error } = await sb.from('lessons').update(fields).eq('id', id);
  fail(error);
}

export async function deleteLesson(lesson) {
  fail((await sb.from('lessons').delete().eq('id', lesson.id)).error);
  await deleteObjects([lesson.video_key]);
}

export async function reorderLessons(productId, ids) {
  const { error } = await sb.rpc('reorder_lessons', { product: productId, ids });
  fail(error);
}

export async function setLessonVideo(lesson, key, durationSec) {
  await updateLesson(lesson.id, { video_key: key, duration_sec: Math.round(durationSec) });
  if (lesson.video_key && lesson.video_key !== key) await deleteObjects([lesson.video_key]);
}

export async function addMaterial(productId, lessonId, title, fileKey) {
  const { error } = await sb.from('materials').insert({
    product_id: productId,
    lesson_id: lessonId || null,
    title,
    file_key: fileKey,
  });
  if (error) {
    await deleteObjects([fileKey]);
    fail(error);
  }
}

export async function deleteMaterial(material) {
  fail((await sb.from('materials').delete().eq('id', material.id)).error);
  await deleteObjects([material.file_key]);
}

// ------------------------------------------------------------------ ключи и продажи

export const generateKey = (fields) => adminFn({ action: 'generate-key', ...fields });

export async function listSales({ query, productId, since } = {}) {
  let q = sb
    .from('sales')
    .select('*, products(title, activation_number)')
    .order('created_at', { ascending: false })
    .limit(1000);
  if (productId) q = q.eq('product_id', productId);
  if (since) q = q.gte('created_at', since);
  // Спецсимволы фильтра PostgREST убираем, значение — в кавычках (пробелы допустимы).
  const s = query?.trim().replace(/[,()*%"\\]/g, ' ').trim();
  if (s) q = q.or(`student.ilike."*${s}*",device_code.ilike."*${s}*",activation_key.ilike."*${s}*"`);
  const { data, error } = await q;
  fail(error);
  return data;
}

export async function deleteSale(id) {
  fail((await sb.from('sales').delete().eq('id', id)).error);
}

/** Кто из учеников активировал курсы (с почтой). */
export async function listActivations() {
  const { data, error } = await sb
    .from('activations')
    .select('id, user_id, device_code, created_at, products(title)')
    .order('created_at', { ascending: false })
    .limit(100);
  fail(error);
  const ids = [...new Set(data.map((a) => a.user_id))];
  const emails = new Map();
  if (ids.length) {
    const { data: profiles } = await sb.from('profiles').select('id, email').in('id', ids);
    for (const p of profiles ?? []) emails.set(p.id, p.email);
  }
  return data.map((a) => ({ ...a, email: emails.get(a.user_id) ?? '—' }));
}

export async function revokeActivation(id) {
  fail((await sb.from('activations').delete().eq('id', id)).error);
}

// ------------------------------------------------------------------ статистика

export async function totals(since) {
  const { data, error } = await sb.rpc('sales_totals', { since });
  fail(error);
  return data[0] ?? { sales: 0, revenue: 0, devices: 0 };
}

export async function salesByMonth(since) {
  const { data, error } = await sb.rpc('sales_by_month', { since });
  fail(error);
  return data;
}

export async function topProducts(since, maxRows = 5) {
  const { data, error } = await sb.rpc('top_products', { since, max_rows: maxRows });
  fail(error);
  return data;
}

export async function counts() {
  const [{ count: students }, { count: activations }] = await Promise.all([
    sb.from('profiles').select('id', { count: 'exact', head: true }),
    sb.from('activations').select('id', { count: 'exact', head: true }),
  ]);
  return { students: students ?? 0, activations: activations ?? 0 };
}
