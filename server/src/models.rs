use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProductType {
    Course,
    SongAlbum,
    Single,
}

impl ProductType {
    pub const ALL: [Self; 3] = [Self::Course, Self::SongAlbum, Self::Single];

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Course => "course",
            Self::SongAlbum => "song_album",
            Self::Single => "single",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|t| t.as_str() == s)
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Course => "Курс",
            Self::SongAlbum => "Альбом песен",
            Self::Single => "Отдельная песня",
        }
    }

    /// Как называются элементы продукта в редакторе.
    pub fn items_label(self) -> &'static str {
        match self {
            Self::Course => "Уроки",
            Self::SongAlbum | Self::Single => "Песни",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Level {
    Beginner,
    Intermediate,
    Advanced,
}

impl Level {
    pub const ALL: [Self; 3] = [Self::Beginner, Self::Intermediate, Self::Advanced];

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Beginner => "beginner",
            Self::Intermediate => "intermediate",
            Self::Advanced => "advanced",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|l| l.as_str() == s)
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Beginner => "Начальный",
            Self::Intermediate => "Средний",
            Self::Advanced => "Продвинутый",
        }
    }
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Product {
    pub id: String,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub title: String,
    pub subtitle: String,
    pub level: String,
    pub price_somoni: Option<i64>,
    pub activation_number: i64,
    pub cover_file: Option<String>,
    pub is_published: bool,
    pub sort_order: i64,
    pub created_at: String,
    pub updated_at: String,
}

impl Product {
    pub fn product_type(&self) -> ProductType {
        ProductType::parse(&self.kind).unwrap_or(ProductType::Course)
    }

    pub fn level(&self) -> Level {
        Level::parse(&self.level).unwrap_or(Level::Beginner)
    }
}

/// Строка таблицы «Продукты».
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct ProductSummary {
    #[sqlx(flatten)]
    pub product: Product,
    pub lesson_count: i64,
    pub video_count: i64,
    pub activation_count: i64,
}

#[derive(Debug, Clone, sqlx::FromRow, Serialize)]
pub struct Lesson {
    pub id: String,
    pub product_id: String,
    pub position: i64,
    pub title: String,
    pub duration_sec: i64,
    pub video_file: Option<String>,
    pub is_free_preview: bool,
    pub preview_limit_sec: Option<i64>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Material {
    pub id: String,
    pub product_id: String,
    pub lesson_id: Option<String>,
    pub position: i64,
    pub title: String,
    pub file: String,
}

/// Запись журнала ключей с названием продукта.
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct ActivationRow {
    pub id: String,
    pub product_id: String,
    pub product_title: String,
    pub activation_number: i64,
    pub device_code: String,
    pub activation_key: String,
    pub student: String,
    pub amount_somoni: Option<i64>,
    pub created_at: String,
}

/// 6:40, 1:02:05.
pub fn format_duration(total: i64) -> String {
    let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60);
    if h > 0 {
        format!("{h}:{m:02}:{s:02}")
    } else {
        format!("{m}:{s:02}")
    }
}

/// 34450 → «34 450».
pub fn format_money(n: i64) -> String {
    let digits = n.abs().to_string();
    let mut out = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            out.push('\u{202F}');
        }
        out.push(ch);
    }
    if n < 0 { format!("−{out}") } else { out }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats() {
        assert_eq!(format_duration(400), "6:40");
        assert_eq!(format_duration(3725), "1:02:05");
        assert_eq!(format_money(34450), "34\u{202F}450");
        assert_eq!(format_money(150), "150");
        assert_eq!(format_money(1_234_567), "1\u{202F}234\u{202F}567");
    }
}
