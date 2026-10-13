pub mod activation;
pub mod admin;
pub mod config;
pub mod db;
pub mod error;
pub mod media;
pub mod models;
pub mod repo;
pub mod routes;
pub mod state;

use std::{sync::Arc, time::Duration};

use anyhow::Context;
use axum::{Router, http::StatusCode, response::Redirect, routing::get};
use tower_http::{services::ServeDir, timeout::TimeoutLayer, trace::TraceLayer};

use crate::{config::Config, media::Media, state::AppState};

/// Готовит состояние: база (с миграциями), папки для файлов, ключ подписи ссылок.
pub async fn build_state(config: Config) -> anyhow::Result<AppState> {
    tokio::fs::create_dir_all(&config.data_dir)
        .await
        .with_context(|| format!("не удалось создать {}", config.data_dir.display()))?;
    let db = db::connect(&config.database_url).await?;
    state_with_db(config, db).await
}

pub async fn state_with_db(config: Config, db: sqlx::SqlitePool) -> anyhow::Result<AppState> {
    let secret = match &config.media_secret {
        Some(s) => s.clone().into_bytes(),
        None => {
            tracing::warn!(
                "MEDIA_SECRET не задан — ссылки на видео перестанут работать после перезапуска"
            );
            format!(
                "{}{}",
                uuid::Uuid::new_v4().simple(),
                uuid::Uuid::new_v4().simple()
            )
            .into_bytes()
        }
    };
    let media = Media::new(&config.data_dir, secret);
    media
        .ensure_dirs()
        .await
        .context("не удалось создать папки для файлов")?;
    Ok(AppState {
        db,
        media: Arc::new(media),
        config: Arc::new(config),
    })
}

/// Всё HTTP-приложение: API для приложения, админка, файлы.
pub fn app(state: AppState) -> Router {
    // Таймаут — только для API: загрузка видео в админке может идти долго.
    let api = routes::api().layer(TimeoutLayer::with_status_code(
        StatusCode::REQUEST_TIMEOUT,
        Duration::from_secs(30),
    ));
    Router::new()
        .nest("/api/v1", api)
        .nest_service(
            "/admin/static",
            ServeDir::new(&state.config.admin_static_dir),
        )
        .nest("/admin", admin::router(state.config.max_upload_mb))
        .route("/admin/", get(|| async { Redirect::permanent("/admin") }))
        .route("/media/{dir}/{file}", get(media::serve))
        .route("/", get(|| async { Redirect::to("/admin") }))
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
