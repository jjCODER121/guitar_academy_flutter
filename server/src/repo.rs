//! Запросы к базе. Все — обычные `sqlx::query`, без макросов,
//! чтобы сборка не требовала живой базы.

use sqlx::SqlitePool;

use crate::{
    error::AppError,
    models::{ActivationRow, Lesson, Material, Product, ProductSummary},
};

type Result<T> = std::result::Result<T, AppError>;

fn new_id() -> String {
    uuid::Uuid::new_v4().to_string()
}

pub fn now_iso() -> String {
    chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
}

// ---------------------------------------------------------------- продукты

pub async fn list_products(db: &SqlitePool, kind: Option<&str>) -> Result<Vec<ProductSummary>> {
    Ok(sqlx::query_as(
        "SELECT p.*,
                (SELECT COUNT(*) FROM lessons l WHERE l.product_id = p.id) AS lesson_count,
                (SELECT COUNT(*) FROM lessons l WHERE l.product_id = p.id
                    AND l.video_file IS NOT NULL) AS video_count,
                (SELECT COUNT(*) FROM activations a WHERE a.product_id = p.id) AS activation_count
         FROM products p
         WHERE (?1 IS NULL OR p.type = ?1)
         ORDER BY p.sort_order, p.created_at",
    )
    .bind(kind)
    .fetch_all(db)
    .await?)
}

pub async fn published_products(db: &SqlitePool) -> Result<Vec<Product>> {
    Ok(sqlx::query_as(
        "SELECT * FROM products WHERE is_published = 1 ORDER BY sort_order, created_at",
    )
    .fetch_all(db)
    .await?)
}

pub async fn get_product(db: &SqlitePool, id: &str) -> Result<Product> {
    Ok(sqlx::query_as("SELECT * FROM products WHERE id = ?")
        .bind(id)
        .fetch_one(db)
        .await?)
}

/// Новый черновик. Номер для ключа — следующий свободный; он не меняется никогда.
pub async fn create_product(db: &SqlitePool, kind: &str, title: &str) -> Result<String> {
    let id = new_id();
    sqlx::query(
        "INSERT INTO products (id, type, title, activation_number, sort_order)
         VALUES (?1, ?2, ?3,
                 (SELECT COALESCE(MAX(activation_number), 0) + 1 FROM products),
                 (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM products))",
    )
    .bind(&id)
    .bind(kind)
    .bind(title)
    .execute(db)
    .await?;
    Ok(id)
}

pub struct ProductFields<'a> {
    pub kind: &'a str,
    pub title: &'a str,
    pub subtitle: &'a str,
    pub level: &'a str,
    pub price_somoni: Option<i64>,
}

pub async fn update_product(db: &SqlitePool, id: &str, f: &ProductFields<'_>) -> Result<()> {
    sqlx::query(
        "UPDATE products SET type = ?2, title = ?3, subtitle = ?4, level = ?5,
                price_somoni = ?6, updated_at = ?7
         WHERE id = ?1",
    )
    .bind(id)
    .bind(f.kind)
    .bind(f.title)
    .bind(f.subtitle)
    .bind(f.level)
    .bind(f.price_somoni)
    .bind(now_iso())
    .execute(db)
    .await?;
    Ok(())
}

pub async fn set_published(db: &SqlitePool, id: &str, published: bool) -> Result<()> {
    sqlx::query("UPDATE products SET is_published = ?2, updated_at = ?3 WHERE id = ?1")
        .bind(id)
        .bind(published)
        .bind(now_iso())
        .execute(db)
        .await?;
    Ok(())
}

/// Возвращает прежний файл обложки, чтобы удалить его с диска.
pub async fn set_cover(db: &SqlitePool, id: &str, file: &str) -> Result<Option<String>> {
    let old = get_product(db, id).await?.cover_file;
    sqlx::query("UPDATE products SET cover_file = ?2, updated_at = ?3 WHERE id = ?1")
        .bind(id)
        .bind(file)
        .bind(now_iso())
        .execute(db)
        .await?;
    Ok(old)
}

