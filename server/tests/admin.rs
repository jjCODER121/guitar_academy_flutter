mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode, header},
};
use common::test_app;
use guitar_school_server::{activation, repo};

#[tokio::test]
async fn admin_requires_login() {
    let app = test_app().await;
    for uri in [
        "/admin",
        "/admin/products",
        "/admin/keys",
        "/admin/keys.csv",
    ] {
        let r = app.get(uri).await;
        assert_eq!(r.status, StatusCode::SEE_OTHER, "{uri}");
        assert_eq!(r.location(), "/admin/login", "{uri}");
    }
    let r = app.get("/admin/login").await;
    assert_eq!(r.status, StatusCode::OK);
    assert!(r.text().contains("Администратор ещё не создан"));
}

#[tokio::test]
async fn login_logout() {
    let mut app = test_app().await;
    guitar_school_server::admin::create_admin(&app.state.db, "admin", "очень-секретно")
        .await
        .unwrap();

    let bad = app
        .post_form(
            "/admin/login",
            &[("username", "admin"), ("password", "не тот")],
        )
        .await;
    assert_eq!(bad.location(), "/admin/login?error=1");

    app.login().await;
    let r = app.get("/admin").await;
    assert_eq!(r.status, StatusCode::OK);
    assert!(r.text().contains("Обзор"));

    let out = app.post_form("/admin/logout", &[]).await;
    assert_eq!(out.location(), "/admin/login");
    // Тот же cookie больше не действует.
    assert_eq!(app.get("/admin").await.status, StatusCode::SEE_OTHER);
}

#[tokio::test]
async fn short_password_is_rejected() {
    let app = test_app().await;
    assert!(
        guitar_school_server::admin::create_admin(&app.state.db, "admin", "123")
            .await
            .is_err()
    );
}

