mod content;
mod health;

use axum::{Router, routing::get};

use crate::{error::AppError, state::AppState};

/// Маршруты `/api/v1` — для приложения.
pub fn api() -> Router<AppState> {
    Router::new()
        .route("/health", get(health::health))
        .route("/catalog", get(content::catalog))
        .route("/lessons/{id}/stream", get(content::lesson_stream))
        .route("/materials/{id}/download", get(content::material_download))
        .fallback(|| async { AppError::NotFound })
}
