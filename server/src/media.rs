//! Загруженные файлы: видео, PDF, обложки. Лежат в `DATA_DIR/media/<вид>/<uuid>.<расширение>`.
//! Видео и PDF отдаются только по временной подписанной ссылке, обложки — открыто.

use std::path::{Path, PathBuf};

use axum::{
    body::Body,
    extract::{Path as UrlPath, Query, Request, State},
    http::{HeaderValue, header},
    response::{IntoResponse, Response},
};
use futures_util::StreamExt;
use hmac::{Hmac, Mac};
use serde::Deserialize;
use sha2::Sha256;
use tokio::io::AsyncWriteExt;
use tower::ServiceExt;
use tower_http::services::ServeFile;

use crate::{error::AppError, state::AppState};

/// Сколько живёт ссылка на видео или PDF.
pub const LINK_TTL_SECS: i64 = 2 * 60 * 60;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaKind {
    Video,
    Pdf,
    Cover,
}

impl MediaKind {
    pub fn dir(self) -> &'static str {
        match self {
            Self::Video => "videos",
            Self::Pdf => "pdfs",
            Self::Cover => "covers",
        }
    }

    fn from_dir(dir: &str) -> Option<Self> {
        match dir {
            "videos" => Some(Self::Video),
            "pdfs" => Some(Self::Pdf),
            "covers" => Some(Self::Cover),
            _ => None,
        }
    }

    fn extensions(self) -> &'static [&'static str] {
        match self {
            Self::Video => &["mp4", "m4v", "mov", "webm"],
            Self::Pdf => &["pdf"],
            Self::Cover => &["jpg", "jpeg", "png", "webp"],
        }
    }

    fn is_public(self) -> bool {
        self == Self::Cover
    }
}

pub struct Media {
    root: PathBuf,
    secret: Vec<u8>,
}

impl Media {
    pub fn new(data_dir: &Path, secret: impl Into<Vec<u8>>) -> Self {
        Self {
            root: data_dir.join("media"),
            secret: secret.into(),
        }
    }

    pub async fn ensure_dirs(&self) -> std::io::Result<()> {
        for kind in [MediaKind::Video, MediaKind::Pdf, MediaKind::Cover] {
            tokio::fs::create_dir_all(self.root.join(kind.dir())).await?;
        }
        Ok(())
    }

    fn path(&self, kind: MediaKind, file: &str) -> PathBuf {
        self.root.join(kind.dir()).join(file)
    }

    /// Новое имя для загружаемого файла: uuid + расширение исходного файла.
    pub fn new_file_name(kind: MediaKind, original: &str) -> Result<String, AppError> {
        let ext = Path::new(original)
            .extension()
            .and_then(|e| e.to_str())
            .map(str::to_ascii_lowercase)
            .filter(|e| kind.extensions().contains(&e.as_str()))
            .ok_or_else(|| {
                AppError::BadRequest(format!(
                    "неподходящий файл: нужен {}",
                    kind.extensions().join(", ")
                ))
            })?;
        Ok(format!("{}.{ext}", uuid::Uuid::new_v4()))
    }

    /// Имя создано сервером: `uuid.расширение`. Всё остальное отклоняем —
    /// так через ссылку нельзя добраться до других файлов на сервере.
    fn is_valid_name(kind: MediaKind, file: &str) -> bool {
        let Some((stem, ext)) = file.split_once('.') else {
            return false;
        };
        stem.len() == 36
            && stem.bytes().all(|b| b.is_ascii_hexdigit() || b == b'-')
            && kind.extensions().contains(&ext)
    }

    /// Сохраняет поле формы в файл потоком (видео может весить гигабайты).
    pub async fn save_field(
        &self,
        kind: MediaKind,
        file: &str,
        mut field: axum::extract::multipart::Field<'_>,
    ) -> Result<u64, AppError> {
        let path = self.path(kind, file);
        let mut out = tokio::fs::File::create(&path)
            .await
            .map_err(anyhow::Error::from)?;
        let mut written = 0u64;
        while let Some(chunk) = field.next().await {
            let chunk = match chunk {
                Ok(c) => c,
                Err(e) => {
                    drop(out);
                    let _ = tokio::fs::remove_file(&path).await;
                    return Err(AppError::BadRequest(format!("загрузка прервана: {e}")));
                }
            };
            written += chunk.len() as u64;
            out.write_all(&chunk).await.map_err(anyhow::Error::from)?;
        }
        out.flush().await.map_err(anyhow::Error::from)?;
        if written == 0 {
            let _ = tokio::fs::remove_file(&path).await;
            return Err(AppError::BadRequest("пустой файл".into()));
        }
        Ok(written)
    }

    pub async fn delete(&self, kind: MediaKind, file: &str) {
        if Self::is_valid_name(kind, file) {
            let _ = tokio::fs::remove_file(self.path(kind, file)).await;
        }
    }

