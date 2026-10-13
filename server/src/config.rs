use std::{env, net::SocketAddr, path::PathBuf};

/// Настройки сервера. Всё — из переменных окружения (см. `.env.example`),
/// секреты в репозиторий не попадают.
#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    /// Папка с данными: файл базы и загруженные видео, PDF, обложки.
    pub data_dir: PathBuf,
    pub bind_addr: SocketAddr,
    pub admin_static_dir: PathBuf,
    pub log_format: LogFormat,
    /// Ключ подписи временных ссылок на видео и PDF. None — сгенерировать
    /// при запуске (ссылки перестанут работать после перезапуска; для разработки).
    pub media_secret: Option<String>,
    /// Ставить cookie админки только по HTTPS. На сервере с доменом — true.
    pub cookie_secure: bool,
    /// Максимальный размер загружаемого файла, МБ.
    pub max_upload_mb: u64,
    /// Название школы в шапке админки.
    pub school_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogFormat {
    Pretty,
    Json,
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("неверное значение {name}: {value}")]
    Invalid { name: &'static str, value: String },
}

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        Self::from_lookup(|name| env::var(name).ok())
    }

    /// Разбор настроек из произвольного источника — удобно для тестов.
    pub fn from_lookup(get: impl Fn(&str) -> Option<String>) -> Result<Self, ConfigError> {
        let data_dir: PathBuf = get("DATA_DIR").unwrap_or_else(|| "data".into()).into();
        let database_url = get("DATABASE_URL").unwrap_or_else(|| {
            format!("sqlite://{}/school.db", data_dir.display()).replace('\\', "/")
        });

        let bind_raw = get("BIND_ADDR").unwrap_or_else(|| "0.0.0.0:8080".into());
        let bind_addr = bind_raw.parse().map_err(|_| ConfigError::Invalid {
            name: "BIND_ADDR",
            value: bind_raw.clone(),
        })?;

        let admin_static_dir = get("ADMIN_STATIC_DIR")
            .unwrap_or_else(|| "../admin/static".into())
            .into();

        let log_format = match get("LOG_FORMAT").as_deref() {
            None | Some("pretty") => LogFormat::Pretty,
            Some("json") => LogFormat::Json,
            Some(other) => {
                return Err(ConfigError::Invalid {
                    name: "LOG_FORMAT",
                    value: other.into(),
                });
            }
        };

        let media_secret = get("MEDIA_SECRET").filter(|s| !s.is_empty());
        if let Some(secret) = &media_secret
            && secret.len() < 32
        {
            return Err(ConfigError::Invalid {
                name: "MEDIA_SECRET",
                value: "короче 32 символов".into(),
            });
        }

        let cookie_secure = matches!(get("COOKIE_SECURE").as_deref(), Some("true" | "1"));

        let max_raw = get("MAX_UPLOAD_MB").unwrap_or_else(|| "4096".into());
        let max_upload_mb = max_raw.parse().map_err(|_| ConfigError::Invalid {
            name: "MAX_UPLOAD_MB",
            value: max_raw.clone(),
        })?;

        let school_name = get("SCHOOL_NAME").unwrap_or_else(|| "[Название школы]".into());

        Ok(Self {
            school_name,
            database_url,
            data_dir,
            bind_addr,
            admin_static_dir,
            log_format,
            media_secret,
            cookie_secure,
            max_upload_mb,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn parse(vars: &[(&str, &str)]) -> Result<Config, ConfigError> {
        let map: HashMap<String, String> = vars
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect();
        Config::from_lookup(|name| map.get(name).cloned())
    }

    #[test]
    fn defaults_work_without_any_variables() {
        let cfg = parse(&[]).unwrap();
        assert_eq!(cfg.bind_addr, "0.0.0.0:8080".parse().unwrap());
        assert_eq!(cfg.database_url, "sqlite://data/school.db");
        assert_eq!(cfg.data_dir, PathBuf::from("data"));
        assert_eq!(cfg.log_format, LogFormat::Pretty);
        assert!(cfg.media_secret.is_none());
        assert!(!cfg.cookie_secure);
    }

    #[test]
    fn database_follows_data_dir() {
        let cfg = parse(&[("DATA_DIR", "/srv/data")]).unwrap();
        assert_eq!(cfg.database_url, "sqlite:///srv/data/school.db");
    }

    #[test]
    fn rejects_bad_values() {
        assert!(matches!(
            parse(&[("BIND_ADDR", "nope")]),
            Err(ConfigError::Invalid {
                name: "BIND_ADDR",
                ..
            })
        ));
        assert!(matches!(
            parse(&[("LOG_FORMAT", "xml")]),
            Err(ConfigError::Invalid {
                name: "LOG_FORMAT",
                ..
            })
        ));
        assert!(matches!(
            parse(&[("MEDIA_SECRET", "short")]),
            Err(ConfigError::Invalid {
                name: "MEDIA_SECRET",
                ..
            })
        ));
    }
}
