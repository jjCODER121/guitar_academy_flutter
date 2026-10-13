# Сборка из корня репозитория (нужна папка admin/):
#   docker build -f server/Dockerfile .

FROM rust:1-slim-trixie AS build
WORKDIR /src/server

# Сначала только манифесты — слой с зависимостями кешируется между сборками.
COPY server/Cargo.toml server/Cargo.lock ./
RUN mkdir src \
    && echo "fn main() {}" > src/main.rs \
    && touch src/lib.rs \
    && cargo build --release --locked \
    && rm -rf src

# Миграции встраиваются в бинарник при сборке (sqlx::migrate!).
COPY server/migrations ./migrations
COPY server/src ./src
RUN touch src/main.rs src/lib.rs && cargo build --release --locked

FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data && chown 10001 /data
COPY --from=build /src/server/target/release/guitar_school_server /usr/local/bin/guitar_school_server
COPY admin/static /srv/admin/static

# /data — база и загруженные видео/PDF/обложки. Подключайте как том и делайте копии.
ENV BIND_ADDR=0.0.0.0:8080 \
    DATA_DIR=/data \
    ADMIN_STATIC_DIR=/srv/admin/static \
    LOG_FORMAT=json
VOLUME ["/data"]
EXPOSE 8080
USER 10001
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
    CMD curl -fsS http://127.0.0.1:8080/api/v1/health || exit 1
CMD ["guitar_school_server"]
