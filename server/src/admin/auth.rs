use std::time::Duration;

use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};
use axum::{
    Form,
    extract::State,
    response::{IntoResponse, Redirect, Response},
};
use axum_extra::extract::{
    CookieJar,
    cookie::{Cookie, SameSite},
};
use maud::{Markup, html};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use sqlx::SqlitePool;

use super::{AdminResult, SESSION_COOKIE, layout};
use crate::{error::AppError, repo, state::AppState};

/// Сколько дней действует вход в админку.
const SESSION_DAYS: i64 = 30;

pub fn hash_password(password: &str) -> anyhow::Result<String> {
    // 16 случайных байт из генератора ОС (uuid v4 берёт их через getrandom).
    let salt = SaltString::encode_b64(uuid::Uuid::new_v4().as_bytes())
        .map_err(|e| anyhow::anyhow!("salt: {e}"))?;
    Ok(Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| anyhow::anyhow!("argon2: {e}"))?
        .to_string())
}

fn verify_password(password: &str, hash: &str) -> bool {
    PasswordHash::new(hash).is_ok_and(|h| {
        Argon2::default()
            .verify_password(password.as_bytes(), &h)
            .is_ok()
    })
}

/// В базе — только хэш токена: утечка базы не даёт войти в админку.
pub fn hash_token(token: &str) -> String {
    hex::encode(Sha256::digest(token.as_bytes()))
}

/// Создать администратора или сменить пароль (команда `admin`).
pub async fn create_admin(db: &SqlitePool, username: &str, password: &str) -> anyhow::Result<()> {
    if password.chars().count() < 8 {
        anyhow::bail!("пароль должен быть не короче 8 символов");
    }
    repo::upsert_admin(db, username, &hash_password(password)?).await?;
    Ok(())
}

#[derive(Deserialize)]
pub struct LoginQuery {
    error: Option<String>,
}

pub async fn login_page(
    State(state): State<AppState>,
    axum::extract::Query(q): axum::extract::Query<LoginQuery>,
) -> AdminResult<Markup> {
    let no_admins = repo::admin_count(&state.db).await? == 0;
    Ok(layout::bare(
        "Вход",
        html! {
            main.login {
                form.card method="post" action="/admin/login" {
                    div.brand-logo aria-hidden="true" { (layout::icon_guitar()) }
                    h1 { "Админ-панель" }
                    p.muted { (state.config.school_name) }
                    @if no_admins {
                        p.notice {
                            "Администратор ещё не создан. На сервере выполните: "
                            code { "guitar_school_server admin <логин> <пароль>" }
                        }
                    }
                    @if q.error.is_some() {
                        p.error role="alert" { "Неверный логин или пароль" }
                    }
                    label { "Логин" input name="username" autocomplete="username" required; }
                    label {
                        "Пароль"
                        input type="password" name="password" autocomplete="current-password" required;
                    }
                    button.primary type="submit" { "Войти" }
                }
            }
        },
    ))
}

#[derive(Deserialize)]
pub struct LoginForm {
    username: String,
    password: String,
}

pub async fn login(
    State(state): State<AppState>,
    jar: CookieJar,
    Form(form): Form<LoginForm>,
) -> AdminResult<Response> {
    let username = form.username.trim();
    let hash = repo::admin_password_hash(&state.db, username).await?;
    let ok = hash.is_some_and(|h| verify_password(&form.password, &h));
    if !ok {
        // Замедляет подбор пароля.
        tokio::time::sleep(Duration::from_millis(700)).await;
        return Ok(Redirect::to("/admin/login?error=1").into_response());
    }

    let token = format!(
        "{}{}",
        uuid::Uuid::new_v4().simple(),
        uuid::Uuid::new_v4().simple()
    );
    let expires = (chrono::Utc::now() + chrono::Duration::days(SESSION_DAYS))
        .format("%Y-%m-%dT%H:%M:%SZ")
        .to_string();
    repo::create_session(&state.db, &hash_token(&token), username, &expires).await?;

    let cookie = Cookie::build((SESSION_COOKIE, token))
        .path("/admin")
        .http_only(true)
        .same_site(SameSite::Strict)
        .secure(state.config.cookie_secure)
        .max_age(time_days(SESSION_DAYS))
        .build();
    Ok((jar.add(cookie), Redirect::to("/admin")).into_response())
}

fn time_days(days: i64) -> cookie::time::Duration {
    cookie::time::Duration::days(days)
}

pub async fn logout(State(state): State<AppState>, jar: CookieJar) -> Result<Response, AppError> {
    if let Some(c) = jar.get(SESSION_COOKIE) {
        repo::delete_session(&state.db, &hash_token(c.value())).await?;
    }
    let removal = Cookie::build((SESSION_COOKIE, "")).path("/admin").build();
    Ok((jar.remove(removal), Redirect::to("/admin/login")).into_response())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn password_hash_roundtrip() {
        let hash = hash_password("очень-секретно-123").unwrap();
        assert!(verify_password("очень-секретно-123", &hash));
        assert!(!verify_password("другой", &hash));
        assert!(!verify_password("x", "не-хэш"));
    }
}