#[tokio::test]
async fn rejects_cross_site_posts() {
    let mut app = test_app().await;
    app.login().await;
    let r = app
        .send(
            Request::post("/admin/products")
                .header(header::HOST, "school.tj")
                .header(header::ORIGIN, "https://evil.example")
                .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
                .body(Body::from("kind=course&title=x"))
                .unwrap(),
        )
        .await;
    assert_eq!(r.status, StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn course_from_draft_to_published() {
    let mut app = test_app().await;
    app.login().await;

    let id = app.create_product("course", "Гитара с нуля").await;
    let editor = app.get(&format!("/admin/products/{id}")).await;
    assert_eq!(editor.status, StatusCode::OK);
    assert!(editor.text().contains("Гитара с нуля"));
    assert!(editor.text().contains("Черновик"));

    // Без уроков опубликовать нельзя.
    let publish = [
        ("action", "publish"),
        ("kind", "course"),
        ("title", "Гитара с нуля"),
        ("subtitle", "10 уроков для новичков"),
        ("level", "beginner"),
        ("price", "150"),
    ];
    let r = app
        .post_form(&format!("/admin/products/{id}"), &publish)
        .await;
    assert!(r.location().contains("err="), "{}", r.location());

    let l1 = app.add_lesson(&id, "Как держать гитару").await;
    let l2 = app.add_lesson(&id, "Настройка").await;

    // Видео есть не у всех уроков — публикация запрещена.
    let up = app.upload_video(&l1, b"fake-mp4-bytes").await;
    assert_eq!(up.status, StatusCode::OK, "{}", up.text());
    assert_eq!(up.json()["duration"], "6:40");
    let r = app
        .post_form(&format!("/admin/products/{id}"), &publish)
        .await;
    assert!(r.location().contains("err="));

    app.upload_video(&l2, b"second-video").await;
    let r = app
        .post_form(&format!("/admin/products/{id}"), &publish)
        .await;
    assert!(r.location().ends_with("?ok=published"), "{}", r.location());

    let p = repo::get_product(&app.state.db, &id).await.unwrap();
    assert!(p.is_published);
    assert_eq!(p.price_somoni, Some(150));
    assert_eq!(p.activation_number, 1);

    // Порядок уроков меняется перетаскиванием.
    let r = app
        .post_json(
            &format!("/admin/products/{id}/order"),
            serde_json::json!([l2, l1]),
        )
        .await;
    assert_eq!(r.status, StatusCode::OK);
    let lessons = repo::lessons_of(&app.state.db, &id).await.unwrap();
    assert_eq!(lessons[0].id, l2);
    assert_eq!(lessons[0].position, 1);

    // Устаревший список отклоняется.
    let r = app
        .post_json(
            &format!("/admin/products/{id}/order"),
            serde_json::json!([l1]),
        )
        .await;
    assert_eq!(r.status, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn uploads_reject_wrong_files() {
    let mut app = test_app().await;
    app.login().await;
    let id = app.create_product("course", "Курс").await;
    let lesson = app.add_lesson(&id, "Урок").await;

    let r = app
        .post_multipart(
            &format!("/admin/lessons/{lesson}/video"),
            &[],
            ("video", "virus.exe", b"MZ"),
        )
        .await;
    assert_eq!(r.status, StatusCode::BAD_REQUEST);

    let r = app
        .post_multipart(
            &format!("/admin/products/{id}/materials"),
            &[("title", "")],
            ("file", "notes.docx", b"x"),
        )
        .await;
    assert!(r.location().contains("err="));
}

#[tokio::test]
async fn materials_to_course_and_lesson() {
    let mut app = test_app().await;
    app.login().await;
    let id = app.create_product("course", "Курс").await;
    let lesson = app.add_lesson(&id, "Урок 1").await;

    let r = app
        .post_multipart(
            &format!("/admin/products/{id}/materials"),
            &[("title", "")],
            ("file", "Аккорды.pdf", b"%PDF-1.4 general"),
        )
        .await;
    assert!(r.location().contains("ok=pdf"), "{}", r.location());
    let r = app
        .post_multipart(
            &format!("/admin/products/{id}/materials"),
            &[("lesson_id", &lesson)],
            ("file", "Ноты.pdf", b"%PDF-1.4 lesson"),
        )
        .await;
    assert!(r.location().ends_with(&format!("#lesson-{lesson}")));

    let materials = repo::materials_of(&app.state.db, &id).await.unwrap();
    assert_eq!(materials.len(), 2);
    assert_eq!(materials[0].title, "Аккорды");
    assert_eq!(materials[0].lesson_id, None);
    assert_eq!(materials[1].lesson_id.as_deref(), Some(lesson.as_str()));

    let r = app
        .post_form(&format!("/admin/materials/{}/delete", materials[0].id), &[])
        .await;
    assert!(r.location().contains("pdf_deleted"));
    assert_eq!(
        repo::materials_of(&app.state.db, &id).await.unwrap().len(),
        1
    );
}

#[tokio::test]
async fn keys_generator_log_and_csv() {
    let mut app = test_app().await;
    app.login().await;
    let id = app.create_product("course", "Гитара с нуля").await;
    app.post_form(
        &format!("/admin/products/{id}"),
        &[
            ("action", "save"),
            ("kind", "course"),
            ("title", "Гитара с нуля"),
            ("level", "beginner"),
            ("price", "150"),
        ],
    )
    .await;

    let r = app
        .post_form(
            "/admin/keys",
            &[
                ("device_code", "1414 0235 5368 43855"),
                ("product_id", &id),
                ("student", "Фарход +992 90 123 45 67"),
                ("amount", ""),
            ],
        )
        .await;
    assert!(
        r.location().starts_with("/admin/keys?created="),
        "{}",
        r.location()
    );

    let page = app.get(&r.location()).await;
    let html = page.text();
    // Ключ из примера: 717 × 4 + 1985 = 4853.
    assert!(html.contains("4D8H5E3C"));
    assert!(html.contains("https://wa.me/992901234567?text="));

    let rows = repo::list_activations(&app.state.db, &Default::default())
        .await
        .unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0].amount_somoni,
        Some(150),
        "сумма по умолчанию — цена"
    );
    assert_eq!(
        Some(rows[0].activation_key.clone()),
        activation::expected_key("14140235536843855", 1)
    );

    let csv = app.get("/admin/keys.csv").await;
    assert_eq!(csv.status, StatusCode::OK);
    let text = csv.text();
    assert!(text.starts_with('\u{FEFF}'));
    assert!(text.contains("4D8H5E3C"));
    assert!(text.contains("Гитара с нуля"));

    let dash = app.get("/admin?period=month").await.text();
    assert!(dash.contains("150"));

    // Продукт с проданными ключами удалить нельзя.
    let del = app
        .post_form(&format!("/admin/products/{id}/delete"), &[])
        .await;
    assert!(del.location().contains("err="));

    let bad = app
        .post_form(
            "/admin/keys",
            &[("device_code", "абв"), ("product_id", &id)],
        )
        .await;
    assert!(bad.location().contains("err="));
}

#[tokio::test]
async fn single_can_belong_to_album() {
    let mut app = test_app().await;
    app.login().await;
    let album = app.create_product("song_album", "Далер Назаров").await;
    let single = app.create_product("single", "[Песня 1]").await;
    app.post_form(
        &format!("/admin/products/{single}"),
        &[
            ("action", "save"),
            ("kind", "single"),
            ("title", "[Песня 1]"),
            ("level", "intermediate"),
            ("album_id", &album),
        ],
    )
    .await;
    let unlocking = repo::unlocking_albums(&app.state.db, &single)
        .await
        .unwrap();
    assert_eq!(unlocking.len(), 1);
    assert_eq!(unlocking[0].id, album);
}

#[tokio::test]
async fn product_without_sales_can_be_deleted_with_files() {
    let mut app = test_app().await;
    app.login().await;
    let id = app.create_product("course", "Временный").await;
    let lesson = app.add_lesson(&id, "Урок").await;
    app.upload_video(&lesson, b"video").await;
    let videos_dir = app.data_dir.join("media/videos");
    assert_eq!(std::fs::read_dir(&videos_dir).unwrap().count(), 1);

    let r = app
        .post_form(&format!("/admin/products/{id}/delete"), &[])
        .await;
    assert_eq!(r.location(), "/admin/products?ok=deleted");
    assert_eq!(std::fs::read_dir(&videos_dir).unwrap().count(), 0);
}
