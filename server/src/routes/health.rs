use std::time::Duration;

use axum::{Json, extract::State};
use serde::Serialize;

use crate::state::AppState;

#[derive(Debug, Serialize)]
pub struct Health {
    pub status: &'static str,
    pub version: &'static str,
    pub db: &'static str,
}

/// `GET /api/v1/health` — жив ли сервер и доступна ли БД.
/// Отвечает 200 даже при недоступной БД, чтобы оркестратор не перезапускал
/// сервер из-за проблем базы; состояние БД — в поле `db`.
pub async fn health(State(state): State<AppState>) -> Json<Health> {
    let ping = sqlx::query("SELECT 1").execute(&state.db);
    let db = match tokio::time::timeout(Duration::from_secs(2), ping).await {
        Ok(Ok(_)) => "up",
        _ => "down",
    };
    Json(Health {
        status: "ok",
        version: env!("CARGO_PKG_VERSION"),
        db,
    })
}
