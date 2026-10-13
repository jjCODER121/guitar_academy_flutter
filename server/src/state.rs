use std::sync::Arc;

use sqlx::SqlitePool;

use crate::{config::Config, media::Media};

/// Общее состояние, доступное всем обработчикам.
#[derive(Clone)]
pub struct AppState {
    pub db: SqlitePool,
    pub media: Arc<Media>,
    pub config: Arc<Config>,
}
