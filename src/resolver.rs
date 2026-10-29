use std::time::{Duration, Instant};
use anyhow::Result;
use crate::{config::{FallbackMode, ResolverConfig}, doh::DohClient};

pub struct ResolverPool { client: DohClient, resolvers: Vec<(ResolverConfig, Option<Instant>)> }
impl ResolverPool {
	pub fn new(resolvers: Vec<ResolverConfig>) -> Result<Self> { Ok(Self { client: DohClient::new()?, resolvers: resolvers.into_iter().map(|r| (r, None)).collect() }) }
	pub async fn resolve(&mut self, query: &[u8], fallback: &FallbackMode) -> Result<Vec<u8>> {
		let now = Instant::now();
		for (resolver, cooldown) in &mut self.resolvers {
			if !resolver.enabled || cooldown.is_some_and(|until| until > now) { continue; }
			match self.client.resolve(resolver, query).await {
				Ok(response) => return Ok(response),
				Err(error) => { *cooldown = Some(now + Duration::from_secs(resolver.cooldown_seconds)); tracing::warn!(resolver = %resolver.name, %error, "resolver failed"); }
			}
		}
		match fallback { FallbackMode::Servfail => anyhow::bail!("all DoH resolvers failed"), FallbackMode::Disabled | FallbackMode::System => anyhow::bail!("all DoH resolvers failed") }
	}
}
