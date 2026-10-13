//! Продукты: таблица, создание, редактор (уроки, видео, PDF, обложка), публикация.

use std::collections::HashMap;

use axum::{
    Form, Json,
    extract::{Multipart, Path, Query, State},
    response::{IntoResponse, Redirect, Response},
};
use maud::{Markup, html};
use serde::{Deserialize, Serialize};

use super::{
    AdminResult, AdminUser,
    layout::{self, Nav},
};
use crate::{
    error::AppError,
    media::{self, Media, MediaKind},
    models::{Level, Material, Product, ProductType, format_duration, format_money},
    repo,
    state::AppState,
};

fn editor_url(id: &str) -> String {
    format!("/admin/products/{id}")
}

/// Сообщение в адресе после перенаправления: `?ok=saved` или `?err=текст`.
#[derive(Deserialize, Default)]
pub struct Flash {
    ok: Option<String>,
    err: Option<String>,
    #[serde(rename = "type")]
    kind: Option<String>,
}

impl Flash {
    fn message(&self) -> Option<&'static str> {
        Some(match self.ok.as_deref()? {
            "created" => "Продукт создан. Добавьте уроки, видео и обложку, затем опубликуйте.",
            "saved" => "Сохранено",
            "published" => "Опубликовано — продукт виден в приложении",
            "unpublished" => "Снято с публикации — в приложении его больше не видно",
            "lesson" => "Урок добавлен",
            "lesson_saved" => "Урок сохранён",
            "lesson_deleted" => "Урок удалён",
            "cover" => "Обложка загружена",
            "pdf" => "PDF загружен",
            "pdf_deleted" => "PDF удалён",
            "deleted" => "Продукт удалён",
            _ => return None,
        })
    }
}

fn redirect_ok(url: &str, code: &str, anchor: &str) -> Response {
    Redirect::to(&format!("{url}?ok={code}{anchor}")).into_response()
}

fn redirect_err(url: &str, err: &AppError) -> Response {
    let q = serde_urlencoded::to_string([("err", err.to_string())]).unwrap_or_default();
    Redirect::to(&format!("{url}?{q}")).into_response()
}

// ---------------------------------------------------------------- таблица

