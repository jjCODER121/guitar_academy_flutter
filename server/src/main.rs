use anyhow::Context;
use guitar_school_server::{
    admin, app, build_state,
    config::{Config, LogFormat},
    repo,
};
use tracing_subscriber::{EnvFilter, fmt, prelude::*};

const USAGE: &str = "\
Сервер гитарной школы.

  guitar_school_server                      запустить сервер
  guitar_school_server admin <логин> <пароль>  создать администратора или сменить пароль

Настройки — переменные окружения (см. .env.example).";

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // .env удобен локально; в Docker и на хостинге переменные задаются окружением.
    dotenvy::dotenv().ok();
    let config = Config::from_env()?;
    init_tracing(config.log_format);

    let args: Vec<String> = std::env::args().skip(1).collect();
    match args
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
        [] | ["serve"] => serve(config).await,
        ["admin", username, password] => {
            let state = build_state(config).await?;
            admin::create_admin(&state.db, username, password).await?;
            println!("Администратор «{username}» сохранён.");
            Ok(())
        }
        _ => {
            println!("{USAGE}");
            Ok(())
        }
    }
}

async fn serve(config: Config) -> anyhow::Result<()> {
    let bind = config.bind_addr;
    let state = build_state(config).await?;

    // Первый запуск в Docker: администратор из ADMIN_USERNAME / ADMIN_PASSWORD,
    // если в базе его ещё нет.
    if repo::admin_count(&state.db).await? == 0 {
        match (
            std::env::var("ADMIN_USERNAME"),
            std::env::var("ADMIN_PASSWORD"),
        ) {
            (Ok(user), Ok(pass)) if !pass.is_empty() => {
                admin::create_admin(&state.db, &user, &pass).await?;
                tracing::info!(%user, "администратор создан из переменных окружения");
            }
            _ => tracing::warn!(
                "администратора нет — выполните: guitar_school_server admin <логин> <пароль>"
            ),
        }
    }

    let listener = tokio::net::TcpListener::bind(bind)
        .await
        .with_context(|| format!("не удалось занять {bind}"))?;
    tracing::info!(addr = %bind, "server started");
    axum::serve(listener, app(state))
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

fn init_tracing(format: LogFormat) {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,tower_http=info,sqlx=warn"));
    let registry = tracing_subscriber::registry().with(filter);
    match format {
        LogFormat::Json => registry.with(fmt::layer().json()).init(),
        LogFormat::Pretty => registry.with(fmt::layer()).init(),
    }
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c().await.ok();
    };
    #[cfg(unix)]
    let terminate = async {
        if let Ok(mut s) = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        {
            s.recv().await;
        }
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    tracing::info!("shutting down");
}
