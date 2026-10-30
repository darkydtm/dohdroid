use dohd::config::ConfigStore;
use std::fs;

fn config_with_resolver() -> String {
    let mut config =
        include_str!("../../module/config/config.toml.example").replace("resolvers = []\n", "");
    config.push_str(
        r#"

[[resolvers]]
name = "custom"
url = "https://example.com/dns-query"
bootstrap_ips = []
enabled = true
cooldown_seconds = 30
"#,
    );
    config
}

#[test]
fn history_survives_reload_and_remains_unique() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("config.toml");
    fs::write(&path, config_with_resolver()).unwrap();
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

#[test]
fn empty_resolvers_keep_system_dns_mode() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("config.toml");
    fs::write(
        &path,
        include_str!("../../module/config/config.toml.example"),
    )
    .unwrap();

    let config = ConfigStore::load(&path).unwrap().snapshot();

    assert!(config.resolvers.is_empty());
}

#[test]
fn loading_legacy_history_removes_duplicates_and_empty_values() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("config.toml");
    let config = config_with_resolver();
    fs::write(
        &path,
        format!("resolver_history = [\"\", \"https://example.com/dns-query\", \"https://example.com/dns-query\"]\n{config}"),
    )
    .unwrap();
    let restored = ConfigStore::load(&path).unwrap().snapshot();
    assert_eq!(restored.resolver_history, ["https://example.com/dns-query"]);
}
