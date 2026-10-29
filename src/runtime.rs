use std::time::Instant;
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
pub struct RuntimeStatus { pub started_at: u64, pub requests: u64, pub errors: u64, pub enabled: bool }

pub struct Runtime { started: Instant, requests: u64, errors: u64, pub enabled: bool }
impl Runtime {
	pub fn new() -> Self { Self { started: Instant::now(), requests: 0, errors: 0, enabled: true } }
	pub fn status(&self) -> RuntimeStatus { RuntimeStatus { started_at: self.started.elapsed().as_secs(), requests: self.requests, errors: self.errors, enabled: self.enabled } }
	pub fn record_request(&mut self, error: bool) { self.requests += 1; if error { self.errors += 1; } }
}