/// Удаление возможно, только пока по продукту не выдано ни одного ключа.
/// Возвращает файлы, которые нужно удалить с диска.
pub async fn delete_product(db: &SqlitePool, id: &str) -> Result<DeletedFiles> {
    let used: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM activations WHERE product_id = ?")
        .bind(id)
        .fetch_one(db)
        .await?;
    if used > 0 {
        return Err(AppError::Conflict(
            "по этому продукту уже выданы ключи — его можно снять с публикации, но не удалить"
                .into(),
        ));
    }
    let product = get_product(db, id).await?;
    let videos: Vec<String> = sqlx::query_scalar(
        "SELECT video_file FROM lessons WHERE product_id = ? AND video_file IS NOT NULL",
    )
    .bind(id)
    .fetch_all(db)
    .await?;
    let pdfs: Vec<String> = sqlx::query_scalar("SELECT file FROM materials WHERE product_id = ?")
        .bind(id)
        .fetch_all(db)
        .await?;
    sqlx::query("DELETE FROM products WHERE id = ?")
        .bind(id)
        .execute(db)
        .await?;
    Ok(DeletedFiles {
        cover: product.cover_file,
        videos,
        pdfs,
    })
}

pub struct DeletedFiles {
    pub cover: Option<String>,
    pub videos: Vec<String>,
    pub pdfs: Vec<String>,
}

// ---------------------------------------------------------------- уроки

pub async fn lessons_of(db: &SqlitePool, product_id: &str) -> Result<Vec<Lesson>> {
    Ok(
        sqlx::query_as("SELECT * FROM lessons WHERE product_id = ? ORDER BY position")
            .bind(product_id)
            .fetch_all(db)
            .await?,
    )
}

pub async fn get_lesson(db: &SqlitePool, id: &str) -> Result<Lesson> {
    Ok(sqlx::query_as("SELECT * FROM lessons WHERE id = ?")
        .bind(id)
        .fetch_one(db)
        .await?)
}

pub async fn add_lesson(db: &SqlitePool, product_id: &str, title: &str) -> Result<String> {
    let id = new_id();
    sqlx::query(
        "INSERT INTO lessons (id, product_id, position, title)
         VALUES (?1, ?2, (SELECT COALESCE(MAX(position), 0) + 1 FROM lessons
                          WHERE product_id = ?2), ?3)",
    )
    .bind(&id)
    .bind(product_id)
    .bind(title)
    .execute(db)
    .await?;
    touch_product(db, product_id).await?;
    Ok(id)
}

pub async fn update_lesson(
    db: &SqlitePool,
    id: &str,
    title: &str,
    is_free_preview: bool,
    preview_limit_sec: Option<i64>,
) -> Result<()> {
    let lesson = get_lesson(db, id).await?;
    sqlx::query(
        "UPDATE lessons SET title = ?2, is_free_preview = ?3, preview_limit_sec = ?4 WHERE id = ?1",
    )
    .bind(id)
    .bind(title)
    .bind(is_free_preview)
    .bind(preview_limit_sec)
    .execute(db)
    .await?;
    touch_product(db, &lesson.product_id).await
}

/// Возвращает прежний файл видео.
pub async fn set_lesson_video(
    db: &SqlitePool,
    id: &str,
    file: &str,
    duration_sec: i64,
) -> Result<Option<String>> {
    let lesson = get_lesson(db, id).await?;
    sqlx::query("UPDATE lessons SET video_file = ?2, duration_sec = ?3 WHERE id = ?1")
        .bind(id)
        .bind(file)
        .bind(duration_sec)
        .execute(db)
        .await?;
    touch_product(db, &lesson.product_id).await?;
    Ok(lesson.video_file)
}

