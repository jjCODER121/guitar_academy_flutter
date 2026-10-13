use axum::extract::{Query, State};
use chrono::{Datelike, Duration, Utc};
use maud::{Markup, html};
use serde::Deserialize;

use super::{
    AdminResult, AdminUser,
    layout::{self, Nav},
};
use crate::{models::format_money, repo, state::AppState};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Period {
    Week,
    Month,
    Year,
}

impl Period {
    fn parse(s: Option<&str>) -> Self {
        match s {
            Some("week") => Self::Week,
            Some("year") => Self::Year,
            _ => Self::Month,
        }
    }

    fn days(self) -> i64 {
        match self {
            Self::Week => 7,
            Self::Month => 30,
            Self::Year => 365,
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Week => "week",
            Self::Month => "month",
            Self::Year => "year",
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::Week => "Неделя",
            Self::Month => "Месяц",
            Self::Year => "Год",
        }
    }

    fn caption(self) -> &'static str {
        match self {
            Self::Week => "за 7 дней",
            Self::Month => "за 30 дней",
            Self::Year => "за год",
        }
    }
}

#[derive(Deserialize)]
pub struct DashboardQuery {
    period: Option<String>,
}

/// `GET /admin` — обзор: активации, выручка, график, лучшие продукты, последние ключи.
pub async fn page(
    _: AdminUser,
    State(state): State<AppState>,
    Query(q): Query<DashboardQuery>,
) -> AdminResult<Markup> {
    let period = Period::parse(q.period.as_deref());
    let since = (Utc::now() - Duration::days(period.days()))
        .format("%Y-%m-%dT%H:%M:%SZ")
        .to_string();
    let db = &state.db;

    let in_period = repo::totals(db, Some(&since)).await?;
    let all_time = repo::totals(db, None).await?;
    let top = repo::top_products(db, Some(&since), 5).await?;
    let recent = repo::list_activations(
        db,
        &repo::ActivationFilter {
            limit: Some(8),
            ..Default::default()
        },
    )
    .await?;

    // Последние 6 месяцев, включая текущий, — даже пустые.
    let today = Utc::now().date_naive();
    let months: Vec<String> = (0..6)
        .rev()
        .map(|back| {
            let total = today.year() * 12 + today.month0() as i32 - back;
            format!("{:04}-{:02}", total / 12, total % 12 + 1)
        })
        .collect();
    let revenue = repo::monthly_revenue(db, &months[0]).await?;
    let bars: Vec<(String, i64)> = months
        .iter()
        .map(|m| {
            let v = revenue.iter().find(|(k, _)| k == m).map_or(0, |(_, v)| *v);
            (m.clone(), v)
        })
        .collect();
    let max_bar = bars.iter().map(|(_, v)| *v).max().unwrap_or(0).max(1);
    let max_top = top.first().map_or(1, |(_, n, _)| (*n).max(1));

    let body = html! {
        header.page-header {
            div { h1 { "Обзор" } p.muted { "Продажи по выданным ключам" } }
            nav.segmented aria-label="Период" {
                @for p in [Period::Week, Period::Month, Period::Year] {
                    a.active[p == period] href={ "/admin?period=" (p.as_str()) } { (p.label()) }
                }
            }
        }
        section.kpis {
            div.card.kpi {
                div.kpi-label { "Продажи" }
                div.kpi-value { (in_period.activations) }
                div.kpi-note { (period.caption()) }
            }
            div.card.kpi {
                div.kpi-label { "Выручка" }
                div.kpi-value { (format_money(in_period.revenue)) " " span { "сомони" } }
                div.kpi-note { (period.caption()) }
            }
            div.card.kpi {
                div.kpi-label { "Ученики" }
                div.kpi-value { (in_period.students) }
                div.kpi-note { "разных телефонов " (period.caption()) }
            }
            div.card.kpi {
                div.kpi-label { "Всего продаж" }
                div.kpi-value { (all_time.activations) }
                div.kpi-note { (format_money(all_time.revenue)) " сомони за всё время" }
            }
        }
        div.grid-2 {
            section.card {
                div.section-head { h2 { "Выручка по месяцам" } span.muted { "сомони" } }
                div.bars role="img" aria-label="Выручка за последние 6 месяцев" {
                    @for (month, value) in &bars {
                        div.bar-col {
                            div.bar-value { (format_money(*value)) }
                            div.bar style={ "height:" (value * 100 / max_bar) "%" } {}
                            div.bar-label { (layout::month_name(month)) }
                        }
                    }
                }
            }
            section.card {
                h2 { "Лучшие продукты" }
                @if top.is_empty() {
                    p.muted { "Пока нет продаж " (period.caption()) "." }
                }
                @for (title, n, sum) in &top {
                    div.top-row {
                        div.top-text {
                            div.top-title { (title) }
                            div.muted { (n) " продаж · " (format_money(*sum)) " сомони" }
                        }
                        div.meter { div style={ "width:" (n * 100 / max_top) "%" } {} }
                    }
                }
            }
        }
        section.card {
            div.section-head {
                h2 { "Последние ключи" }
                a href="/admin/keys" { "Все ключи →" }
            }
            @if recent.is_empty() {
                p.muted {
                    "Ключей ещё нет. Создайте первый в разделе "
                    a href="/admin/keys" { "«Ключи»" } "."
                }
            } @else {
                div.table-wrap {
                    table {
                        thead { tr { th { "Дата" } th { "Ученик" } th { "Продукт" } th.num { "Сумма" } } }
                        tbody {
                            @for a in &recent {
                                tr {
                                    td.nowrap { (layout::format_date(&a.created_at)) }
                                    td { @if a.student.is_empty() { span.muted { "—" } } @else { (a.student) } }
                                    td { (a.product_title) }
                                    td.num { @if let Some(s) = a.amount_somoni { (format_money(s)) } @else { "—" } }
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
        "Обзор",
        Nav::Dashboard,
        body,
    ))
}
