use std::{
    collections::{HashMap, VecDeque},
    sync::{Arc, Mutex, Weak},
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
    lru: VecDeque<Vec<u8>>,
}

/// Evict the least-recently-used live entry; TTL expiry remains authoritative.
impl DnsCache {
    pub fn new(capacity: usize) -> Self {
        Self {
            capacity,
            entries: HashMap::new(),
            lru: VecDeque::new(),
        }
    }
    pub fn get(&mut self, key: &[u8]) -> Option<Vec<u8>> {
        if self
            .entries
            .get(key)
            .is_some_and(|(_, expiry)| *expiry <= Instant::now())
        {
            self.entries.remove(key);
            self.lru.retain(|entry| entry.as_slice() != key);
            None
        } else {
            let value = self.entries.get(key)?.0.clone();
            self.lru.retain(|entry| entry.as_slice() != key);
            self.lru.push_back(key.to_vec());
            Some(value)
        }
    }
    pub fn insert(&mut self, key: Vec<u8>, value: Vec<u8>, ttl: Duration) {
        if self.capacity == 0 || ttl.is_zero() {
            return;
        }
        if self.entries.contains_key(&key) {
            self.lru.retain(|entry| entry != &key);
        } else if self.entries.len() >= self.capacity {
            if let Some(evicted) = self.lru.pop_front() {
                self.entries.remove(&evicted);
            }
        }
        self.entries
            .insert(key.clone(), (value, Instant::now() + ttl));
        self.lru.push_back(key);
    }
    pub fn clear(&mut self) {
        self.entries.clear();
        self.lru.clear();
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

type InFlight = Arc<tokio::sync::Mutex<HashMap<Vec<u8>, Weak<tokio::sync::Mutex<()>>>>>;

pub struct CachingHandler<H> {
    inner: H,
    cache: Arc<Mutex<DnsCache>>,
    enabled: bool,
    // Keep only weak per-key locks so idle keys do not grow this map forever.
    in_flight: InFlight,
}
impl<H> CachingHandler<H> {
    pub fn new(inner: H, cache: Arc<Mutex<DnsCache>>, enabled: bool) -> Self {
        Self {
            inner,
            cache,
            enabled,
            in_flight: Arc::new(tokio::sync::Mutex::new(HashMap::new())),
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
        if let Some(mut response) = self.cache.lock().unwrap().get(&key) {
            response[..2].copy_from_slice(&query[..2]);
            return Ok(response);
        }
        let key_lock = {
            let mut in_flight = self.in_flight.lock().await;
            in_flight.retain(|_, lock| lock.strong_count() > 0);
            in_flight
                .entry(key.clone())
                .and_modify(|lock| {
                    if lock.strong_count() == 0 {
                        *lock = Weak::new();
                    }
                })
                .or_insert_with(Weak::new);
            let lock = in_flight
                .get(&key)
                .and_then(Weak::upgrade)
                .unwrap_or_else(|| {
                    let lock = Arc::new(tokio::sync::Mutex::new(()));
                    in_flight.insert(key.clone(), Arc::downgrade(&lock));
                    lock
                });
            lock
        };
        let _flight_guard = key_lock.lock().await;
        if let Some(mut response) = self.cache.lock().unwrap().get(&key) {
            response[..2].copy_from_slice(&query[..2]);
            return Ok(response);
        }
        let result = self.inner.handle(query.clone()).await;
        if let Ok(response) = &result {
            if let Some(ttl) = cache_ttl(response) {
                self.cache
                    .lock()
                    .unwrap()
                    .insert(key.clone(), response.clone(), ttl);
            }
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::DnsCache;
    use std::time::Duration;

    #[test]
    fn evicts_least_recently_used_entry() {
        let mut cache = DnsCache::new(2);
        cache.insert(b"a".to_vec(), b"A".to_vec(), Duration::from_secs(60));
        cache.insert(b"b".to_vec(), b"B".to_vec(), Duration::from_secs(60));
        assert_eq!(cache.get(b"a"), Some(b"A".to_vec()));
        cache.insert(b"c".to_vec(), b"C".to_vec(), Duration::from_secs(60));
        assert_eq!(cache.get(b"a"), Some(b"A".to_vec()));
        assert_eq!(cache.get(b"b"), None);
    }
}
