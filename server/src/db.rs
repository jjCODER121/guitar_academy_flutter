use std::str::FromStr;

use anyhow::Context;
use sqlx::{
    SqlitePool,
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
};

/// Открывает базу (создаёт файл при первом запуске) и применяет миграции.
pub async fn connect(url: &str) -> anyhow::Result<SqlitePool> {
    let options = SqliteConnectOptions::from_str(url)
        .with_context(|| format!("неверный DATABASE_URL: {url}"))?
        .create_if_missing(true)
        .foreign_keys(true)
        // WAL: чтение не ждёт записи — админка и приложение не мешают друг другу.
        .journal_mode(SqliteJournalMode::Wal);
    let pool = SqlitePoolOptions::new()
        .max_connections(8)
        .connect_with(options)
        .await
        .context("не удалось открыть базу")?;
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .context("не удалось применить миграции")?;
    Ok(pool)
}

/// База в памяти — для тестов.
pub async fn connect_memory() -> anyhow::Result<SqlitePool> {
    let options = SqliteConnectOptions::from_str("sqlite::memory:")?.foreign_keys(true);
    // Одно соединение: у каждой in-memory базы своё содержимое.
    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .idle_timeout(None)
        .max_lifetime(None)
        .connect_with(options)
        .await?;
    sqlx::migrate!("./migrations").run(&pool).await?;
    Ok(pool)
}
