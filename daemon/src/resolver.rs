use crate::{
    config::{FallbackMode, ResolverConfig},
    doh::DohClient,
};
use anyhow::Result;
use std::{
    sync::Mutex,
    time::{Duration, Instant},
};

pub struct ResolverPool {
    client: DohClient,
    resolvers: Vec<(ResolverConfig, Mutex<Option<Instant>>)>,
}
impl ResolverPool {
    pub fn new(resolvers: Vec<ResolverConfig>) -> Result<Self> {
        Ok(Self {
            client: DohClient::new()?,
            resolvers: resolvers
                .into_iter()
                .map(|r| (r, Mutex::new(None)))
                .collect(),
        })
    }
    pub async fn resolve(
        &self,
        query: &[u8],
        fallback: &FallbackMode,
        connect_timeout: Duration,
        request_timeout: Duration,
    ) -> Result<Vec<u8>> {
        let now = Instant::now();
        let ready: Vec<_> = self
            .resolvers
            .iter()
            .filter(|(resolver, _)| resolver.enabled)
            .filter(|(_, cooldown)| !cooldown.lock().unwrap().is_some_and(|until| until > now))
            .collect();
        let candidates = if ready.is_empty() {
            self.resolvers
                .iter()
                .filter(|(resolver, _)| resolver.enabled)
                .collect()
        } else {
            ready
        };
        for (resolver, cooldown) in candidates {
            match self
                .client
                .resolve(resolver, query, connect_timeout, request_timeout)
                .await
            {
                Ok(response) => return Ok(response),
                Err(error) => {
                    *cooldown.lock().unwrap() =
                        Some(Instant::now() + Duration::from_secs(resolver.cooldown_seconds));
                    tracing::warn!(resolver = %resolver.name, %error, "resolver failed");
                }
            }
        }
        match fallback {
            FallbackMode::Servfail => anyhow::bail!("all DoH resolvers failed"),
            FallbackMode::Disabled | FallbackMode::System => {
                anyhow::bail!("all DoH resolvers failed")
            }
        }
    }
}
