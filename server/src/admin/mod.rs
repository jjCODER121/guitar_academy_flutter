//! Админ-панель музыканта: HTML со стороны сервера (maud) + немного JS
//! (`admin/static/admin.js`: прогресс загрузки видео, перетаскивание уроков).

mod auth;
mod dashboard;
mod keys;
mod layout;
mod products;

use axum::{
    Router,
    extract::{DefaultBodyLimit, FromRequestParts, Request},
    http::{Method, StatusCode, header, request::Parts},
    middleware::{self, Next},
    response::{IntoResponse, Redirect, Response},
    routing::{get, post},
};
use axum_extra::extract::CookieJar;
use maud::html;

use crate::{error::AppError, state::AppState};

pub use auth::{create_admin, hash_password};

const SESSION_COOKIE: &str = "gs_admin";

pub fn router(max_upload_mb: u64) -> Router<AppState> {
    let upload_limit = DefaultBodyLimit::max((max_upload_mb * 1024 * 1024) as usize);
    Router::new()
        .route("/", get(dashboard::page))
        .route("/login", get(auth::login_page).post(auth::login))
        .route("/logout", post(auth::logout))
        .route("/products", get(products::list).post(products::create))
        .route("/products/new", get(products::new_page))
        .route("/products/{id}", get(products::editor).post(products::save))
        .route("/products/{id}/delete", post(products::delete))
        .route("/products/{id}/cover", post(products::upload_cover))
        .route("/products/{id}/lessons", post(products::add_lesson))
        .route("/products/{id}/order", post(products::reorder))
        .route("/products/{id}/materials", post(products::add_material))
        .route("/lessons/{id}", post(products::save_lesson))
        .route("/lessons/{id}/delete", post(products::delete_lesson))
        .route("/lessons/{id}/video", post(products::upload_video))
        .route("/materials/{id}/delete", post(products::delete_material))
        .route("/preview/{kind}/{id}", get(products::preview))
        .route("/keys", get(keys::page).post(keys::create))
        .route("/keys.csv", get(keys::export_csv))
        .route("/keys/{id}/delete", post(keys::delete))
        .layer(upload_limit)
        .layer(middleware::from_fn(same_origin))
}

/// Вошедший администратор. Без входа — перенаправление на страницу входа.
pub struct AdminUser(#[allow(dead_code)] pub String);

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = Response;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let to_login = || Redirect::to("/admin/login").into_response();
        let jar = CookieJar::from_headers(&parts.headers);
        let Some(token) = jar.get(SESSION_COOKIE) else {
            return Err(to_login());
        };
        match crate::repo::session_user(&state.db, &auth::hash_token(token.value())).await {
            Ok(Some(user)) => Ok(Self(user)),
            _ => Err(to_login()),
        }
    }
}

/// Защита от подделки запросов с чужих сайтов: POST принимается, только если
/// браузер прислал Origin этого же сервера (или не прислал вовсе).
/// Вторая линия — cookie входа с SameSite=Strict.
async fn same_origin(req: Request, next: Next) -> Response {
    if req.method() != Method::GET && req.method() != Method::HEAD {
        let host = req
            .headers()
            .get(header::HOST)
            .and_then(|h| h.to_str().ok());
        if let Some(origin) = req.headers().get(header::ORIGIN) {
            let origin_host = origin
                .to_str()
                .ok()
                .and_then(|o| o.split_once("://"))
                .map(|(_, h)| h);
            if origin_host.is_none() || origin_host != host {
                return (StatusCode::FORBIDDEN, "запрос с чужого сайта").into_response();
            }
        }
    }
    next.run(req).await
}

/// Ошибка на странице админки — показывается страницей, а не JSON.
pub struct AdminError(AppError);

impl<E: Into<AppError>> From<E> for AdminError {
    fn from(e: E) -> Self {
        Self(e.into())
    }
}

impl IntoResponse for AdminError {
    fn into_response(self) -> Response {
        let status = self.0.status();
        if let AppError::Internal(err) = &self.0 {
            tracing::error!(error = ?err, "admin internal error");
        }
        let message = self.0.to_string();
        let body = layout::bare(
            "Ошибка",
            html! {
                main.login {
                    div.card {
                        h1 { "Не получилось" }
                        p { (message) }
                        a.button href="/admin" { "В админ-панель" }
                    }
                }
            },
        );
        (status, body).into_response()
    }
}

pub type AdminResult<T> = Result<T, AdminError>;
