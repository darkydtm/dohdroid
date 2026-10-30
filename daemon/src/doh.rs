use crate::config::ResolverConfig;
use anyhow::{Context, Result};
use reqwest::Client;
use std::net::SocketAddr;
use url::Url;

pub struct DohClient {
    client: Client,
}
impl DohClient {
    pub fn new(resolvers: &[ResolverConfig]) -> Result<Self> {
        use std::net::ToSocketAddrs;
        let mut builder = Client::builder().user_agent("dohd/0.1");
        for resolver in resolvers.iter().filter(|resolver| resolver.enabled) {
            let url = Url::parse(&resolver.url)?;
            let host = url.host_str().context("resolver host missing")?;
            let port = url
                .port_or_known_default()
                .context("resolver port missing")?;
            let addresses: Vec<_> = (host, port).to_socket_addrs()?.collect();
            if addresses.is_empty() {
                anyhow::bail!("resolver hostname has no addresses: {host}");
            }
            builder = builder.resolve_to_addrs(host, &addresses);
        }
        Ok(Self {
            client: builder.build()?,
        })
    }
    pub async fn resolve(&self, resolver: &ResolverConfig, query: &[u8]) -> Result<Vec<u8>> {
        let url = Url::parse(&resolver.url)?;
        let client = if resolver.bootstrap_ips.is_empty() {
            self.client.clone()
        } else {
            let addresses = resolver
                .bootstrap_ips
                .iter()
                .map(|ip| {
                    Ok(SocketAddr::new(
                        ip.parse()?,
                        url.port_or_known_default().unwrap_or(443),
                    ))
                })
                .collect::<Result<Vec<_>>>()?;
            Client::builder()
                .user_agent("dohd/0.1")
                .resolve_to_addrs(url.host_str().unwrap(), &addresses)
                .build()?
        };
        let response = client
            .post(&resolver.url)
            .header("content-type", "application/dns-message")
            .body(query.to_vec())
            .send()
            .await
            .context("DoH request")?;
        if !response.status().is_success() {
            anyhow::bail!("DoH status {}", response.status());
        }
        let body = response.bytes().await?;
        if body.len() > crate::dns::MAX_DNS_PACKET {
            anyhow::bail!("DoH response too large");
        }
        Ok(body.to_vec())
    }
}
