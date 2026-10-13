// Cloudflare R2 (S3-совместимое хранилище): подписанные ссылки на видео и PDF.
// Секреты задаются в Supabase → Edge Functions → Secrets:
//   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
import { AwsClient } from 'npm:aws4fetch@1';

/** Сколько живёт ссылка на просмотр. */
export const VIEW_TTL_SECS = 2 * 60 * 60;
/** Сколько живёт ссылка на загрузку из админки. */
export const UPLOAD_TTL_SECS = 60 * 60;

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`не задан секрет ${name}`);
  return value;
}

function client() {
  return new AwsClient({
    accessKeyId: env('R2_ACCESS_KEY_ID'),
    secretAccessKey: env('R2_SECRET_ACCESS_KEY'),
    service: 's3',
    region: 'auto',
  });
}

function objectUrl(key: string): URL {
  const path = key.split('/').map(encodeURIComponent).join('/');
  return new URL(`https://${env('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com/${env('R2_BUCKET')}/${path}`);
}

/** Подписанная ссылка: GET — смотреть/скачать, PUT — загрузить из браузера. */
export async function presign(method: 'GET' | 'PUT', key: string, ttlSecs: number): Promise<string> {
  const url = objectUrl(key);
  url.searchParams.set('X-Amz-Expires', String(ttlSecs));
  const signed = await client().sign(new Request(url, { method }), { aws: { signQuery: true } });
  return signed.url;
}

export async function deleteObject(key: string): Promise<void> {
  const resp = await client().fetch(objectUrl(key), { method: 'DELETE' });
  if (!resp.ok && resp.status !== 404) throw new Error(`R2 delete ${key}: ${resp.status}`);
}

const EXTENSIONS = {
  video: ['mp4', 'm4v', 'mov', 'webm'],
  pdf: ['pdf'],
} as const;

export type MediaKind = keyof typeof EXTENSIONS;

/** Ключ нового объекта: `videos/<uuid>.mp4`. Имя файла от пользователя в ключ не попадает. */
export function newObjectKey(kind: MediaKind, filename: string): string | null {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  if (!(EXTENSIONS[kind] as readonly string[]).includes(ext)) return null;
  return `${kind}s/${crypto.randomUUID()}.${ext}`;
}

/** Ключ создан сервером — по нему можно удалять/смотреть только свои объекты. */
export function isOurKey(key: unknown): key is string {
  return typeof key === 'string' && /^(videos|pdfs)\/[0-9a-f-]{36}\.[a-z0-9]{2,4}$/.test(key);
}
