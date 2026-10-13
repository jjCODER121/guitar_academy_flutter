// Проверка миграции Supabase в PGlite: заглушки auth/storage, затем RLS и триггеры.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const migration = readFileSync(new URL('../migrations/20261012120000_init.sql', import.meta.url), 'utf8');
const db = new PGlite();

// --- заглушки того, что есть в Supabase
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create schema auth;
  create table auth.users (id uuid primary key, email text);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  alter table storage.objects enable row level security;
`);

await db.exec(migration);
await db.exec(`
  grant usage on schema public to anon, authenticated;
  grant select, insert, update, delete on all tables in schema public to anon, authenticated;
  grant usage, select on all sequences in schema public to anon, authenticated;
  grant execute on all functions in schema public to anon, authenticated;
`);

const ADMIN = '11111111-1111-1111-1111-111111111111';
const STUDENT = '22222222-2222-2222-2222-222222222222';
await db.exec(`
  insert into auth.users values ('${ADMIN}', 'admin@school.tj'), ('${STUDENT}', 'student@mail.tj');
  insert into public.admins (user_id) values ('${ADMIN}');
`);

async function as(role, sub, fn) {
  await db.exec(`set role ${role}; select set_config('request.jwt.claim.sub', '${sub ?? ''}', false);`);
  try {
    return await fn();
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}
const rows = async (sql, params) => (await db.query(sql, params)).rows;

// --- профили создаются триггером
assert.equal((await rows('select count(*)::int as n from public.profiles'))[0].n, 2);

// --- админ создаёт курс: номер для ключа выдаётся сам
const course = await as('authenticated', ADMIN, async () => {
  const [p] = await rows(`insert into public.products (type, title, price_somoni) values ('course', 'Гитара с нуля', 150) returning id, activation_number`);
  assert.equal(p.activation_number, 1);
  const [p2] = await rows(`insert into public.products (type, title) values ('song_album', 'Далер Назаров') returning activation_number`);
  assert.equal(p2.activation_number, 2);
  for (const t of ['Урок 1', 'Урок 2', 'Урок 3']) {
    await rows(`insert into public.lessons (product_id, title) values ($1, $2)`, [p.id, t]);
  }
  return p.id;
});

let lessons = await rows(`select id, position, title from public.lessons where product_id = $1 order by position`, [course]);
assert.deepEqual(lessons.map((l) => l.position), [1, 2, 3], 'номера уроков по порядку');

// --- перестановка одним действием (только админ)
await as('authenticated', ADMIN, () =>
  rows(`select public.reorder_lessons($1, $2::uuid[])`, [course, [lessons[2].id, lessons[0].id, lessons[1].id]]));
lessons = await rows(`select title, position from public.lessons where product_id = $1 order by position`, [course]);
assert.deepEqual(lessons.map((l) => l.title), ['Урок 3', 'Урок 1', 'Урок 2']);

await assert.rejects(
  as('authenticated', STUDENT, () => rows(`select public.reorder_lessons($1, '{}'::uuid[])`, [course])),
  /forbidden/,
  'ученик не может менять порядок',
);

// --- удаление урока сдвигает номера
await as('authenticated', ADMIN, () => rows(`delete from public.lessons where title = 'Урок 1'`));
lessons = await rows(`select title, position from public.lessons where product_id = $1 order by position`, [course]);
assert.deepEqual(lessons.map((l) => [l.title, l.position]), [['Урок 3', 1], ['Урок 2', 2]]);

// --- RLS: черновик не виден гостю и ученику, виден админу
const visible = (role, sub) => as(role, sub, () => rows(`select title from public.products order by activation_number`));
assert.equal((await visible('anon', null)).length, 0);
assert.equal((await visible('authenticated', STUDENT)).length, 0);
assert.equal((await visible('authenticated', ADMIN)).length, 2);

await as('authenticated', ADMIN, () => rows(`update public.products set is_published = true where id = $1`, [course]));
assert.deepEqual((await visible('anon', null)).map((r) => r.title), ['Гитара с нуля']);
assert.equal((await as('anon', null, () => rows(`select * from public.lessons`))).length, 2, 'уроки опубликованного курса видны гостю');

// --- ученик не может править каталог
await as('authenticated', STUDENT, () => rows(`update public.products set title = 'взлом' where id = $1`, [course]));
assert.equal((await rows(`select title from public.products where id = $1`, [course]))[0].title, 'Гитара с нуля');
await assert.rejects(
  as('authenticated', STUDENT, () => rows(`insert into public.products (type, title) values ('course', 'x')`)),
  /row-level security/,
);

// --- активации: пишет только функция (service_role = владелец), ученик видит свои
await rows(`insert into public.activations (user_id, product_id, device_code, activation_key) values ($1, $2, '14140235536843855', '4D8H5E3C')`, [STUDENT, course]);
assert.equal((await as('authenticated', STUDENT, () => rows(`select * from public.activations`))).length, 1);
assert.equal((await as('authenticated', ADMIN, () => rows(`select * from public.activations`))).length, 1);
assert.equal((await as('anon', null, () => rows(`select * from public.activations`))).length, 0);
await assert.rejects(
  as('authenticated', STUDENT, () => rows(`insert into public.activations (user_id, product_id, device_code, activation_key) values ($1, $2, '1', 'X')`, [STUDENT, course])),
  /row-level security/,
  'ученик не может сам выдать себе доступ',
);

// --- продажи и статистика — только админ
await as('authenticated', ADMIN, () => rows(`insert into public.sales (product_id, device_code, activation_key, student, amount_somoni) values ($1, '14140235536843855', '4D8H5E3C', 'Фарход', 150)`, [course]));
const adminTotals = await as('authenticated', ADMIN, () => rows(`select * from public.sales_totals()`));
assert.equal(Number(adminTotals[0].revenue), 150);
const studentTotals = await as('authenticated', STUDENT, () => rows(`select * from public.sales_totals()`));
assert.equal(Number(studentTotals[0].sales), 0, 'ученик не видит продаж');
const top = await as('authenticated', ADMIN, () => rows(`select * from public.top_products()`));
assert.equal(top[0].title, 'Гитара с нуля');
const months = await as('authenticated', ADMIN, () => rows(`select * from public.sales_by_month(now() - interval '1 year')`));
assert.equal(months.length, 1);

// --- прогресс: только свой
await as('authenticated', STUDENT, async () => {
  const [l] = await rows(`select id from public.lessons limit 1`);
  await rows(`insert into public.lesson_progress (user_id, lesson_id, position_sec) values ($1, $2, 30)`, [STUDENT, l.id]);
});
assert.equal((await as('authenticated', ADMIN, () => rows(`select * from public.lesson_progress`))).length, 0);

// --- продукт с активациями удалить нельзя
await assert.rejects(
  as('authenticated', ADMIN, () => rows(`delete from public.products where id = $1`, [course])),
  /foreign key/,
);

console.log('migration OK: все проверки прошли');
