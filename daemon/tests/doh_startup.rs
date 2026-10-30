use dohd::{config::ResolverConfig, doh::DohClient};

#[test]
fn client_creation_does_not_resolve_resolver_hosts() {
    let resolvers = vec![ResolverConfig {
        name: "unavailable-at-startup".into(),
        url: "https://resolver.invalid/dns-query".into(),
        bootstrap_ips: Vec::new(),
        enabled: true,
        cooldown_seconds: 30,
    }];

    DohClient::new(&resolvers).expect("client creation must not require network DNS");
}
