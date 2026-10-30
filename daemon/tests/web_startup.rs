use dohd::{
    cache::DnsCache,
    config::ConfigStore,
    runtime::Runtime,
    web::{router, WebState},
};
use std::{
    fs,
    sync::{Arc, Mutex},
};
use tempfile::tempdir;

#[test]
fn web_router_accepts_static_asset_catch_all() {
    let dir = tempdir().unwrap();
    let config_path = dir.path().join("config.toml");
    fs::write(
        &config_path,
        include_str!("../../module/config/config.toml.example"),
    )
    .unwrap();
    let config = ConfigStore::load(config_path).unwrap();

    let _router = router(WebState {
        config,
        cache: Arc::new(Mutex::new(DnsCache::new(16))),
        runtime: Arc::new(Mutex::new(Runtime::new())),
        web_root: dir.path().join("webroot"),
    });
}