    fn signature(&self, kind: MediaKind, file: &str, exp: i64) -> Hmac<Sha256> {
        let mut mac = Hmac::<Sha256>::new_from_slice(&self.secret).expect("any key length");
        mac.update(format!("{}/{file}:{exp}", kind.dir()).as_bytes());
        mac
    }

    /// Путь для приложения: обложка — открыто, видео и PDF — с подписью на [LINK_TTL_SECS].
    pub fn url(&self, kind: MediaKind, file: &str, now: i64) -> String {
        if kind.is_public() {
            return format!("/media/{}/{file}", kind.dir());
        }
        let exp = now + LINK_TTL_SECS;
        let sig = hex::encode(self.signature(kind, file, exp).finalize().into_bytes());
        format!("/media/{}/{file}?exp={exp}&sig={sig}", kind.dir())
    }

    fn verify(&self, kind: MediaKind, file: &str, exp: i64, sig: &str, now: i64) -> bool {
        if exp < now {
            return false;
        }
        let Ok(sig) = hex::decode(sig) else {
            return false;
        };
        self.signature(kind, file, exp).verify_slice(&sig).is_ok()
    }
}

pub fn now() -> i64 {
    chrono::Utc::now().timestamp()
}

#[derive(Deserialize)]
pub struct SignedQuery {
    exp: Option<i64>,
    sig: Option<String>,
}

/// `GET /media/{вид}/{файл}` — с поддержкой Range: видео можно перематывать.
pub async fn serve(
    State(state): State<AppState>,
    UrlPath((dir, file)): UrlPath<(String, String)>,
    Query(q): Query<SignedQuery>,
    req: Request,
) -> Result<Response, AppError> {
    let kind = MediaKind::from_dir(&dir).ok_or(AppError::NotFound)?;
    if !Media::is_valid_name(kind, &file) {
        return Err(AppError::NotFound);
    }
    if !kind.is_public() {
        let (Some(exp), Some(sig)) = (q.exp, q.sig.as_deref()) else {
            return Err(AppError::Forbidden);
        };
        if !state.media.verify(kind, &file, exp, sig, now()) {
            return Err(AppError::Forbidden);
        }
    }
    let path = state.media.path(kind, &file);
    if !path.exists() {
        return Err(AppError::NotFound);
    }
    let mut resp = ServeFile::new(path)
        .oneshot(req)
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!(e)))?
        .map(Body::new)
        .into_response();
    resp.headers_mut().insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static(if kind.is_public() {
            "public, max-age=86400"
        } else {
            "private, no-store"
        }),
    );
    Ok(resp)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn media() -> Media {
        Media::new(
            Path::new("data"),
            b"0123456789abcdef0123456789abcdef".to_vec(),
        )
    }

    #[test]
    fn signed_link_checks_signature_and_expiry() {
        let m = media();
        let file = "0d3c5b2a-1111-4222-8333-444455556666.mp4";
        let url = m.url(MediaKind::Video, file, 1_000);
        let query = url.split_once('?').unwrap().1;
        let q: std::collections::HashMap<String, String> =
            serde_urlencoded::from_str(query).unwrap();
        let exp: i64 = q["exp"].parse::<i64>().unwrap();
        let sig: &String = &q["sig"];

        assert!(m.verify(MediaKind::Video, file, exp, sig, 1_000));
        // Истёкшая ссылка
        assert!(!m.verify(MediaKind::Video, file, exp, sig, exp + 1));
        // Подпись от другого файла
        assert!(!m.verify(
            MediaKind::Video,
            "0d3c5b2a-1111-4222-8333-444455556667.mp4",
            exp,
            sig,
            1_000
        ));
        // Подпись другим ключом
        let other = Media::new(
            Path::new("data"),
            b"another-secret-another-secret-123".to_vec(),
        );
        assert!(!other.verify(MediaKind::Video, file, exp, sig, 1_000));
    }

    #[test]
    fn file_names_are_strict() {
        assert!(Media::is_valid_name(
            MediaKind::Pdf,
            "0d3c5b2a-1111-4222-8333-444455556666.pdf"
        ));
        assert!(!Media::is_valid_name(MediaKind::Pdf, "../../school.db"));
        assert!(!Media::is_valid_name(
            MediaKind::Pdf,
            "0d3c5b2a-1111-4222-8333-444455556666.mp4"
        ));
    }

    #[test]
    fn upload_names_keep_allowed_extension() {
        let name = Media::new_file_name(MediaKind::Video, "Урок 1.MP4").unwrap();
        assert!(name.ends_with(".mp4"));
        assert!(Media::new_file_name(MediaKind::Video, "virus.exe").is_err());
        assert!(Media::new_file_name(MediaKind::Pdf, "без расширения").is_err());
    }
}
