mod common;

use std::time::Duration;

use common::{query, FakeDoh};
use dohd::{
    config::{FallbackMode, ResolverConfig},
    resolver::ResolverPool,
};
use tokio::net::TcpListener;

#[tokio::test]
async fn resolver_in_cooldown_is_retried_when_nothing_else_is_available() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    drop(listener);
    let pool = ResolverPool::new(vec![ResolverConfig {
        name: "late".into(),
        url: format!("http://doh.test:{port}/dns-query"),
        bootstrap_ips: vec!["127.0.0.1".into()],
        enabled: true,
        cooldown_seconds: 3600,
    }])
    .unwrap();
    let timeout = Duration::from_secs(2);

    let first = pool
        .resolve(
            &query(1, "example.org."),
            &FallbackMode::System,
            timeout,
            timeout,
        )
        .await;
    assert!(first.is_err());

    let _server = FakeDoh::start_on(port).await;
    let second = pool
        .resolve(
            &query(2, "example.org."),
            &FallbackMode::System,
            timeout,
            timeout,
        )
        .await;
    assert!(
        second.is_ok(),
        "the only resolver stayed unreachable after the network came back"
    );
}
