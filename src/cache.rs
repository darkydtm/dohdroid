use std::{collections::HashMap, time::{Duration, Instant}};

pub struct DnsCache { capacity: usize, entries: HashMap<Vec<u8>, (Vec<u8>, Instant)> }
impl DnsCache {
	pub fn new(capacity: usize) -> Self { Self { capacity, entries: HashMap::new() } }
	pub fn get(&mut self, key: &[u8]) -> Option<Vec<u8>> { let (value, expiry) = self.entries.get(key)?; if *expiry <= Instant::now() { self.entries.remove(key); None } else { Some(value.clone()) } }
	pub fn insert(&mut self, key: Vec<u8>, value: Vec<u8>, ttl: Duration) { if self.entries.len() >= self.capacity { if let Some(key) = self.entries.keys().next().cloned() { self.entries.remove(&key); } } self.entries.insert(key, (value, Instant::now() + ttl)); }
	pub fn clear(&mut self) { self.entries.clear(); }
}
