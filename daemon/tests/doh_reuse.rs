mod common;

use std::{sync::atomic::Ordering, time::Duration};

use common::{query, FakeDoh};
use dohd::{
    config::{FallbackMode, ResolverConfig},
    resolver::ResolverPool,
};

fn resolver(url: String) -> ResolverConfig {
    ResolverConfig {
        name: "fake".into(),
        url,
        bootstrap_ips: vec!["127.0.0.1".into()],
        enabled: true,
        cooldown_seconds: 30,
    }
}

#[tokio::test]
async fn sequential_queries_share_one_connection() {
    let server = FakeDoh::start().await;
    let pool = ResolverPool::new(vec![resolver(server.url())]).unwrap();
    let timeout = Duration::from_secs(2);

    for id in 1..=3 {
        pool.resolve(
            &query(id, "example.org."),
            &FallbackMode::System,
            timeout,
            timeout,
        )
        .await
        .unwrap();
    }

    assert_eq!(server.requests.load(Ordering::SeqCst), 3);
    assert_eq!(
        server.connections.load(Ordering::SeqCst),
        1,
        "every query opened a new connection"
    );
}