/// Удаляет урок и сдвигает номера остальных. Возвращает (продукт, файл видео).
pub async fn delete_lesson(db: &SqlitePool, id: &str) -> Result<(String, Option<String>)> {
    let lesson = get_lesson(db, id).await?;
    let mut tx = db.begin().await?;
    sqlx::query("DELETE FROM lessons WHERE id = ?")
        .bind(id)
        .execute(&mut *tx)
        .await?;
    sqlx::query("UPDATE lessons SET position = position - 1 WHERE product_id = ? AND position > ?")
        .bind(&lesson.product_id)
        .bind(lesson.position)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    touch_product(db, &lesson.product_id).await?;
    Ok((lesson.product_id, lesson.video_file))
}

/// Новый порядок уроков: все id уроков продукта в нужной последовательности.
pub async fn reorder_lessons(db: &SqlitePool, product_id: &str, ids: &[String]) -> Result<()> {
    let current = lessons_of(db, product_id).await?;
    let mut expected: Vec<&str> = current.iter().map(|l| l.id.as_str()).collect();
    let mut given: Vec<&str> = ids.iter().map(String::as_str).collect();
    expected.sort_unstable();
    given.sort_unstable();
    if expected != given {
        return Err(AppError::BadRequest(
            "список уроков устарел — обновите страницу".into(),
        ));
    }
    let mut tx = db.begin().await?;
    for (i, id) in ids.iter().enumerate() {
        sqlx::query("UPDATE lessons SET position = ?2 WHERE id = ?1")
            .bind(id)
            .bind(i as i64 + 1)
            .execute(&mut *tx)
            .await?;
    }
    tx.commit().await?;
    touch_product(db, product_id).await
}

async fn touch_product(db: &SqlitePool, id: &str) -> Result<()> {
    sqlx::query("UPDATE products SET updated_at = ?2 WHERE id = ?1")
        .bind(id)
        .bind(now_iso())
        .execute(db)
        .await?;
    Ok(())
}

// ---------------------------------------------------------------- PDF

pub async fn materials_of(db: &SqlitePool, product_id: &str) -> Result<Vec<Material>> {
    Ok(
        sqlx::query_as("SELECT * FROM materials WHERE product_id = ? ORDER BY position")
            .bind(product_id)
            .fetch_all(db)
            .await?,
    )
}

pub async fn get_material(db: &SqlitePool, id: &str) -> Result<Material> {
    Ok(sqlx::query_as("SELECT * FROM materials WHERE id = ?")
        .bind(id)
        .fetch_one(db)
        .await?)
}

pub async fn add_material(
    db: &SqlitePool,
    product_id: &str,
    lesson_id: Option<&str>,
    title: &str,
    file: &str,
) -> Result<String> {
    if let Some(lesson_id) = lesson_id {
        let lesson = get_lesson(db, lesson_id).await?;
        if lesson.product_id != product_id {
            return Err(AppError::BadRequest("урок из другого продукта".into()));
        }
    }
    let id = new_id();
    sqlx::query(
        "INSERT INTO materials (id, product_id, lesson_id, position, title, file)
         VALUES (?1, ?2, ?3, (SELECT COALESCE(MAX(position), 0) + 1 FROM materials
                              WHERE product_id = ?2), ?4, ?5)",
    )
    .bind(&id)
    .bind(product_id)
    .bind(lesson_id)
    .bind(title)
    .bind(file)
    .execute(db)
    .await?;
    touch_product(db, product_id).await?;
    Ok(id)
}

/// Возвращает (продукт, файл PDF).
pub async fn delete_material(db: &SqlitePool, id: &str) -> Result<(String, String)> {
    let m = get_material(db, id).await?;
    sqlx::query("DELETE FROM materials WHERE id = ?")
        .bind(id)
        .execute(db)
        .await?;
    touch_product(db, &m.product_id).await?;
    Ok((m.product_id, m.file))
}

// ---------------------------------------------------------------- связи альбом ↔ песня

/// Альбомы, ключ которых открывает этот продукт (для отдельной песни).
pub async fn unlocking_albums(db: &SqlitePool, product_id: &str) -> Result<Vec<Product>> {
    Ok(sqlx::query_as(
        "SELECT p.* FROM products p
         JOIN product_links l ON l.song_album_id = p.id
         WHERE l.single_id = ?",
    )
    .bind(product_id)
    .fetch_all(db)
    .await?)
}

