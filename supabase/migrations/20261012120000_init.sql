-- Гитарная школа: каталог, ученики, активации, продажи.
-- Видео и PDF лежат в Cloudflare R2 (здесь — только ключи объектов),
-- обложки — в публичном бакете Supabase Storage «covers».

-- ---------------------------------------------------------------- администраторы

create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- security definer: функция видит таблицу admins, даже если RLS вызывающего не даёт.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------------------------------------------------------------- профили учеников

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  name text,
  locale text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- каталог

-- Номер продукта в формуле ключа: выдаётся по порядку и не меняется никогда.
create sequence public.product_activation_number_seq;

create table public.products (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('course', 'song_album', 'single')),
  title text not null check (length(trim(title)) > 0),
  subtitle text not null default '',
  level text not null default 'beginner'
    check (level in ('beginner', 'intermediate', 'advanced')),
  -- Для статистики и генератора; в приложении не показывается.
  price_somoni integer check (price_somoni >= 0),
  activation_number integer not null unique
    default nextval('public.product_activation_number_seq'),
  cover_path text,
  is_published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter sequence public.product_activation_number_seq owned by public.products.activation_number;

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  -- Заполняется триггером: следующий номер в продукте.
  position integer,
  title text not null check (length(trim(title)) > 0),
  duration_sec integer not null default 0,
  video_key text,
  is_free_preview boolean not null default false,
  -- Для отдельной песни: бесплатны только первые N секунд.
  preview_limit_sec integer check (preview_limit_sec between 5 and 600),
  -- deferrable: при перестановке уроков номера временно совпадают.
  unique (product_id, position) deferrable initially deferred
);
create index lessons_product on public.lessons (product_id, position);

-- PDF к уроку (ноты песни) или ко всему продукту (lesson_id is null).
create table public.materials (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  lesson_id uuid references public.lessons (id) on delete set null,
  position integer,
  title text not null,
  file_key text not null
);
create index materials_product on public.materials (product_id, position);

