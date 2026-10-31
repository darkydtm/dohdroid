use crate::{
    cache::DnsCache,
    config::{Config, ConfigStore},
    runtime::Runtime,
};
use axum::{
    extract::{Path as AxumPath, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Value};
use std::{
    net::SocketAddr,
    path::{Component, Path, PathBuf},
    sync::{Arc, Mutex},
};
use tokio::net::TcpListener;

const ASSET_CONTENT_TYPES: &[(&str, &str)] = &[
    ("css", "text/css; charset=utf-8"),
    ("js", "application/javascript; charset=utf-8"),
    ("html", "text/html; charset=utf-8"),
];

#[derive(Clone)]
pub struct WebState {
    pub config: ConfigStore,
    pub cache: Arc<Mutex<DnsCache>>,
    pub runtime: Arc<Mutex<Runtime>>,
    pub web_root: PathBuf,
}

pub fn router(state: WebState) -> Router {
    Router::new()
        .route("/", get(index))
        .route("/api/status", get(status))
        .route("/api/config", get(get_config).put(put_config))
        .route("/api/cache/clear", post(clear_cache))
        .route("/*path", get(asset))
        .with_state(state)
}

async fn index(State(state): State<WebState>) -> Result<Response, StatusCode> {
    asset_file(&state.web_root, "index.html").await
}

async fn asset(
    State(state): State<WebState>,
    AxumPath(path): AxumPath<String>,
) -> Result<Response, StatusCode> {
    asset_file(&state.web_root, &path).await
}

async fn asset_file(root: &Path, relative_path: &str) -> Result<Response, StatusCode> {
    let path = safe_asset_path(root, relative_path)?;
    let content = read_asset(&path).await?;
    let content_type = asset_content_type(Path::new(relative_path));
    Ok(([(header::CONTENT_TYPE, content_type)], content).into_response())
}

fn safe_asset_path(root: &Path, relative_path: &str) -> Result<PathBuf, StatusCode> {
    let relative_path = Path::new(relative_path);
    if relative_path.components().any(|component| {
        matches!(
            component,
            Component::CurDir | Component::ParentDir | Component::RootDir | Component::Prefix(_)
        )
    }) {
        return Err(StatusCode::NOT_FOUND);
    }
    Ok(root.join(relative_path))
}

async fn read_asset(path: &Path) -> Result<Vec<u8>, StatusCode> {
    let content = tokio::fs::read(path)
        .await
        .map_err(|error| match error.kind() {
            std::io::ErrorKind::NotFound => StatusCode::NOT_FOUND,
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        })?;
    Ok(content)
}

fn asset_content_type(path: &Path) -> &'static str {
    path.extension()
        .and_then(|extension| extension.to_str())
        .and_then(|extension| {
            ASSET_CONTENT_TYPES
                .iter()
                .find_map(|(known_extension, content_type)| {
                    (*known_extension == extension).then_some(*content_type)
                })
        })
        .unwrap_or("application/octet-stream")
}

async fn status(State(state): State<WebState>) -> Json<Value> {
    Json(json!({ "ok": true, "status": state.runtime.lock().unwrap().status() }))
}

async fn get_config(State(state): State<WebState>) -> Json<Value> {
    Json(json!({ "ok": true, "config": state.config.snapshot() }))
}

async fn put_config(
    State(state): State<WebState>,
    Json(config): Json<Config>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    state.config.replace(config).map_err(|error| {
        (
            StatusCode::BAD_REQUEST,
            Json(json!({ "ok": false, "error": error.to_string() })),
        )
    })?;
    Ok(Json(json!({ "ok": true })))
}

async fn clear_cache(State(state): State<WebState>) -> Json<Value> {
    state.cache.lock().unwrap().clear();
    Json(json!({ "ok": true, "cleared": true }))
}

pub async fn serve_web(state: WebState, address: SocketAddr) -> anyhow::Result<()> {
    let listener = TcpListener::bind(address).await?;
    tracing::info!(%address, "web UI listening");
    axum::serve(listener, router(state)).await?;
    Ok(())
}
