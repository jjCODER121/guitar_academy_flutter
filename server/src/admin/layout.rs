use maud::{DOCTYPE, Markup, PreEscaped, html};

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Nav {
    Dashboard,
    Products,
    Keys,
}

fn head(title: &str) -> Markup {
    html! {
        head {
            meta charset="utf-8";
            meta name="viewport" content="width=device-width, initial-scale=1";
            meta name="robots" content="noindex";
            title { (title) " · Админ-панель" }
            link rel="preconnect" href="https://fonts.googleapis.com";
            link rel="preconnect" href="https://fonts.gstatic.com" crossorigin;
            link rel="stylesheet"
                href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&display=swap";
            link rel="stylesheet" href="/admin/static/tokens.css";
            link rel="stylesheet" href="/admin/static/admin.css";
            script src="/admin/static/admin.js" defer {}
        }
    }
}

/// Страница без меню: вход, ошибки.
pub fn bare(title: &str, body: Markup) -> Markup {
    html! {
        (DOCTYPE)
        html lang="ru" {
            (head(title))
            body { (body) }
        }
    }
}

/// Страница админки с боковым меню.
pub fn page(school: &str, title: &str, active: Nav, body: Markup) -> Markup {
    let link = |nav: Nav, href: &str, label: &str, icon: Markup| {
        html! {
            a.nav-link.active[nav == active] href=(href)
                aria-current=[(nav == active).then_some("page")] {
                (icon) span { (label) }
            }
        }
    };
    html! {
        (DOCTYPE)
        html lang="ru" {
            (head(title))
            body.admin {
                aside.sidebar {
                    div.brand {
                        div.brand-logo aria-hidden="true" { (icon_guitar()) }
                        div {
                            div.brand-name { (school) }
                            div.brand-sub { "Админ-панель" }
                        }
                    }
                    nav {
                        (link(Nav::Dashboard, "/admin", "Обзор", icon_chart()))
                        (link(Nav::Products, "/admin/products", "Продукты", icon_music()))
                        (link(Nav::Keys, "/admin/keys", "Ключи", icon_key()))
                    }
                    form.logout method="post" action="/admin/logout" {
                        button.ghost type="submit" { "Выйти" }
                    }
                }
                main.content { (body) }
            }
        }
    }
}

fn svg(paths: &str) -> Markup {
    PreEscaped(format!(
        r#"<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{paths}</svg>"#
    ))
}

pub fn icon_guitar() -> Markup {
    svg(
        r#"<path d="m11.9 12.1 4.514-4.514"/><path d="M20.1 2.3a1 1 0 0 0-1.4 0l-1.114 1.114A2 2 0 0 0 17 4.828v1.344a2 2 0 0 1-.586 1.414A2 2 0 0 1 17.828 7h1.344a2 2 0 0 0 1.414-.586L21.7 5.3a1 1 0 0 0 0-1.4z"/><path d="m6 16 2 2"/><path d="M8.23 9.85A3 3 0 0 1 11 8a5 5 0 0 1 5 5 3 3 0 0 1-1.85 2.77l-.92.38A2 2 0 0 0 12 18a4 4 0 0 1-4 4 6 6 0 0 1-6-6 4 4 0 0 1 4-4 2 2 0 0 0 1.85-1.23z"/>"#,
    )
}

fn icon_chart() -> Markup {
    svg(
        r#"<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/>"#,
    )
}

fn icon_music() -> Markup {
    svg(
        r#"<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>"#,
    )
}

fn icon_key() -> Markup {
    svg(
        r#"<path d="m15.5 7.5 2.3 2.3a1 1 0 0 0 1.4 0l2.1-2.1a1 1 0 0 0 0-1.4L19 4"/><path d="m21 2-9.6 9.6"/><circle cx="7.5" cy="15.5" r="5.5"/>"#,
    )
}

pub fn icon_grip() -> Markup {
    svg(
        r#"<circle cx="9" cy="6" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="9" cy="18" r="1"/><circle cx="15" cy="6" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="15" cy="18" r="1"/>"#,
    )
}

/// Уведомление вверху страницы («Сохранено»).
pub fn flash(message: Option<&str>) -> Markup {
    html! {
        @if let Some(m) = message {
            p.flash role="status" { (m) }
        }
    }
}

pub fn status_badge(published: bool) -> Markup {
    html! {
        @if published {
            span.badge.badge-success { "Опубликован" }
        } @else {
            span.badge { "Черновик" }
        }
    }
}

/// «2026-10-12T10:31:00Z» → «12.10.2026 10:31» (время UTC+5 — Душанбе).
pub fn format_date(iso: &str) -> String {
    chrono::DateTime::parse_from_rfc3339(iso)
        .map(|d| {
            d.with_timezone(&chrono::FixedOffset::east_opt(5 * 3600).expect("valid offset"))
                .format("%d.%m.%Y %H:%M")
                .to_string()
        })
        .unwrap_or_else(|_| iso.to_owned())
}

pub fn month_name(yyyy_mm: &str) -> &'static str {
    const NAMES: [&str; 12] = [
        "янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек",
    ];
    yyyy_mm
        .get(5..7)
        .and_then(|m| m.parse::<usize>().ok())
        .and_then(|m| NAMES.get(m.wrapping_sub(1)))
        .copied()
        .unwrap_or("")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dates_and_months() {
        assert_eq!(format_date("2026-10-12T10:31:00Z"), "12.10.2026 15:31");
        assert_eq!(month_name("2026-10"), "окт");
        assert_eq!(month_name("2026-01"), "янв");
        assert_eq!(month_name("bad"), "");
    }
}
