-- Продукты школы: курс, альбом песен, отдельная песня.
CREATE TABLE products (
    id                TEXT PRIMARY KEY,
    type              TEXT NOT NULL CHECK (type IN ('course', 'song_album', 'single')),
    title             TEXT NOT NULL,
    subtitle          TEXT NOT NULL DEFAULT '',
    level             TEXT NOT NULL DEFAULT 'beginner'
                      CHECK (level IN ('beginner', 'intermediate', 'advanced')),
    -- Цена для статистики и подсказки в генераторе ключей; в приложении не показывается.
    price_somoni      INTEGER CHECK (price_somoni IS NULL OR price_somoni >= 0),
    -- Номер в формуле ключа активации. Выдаётся один раз и не меняется.
    activation_number INTEGER NOT NULL UNIQUE,
    cover_file        TEXT,
    is_published      INTEGER NOT NULL DEFAULT 0,
    sort_order        INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE lessons (
    id                TEXT PRIMARY KEY,
    product_id        TEXT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    position          INTEGER NOT NULL,
    title             TEXT NOT NULL,
    duration_sec      INTEGER NOT NULL DEFAULT 0,
    video_file        TEXT,
    is_free_preview   INTEGER NOT NULL DEFAULT 0,
    -- Для отдельной песни: бесплатны только первые N секунд.
    preview_limit_sec INTEGER
);
CREATE INDEX lessons_product ON lessons (product_id, position);

-- PDF: к уроку (ноты песни) или ко всему продукту (lesson_id IS NULL).
CREATE TABLE materials (
    id         TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    lesson_id  TEXT REFERENCES lessons (id) ON DELETE SET NULL,
    position   INTEGER NOT NULL,
    title      TEXT NOT NULL,
    file       TEXT NOT NULL
);
CREATE INDEX materials_product ON materials (product_id, position);

-- Песня из альбома, которая продаётся и отдельно: ключ альбома открывает и её.
CREATE TABLE product_links (
    song_album_id TEXT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    single_id     TEXT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    PRIMARY KEY (song_album_id, single_id)
);

-- Журнал выданных ключей (продажи). Ключи, сделанные в генераторе на телефоне,
-- сюда не попадают — их можно внести вручную.
CREATE TABLE activations (
    id             TEXT PRIMARY KEY,
    product_id     TEXT NOT NULL REFERENCES products (id) ON DELETE RESTRICT,
    device_code    TEXT NOT NULL,
    activation_key TEXT NOT NULL,
    student        TEXT NOT NULL DEFAULT '',
    amount_somoni  INTEGER CHECK (amount_somoni IS NULL OR amount_somoni >= 0),
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX activations_created ON activations (created_at);
CREATE INDEX activations_device ON activations (device_code);

CREATE TABLE admins (
    username      TEXT PRIMARY KEY,
    password_hash TEXT NOT NULL
);

-- В базе хранится только SHA-256 токена; сам токен — в cookie браузера.
CREATE TABLE admin_sessions (
    token_hash TEXT PRIMARY KEY,
    username   TEXT NOT NULL REFERENCES admins (username) ON DELETE CASCADE,
    expires_at TEXT NOT NULL
);
