use dohd::{config::ResolverConfig, doh::DohClient};

#[test]
fn client_creation_succeeds_without_resolver_configuration() {
    DohClient::new().expect("client creation must not require resolver configuration");
}

#[tokio::test]
async fn stalled_doh_request_respects_configured_timeout() {
    use std::time::Duration;
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    let server = tokio::spawn(async move {
        let (_stream, _) = listener.accept().await.unwrap();
        tokio::time::sleep(Duration::from_secs(3)).await;
    });
    let resolver = ResolverConfig {
        name: "stalled".into(),
        url: format!("https://localhost:{port}/dns-query"),
        bootstrap_ips: vec!["127.0.0.1".into()],
        enabled: true,
        cooldown_seconds: 0,
    };
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("config.toml");
    std::fs::write(&path, format!("request_timeout_ms = 100\nconnect_timeout_ms = 100\n[[resolvers]]\nname = \"stalled\"\nurl = \"{}\"\nbootstrap_ips = [\"127.0.0.1\"]\nenabled = true\ncooldown_seconds = 0\n", resolver.url)).unwrap();
    let store = dohd::config::ConfigStore::load(path).unwrap();
    let handler = dohd::dns::DohHandler::new(store).unwrap();
    use dohd::dns::DnsHandler;
    let response =
        tokio::time::timeout(Duration::from_secs(1), handler.handle(b"query".to_vec())).await;
    server.abort();
    assert!(response.is_ok(), "stalled request exceeded its deadline");
    assert!(response.unwrap().is_err());
}
