mod common;

use axum::http::StatusCode;
use common::{TestApp, test_app};
use guitar_school_server::{activation, repo};

const DEVICE: &str = "14140235536843855";

/// Опубликованный курс: урок 1 бесплатный, урок 2 платный, PDF к курсу и к уроку 2.
async fn published_course(app: &mut TestApp) -> (String, String, String, String) {
    app.login().await;
    let id = app.create_product("course", "Гитара с нуля").await;
    let free = app.add_lesson(&id, "Как держать гитару").await;
    let paid = app.add_lesson(&id, "Настройка").await;
    app.post_form(
        &format!("/admin/lessons/{free}"),
        &[("title", "Как держать гитару"), ("free", "1")],
    )
    .await;
    app.upload_video(&free, b"0123456789-free-video").await;
    app.upload_video(&paid, b"0123456789-paid-video").await;
    app.post_multipart(
        &format!("/admin/products/{id}/materials"),
        &[("lesson_id", &paid)],
        ("file", "Ноты.pdf", b"%PDF-1.4 notes"),
    )
    .await;
    let r = app
        .post_form(
            &format!("/admin/products/{id}"),
            &[
                ("action", "publish"),
                ("kind", "course"),
                ("title", "Гитара с нуля"),
                ("level", "beginner"),
            ],
        )
        .await;
    assert!(r.location().ends_with("ok=published"), "{}", r.location());
    let material = repo::materials_of(&app.state.db, &id).await.unwrap()[0]
        .id
        .clone();
    (id, free, paid, material)
}

#[tokio::test]
async fn health_reports_db() {
    let app = test_app().await;
    let r = app.get("/api/v1/health").await;
    assert_eq!(r.status, StatusCode::OK);
    assert_eq!(r.json()["status"], "ok");
    assert_eq!(r.json()["db"], "up");
}

#[tokio::test]
async fn unknown_api_route_returns_json_404() {
    let app = test_app().await;
    let r = app.get("/api/v1/nope").await;
    assert_eq!(r.status, StatusCode::NOT_FOUND);
    assert_eq!(r.json()["error"]["code"], "not_found");
}

#[tokio::test]
async fn catalog_shows_only_published_without_prices() {
    let mut app = test_app().await;
    let (id, free, paid, material) = published_course(&mut app).await;
    app.create_product("song_album", "Черновик альбома").await;

    let r = app.get("/api/v1/catalog").await;
    assert_eq!(r.status, StatusCode::OK);
    let json = r.json();
    let products = json["products"].as_array().unwrap();
    assert_eq!(products.len(), 1, "черновик не попадает в каталог");
    let p = &products[0];
    assert_eq!(p["id"], id);
    assert_eq!(p["activation_number"], 1);
    assert!(p.get("price_somoni").is_none(), "цен в приложении нет");
    assert_eq!(p["lessons"][0]["id"], free);
    assert_eq!(p["lessons"][0]["is_free_preview"], true);
    assert_eq!(p["lessons"][0]["duration_sec"], 400);
    assert_eq!(p["lessons"][1]["id"], paid);
    assert_eq!(p["lessons"][1]["material_id"], material);
    assert!(
        !r.text().contains(".mp4"),
        "имена файлов наружу не отдаются"
    );
}

#[tokio::test]
async fn free_lesson_streams_without_key() {
    let mut app = test_app().await;
    let (_, free, _, _) = published_course(&mut app).await;

    let r = app.get(&format!("/api/v1/lessons/{free}/stream")).await;
    assert_eq!(r.status, StatusCode::OK, "{}", r.text());
    let url = r.json()["url"].as_str().unwrap().to_owned();
    assert!(url.starts_with("/media/videos/") && url.contains("sig="));

    let video = app.get(&url).await;
    assert_eq!(video.status, StatusCode::OK);
    assert_eq!(video.body, b"0123456789-free-video");
}

