//! Ключи: генератор (ID-код ученика + продукт → ключ), журнал продаж, выгрузка в Excel.

use axum::{
    Form,
    extract::{Path, Query, State},
    http::header,
    response::{IntoResponse, Redirect, Response},
};
use chrono::{Duration, Utc};
use maud::{Markup, html};
use serde::Deserialize;

use super::{
    AdminResult, AdminUser,
    layout::{self, Nav},
};
use crate::{
    activation,
    error::AppError,
    models::{ActivationRow, format_money},
    repo,
    state::AppState,
};

#[derive(Deserialize, Default)]
pub struct KeysQuery {
    q: Option<String>,
    product: Option<String>,
    period: Option<String>,
    created: Option<String>,
    err: Option<String>,
    ok: Option<String>,
}

impl KeysQuery {
    fn since(&self) -> Option<String> {
        let days = match self.period.as_deref() {
            Some("week") => 7,
            Some("month") => 30,
            Some("year") => 365,
            _ => return None,
        };
        Some(
            (Utc::now() - Duration::days(days))
                .format("%Y-%m-%dT%H:%M:%SZ")
                .to_string(),
        )
    }

    fn filter_query(&self) -> String {
        let pairs: Vec<(&str, &str)> = [
            ("q", self.q.as_deref()),
            ("product", self.product.as_deref()),
            ("period", self.period.as_deref()),
        ]
        .into_iter()
        .filter_map(|(k, v)| v.filter(|v| !v.is_empty()).map(|v| (k, v)))
        .collect();
        serde_urlencoded::to_string(pairs).unwrap_or_default()
    }
}

async fn rows(state: &AppState, q: &KeysQuery) -> Result<Vec<ActivationRow>, AppError> {
    let since = q.since();
    repo::list_activations(
        &state.db,
        &repo::ActivationFilter {
            query: q.q.as_deref().filter(|s| !s.trim().is_empty()),
            product_id: q.product.as_deref().filter(|s| !s.is_empty()),
            since: since.as_deref(),
            limit: None,
        },
    )
    .await
}

/// Текст для ученика — тот же, что отправляет генератор на телефоне.
fn message(row: &ActivationRow) -> String {
    format!(
        "Код активации курса «{}»: {}\nВ приложении: «Активировать курс» → поле «Код активации».",
        row.product_title, row.activation_key
    )
}

/// Ссылка «Отправить в WhatsApp»: если в поле «Ученик» есть номер — сразу в его чат.
fn whatsapp_link(row: &ActivationRow) -> String {
    let digits: String = row.student.chars().filter(char::is_ascii_digit).collect();
    let text = serde_urlencoded::to_string([("text", message(row))]).unwrap_or_default();
    if digits.len() >= 9 {
        format!("https://wa.me/{digits}?{text}")
    } else {
        format!("https://wa.me/?{text}")
    }
}

