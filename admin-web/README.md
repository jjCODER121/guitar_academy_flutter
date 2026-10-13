# Веб-админка (Supabase + Cloudflare R2)

Статические файлы — без сборки. Данные: Supabase (база, обложки, функция `admin`), видео и PDF — R2.
Вход — почта и пароль администратора (Supabase Auth + запись в таблице `admins`).

## Проверить на этом компьютере

```bash
cd admin-web && python -m http.server 5500 --bind 127.0.0.1
```

Откройте http://127.0.0.1:5500

## Выложить на Cloudflare Pages (бесплатно)

1. dash.cloudflare.com → **Workers & Pages** → **Create** → вкладка **Pages** → **Upload assets**.
2. Название проекта, например `guitar-school-admin`.
3. Перетащите папку `admin-web` целиком → **Deploy**.
4. Адрес будет вида `https://guitar-school-admin.pages.dev`.
5. В R2 → бакет → CORS можно заменить `*` на этот адрес.

Обновление — так же: **Create deployment** → перетащить папку снова.

`tokens.css` генерируется из `design/tokens.json` (`dart run tools/gen_tokens.dart`), руками не править.