pub async fn list(
    _: AdminUser,
    State(state): State<AppState>,
    Query(flash): Query<Flash>,
) -> AdminResult<Markup> {
    let filter = flash.kind.as_deref().and_then(ProductType::parse);
    let items = repo::list_products(&state.db, filter.map(ProductType::as_str)).await?;
    let now = media::now();

    let chip = |label: &str, value: Option<ProductType>| {
        let href = match value {
            Some(t) => format!("/admin/products?type={}", t.as_str()),
            None => "/admin/products".into(),
        };
        html! { a.active[filter == value] href=(href) { (label) } }
    };

    let body = html! {
        header.page-header {
            div { h1 { "Продукты" } p.muted { "Курсы, альбомы песен и отдельные песни" } }
            a.button.primary href="/admin/products/new" { "Новый продукт" }
        }
        (layout::flash(flash.message()))
        nav.segmented aria-label="Тип" {
            (chip("Все", None))
            (chip("Курсы", Some(ProductType::Course)))
            (chip("Альбомы", Some(ProductType::SongAlbum)))
            (chip("Песни", Some(ProductType::Single)))
        }
        section.card {
            @if items.is_empty() {
                div.empty {
                    p { "Продуктов пока нет." }
                    a.button.primary href="/admin/products/new" { "Создать первый" }
                }
            } @else {
                div.table-wrap {
                    table.products {
                        thead {
                            tr {
                                th { "Название" } th { "Тип" } th.num { "№ ключа" }
                                th.num { "Видео" } th.num { "Цена" } th.num { "Продажи" } th { "Статус" }
                            }
                        }
                        tbody {
                            @for s in &items {
                                @let p = &s.product;
                                tr.clickable {
                                    td {
                                        a.product-cell href=(editor_url(&p.id)) {
                                            (cover_thumb(&state.media, p, now, 40))
                                            span {
                                                strong { (p.title) }
                                                @if !p.subtitle.is_empty() { br; span.muted { (p.subtitle) } }
                                            }
                                        }
                                    }
                                    td { (p.product_type().label()) }
                                    td.num { (p.activation_number) }
                                    td.num.warn[s.video_count < s.lesson_count] {
                                        (s.video_count) " / " (s.lesson_count)
                                    }
                                    td.num {
                                        @if let Some(price) = p.price_somoni { (format_money(price)) } @else { "—" }
                                    }
                                    td.num { (s.activation_count) }
                                    td { (layout::status_badge(p.is_published)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    };
    Ok(layout::page(
        &state.config.school_name,
        "Продукты",
        Nav::Products,
        body,
    ))
}

fn cover_thumb(media: &Media, p: &Product, now: i64, size: u32) -> Markup {
    html! {
        @if let Some(file) = &p.cover_file {
            img.thumb src=(media.url(MediaKind::Cover, file, now)) alt=""
                width=(size) height=(size) loading="lazy";
        } @else {
            span.thumb.thumb-empty style={ "width:" (size) "px;height:" (size) "px" } aria-hidden="true" {
                (layout::icon_guitar())
            }
        }
    }
}

// ---------------------------------------------------------------- создание

pub async fn new_page(_: AdminUser, State(state): State<AppState>) -> AdminResult<Markup> {
    let body = html! {
        header.page-header {
            div { a.back href="/admin/products" { "← Продукты" } h1 { "Новый продукт" } }
        }
        section.card.narrow {
            form.stack method="post" action="/admin/products" {
                (type_picker(ProductType::Course))
                label { "Название" input name="title" required maxlength="120" placeholder="Например: Гитара с нуля"; }
                p.muted {
                    "Продукт создастся черновиком: в приложении его не будет видно, пока вы не нажмёте «Опубликовать»."
                }
                button.primary type="submit" { "Создать" }
            }
        }
    };
    Ok(layout::page(
        &state.config.school_name,
        "Новый продукт",
        Nav::Products,
        body,
    ))
}

fn type_picker(current: ProductType) -> Markup {
    html! {
        fieldset.type-picker {
            legend { "Тип продукта" }
            @for t in ProductType::ALL {
                label.chip {
                    input type="radio" name="kind" value=(t.as_str()) checked[t == current] required;
                    span { (t.label()) }
                }
            }
        }
    }
}

#[derive(Deserialize)]
pub struct CreateForm {
    kind: String,
    title: String,
}

pub async fn create(
    _: AdminUser,
    State(state): State<AppState>,
    Form(f): Form<CreateForm>,
) -> AdminResult<Response> {
    let kind = ProductType::parse(&f.kind)
        .ok_or_else(|| AppError::BadRequest("выберите тип продукта".into()))?;
    let title = f.title.trim();
    if title.is_empty() {
        return Err(AppError::BadRequest("введите название".into()).into());
    }
    let id = repo::create_product(&state.db, kind.as_str(), title).await?;
    Ok(redirect_ok(&editor_url(&id), "created", ""))
}

// ---------------------------------------------------------------- редактор

pub async fn editor(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Query(flash): Query<Flash>,
) -> AdminResult<Markup> {
    let db = &state.db;
    let p = repo::get_product(db, &id).await?;
    let kind = p.product_type();
    let lessons = repo::lessons_of(db, &id).await?;
    let materials = repo::materials_of(db, &id).await?;
    let general: Vec<&Material> = materials.iter().filter(|m| m.lesson_id.is_none()).collect();
    let albums: Vec<Product> = if kind == ProductType::Single {
        repo::list_products(db, Some(ProductType::SongAlbum.as_str()))
            .await?
            .into_iter()
            .map(|s| s.product)
            .collect()
    } else {
        vec![]
    };
    let current_album = if kind == ProductType::Single {
        repo::unlocking_albums(db, &id)
            .await?
            .into_iter()
            .next()
            .map(|a| a.id)
    } else {
        None
    };
    let sold: i64 = repo::list_activations(
        db,
        &repo::ActivationFilter {
            product_id: Some(&id),
            ..Default::default()
        },
    )
    .await?
    .len() as i64;
    let now = media::now();
    let missing_video = lessons.iter().filter(|l| l.video_file.is_none()).count();
    let total_duration: i64 = lessons.iter().map(|l| l.duration_sec).sum();

    let body = html! {
        header.page-header {
            div {
                a.back href="/admin/products" { "← Продукты" }
                h1 { (p.title) " " (layout::status_badge(p.is_published)) }
            }
            div.actions {
                button.secondary type="submit" form="product-form" name="action" value="save" {
                    @if p.is_published { "Сохранить" } @else { "Сохранить черновик" }
                }
                @if p.is_published {
                    button.secondary type="submit" form="product-form" name="action" value="unpublish" {
                        "Снять с публикации"
                    }
                } @else {
                    button.primary type="submit" form="product-form" name="action" value="publish" {
                        "Опубликовать"
                    }
                }
            }
        }
        (layout::flash(flash.message()))
        @if let Some(err) = &flash.err { p.error role="alert" { (err) } }

        div.editor-grid {
            div.editor-main {
                section.card {
                    form #product-form method="post" action=(editor_url(&id)) {
                        (type_picker(kind))
                        label { "Название" input name="title" value=(p.title) required maxlength="120"; }
                        label {
                            "Короткое описание (1–2 строки)"
                            textarea name="subtitle" rows="2" maxlength="160" { (p.subtitle) }
                        }
                        div.row3 {
                            label {
                                "Цена, сомони"
                                input name="price" inputmode="numeric" pattern="[0-9]*"
                                    value=[p.price_somoni] placeholder="—";
                                span.hint { "для статистики и генератора; в приложении не показывается" }
                            }
                            label {
                                "Уровень"
                                select name="level" {
                                    @for l in Level::ALL {
                                        option value=(l.as_str()) selected[l == p.level()] { (l.label()) }
                                    }
                                }
                            }
                            div.readonly {
                                span.label { "Номер для ключей" }
                                strong { "№ " (p.activation_number) }
                                span.hint { "не меняется" }
                            }
                        }
                        @if kind == ProductType::Single {
                            label {
                                "Входит в альбом"
                                select name="album_id" {
                                    option value="" selected[current_album.is_none()] { "— не входит —" }
                                    @for a in &albums {
                                        option value=(a.id) selected[current_album.as_deref() == Some(a.id.as_str())] {
                                            (a.title)
                                        }
                                    }
                                }
                                span.hint { "ключ альбома откроет и эту песню" }
                            }
                        }
                    }
                }

                section.card #lessons {
                    div.section-head {
                        h2 { (kind.items_label()) " · " (lessons.len()) }
                        span.muted {
                            @if lessons.len() > 1 { "Перетащите, чтобы изменить порядок · " }
                            "всего " (format_duration(total_duration))
                        }
                    }
                    ol.lesson-list data-reorder-url={ "/admin/products/" (id) "/order" } {
                        @for l in &lessons {
                            @let pdfs: Vec<&Material> = materials.iter().filter(|m| m.lesson_id.as_deref() == Some(l.id.as_str())).collect();
                            li.lesson data-id=(l.id) id={ "lesson-" (l.id) } {
                                div.lesson-row {
                                    button.grip type="button" title="Перетащите или нажмите и используйте стрелки ↑↓" aria-label={ "Переместить урок " (l.position) } { (layout::icon_grip()) }
                                    span.lesson-num { (l.position) }
                                    form.lesson-form method="post" action={ "/admin/lessons/" (l.id) } {
                                        input name="title" value=(l.title) required maxlength="120" aria-label="Название";
                                        label.check {
                                            input type="checkbox" name="free" value="1" checked[l.is_free_preview];
                                            " бесплатно"
                                        }
                                        @if kind == ProductType::Single {
                                            label.inline {
                                                "превью, сек"
                                                input name="preview_limit" inputmode="numeric" size="3"
                                                    value=[l.preview_limit_sec];
                                            }
                                        }
                                        button.small.secondary type="submit" { "Сохранить" }
                                    }
                                }
                                div.lesson-media {
                                    div.video-state {
                                        @if l.video_file.is_some() {
                                            span.ok { "✓ Видео · " (format_duration(l.duration_sec)) }
                                            a href={ "/admin/preview/lesson/" (l.id) } target="_blank" rel="noopener" { "смотреть" }
                                        } @else {
                                            span.warn { "Нет видео" }
                                        }
                                    }
                                    form.upload data-upload method="post" action={ "/admin/lessons/" (l.id) "/video" } enctype="multipart/form-data" {
                                        input type="file" name="video" accept="video/*,.mp4,.mov,.m4v,.webm" required aria-label="Видео";
                                        button.small type="submit" {
                                            @if l.video_file.is_some() { "Заменить видео" } @else { "Загрузить видео" }
                                        }
                                        progress hidden max="100" value="0" {}
                                        span.upload-status role="status" {}
                                    }
                                    div.pdfs {
                                        @for m in &pdfs {
                                            span.pdf-chip {
                                                a href={ "/admin/preview/material/" (m.id) } target="_blank" rel="noopener" { "PDF · " (m.title) }
                                                form method="post" action={ "/admin/materials/" (m.id) "/delete" } data-confirm="Удалить этот PDF?" {
                                                    button.icon type="submit" aria-label="Удалить PDF" { "×" }
                                                }
                                            }
                                        }
                                        form.inline-upload method="post" action={ "/admin/products/" (id) "/materials" } enctype="multipart/form-data" {
                                            input type="hidden" name="lesson_id" value=(l.id);
                                            input type="file" name="file" accept="application/pdf,.pdf" required aria-label="PDF к уроку";
                                            button.small.secondary type="submit" { "Добавить PDF к уроку" }
                                        }
                                    }
                                    form method="post" action={ "/admin/lessons/" (l.id) "/delete" } data-confirm="Удалить урок вместе с видео?" {
                                        button.small.danger type="submit" { "Удалить урок" }
                                    }
                                }
                            }
                        }
                    }
                    form.add-lesson method="post" action={ "/admin/products/" (id) "/lessons" } {
                        input name="title" required maxlength="120" aria-label="Название нового урока"
                            placeholder={ "Название — например «" (lessons.len() + 1) ". Как держать гитару»" };
                        button.primary type="submit" {
                            @if kind == ProductType::Course { "Добавить урок" } @else { "Добавить песню" }
                        }
                    }
                }

                section.card #materials {
                    h2 { "PDF ко всему продукту · " (general.len()) }
                    p.muted {
                        "Показываются на странице курса в приложении (например, аккорды, схемы, упражнения). "
                        "PDF к конкретному уроку добавляйте в строке урока."
                    }
                    @if !general.is_empty() {
                        ul.file-list {
                            @for m in &general {
                                li {
                                    a href={ "/admin/preview/material/" (m.id) } target="_blank" rel="noopener" { (m.title) }
                                    form method="post" action={ "/admin/materials/" (m.id) "/delete" } data-confirm="Удалить этот PDF?" {
                                        button.small.danger type="submit" { "Удалить" }
                                    }
                                }
                            }
                        }
                    }
                    form.upload-row method="post" action={ "/admin/products/" (id) "/materials" } enctype="multipart/form-data" {
                        input name="title" maxlength="120" placeholder="Название (необязательно)" aria-label="Название PDF";
                        input type="file" name="file" accept="application/pdf,.pdf" required aria-label="PDF";
                        button.secondary type="submit" { "Загрузить PDF" }
                    }
                }

                section.card.danger-zone {
                    h2 { "Удаление" }
                    @if sold > 0 {
                        p.muted {
                            "По этому продукту выдано ключей: " (sold) ". Удалить его нельзя — ученики потеряют доступ. "
                            "Если продукт больше не нужен, снимите его с публикации."
                        }
                    } @else {
                        form method="post" action={ "/admin/products/" (id) "/delete" }
                            data-confirm="Удалить продукт со всеми уроками, видео и PDF? Это нельзя отменить." {
                            button.danger type="submit" { "Удалить продукт" }
                        }
                    }
                }
            }

            aside.editor-side {
                section.card {
                    h2 { "Обложка" }
                    div.cover-preview { (cover_thumb(&state.media, &p, now, 220)) }
                    form.stack method="post" action={ "/admin/products/" (id) "/cover" } enctype="multipart/form-data" {
                        input type="file" name="cover" accept="image/jpeg,image/png,image/webp" required aria-label="Обложка";
                        button.secondary type="submit" { "Загрузить обложку" }
                    }
                    p.hint { "Квадрат, от 1000×1000 px, JPG или PNG" }
                }
                section.card {
                    h2 { "Как в приложении" }
                    div.app-card {
                        (cover_thumb(&state.media, &p, now, 120))
                        div.app-card-title { (p.title) }
                        div.muted { (p.level().label()) " уровень · " (lessons.len()) " " (kind.items_label().to_lowercase()) }
                    }
                }
                section.card {
                    h2 { "Готовность" }
                    ul.checklist {
                        li.done[!p.title.is_empty()] { "Название" }
                        li.done[p.cover_file.is_some()] { "Обложка" }
                        li.done[!lessons.is_empty()] { (kind.items_label()) ": " (lessons.len()) }
                        li.done[!lessons.is_empty() && missing_video == 0] {
                            @if missing_video == 0 { "Видео у всех" } @else { "Нет видео: " (missing_video) }
                        }
                        li.done[lessons.iter().any(|l| l.is_free_preview || l.preview_limit_sec.is_some())] {
                            "Бесплатный урок"
                        }
                        li.done[!materials.is_empty()] { "PDF: " (materials.len()) }
                    }
                }
            }
        }
    };
    Ok(layout::page(
        &state.config.school_name,
        &p.title,
        Nav::Products,
        body,
    ))
}

#[derive(Deserialize)]
pub struct ProductForm {
    action: String,
    kind: String,
    title: String,
    #[serde(default)]
    subtitle: String,
    level: String,
    #[serde(default)]
    price: String,
    album_id: Option<String>,
}

pub async fn save(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Form(f): Form<ProductForm>,
) -> AdminResult<Response> {
    let url = editor_url(&id);
    match save_inner(&state, &id, &f).await {
        Ok(code) => Ok(redirect_ok(&url, code, "")),
        Err(AppError::BadRequest(m)) => Ok(redirect_err(&url, &AppError::BadRequest(m))),
        Err(e) => Err(e.into()),
    }
}

async fn save_inner(state: &AppState, id: &str, f: &ProductForm) -> Result<&'static str, AppError> {
    let db = &state.db;
    repo::get_product(db, id).await?;
    let kind =
        ProductType::parse(&f.kind).ok_or_else(|| AppError::BadRequest("выберите тип".into()))?;
    let level = Level::parse(&f.level).unwrap_or(Level::Beginner);
    let title = f.title.trim();
    if title.is_empty() {
        return Err(AppError::BadRequest("введите название".into()));
    }
    let price = match f.price.trim() {
        "" => None,
        s => Some(
            s.parse::<i64>()
                .ok()
                .filter(|p| *p >= 0)
                .ok_or_else(|| AppError::BadRequest("цена — целое число сомони".into()))?,
        ),
    };
    repo::update_product(
        db,
        id,
        &repo::ProductFields {
            kind: kind.as_str(),
            title,
            subtitle: f.subtitle.trim(),
            level: level.as_str(),
            price_somoni: price,
        },
    )
    .await?;
    if kind == ProductType::Single {
        let album = f.album_id.as_deref().filter(|a| !a.is_empty());
        repo::set_album_of_single(db, id, album).await?;
    }

    match f.action.as_str() {
        "publish" => {
            let lessons = repo::lessons_of(db, id).await?;
            if lessons.is_empty() {
                return Err(AppError::BadRequest(
                    "нельзя опубликовать без уроков — добавьте хотя бы один".into(),
                ));
            }
            let missing: Vec<String> = lessons
                .iter()
                .filter(|l| l.video_file.is_none())
                .map(|l| l.position.to_string())
                .collect();
            if !missing.is_empty() {
                return Err(AppError::BadRequest(format!(
                    "нельзя опубликовать: нет видео у уроков № {}",
                    missing.join(", ")
                )));
            }
            repo::set_published(db, id, true).await?;
            Ok("published")
        }
        "unpublish" => {
            repo::set_published(db, id, false).await?;
            Ok("unpublished")
        }
        _ => Ok("saved"),
    }
}

pub async fn delete(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> AdminResult<Response> {
    match repo::delete_product(&state.db, &id).await {
        Ok(files) => {
            if let Some(c) = files.cover {
                state.media.delete(MediaKind::Cover, &c).await;
            }
            for v in files.videos {
                state.media.delete(MediaKind::Video, &v).await;
            }
            for p in files.pdfs {
                state.media.delete(MediaKind::Pdf, &p).await;
            }
            Ok(redirect_ok("/admin/products", "deleted", ""))
        }
        Err(e @ AppError::Conflict(_)) => Ok(redirect_err(&editor_url(&id), &e)),
        Err(e) => Err(e.into()),
    }
}

// ---------------------------------------------------------------- загрузки

/// Разбирает форму: файл (поле `file_field`) пишется на диск сразу,
/// остальные поля — в словарь. Возвращает (имя файла на сервере, исходное имя, поля).
async fn read_upload(
    state: &AppState,
    mut multipart: Multipart,
    file_field: &str,
    kind: MediaKind,
) -> Result<(String, String, HashMap<String, String>), AppError> {
    let mut saved: Option<(String, String)> = None;
    let mut fields = HashMap::new();
    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(format!("форма: {e}")))?
    {
        let name = field.name().unwrap_or_default().to_owned();
        if name == file_field {
            let original = field.file_name().unwrap_or_default().to_owned();
            let file = Media::new_file_name(kind, &original)?;
            state.media.save_field(kind, &file, field).await?;
            saved = Some((file, original));
        } else {
            let value = field
                .text()
                .await
                .map_err(|e| AppError::BadRequest(format!("форма: {e}")))?;
            fields.insert(name, value);
        }
    }
    let (file, original) = saved.ok_or_else(|| AppError::BadRequest("выберите файл".into()))?;
    Ok((file, original, fields))
}

pub async fn upload_cover(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    multipart: Multipart,
) -> AdminResult<Response> {
    let url = editor_url(&id);
    repo::get_product(&state.db, &id).await?;
    let (file, _, _) = match read_upload(&state, multipart, "cover", MediaKind::Cover).await {
        Ok(v) => v,
        Err(e @ AppError::BadRequest(_)) => return Ok(redirect_err(&url, &e)),
        Err(e) => return Err(e.into()),
    };
    if let Some(old) = repo::set_cover(&state.db, &id, &file).await? {
        state.media.delete(MediaKind::Cover, &old).await;
    }
    Ok(redirect_ok(&url, "cover", ""))
}

#[derive(Serialize)]
pub struct UploadResult {
    ok: bool,
    duration: String,
}

/// Загрузка видео урока (из admin.js с полосой прогресса). Отвечает JSON.
/// Длительность присылает браузер — он читает её из файла до отправки.
pub async fn upload_video(
    _: AdminUser,
    State(state): State<AppState>,
    Path(lesson_id): Path<String>,
    multipart: Multipart,
) -> Result<Json<UploadResult>, AppError> {
    repo::get_lesson(&state.db, &lesson_id).await?;
    let (file, _, fields) = read_upload(&state, multipart, "video", MediaKind::Video).await?;
    let duration = fields
        .get("duration")
        .and_then(|d| d.parse::<f64>().ok())
        .filter(|d| d.is_finite() && *d >= 0.0)
        .map_or(0, |d| d.round() as i64);
    if let Some(old) = repo::set_lesson_video(&state.db, &lesson_id, &file, duration).await? {
        state.media.delete(MediaKind::Video, &old).await;
    }
    Ok(Json(UploadResult {
        ok: true,
        duration: format_duration(duration),
    }))
}

pub async fn add_material(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    multipart: Multipart,
) -> AdminResult<Response> {
    let url = editor_url(&id);
    repo::get_product(&state.db, &id).await?;
    let (file, original, fields) =
        match read_upload(&state, multipart, "file", MediaKind::Pdf).await {
            Ok(v) => v,
            Err(e @ AppError::BadRequest(_)) => return Ok(redirect_err(&url, &e)),
            Err(e) => return Err(e.into()),
        };
    let lesson_id = fields
        .get("lesson_id")
        .map(String::as_str)
        .filter(|s| !s.is_empty());
    let title = fields
        .get("title")
        .map(|t| t.trim().to_owned())
        .filter(|t| !t.is_empty())
        .unwrap_or_else(|| {
            std::path::Path::new(&original)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("PDF")
                .to_owned()
        });
    if let Err(e) = repo::add_material(&state.db, &id, lesson_id, &title, &file).await {
        state.media.delete(MediaKind::Pdf, &file).await;
        return Err(e.into());
    }
    let anchor = lesson_id.map_or_else(|| "#materials".to_owned(), |l| format!("#lesson-{l}"));
    Ok(redirect_ok(&url, "pdf", &anchor))
}

pub async fn delete_material(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> AdminResult<Response> {
    let (product_id, file) = repo::delete_material(&state.db, &id).await?;
    state.media.delete(MediaKind::Pdf, &file).await;
    Ok(redirect_ok(
        &editor_url(&product_id),
        "pdf_deleted",
        "#materials",
    ))
}

// ---------------------------------------------------------------- уроки

#[derive(Deserialize)]
pub struct TitleForm {
    title: String,
}

pub async fn add_lesson(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Form(f): Form<TitleForm>,
) -> AdminResult<Response> {
    repo::get_product(&state.db, &id).await?;
    let title = f.title.trim();
    if title.is_empty() {
        return Ok(redirect_err(
            &editor_url(&id),
            &AppError::BadRequest("введите название урока".into()),
        ));
    }
    let lesson_id = repo::add_lesson(&state.db, &id, title).await?;
    Ok(redirect_ok(
        &editor_url(&id),
        "lesson",
        &format!("#lesson-{lesson_id}"),
    ))
}

#[derive(Deserialize)]
pub struct LessonForm {
    title: String,
    free: Option<String>,
    preview_limit: Option<String>,
}

pub async fn save_lesson(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Form(f): Form<LessonForm>,
) -> AdminResult<Response> {
    let lesson = repo::get_lesson(&state.db, &id).await?;
    let url = editor_url(&lesson.product_id);
    let title = f.title.trim();
    if title.is_empty() {
        return Ok(redirect_err(
            &url,
            &AppError::BadRequest("название урока не может быть пустым".into()),
        ));
    }
    let preview_limit = match f.preview_limit.as_deref().map(str::trim) {
        None | Some("") => None,
        Some(s) => match s.parse::<i64>() {
            Ok(n) if (5..=600).contains(&n) => Some(n),
            _ => {
                return Ok(redirect_err(
                    &url,
                    &AppError::BadRequest("превью — от 5 до 600 секунд".into()),
                ));
            }
        },
    };
    repo::update_lesson(&state.db, &id, title, f.free.is_some(), preview_limit).await?;
    Ok(redirect_ok(&url, "lesson_saved", &format!("#lesson-{id}")))
}

pub async fn delete_lesson(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> AdminResult<Response> {
    let (product_id, video) = repo::delete_lesson(&state.db, &id).await?;
    if let Some(v) = video {
        state.media.delete(MediaKind::Video, &v).await;
    }
    Ok(redirect_ok(
        &editor_url(&product_id),
        "lesson_deleted",
        "#lessons",
    ))
}

/// Новый порядок уроков после перетаскивания (JSON-массив id).
pub async fn reorder(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(ids): Json<Vec<String>>,
) -> Result<Json<serde_json::Value>, AppError> {
    repo::reorder_lessons(&state.db, &id, &ids).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

/// Просмотр загруженного видео или PDF из админки — по временной ссылке.
pub async fn preview(
    _: AdminUser,
    State(state): State<AppState>,
    Path((kind, id)): Path<(String, String)>,
) -> AdminResult<Response> {
    let now = media::now();
    let url = match kind.as_str() {
        "lesson" => {
            let lesson = repo::get_lesson(&state.db, &id).await?;
            let file = lesson.video_file.ok_or(AppError::NotFound)?;
            state.media.url(MediaKind::Video, &file, now)
        }
        "material" => {
            let m = repo::get_material(&state.db, &id).await?;
            state.media.url(MediaKind::Pdf, &m.file, now)
        }
        _ => return Err(AppError::NotFound.into()),
    };
    Ok(Redirect::to(&url).into_response())
}
