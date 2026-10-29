use crate::config::ResolverConfig;
use anyhow::{Context, Result};
use reqwest::Client;
use std::net::SocketAddr;
use url::Url;

pub struct DohClient {
    client: Client,
}
impl DohClient {
    pub fn new() -> Result<Self> {
        Ok(Self {
            client: Client::builder().user_agent("dohd/0.1").build()?,
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