/// Песня входит не больше чем в один альбом — так проще в редакторе.
pub async fn set_album_of_single(
    db: &SqlitePool,
    single_id: &str,
    album_id: Option<&str>,
) -> Result<()> {
    let mut tx = db.begin().await?;
    sqlx::query("DELETE FROM product_links WHERE single_id = ?")
        .bind(single_id)
        .execute(&mut *tx)
        .await?;
    if let Some(album_id) = album_id {
        sqlx::query("INSERT INTO product_links (song_album_id, single_id) VALUES (?, ?)")
            .bind(album_id)
            .bind(single_id)
            .execute(&mut *tx)
            .await?;
    }
    tx.commit().await?;
    Ok(())
}

pub async fn all_links(db: &SqlitePool) -> Result<Vec<(String, String)>> {
    Ok(
        sqlx::query_as("SELECT song_album_id, single_id FROM product_links")
            .fetch_all(db)
            .await?,
    )
}

// ---------------------------------------------------------------- ключи (продажи)

pub struct NewActivation<'a> {
    pub product_id: &'a str,
    pub device_code: &'a str,
    pub activation_key: &'a str,
    pub student: &'a str,
    pub amount_somoni: Option<i64>,
}

pub async fn add_activation(db: &SqlitePool, a: &NewActivation<'_>) -> Result<String> {
    let id = new_id();
    sqlx::query(
        "INSERT INTO activations (id, product_id, device_code, activation_key, student,
                                  amount_somoni, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&id)
    .bind(a.product_id)
    .bind(a.device_code)
    .bind(a.activation_key)
    .bind(a.student)
    .bind(a.amount_somoni)
    .bind(now_iso())
    .execute(db)
    .await?;
    Ok(id)
}

pub async fn get_activation(db: &SqlitePool, id: &str) -> Result<ActivationRow> {
    Ok(sqlx::query_as(
        "SELECT a.id, a.product_id, p.title AS product_title, p.activation_number,
                a.device_code, a.activation_key, a.student, a.amount_somoni, a.created_at
         FROM activations a JOIN products p ON p.id = a.product_id
         WHERE a.id = ?",
    )
    .bind(id)
    .fetch_one(db)
    .await?)
}

pub async fn delete_activation(db: &SqlitePool, id: &str) -> Result<()> {
    sqlx::query("DELETE FROM activations WHERE id = ?")
        .bind(id)
        .execute(db)
        .await?;
    Ok(())
}

#[derive(Default)]
pub struct ActivationFilter<'a> {
    /// Поиск по ученику, ID-коду, ключу.
    pub query: Option<&'a str>,
    pub product_id: Option<&'a str>,
    pub since: Option<&'a str>,
    pub limit: Option<i64>,
}

pub async fn list_activations(
    db: &SqlitePool,
    f: &ActivationFilter<'_>,
) -> Result<Vec<ActivationRow>> {
    let like = f.query.map(|q| format!("%{}%", q.trim()));
    Ok(sqlx::query_as(
        "SELECT a.id, a.product_id, p.title AS product_title, p.activation_number,
                a.device_code, a.activation_key, a.student, a.amount_somoni, a.created_at
         FROM activations a JOIN products p ON p.id = a.product_id
         WHERE (?1 IS NULL OR a.student LIKE ?1 OR a.device_code LIKE ?1
                OR a.activation_key LIKE ?1)
           AND (?2 IS NULL OR a.product_id = ?2)
           AND (?3 IS NULL OR a.created_at >= ?3)
         ORDER BY a.created_at DESC
         LIMIT ?4",
    )
    .bind(like)
    .bind(f.product_id)
    .bind(f.since)
    .bind(f.limit.unwrap_or(-1))
    .fetch_all(db)
    .await?)
}

// ---------------------------------------------------------------- статистика

pub struct Totals {
    pub activations: i64,
    pub revenue: i64,
    pub students: i64,
}

