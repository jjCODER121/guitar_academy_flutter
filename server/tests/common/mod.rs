//! Общие помощники интеграционных тестов: приложение на базе в памяти,
//! вход в админку, multipart-формы.

#![allow(dead_code)]

use std::path::PathBuf;

use axum::{
    Router,
    body::{Body, to_bytes},
    http::{Request, Response, StatusCode, header},
};
use guitar_school_server::{admin, app, config::Config, db, state::AppState, state_with_db};
use tower::ServiceExt;

pub struct TestApp {
    pub router: Router,
    pub state: AppState,
    pub data_dir: PathBuf,
    pub cookie: Option<String>,
}

impl Drop for TestApp {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.data_dir);
    }
}

pub async fn test_app() -> TestApp {
    let data_dir = std::env::temp_dir().join(format!("gs-test-{}", uuid::Uuid::new_v4()));
    let static_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../admin/static");
    let config = Config::from_lookup(|name| match name {
        "DATA_DIR" => Some(data_dir.display().to_string()),
        "ADMIN_STATIC_DIR" => Some(static_dir.display().to_string()),
        "MEDIA_SECRET" => Some("test-secret-test-secret-test-secret!".into()),
        _ => None,
    })
    .unwrap();
    std::fs::create_dir_all(&data_dir).unwrap();
    let pool = db::connect_memory().await.unwrap();
    let state = state_with_db(config, pool).await.unwrap();
    TestApp {
        router: app(state.clone()),
        state,
        data_dir,
        cookie: None,
    }
}

pub struct Reply {
    pub status: StatusCode,
    pub headers: axum::http::HeaderMap,
    pub body: Vec<u8>,
}

impl Reply {
    pub fn text(&self) -> String {
        String::from_utf8_lossy(&self.body).into_owned()
    }

    pub fn json(&self) -> serde_json::Value {
        serde_json::from_slice(&self.body).unwrap_or_else(|_| panic!("not json: {}", self.text()))
    }

    pub fn location(&self) -> String {
        self.headers
            .get(header::LOCATION)
            .map(|v| v.to_str().unwrap().to_owned())
            .unwrap_or_default()
    }
}

async fn reply(resp: Response<Body>) -> Reply {
    let status = resp.status();
    let headers = resp.headers().clone();
    let body = to_bytes(resp.into_body(), usize::MAX)
        .await
        .unwrap()
        .to_vec();
    Reply {
        status,
        headers,
        body,
    }
}

impl TestApp {
    pub async fn send(&self, mut req: Request<Body>) -> Reply {
        if let Some(c) = &self.cookie {
            req.headers_mut().insert(header::COOKIE, c.parse().unwrap());
        }
        reply(self.router.clone().oneshot(req).await.unwrap()).await
    }

    pub async fn get(&self, uri: &str) -> Reply {
        self.send(Request::get(uri).body(Body::empty()).unwrap())
            .await
    }

    pub async fn get_with(&self, uri: &str, headers: &[(&str, &str)]) -> Reply {
        let mut b = Request::get(uri);
        for (k, v) in headers {
            b = b.header(*k, *v);
        }
        self.send(b.body(Body::empty()).unwrap()).await
    }

    pub async fn post_form(&self, uri: &str, fields: &[(&str, &str)]) -> Reply {
        let body = serde_urlencoded::to_string(fields).unwrap();
        self.send(
            Request::post(uri)
                .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
                .body(Body::from(body))
                .unwrap(),
        )
        .await
    }

    pub async fn post_json(&self, uri: &str, json: serde_json::Value) -> Reply {
        self.send(
            Request::post(uri)
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(json.to_string()))
                .unwrap(),
        )
        .await
    }

    /// multipart: текстовые поля + один файл.
    pub async fn post_multipart(
        &self,
        uri: &str,
        fields: &[(&str, &str)],
        file: (&str, &str, &[u8]),
    ) -> Reply {
        let boundary = "----gs-test-boundary";
        let mut body = Vec::new();
        for (name, value) in fields {
            body.extend_from_slice(
                format!(
                    "--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n"
                )
                .as_bytes(),
            );
        }
        let (name, filename, bytes) = file;
        body.extend_from_slice(
            format!(
                "--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{filename}\"\r\nContent-Type: application/octet-stream\r\n\r\n"
            )
            .as_bytes(),
        );
        body.extend_from_slice(bytes);
        body.extend_from_slice(format!("\r\n--{boundary}--\r\n").as_bytes());
        self.send(
            Request::post(uri)
                .header(
                    header::CONTENT_TYPE,
                    format!("multipart/form-data; boundary={boundary}"),
                )
                .body(Body::from(body))
                .unwrap(),
        )
        .await
    }

    /// Создаёт администратора и входит; cookie сохраняется для следующих запросов.
    pub async fn login(&mut self) {
        admin::create_admin(&self.state.db, "admin", "очень-секретно")
            .await
            .unwrap();
        let r = self
            .post_form(
                "/admin/login",
                &[("username", "admin"), ("password", "очень-секретно")],
            )
            .await;
        assert_eq!(r.status, StatusCode::SEE_OTHER, "{}", r.text());
        let set_cookie = r.headers.get(header::SET_COOKIE).unwrap().to_str().unwrap();
        self.cookie = Some(set_cookie.split(';').next().unwrap().to_owned());
    }

    /// Создаёт продукт через админку и возвращает его id.
    pub async fn create_product(&self, kind: &str, title: &str) -> String {
        let r = self
            .post_form("/admin/products", &[("kind", kind), ("title", title)])
            .await;
        assert_eq!(r.status, StatusCode::SEE_OTHER, "{}", r.text());
        let loc = r.location();
        loc.trim_start_matches("/admin/products/")
            .split('?')
            .next()
            .unwrap()
            .to_owned()
    }

    pub async fn add_lesson(&self, product_id: &str, title: &str) -> String {
        let r = self
            .post_form(
                &format!("/admin/products/{product_id}/lessons"),
                &[("title", title)],
            )
            .await;
        assert_eq!(r.status, StatusCode::SEE_OTHER);
        r.location().rsplit("#lesson-").next().unwrap().to_owned()
    }

    pub async fn upload_video(&self, lesson_id: &str, bytes: &[u8]) -> Reply {
        self.post_multipart(
            &format!("/admin/lessons/{lesson_id}/video"),
            &[("duration", "400.4")],
            ("video", "урок.mp4", bytes),
        )
        .await
    }
}
