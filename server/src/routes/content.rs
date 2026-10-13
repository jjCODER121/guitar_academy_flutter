//! API для приложения: каталог и временные ссылки на видео и PDF.

use axum::{
    Json,
    extract::{Path, State},
    http::HeaderMap,
};
use serde::Serialize;

use crate::{
    activation,
    error::AppError,
    media::{self, LINK_TTL_SECS, MediaKind},
    models::Product,
    repo,
    state::AppState,
};

#[derive(Serialize)]
pub struct Catalog {
    pub products: Vec<CatalogProduct>,
}

#[derive(Serialize)]
pub struct CatalogProduct {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub title: String,
    pub subtitle: String,
    pub level: String,
    pub activation_number: i64,
    pub cover_url: Option<String>,
    /// Альбомы, ключ которых открывает этот продукт.
    pub unlocked_by: Vec<String>,
    pub lessons: Vec<CatalogLesson>,
    pub materials: Vec<CatalogMaterial>,
}

#[derive(Serialize)]
pub struct CatalogLesson {
    pub id: String,
    pub position: i64,
    pub title: String,
    pub duration_sec: i64,
    pub is_free_preview: bool,
    pub preview_limit_sec: Option<i64>,
    pub has_video: bool,
    /// PDF к этому уроку (ноты песни), если есть.
    pub material_id: Option<String>,
}

#[derive(Serialize)]
pub struct CatalogMaterial {
    pub id: String,
    pub title: String,
    pub lesson_id: Option<String>,
}

/// `GET /api/v1/catalog` — опубликованные продукты. Цен здесь нет: в приложении
/// их не показываем (правило Google Play об оплате вне магазина).
pub async fn catalog(State(state): State<AppState>) -> Result<Json<Catalog>, AppError> {
    let now = media::now();
    let links = repo::all_links(&state.db).await?;
    let mut products = Vec::new();
    for p in repo::published_products(&state.db).await? {
        let lessons = repo::lessons_of(&state.db, &p.id).await?;
        let materials = repo::materials_of(&state.db, &p.id).await?;
        products.push(CatalogProduct {
            cover_url: p
                .cover_file
                .as_deref()
                .map(|f| state.media.url(MediaKind::Cover, f, now)),
            unlocked_by: links
                .iter()
                .filter(|(_, single)| *single == p.id)
                .map(|(album, _)| album.clone())
                .collect(),
            lessons: lessons
                .into_iter()
                .map(|l| CatalogLesson {
                    material_id: materials
                        .iter()
                        .find(|m| m.lesson_id.as_deref() == Some(l.id.as_str()))
                        .map(|m| m.id.clone()),
                    id: l.id,
                    position: l.position,
                    title: l.title,
                    duration_sec: l.duration_sec,
                    is_free_preview: l.is_free_preview,
                    preview_limit_sec: l.preview_limit_sec,
                    has_video: l.video_file.is_some(),
                })
                .collect(),
            materials: materials
                .into_iter()
                .map(|m| CatalogMaterial {
                    id: m.id,
                    title: m.title,
                    lesson_id: m.lesson_id,
                })
                .collect(),
            id: p.id,
            kind: p.kind,
            title: p.title,
            subtitle: p.subtitle,
            level: p.level,
            activation_number: p.activation_number,
        });
    }
    Ok(Json(Catalog { products }))
}

#[derive(Serialize)]
pub struct Link {
    pub url: String,
    pub expires_in: i64,
}

/// Ключ, который приложение приложило к запросу, подходит к продукту:
/// его собственный номер или номер альбома, в который входит песня.
async fn has_access(
    state: &AppState,
    product: &Product,
    headers: &HeaderMap,
) -> Result<bool, AppError> {
    let header = |name: &str| {
        headers
            .get(name)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
    };
    let (code, key) = (header("x-device-code"), header("x-activation-key"));
    if code.is_empty() || key.is_empty() {
        return Ok(false);
    }
    let fits = |p: &Product| activation::verify_key(code, p.activation_number as u64, key);
    if fits(product) {
        return Ok(true);
    }
    Ok(repo::unlocking_albums(&state.db, &product.id)
        .await?
        .iter()
        .any(fits))
}

async fn published(state: &AppState, product_id: &str) -> Result<Product, AppError> {
    let product = repo::get_product(&state.db, product_id).await?;
    if !product.is_published {
        return Err(AppError::NotFound);
    }
    Ok(product)
}

/// `GET /api/v1/lessons/{id}/stream` — ссылка на видео на [LINK_TTL_SECS].
/// Без ключа — только бесплатные уроки. Заголовки: `X-Device-Code`, `X-Activation-Key`.
pub async fn lesson_stream(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<Link>, AppError> {
    let lesson = repo::get_lesson(&state.db, &id).await?;
    let product = published(&state, &lesson.product_id).await?;
    let file = lesson.video_file.ok_or(AppError::NotFound)?;
    let free = lesson.is_free_preview || lesson.preview_limit_sec.is_some();
    if !free && !has_access(&state, &product, &headers).await? {
        return Err(AppError::Forbidden);
    }
    Ok(Json(Link {
        url: state.media.url(MediaKind::Video, &file, media::now()),
        expires_in: LINK_TTL_SECS,
    }))
}

/// `GET /api/v1/materials/{id}/download` — ссылка на PDF; только с верным ключом.
pub async fn material_download(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<Link>, AppError> {
    let material = repo::get_material(&state.db, &id).await?;
    let product = published(&state, &material.product_id).await?;
    if !has_access(&state, &product, &headers).await? {
        return Err(AppError::Forbidden);
    }
    Ok(Json(Link {
        url: state
            .media
            .url(MediaKind::Pdf, &material.file, media::now()),
        expires_in: LINK_TTL_SECS,
    }))
}
