use crate::config::ResolverConfig;
use anyhow::{Context, Result};
use reqwest::Client;
use std::{collections::HashMap, net::SocketAddr, sync::Mutex, time::Duration};
use url::Url;

type ClientKey = (String, Vec<String>, Duration, Duration);

pub struct DohClient {
    clients: Mutex<HashMap<ClientKey, Client>>,
}
impl DohClient {
    pub fn new(_resolvers: &[ResolverConfig]) -> Result<Self> {
        Ok(Self {
            clients: Mutex::new(HashMap::new()),
        })
    }

    fn client(
        &self,
        resolver: &ResolverConfig,
        url: &Url,
        connect_timeout: Duration,
        request_timeout: Duration,
    ) -> Result<Client> {
        let key = (
            resolver.url.clone(),
            resolver.bootstrap_ips.clone(),
            connect_timeout,
            request_timeout,
        );
        let mut clients = self.clients.lock().unwrap();
        if let Some(client) = clients.get(&key) {
            return Ok(client.clone());
        }
        let mut builder = Client::builder()
            .user_agent("dohd/0.1")
            .connect_timeout(connect_timeout)
            .timeout(request_timeout);
        if !resolver.bootstrap_ips.is_empty() {
            let host = url.host_str().context("resolver URL has no host")?;
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
            builder = builder.resolve_to_addrs(host, &addresses);
        }
        let client = builder.build()?;
        clients.insert(key, client.clone());
        Ok(client)
    }

    pub async fn resolve(
        &self,
        resolver: &ResolverConfig,
        query: &[u8],
        connect_timeout: Duration,
        request_timeout: Duration,
    ) -> Result<Vec<u8>> {
        let url = Url::parse(&resolver.url)?;
        let client = self.client(resolver, &url, connect_timeout, request_timeout)?;
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