pub async fn page(
    _: AdminUser,
    State(state): State<AppState>,
    Query(q): Query<KeysQuery>,
) -> AdminResult<Markup> {
    let products: Vec<_> = repo::list_products(&state.db, None)
        .await?
        .into_iter()
        .map(|s| s.product)
        .collect();
    let created = match q.created.as_deref() {
        Some(id) => repo::get_activation(&state.db, id).await.ok(),
        None => None,
    };
    let list = rows(&state, &q).await?;
    let total: i64 = list.iter().filter_map(|r| r.amount_somoni).sum();
    let filter = q.filter_query();
    let csv_href = if filter.is_empty() {
        "/admin/keys.csv".to_owned()
    } else {
        format!("/admin/keys.csv?{filter}")
    };

    let body = html! {
        header.page-header {
            div { h1 { "Ключи" } p.muted { "Ученик присылает ID-код из приложения — вы создаёте ключ и отправляете ему" } }
        }
        @if q.ok.as_deref() == Some("deleted") { p.flash role="status" { "Запись удалена" } }
        @if let Some(err) = &q.err { p.error role="alert" { (err) } }

        @if let Some(row) = &created {
            section.card.key-result {
                div.muted { "Ключ · " (row.product_title) " · ID-код " code { (row.device_code) } }
                div.key-value data-copy-source { (row.activation_key) }
                div.key-calc.muted {
                    @let sum = activation::weighted_sum(&row.device_code).unwrap_or(0);
                    "Сумма «цифра × место»: " (sum) " · "
                    (sum) " × (" (row.activation_number) " + " (activation::KEY_COURSE_OFFSET) ") + "
                    (activation::KEY_SECRET) " = " (activation::key_number(&row.device_code, row.activation_number as u64).unwrap_or(0))
                }
                div.actions {
                    a.button.primary href=(whatsapp_link(row)) target="_blank" rel="noopener" { "Отправить в WhatsApp" }
                    button.secondary type="button" data-copy=(row.activation_key) { "Скопировать ключ" }
                    button.secondary type="button" data-copy=(message(row)) { "Скопировать сообщение" }
                }
            }
        }

        div.grid-2.keys-grid {
            section.card {
                h2 { "Новый ключ" }
                @if products.is_empty() {
                    p.muted { "Сначала создайте продукт в разделе " a href="/admin/products" { "«Продукты»" } "." }
                } @else {
                    form.stack method="post" action="/admin/keys" {
                        label {
                            "ID-код ученика"
                            input name="device_code" inputmode="numeric" required autocomplete="off"
                                placeholder="17 цифр из приложения" data-device-code;
                        }
                        label {
                            "Продукт"
                            select name="product_id" required data-product-select {
                                @for p in &products {
                                    option value=(p.id) data-price=[p.price_somoni] {
                                        "№ " (p.activation_number) " · " (p.title)
                                        @if !p.is_published { " (черновик)" }
                                    }
                                }
                            }
                        }
                        label {
                            "Ученик"
                            input name="student" maxlength="120" placeholder="Имя и телефон, например: Фарход +992 90 123 45 67";
                            span.hint { "если указать телефон — «Отправить в WhatsApp» откроет его чат" }
                        }
                        label {
                            "Сумма, сомони"
                            input name="amount" inputmode="numeric" pattern="[0-9]*" data-amount;
                            span.hint { "для статистики; по умолчанию — цена продукта" }
                        }
                        button.primary type="submit" { "Создать ключ" }
                        p.hint {
                            "Ключи, сделанные в генераторе на телефоне, сюда не попадают — "
                            "чтобы они были в статистике, внесите продажу этой же формой (ключ получится тот же)."
                        }
                    }
                }
            }
            section.card {
                h2 { "Найти" }
                form.stack method="get" action="/admin/keys" {
                    label { "Поиск" input name="q" value=[q.q.as_deref()] placeholder="ученик, ID-код или ключ"; }
                    label {
                        "Продукт"
                        select name="product" {
                            option value="" { "Все продукты" }
                            @for p in &products {
                                option value=(p.id) selected[q.product.as_deref() == Some(p.id.as_str())] { (p.title) }
                            }
                        }
                    }
                    label {
                        "Период"
                        select name="period" {
                            @for (v, l) in [("", "За всё время"), ("week", "Неделя"), ("month", "Месяц"), ("year", "Год")] {
                                option value=(v) selected[q.period.as_deref().unwrap_or("") == v] { (l) }
                            }
                        }
                    }
                    div.actions {
                        button.secondary type="submit" { "Показать" }
                        a.button.ghost href="/admin/keys" { "Сбросить" }
                    }
                }
            }
        }

        section.card {
            div.section-head {
                h2 { "Журнал · " (list.len()) " · " (format_money(total)) " сомони" }
                a.button.secondary href=(csv_href) { "Скачать для Excel" }
            }
            @if list.is_empty() {
                p.muted { "Записей нет." }
            } @else {
                div.table-wrap {
                    table {
                        thead {
                            tr {
                                th { "Дата" } th { "Ученик" } th { "Продукт" } th { "ID-код" }
                                th { "Ключ" } th.num { "Сумма" } th {}
                            }
                        }
                        tbody {
                            @for r in &list {
                                tr {
                                    td.nowrap { (layout::format_date(&r.created_at)) }
                                    td { @if r.student.is_empty() { span.muted { "—" } } @else { (r.student) } }
                                    td { (r.product_title) }
                                    td { code { (r.device_code) } }
                                    td {
                                        code { (r.activation_key) }
                                        " "
                                        button.icon type="button" data-copy=(r.activation_key) aria-label="Скопировать ключ" { "⧉" }
                                    }
                                    td.num { @if let Some(a) = r.amount_somoni { (format_money(a)) } @else { "—" } }
                                    td {
                                        form method="post" action={ "/admin/keys/" (r.id) "/delete" }
                                            data-confirm="Удалить запись? Ключ у ученика продолжит работать — запись нужна только для статистики." {
                                            button.icon type="submit" aria-label="Удалить запись" { "×" }
                                        }
                                    }
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
        "Ключи",
        Nav::Keys,
        body,
    ))
}

#[derive(Deserialize)]
pub struct CreateKeyForm {
    device_code: String,
    product_id: String,
    #[serde(default)]
    student: String,
    #[serde(default)]
    amount: String,
}

pub async fn create(
    _: AdminUser,
    State(state): State<AppState>,
    Form(f): Form<CreateKeyForm>,
) -> AdminResult<Response> {
    let fail = |m: &str| {
        let q = serde_urlencoded::to_string([("err", m)]).unwrap_or_default();
        Ok(Redirect::to(&format!("/admin/keys?{q}")).into_response())
    };
    let code: String = f.device_code.chars().filter(char::is_ascii_digit).collect();
    if code.is_empty() {
        return fail("введите ID-код ученика — только цифры");
    }
    let Ok(product) = repo::get_product(&state.db, &f.product_id).await else {
        return fail("выберите продукт");
    };
    let amount = match f.amount.trim() {
        "" => product.price_somoni,
        s => match s.parse::<i64>() {
            Ok(n) if n >= 0 => Some(n),
            _ => return fail("сумма — целое число сомони"),
        },
    };
    let key = activation::expected_key(&code, product.activation_number as u64)
        .ok_or_else(|| AppError::BadRequest("неверный ID-код".into()))?;
    let id = repo::add_activation(
        &state.db,
        &repo::NewActivation {
            product_id: &product.id,
            device_code: &code,
            activation_key: &key,
            student: f.student.trim(),
            amount_somoni: amount,
        },
    )
    .await?;
    Ok(Redirect::to(&format!("/admin/keys?created={id}")).into_response())
}

pub async fn delete(
    _: AdminUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> AdminResult<Response> {
    repo::delete_activation(&state.db, &id).await?;
    Ok(Redirect::to("/admin/keys?ok=deleted").into_response())
}

/// Поле CSV: кавычки при необходимости и защита от формул Excel.
fn csv_field(value: &str) -> String {
    let mut v = value.to_owned();
    if v.starts_with(['=', '+', '-', '@']) {
        v.insert(0, '\'');
    }
    if v.contains([';', '"', '\n', '\r']) {
        format!("\"{}\"", v.replace('"', "\"\""))
    } else {
        v
    }
}

/// `GET /admin/keys.csv` — с теми же фильтрами, что на странице.
/// UTF-8 с BOM и «;» — так Excel сразу открывает кириллицу по столбцам.
pub async fn export_csv(
    _: AdminUser,
    State(state): State<AppState>,
    Query(q): Query<KeysQuery>,
) -> AdminResult<Response> {
    let list = rows(&state, &q).await?;
    let mut out =
        String::from("\u{FEFF}Дата;Ученик;Продукт;Номер продукта;ID-код;Ключ;Сумма, сомони\r\n");
    for r in &list {
        let line = [
            layout::format_date(&r.created_at),
            r.student.clone(),
            r.product_title.clone(),
            r.activation_number.to_string(),
            r.device_code.clone(),
            r.activation_key.clone(),
            r.amount_somoni.map(|a| a.to_string()).unwrap_or_default(),
        ]
        .iter()
        .map(|f| csv_field(f))
        .collect::<Vec<_>>()
        .join(";");
        out.push_str(&line);
        out.push_str("\r\n");
    }
    let filename = format!("keys-{}.csv", Utc::now().format("%Y-%m-%d"));
    Ok((
        [
            (header::CONTENT_TYPE, "text/csv; charset=utf-8".to_owned()),
            (
                header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{filename}\""),
            ),
        ],
        out,
    )
        .into_response())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn csv_escaping() {
        assert_eq!(csv_field("просто"), "просто");
        assert_eq!(csv_field("a;b"), "\"a;b\"");
        assert_eq!(csv_field("say \"hi\""), "\"say \"\"hi\"\"\"");
        assert_eq!(csv_field("=HYPERLINK()"), "'=HYPERLINK()");
    }

    #[test]
    fn whatsapp_uses_phone_from_student_field() {
        let row = ActivationRow {
            id: "1".into(),
            product_id: "p".into(),
            product_title: "Гитара с нуля".into(),
            activation_number: 1,
            device_code: "14140235536843855".into(),
            activation_key: "4D8H5E3C".into(),
            student: "Фарход +992 90 123 45 67".into(),
            amount_somoni: Some(150),
            created_at: "2026-10-12T10:00:00Z".into(),
        };
        let link = whatsapp_link(&row);
        assert!(link.starts_with("https://wa.me/992901234567?text="));
        assert!(link.contains("4D8H5E3C"));

        let anonymous = ActivationRow {
            student: "Фарход".into(),
            ..row
        };
        assert!(whatsapp_link(&anonymous).starts_with("https://wa.me/?text="));
    }
}
