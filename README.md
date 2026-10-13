# Гитарная школа

Мобильное приложение для изучения гитары и продажи видеокурсов музыканта
[Имя музыканта] и школы [Название школы]: Flutter-приложение, сервер на Rust,
веб-админка для музыканта.

Полный промт проекта, дизайн-контекст и принятые решения — в [CLAUDE.md](CLAUDE.md).
Макеты экранов: https://claude.ai/artifact/HVNB9brcghUUXEsUdCtqRi

## Структура

```
app/      Flutter-приложение (Android, затем iOS)
keygen/   генератор ключей активации для музыканта (Flutter, Android; не публикуется)
packages/activation_key/  формула ID-кода устройства и ключа — общая для app и keygen
server/   сервер на Rust: Axum + SQLx + SQLite — API для приложения и админ-панель
admin/    стили и скрипт админ-панели (страницы рисует сервер), /admin
design/   tokens.json — единый источник цветов, шрифтов и отступов
tools/    gen_tokens.dart — генерирует из токенов тему Flutter и CSS админки
```

## Требования

- Flutter 3.47 (Dart 3.13), Android SDK
- Rust stable (1.85+, edition 2024)
- Docker — только для запуска на сервере (локально не нужен)

## Запуск

### Сервер и админ-панель на этом компьютере

Нужен только Rust; база — файл SQLite, создаётся сама в `server/data/`.

```bash
cp .env.example server/.env
```

В `server/.env` задайте `ADMIN_PASSWORD` (8+ символов) и `MEDIA_SECRET` (32+ символа), затем:

```bash
cd server && cargo run
```

Админка: http://127.0.0.1:8088/admin (логин из `ADMIN_USERNAME`, по умолчанию `admin`).
Сменить пароль: `cargo run -- admin admin <новый пароль>`.

### На сервере (Docker)

```bash
docker compose up -d --build
```

Все данные — в томе `school-data` (`/data` в контейнере): база `school.db` и папка `media/`
с видео, PDF и обложками. Делайте копии этого тома.

### Приложение (эмулятор или телефон с отладкой по USB)

```bash
cd app && flutter run
```

## Админ-панель

| Раздел | Что там |
|---|---|
| Обзор | продажи, выручка, ученики за неделю/месяц/год, график по месяцам, лучшие продукты, последние ключи |
| Продукты | таблица всех курсов, альбомов и песен с фильтром; видно, у скольких уроков есть видео |
| Редактор продукта | тип, название, описание, цена (для статистики), уровень, обложка; уроки с загрузкой видео (полоса прогресса), порядок перетаскиванием, бесплатный урок, PDF к уроку и ко всему курсу; «Сохранить черновик» / «Опубликовать» |
| Ключи | генератор (ID-код ученика + продукт → ключ, «Отправить в WhatsApp»), журнал продаж с поиском и фильтрами, выгрузка в Excel |

API для приложения (`/api/v1`): `GET /catalog`, `GET /lessons/{id}/stream`, `GET /materials/{id}/download`
(последние два — с заголовками `X-Device-Code` и `X-Activation-Key`; отдают ссылку на 2 часа).

## Сборка для телефона и Google Play

`flutter run` и `flutter build apk --debug` дают отладочную сборку (~190 МБ): в ней
движок под три типа процессоров и код для горячей перезагрузки. Раздавать её нельзя.

APK для установки на телефон (arm64, ~17 МБ):

```bash
cd app && flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Файл: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Для Google Play — App Bundle; магазин сам отдаёт телефону только нужную часть (~8 МБ загрузки):

```bash
cd app && flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Две версии из одного кода:

| | Google Play (по умолчанию) | Прямая раздача (APK через WhatsApp/Telegram/сайт) |
|---|---|---|
| Флаг сборки | — | `--dart-define=DISTRIBUTION=direct` |
| Кнопка на закрытом курсе | «Активировать курс» | «Купить» |
| В окне активации | ID-код и поле ключа | + «Как купить», кнопки WhatsApp и «Позвонить» |

```bash
cd app && flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=DISTRIBUTION=direct
```

Номер для WhatsApp и звонка — `School.contactNumber` в `app/lib/core/config/school.dart`.

Папку `build/symbols` сохраняйте для каждой выпущенной версии — без неё не расшифровать отчёты о сбоях.
Пока release подписывается отладочным ключом; ключ загрузки для Google Play настраивается на этапе 7.

## Генератор ключей

Отдельное приложение для телефона музыканта: вставить ID-код ученика → выбрать курс →
«Отправить» (WhatsApp, Telegram…) или «Скопировать». Показывает расчёт для сверки с ручным.
В нём формула ключа — **не публиковать в Google Play**, ставить только на свой телефон.

```bash
cd keygen && flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Файл: `keygen/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Список курсов и их номера —
`keygen/lib/courses.dart` (номера совпадают с `activationNumber` в каталоге приложения).

## Проверки (то же самое запускает CI)

```bash
dart run tools/gen_tokens.dart --check
cd server && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test
cd app && flutter analyze && flutter test
```

## Design tokens

Цвета, шрифты, размеры и скругления правятся только в `design/tokens.json`, затем:

```bash
dart run tools/gen_tokens.dart
```

Генератор перепишет `app/lib/core/theme/tokens.g.dart` и `admin/static/tokens.css`
и проверит контраст текста по WCAG AA (при нарушении завершится с ошибкой).
