//! Ключ активации — та же формула, что в `packages/activation_key` (Dart).
//! Совпадение проверяется тестом по общему файлу примеров
//! `packages/activation_key/test/vectors.json`.

/// Секретное число школы в формуле ключа (`keySecret` в Dart).
pub const KEY_SECRET: u64 = 1985;
/// Сдвиг номера курса (`keyCourseOffset` в Dart).
pub const KEY_COURSE_OFFSET: u64 = 3;

/// ID-код устройства — только цифры.
pub fn is_device_code(code: &str) -> bool {
    !code.is_empty() && code.len() <= 64 && code.bytes().all(|b| b.is_ascii_digit())
}

/// Сумма «цифра × номер места» (места слева направо, с 1).
pub fn weighted_sum(code: &str) -> Option<u64> {
    if !is_device_code(code) {
        return None;
    }
    Some(
        code.bytes()
            .enumerate()
            .map(|(i, b)| u64::from(b - b'0') * (i as u64 + 1))
            .sum(),
    )
}

/// Число, из которого получается ключ.
pub fn key_number(code: &str, course: u64) -> Option<u64> {
    Some(weighted_sum(code)? * (course + KEY_COURSE_OFFSET) + KEY_SECRET)
}

/// После каждой цифры — её буква (1→A … 9→I), 0 → `0FFF`.
pub fn encode_key_number(n: u64) -> String {
    let mut out = String::new();
    for ch in n.to_string().chars() {
        out.push(ch);
        match ch {
            '0' => out.push_str("FFF"),
            d => out.push(char::from(b'A' + (d as u8 - b'1'))),
        }
    }
    out
}

pub fn expected_key(code: &str, course: u64) -> Option<String> {
    key_number(code, course).map(encode_key_number)
}

/// Заглавные латинские буквы и цифры, без пробелов и дефисов.
pub fn normalize_key(input: &str) -> String {
    input
        .chars()
        .filter(char::is_ascii_alphanumeric)
        .map(|c| c.to_ascii_uppercase())
        .collect()
}

pub fn verify_key(code: &str, course: u64, key: &str) -> bool {
    expected_key(code, course).is_some_and(|k| k == normalize_key(key))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::Deserialize;

    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Vectors {
        encode: Vec<Encode>,
        keys: Vec<Key>,
    }
    #[derive(Deserialize)]
    struct Encode {
        number: u64,
        key: String,
    }
    #[derive(Deserialize)]
    struct Key {
        code: String,
        course: u64,
        key: String,
    }

    fn vectors() -> Vectors {
        serde_json::from_str(include_str!(
            "../../packages/activation_key/test/vectors.json"
        ))
        .unwrap()
    }

    #[test]
    fn matches_shared_vectors() {
        let v = vectors();
        for e in v.encode {
            assert_eq!(encode_key_number(e.number), e.key);
        }
        for k in v.keys {
            assert_eq!(
                expected_key(&k.code, k.course).as_deref(),
                Some(k.key.as_str()),
                "{} / {}",
                k.code,
                k.course
            );
            assert!(verify_key(&k.code, k.course, &k.key.to_lowercase()));
        }
    }

    #[test]
    fn rejects_non_digit_codes_and_wrong_course() {
        assert_eq!(expected_key("12a4", 1), None);
        assert_eq!(expected_key("", 1), None);
        assert!(!verify_key("14140235536843855", 2, "4D8H5E3C"));
    }

    #[test]
    fn normalizes_user_input() {
        assert_eq!(normalize_key(" 4d-8h 5e3c "), "4D8H5E3C");
    }
}
