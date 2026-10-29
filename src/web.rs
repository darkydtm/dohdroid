use crate::{
    cache::DnsCache,
    config::{Config, ConfigStore},
    runtime::Runtime,
};
use axum::{
    extract::State,
    http::StatusCode,
    response::Html,
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Value};
use std::{
    net::SocketAddr,
    sync::{Arc, Mutex},
};
use tokio::net::TcpListener;

#[derive(Clone)]
pub struct WebState {
    pub config: ConfigStore,
    pub cache: Arc<Mutex<DnsCache>>,
    pub runtime: Arc<Mutex<Runtime>>,
}

pub fn router(state: WebState) -> Router {
    Router::new()
        .route("/", get(index))
        .route("/api/status", get(status))
        .route("/api/config", get(get_config).put(put_config))
        .route("/api/cache/clear", post(clear_cache))
        .with_state(state)
}

async fn index() -> Html<&'static str> {
    Html(include_str!("../webui-prototype.html"))
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
