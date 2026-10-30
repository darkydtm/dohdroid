use dohd::{config::ResolverConfig, doh::DohClient};

#[test]
fn client_creation_rejects_unresolvable_resolver_hosts() {
    let resolvers = vec![ResolverConfig {
        name: "unavailable-at-startup".into(),
        url: "https://resolver.invalid/dns-query".into(),
        bootstrap_ips: Vec::new(),
        enabled: true,
        cooldown_seconds: 30,
    }];

    assert!(DohClient::new(&resolvers).is_err());
}
