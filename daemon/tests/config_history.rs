use dohd::config::ConfigStore;
use std::fs;

#[test]
fn history_survives_reload_and_remains_unique() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("config.toml");
    fs::write(
        &path,
        include_str!("../../module/config/config.toml.example"),
    )
    .unwrap();
    let store = ConfigStore::load(&path).unwrap();
    let mut config = store.snapshot();
    config.resolvers[0].url = "https://example.com/dns-query".into();
    store.replace(config.clone()).unwrap();
    config.resolvers[0].url = "https://other.example/dns-query".into();
    store.replace(config.clone()).unwrap();
    config.resolvers[0].url = "https://example.com/dns-query".into();
    store.replace(config).unwrap();
    let restored = ConfigStore::load(&path).unwrap().snapshot();
    assert_eq!(restored.resolvers[0].url, "https://example.com/dns-query");
    assert_eq!(
        restored.resolver_history,
        [
            "https://example.com/dns-query",
            "https://other.example/dns-query"
        ]
    );
}
