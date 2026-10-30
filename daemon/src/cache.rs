use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use anyhow::Result;
use async_trait::async_trait;
use hickory_proto::op::{Message, ResponseCode};

use crate::dns::DnsHandler;

const MAX_TTL_SECONDS: u32 = 300;

pub struct DnsCache {
    capacity: usize,
    entries: HashMap<Vec<u8>, (Vec<u8>, Instant)>,
}
impl DnsCache {
    pub fn new(capacity: usize) -> Self {
        Self {
            capacity,
            entries: HashMap::new(),
        }
    }
    pub fn get(&mut self, key: &[u8]) -> Option<Vec<u8>> {
        let (value, expiry) = self.entries.get(key)?;
        if *expiry <= Instant::now() {
            self.entries.remove(key);
            None
        } else {
            Some(value.clone())
        }
    }
    pub fn insert(&mut self, key: Vec<u8>, value: Vec<u8>, ttl: Duration) {
        if self.entries.len() >= self.capacity {
            if let Some(key) = self.entries.keys().next().cloned() {
                self.entries.remove(&key);
            }
        }
        self.entries.insert(key, (value, Instant::now() + ttl));
    }
    pub fn clear(&mut self) {
        self.entries.clear();
    }
}

fn cache_key(query: &[u8]) -> Option<Vec<u8>> {
    let mut message = Message::from_vec(query).ok()?;
    if message.queries().len() != 1 {
        return None;
    }
    message.set_id(0);
    message.to_vec().ok()
}

fn cache_ttl(response: &[u8]) -> Option<Duration> {
    let message = Message::from_vec(response).ok()?;
    if message.response_code() != ResponseCode::NoError || message.truncated() {
        return None;
    }
    let ttl = message.answers().iter().map(|record| record.ttl()).min()?;
    if ttl == 0 {
        return None;
    }
    Some(Duration::from_secs(u64::from(ttl.min(MAX_TTL_SECONDS))))
}

pub struct CachingHandler<H> {
    inner: H,
    cache: Arc<Mutex<DnsCache>>,
    enabled: bool,
}
impl<H> CachingHandler<H> {
    pub fn new(inner: H, cache: Arc<Mutex<DnsCache>>, enabled: bool) -> Self {
        Self {
            inner,
            cache,
            enabled,
        }
    }
}

#[async_trait]
impl<H: DnsHandler> DnsHandler for CachingHandler<H> {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>> {
        let key = if self.enabled {
            cache_key(&query)
        } else {
            None
        };
        let Some(key) = key else {
            return self.inner.handle(query).await;
        };
        let cached = self.cache.lock().unwrap().get(&key);
        if let Some(mut response) = cached {
            response[..2].copy_from_slice(&query[..2]);
            return Ok(response);
        }
        let response = self.inner.handle(query).await?;
        if let Some(ttl) = cache_ttl(&response) {
            self.cache
                .lock()
                .unwrap()
                .insert(key, response.clone(), ttl);
        }
        Ok(response)
    }
}