pub async fn totals(db: &SqlitePool, since: Option<&str>) -> Result<Totals> {
    let (activations, revenue, students): (i64, i64, i64) = sqlx::query_as(
        "SELECT COUNT(*), COALESCE(SUM(amount_somoni), 0), COUNT(DISTINCT device_code)
         FROM activations WHERE (?1 IS NULL OR created_at >= ?1)",
    )
    .bind(since)
    .fetch_one(db)
    .await?;
    Ok(Totals {
        activations,
        revenue,
        students,
    })
}

/// Выручка по месяцам начиная с `since_month` (YYYY-MM).
pub async fn monthly_revenue(db: &SqlitePool, since_month: &str) -> Result<Vec<(String, i64)>> {
    Ok(sqlx::query_as(
        "SELECT substr(created_at, 1, 7) AS month, COALESCE(SUM(amount_somoni), 0)
         FROM activations WHERE substr(created_at, 1, 7) >= ?
         GROUP BY month ORDER BY month",
    )
    .bind(since_month)
    .fetch_all(db)
    .await?)
}

pub async fn top_products(
    db: &SqlitePool,
    since: Option<&str>,
    limit: i64,
) -> Result<Vec<(String, i64, i64)>> {
    Ok(sqlx::query_as(
        "SELECT p.title, COUNT(*) AS n, COALESCE(SUM(a.amount_somoni), 0)
         FROM activations a JOIN products p ON p.id = a.product_id
         WHERE (?1 IS NULL OR a.created_at >= ?1)
         GROUP BY p.id ORDER BY n DESC, p.title LIMIT ?2",
    )
    .bind(since)
    .bind(limit)
    .fetch_all(db)
    .await?)
}

// ---------------------------------------------------------------- админы

pub async fn admin_password_hash(db: &SqlitePool, username: &str) -> Result<Option<String>> {
    Ok(
        sqlx::query_scalar("SELECT password_hash FROM admins WHERE username = ?")
            .bind(username)
            .fetch_optional(db)
            .await?,
    )
}

pub async fn upsert_admin(db: &SqlitePool, username: &str, password_hash: &str) -> Result<()> {
    sqlx::query(
        "INSERT INTO admins (username, password_hash) VALUES (?1, ?2)
         ON CONFLICT (username) DO UPDATE SET password_hash = ?2",
    )
    .bind(username)
    .bind(password_hash)
    .execute(db)
    .await?;
    // После смены пароля все старые входы недействительны.
    sqlx::query("DELETE FROM admin_sessions WHERE username = ?")
        .bind(username)
        .execute(db)
        .await?;
    Ok(())
}

pub async fn admin_count(db: &SqlitePool) -> Result<i64> {
    Ok(sqlx::query_scalar("SELECT COUNT(*) FROM admins")
        .fetch_one(db)
        .await?)
}

pub async fn create_session(
    db: &SqlitePool,
    token_hash: &str,
    username: &str,
    expires_at: &str,
) -> Result<()> {
    sqlx::query("DELETE FROM admin_sessions WHERE expires_at < ?")
        .bind(now_iso())
        .execute(db)
        .await?;
    sqlx::query("INSERT INTO admin_sessions (token_hash, username, expires_at) VALUES (?, ?, ?)")
        .bind(token_hash)
        .bind(username)
        .bind(expires_at)
        .execute(db)
        .await?;
    Ok(())
}

pub async fn session_user(db: &SqlitePool, token_hash: &str) -> Result<Option<String>> {
    Ok(sqlx::query_scalar(
        "SELECT username FROM admin_sessions WHERE token_hash = ? AND expires_at > ?",
    )
    .bind(token_hash)
    .bind(now_iso())
    .fetch_optional(db)
    .await?)
}

pub async fn delete_session(db: &SqlitePool, token_hash: &str) -> Result<()> {
    sqlx::query("DELETE FROM admin_sessions WHERE token_hash = ?")
        .bind(token_hash)
        .execute(db)
        .await?;
    Ok(())
}
