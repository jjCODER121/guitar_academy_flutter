# Supabase + Cloudflare R2

Проект Supabase: `https://aqihlmikvzdfiutmuwdd.supabase.co` (ref `aqihlmikvzdfiutmuwdd`, регион Frankfurt).

```
migrations/20261012120000_init.sql   таблицы, правила доступа (RLS), триггеры, статистика, бакет обложек
functions/activate                   проверка ключа активации → доступ в аккаунт (10 ошибок в час максимум)
functions/media-url                  временная ссылка (2 ч) на видео/PDF в R2 — только при активации
functions/admin                      для админки: загрузка в R2, просмотр, удаление, генератор ключей
functions/_shared/activation.ts      формула ключа (та же, что в Dart и Rust; общие примеры — vectors.json)
tests/                               проверка миграции в PGlite и формулы: cd tests && npm test
```

Секреты в репозиторий не попадают. `service_role`, пароль базы и ключи R2 задаются только в панели Supabase.

## 1. База и функции (один раз)

В терминале, из корня проекта. Вход откроет браузер, пароль базы вводится в терминале:

```bash
npx supabase login
```

```bash
npx supabase link --project-ref aqihlmikvzdfiutmuwdd
```

```bash
npx supabase db push
```

```bash
npx supabase functions deploy activate media-url admin --use-api
```

## 2. Cloudflare R2

1. R2 → **Create bucket** → `guitar-school-media`.
2. Бакет → Settings → **CORS policy** (нужно для загрузки видео из админки в браузере):

   ```json
   [{ "AllowedOrigins": ["*"], "AllowedMethods": ["GET", "PUT"], "AllowedHeaders": ["*"], "MaxAgeSeconds": 3600 }]
   ```

   Ссылки всё равно подписаны и живут ограниченное время; после запуска админки на своём адресе
   `*` можно заменить на этот адрес.
3. R2 → **Manage API tokens** → Create API token: права **Object Read & Write**, только бакет `guitar-school-media`.
   Сохраните **Access Key ID** и **Secret Access Key**; **Account ID** — на главной странице R2.

## 3. Секреты функций

Supabase → Edge Functions → **Secrets** → добавить:

| Имя | Значение |
|---|---|
| `R2_ACCOUNT_ID` | Account ID из Cloudflare |
| `R2_ACCESS_KEY_ID` | Access Key ID токена R2 |
| `R2_SECRET_ACCESS_KEY` | Secret Access Key токена R2 |
| `R2_BUCKET` | `guitar-school-media` |

## 4. Администратор

1. Supabase → Authentication → Users → **Add user** → Create new user: email и пароль музыканта,
   отметить **Auto Confirm User**.
2. Supabase → SQL Editor:

   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'почта-музыканта@example.com';
   ```

## 5. Вход учеников по коду из письма

- Authentication → Emails → шаблон **Magic Link**: добавить в текст `{{ .Token }}` — это 6-значный код,
  который ученик вводит в приложении. Например: «Ваш код для входа: {{ .Token }}».
- Встроенная почта Supabase отправляет письма только участникам проекта и с жёстким лимитом.
  Для учеников нужен свой SMTP (Authentication → Emails → SMTP Settings), бесплатно, например:
  - Brevo — 300 писем в день;
  - Gmail школы с «паролем приложения» — до ~500 писем в день.