-- Песня из альбома, которая продаётся и отдельно: ключ альбома открывает и её.
create table public.product_links (
  song_album_id uuid not null references public.products (id) on delete cascade,
  single_id uuid not null references public.products (id) on delete cascade,
  primary key (song_album_id, single_id)
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();

-- Новый урок / PDF — в конец списка своего продукта.
create or replace function public.set_next_position()
returns trigger
language plpgsql
as $$
begin
  if new.position is null then
    execute format(
      'select coalesce(max(position), 0) + 1 from %I.%I where product_id = $1',
      tg_table_schema, tg_table_name
    ) into new.position using new.product_id;
  end if;
  return new;
end;
$$;

create trigger lessons_position before insert on public.lessons
  for each row execute function public.set_next_position();
create trigger materials_position before insert on public.materials
  for each row execute function public.set_next_position();

-- Удалили урок — номера следующих сдвигаются, дыр нет.
create or replace function public.close_lesson_gap()
returns trigger
language plpgsql
as $$
begin
  update public.lessons set position = position - 1
  where product_id = old.product_id and position > old.position;
  return old;
end;
$$;

create trigger lessons_close_gap after delete on public.lessons
  for each row execute function public.close_lesson_gap();

-- Новый порядок уроков одним действием (перетаскивание в админке).
create or replace function public.reorder_lessons(product uuid, ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if (select count(*) from public.lessons where product_id = product)
       <> coalesce(array_length(ids, 1), 0)
     or exists (
       select 1 from unnest(ids) as x(id)
       where not exists (
         select 1 from public.lessons l where l.id = x.id and l.product_id = product
       )
     ) then
    raise exception 'список уроков устарел — обновите страницу' using errcode = '22023';
  end if;
  update public.lessons l
  set position = x.ord
  from unnest(ids) with ordinality as x(id, ord)
  where l.id = x.id;
end;
$$;

-- ---------------------------------------------------------------- доступ и продажи

-- Активация: ученик ввёл верный ключ на своём телефоне. Пишет только
-- серверная функция «activate» (ключом service_role), клиенты — только читают свои.
create table public.activations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  device_code text not null,
  activation_key text not null,
  created_at timestamptz not null default now(),
  unique (user_id, product_id, device_code)
);
create index activations_user on public.activations (user_id);

-- Неудачные попытки ввода ключа — защита от перебора (функция «activate»).
create table public.activation_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index activation_attempts_user on public.activation_attempts (user_id, created_at);

-- Журнал выданных ключей (продажи) — ведёт музыкант в админке.
create table public.sales (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete restrict,
  device_code text not null,
  activation_key text not null,
  student text not null default '',
  amount_somoni integer check (amount_somoni >= 0),
  created_at timestamptz not null default now()
);
create index sales_created on public.sales (created_at);

create table public.lesson_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  position_sec integer not null default 0,
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

-- ---------------------------------------------------------------- правила доступа (RLS)

alter table public.admins enable row level security;
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.lessons enable row level security;
alter table public.materials enable row level security;
alter table public.product_links enable row level security;
alter table public.activations enable row level security;
alter table public.activation_attempts enable row level security;
alter table public.sales enable row level security;
alter table public.lesson_progress enable row level security;

create policy "admins: свои и админы" on public.admins
  for select using (user_id = (select auth.uid()) or public.is_admin());

create policy "profiles: свой и админы" on public.profiles
  for select using (id = (select auth.uid()) or public.is_admin());
create policy "profiles: правка своего" on public.profiles
  for update using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Каталог: опубликованное видят все (и гости), черновики — только админ.
create policy "products: чтение" on public.products
  for select using (is_published or public.is_admin());
create policy "products: админ" on public.products
  for all using (public.is_admin()) with check (public.is_admin());

create policy "lessons: чтение" on public.lessons
  for select using (exists (
    select 1 from public.products p
    where p.id = product_id and (p.is_published or public.is_admin())
  ));
create policy "lessons: админ" on public.lessons
  for all using (public.is_admin()) with check (public.is_admin());

create policy "materials: чтение" on public.materials
  for select using (exists (
    select 1 from public.products p
    where p.id = product_id and (p.is_published or public.is_admin())
  ));
create policy "materials: админ" on public.materials
  for all using (public.is_admin()) with check (public.is_admin());

create policy "product_links: чтение" on public.product_links
  for select using (true);
create policy "product_links: админ" on public.product_links
  for all using (public.is_admin()) with check (public.is_admin());

-- Активации: ученик видит свои; админ видит все и может отозвать (удалить).
create policy "activations: свои и админы" on public.activations
  for select using (user_id = (select auth.uid()) or public.is_admin());
create policy "activations: отзыв админом" on public.activations
  for delete using (public.is_admin());

-- activation_attempts: клиентам не видно ничего (только серверной функции).

create policy "sales: админ" on public.sales
  for all using (public.is_admin()) with check (public.is_admin());

create policy "progress: свой" on public.lesson_progress
  for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- обложки (Supabase Storage)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('covers', 'covers', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "covers: загрузка админом" on storage.objects
  for insert with check (bucket_id = 'covers' and public.is_admin());
create policy "covers: замена админом" on storage.objects
  for update using (bucket_id = 'covers' and public.is_admin());
create policy "covers: удаление админом" on storage.objects
  for delete using (bucket_id = 'covers' and public.is_admin());

-- ---------------------------------------------------------------- статистика для админки

-- Сводка за период: продажи, выручка, разные телефоны.
create or replace function public.sales_totals(since timestamptz default null)
returns table (sales bigint, revenue bigint, devices bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select count(*), coalesce(sum(amount_somoni), 0), count(distinct device_code)
  from public.sales
  where since is null or created_at >= since;
$$;

-- Выручка по месяцам (YYYY-MM).
create or replace function public.sales_by_month(since timestamptz)
returns table (month text, revenue bigint, sales bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select to_char(created_at at time zone 'Asia/Dushanbe', 'YYYY-MM') as month,
         coalesce(sum(amount_somoni), 0), count(*)
  from public.sales
  where created_at >= since
  group by 1
  order by 1;
$$;

-- Лучшие продукты за период.
create or replace function public.top_products(since timestamptz default null, max_rows integer default 5)
returns table (product_id uuid, title text, sales bigint, revenue bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id, p.title, count(*), coalesce(sum(s.amount_somoni), 0)
  from public.sales s
  join public.products p on p.id = s.product_id
  where since is null or s.created_at >= since
  group by p.id, p.title
  order by count(*) desc, p.title
  limit max_rows;
$$;
