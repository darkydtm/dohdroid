use serde::Serialize;
use std::time::Instant;

#[derive(Clone, Debug, Serialize)]
pub struct RuntimeStatus {
    pub uptime_seconds: u64,
    pub requests: u64,
    pub errors: u64,
    pub enabled: bool,
}

pub struct Runtime {
    started: Instant,
    requests: u64,
    errors: u64,
    pub enabled: bool,
}

impl Default for Runtime {
    fn default() -> Self {
        Self::new()
    }
}

impl Runtime {
    pub fn new() -> Self {
        Self {
            started: Instant::now(),
            requests: 0,
            errors: 0,
            enabled: true,
        }
    }
    pub fn status(&self) -> RuntimeStatus {
        RuntimeStatus {
            uptime_seconds: self.started.elapsed().as_secs(),
            requests: self.requests,
            errors: self.errors,
            enabled: self.enabled,
        }
    }
    pub fn record_request(&mut self, error: bool) {
        self.requests += 1;
        if error {
            self.errors += 1;
        }
    }
}