#[tokio::test]
async fn paid_lesson_needs_valid_key() {
    let mut app = test_app().await;
    let (_, _, paid, material) = published_course(&mut app).await;
    let uri = format!("/api/v1/lessons/{paid}/stream");

    assert_eq!(app.get(&uri).await.status, StatusCode::FORBIDDEN);
    let wrong = app
        .get_with(
            &uri,
            &[("x-device-code", DEVICE), ("x-activation-key", "1A2B")],
        )
        .await;
    assert_eq!(wrong.status, StatusCode::FORBIDDEN);
    // Ключ другого курса (№ 2) к курсу № 1 не подходит.
    let other = activation::expected_key(DEVICE, 2).unwrap();
    let r = app
        .get_with(
            &uri,
            &[("x-device-code", DEVICE), ("x-activation-key", &other)],
        )
        .await;
    assert_eq!(r.status, StatusCode::FORBIDDEN);

    let key = activation::expected_key(DEVICE, 1).unwrap();
    let headers = [
        ("x-device-code", DEVICE),
        ("x-activation-key", key.as_str()),
    ];
    let r = app.get_with(&uri, &headers).await;
    assert_eq!(r.status, StatusCode::OK);
    let url = r.json()["url"].as_str().unwrap().to_owned();

    // Перемотка: Range-запрос отдаёт кусок файла.
    let part = app.get_with(&url, &[("range", "bytes=0-3")]).await;
    assert_eq!(part.status, StatusCode::PARTIAL_CONTENT);
    assert_eq!(part.body, b"0123");

    // PDF — тоже только с ключом.
    let pdf_uri = format!("/api/v1/materials/{material}/download");
    assert_eq!(app.get(&pdf_uri).await.status, StatusCode::FORBIDDEN);
    let pdf = app.get_with(&pdf_uri, &headers).await;
    assert_eq!(pdf.status, StatusCode::OK);
    let pdf_file = app.get(pdf.json()["url"].as_str().unwrap()).await;
    assert_eq!(pdf_file.body, b"%PDF-1.4 notes");
}

#[tokio::test]
async fn media_links_cannot_be_forged() {
    let mut app = test_app().await;
    let (_, free, _, _) = published_course(&mut app).await;
    let url = app
        .get(&format!("/api/v1/lessons/{free}/stream"))
        .await
        .json()["url"]
        .as_str()
        .unwrap()
        .to_owned();

    let (path, _) = url.split_once('?').unwrap();
    assert_eq!(
        app.get(path).await.status,
        StatusCode::FORBIDDEN,
        "без подписи"
    );
    let tampered = url.replace("sig=", "sig=00");
    assert_eq!(app.get(&tampered).await.status, StatusCode::FORBIDDEN);
    assert_eq!(
        app.get("/media/videos/..%2F..%2Fschool.db").await.status,
        StatusCode::NOT_FOUND
    );
}

#[tokio::test]
async fn unpublished_product_is_hidden() {
    let mut app = test_app().await;
    let (id, free, _, _) = published_course(&mut app).await;
    app.post_form(
        &format!("/admin/products/{id}"),
        &[
            ("action", "unpublish"),
            ("kind", "course"),
            ("title", "Гитара с нуля"),
            ("level", "beginner"),
        ],
    )
    .await;
    assert_eq!(
        app.get("/api/v1/catalog").await.json()["products"]
            .as_array()
            .unwrap()
            .len(),
        0
    );
    assert_eq!(
        app.get(&format!("/api/v1/lessons/{free}/stream"))
            .await
            .status,
        StatusCode::NOT_FOUND
    );
}

#[tokio::test]
async fn album_key_opens_its_single() {
    let mut app = test_app().await;
    app.login().await;
    let album = app.create_product("song_album", "Далер Назаров").await;
    let single = app.create_product("single", "[Песня 1]").await;
    let lesson = app.add_lesson(&single, "[Песня 1]").await;
    app.upload_video(&lesson, b"song").await;
    let publish =
        |kind: &'static str, title: &'static str, extra: Option<(&'static str, String)>| {
            let mut f: Vec<(&str, String)> = vec![
                ("action", "publish".into()),
                ("kind", kind.into()),
                ("title", title.into()),
                ("level", "intermediate".into()),
            ];
            if let Some(e) = extra {
                f.push(e);
            }
            f
        };
    let single_form = publish("single", "[Песня 1]", Some(("album_id", album.clone())));
    let fields: Vec<(&str, &str)> = single_form.iter().map(|(k, v)| (*k, v.as_str())).collect();
    let r = app
        .post_form(&format!("/admin/products/{single}"), &fields)
        .await;
    assert!(r.location().ends_with("ok=published"), "{}", r.location());

    let album_number = repo::get_product(&app.state.db, &album)
        .await
        .unwrap()
        .activation_number;
    let key = activation::expected_key(DEVICE, album_number as u64).unwrap();
    let r = app
        .get_with(
            &format!("/api/v1/lessons/{lesson}/stream"),
            &[("x-device-code", DEVICE), ("x-activation-key", &key)],
        )
        .await;
    assert_eq!(r.status, StatusCode::OK, "{}", r.text());

    let catalog = app.get("/api/v1/catalog").await.json();
    assert_eq!(catalog["products"][0]["unlocked_by"][0], album);
}
