mod common;

use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc, Mutex,
};

use anyhow::Result;
use async_trait::async_trait;
use common::{answer, query};
use dohd::{cache::CachingHandler, cache::DnsCache, dns::DnsHandler};
use hickory_proto::op::Message;

struct CountingHandler {
    calls: Arc<AtomicUsize>,
    ttl: u32,
}

#[async_trait]
impl DnsHandler for CountingHandler {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(answer(&query, self.ttl))
    }
}

fn handler(ttl: u32, enabled: bool) -> (CachingHandler<CountingHandler>, Arc<AtomicUsize>) {
    let calls = Arc::new(AtomicUsize::new(0));
    let inner = CountingHandler {
        calls: Arc::clone(&calls),
        ttl,
    };
    let cache = Arc::new(Mutex::new(DnsCache::new(16)));
    (CachingHandler::new(inner, cache, enabled), calls)
}

#[tokio::test]
async fn repeated_question_is_served_from_cache_with_its_own_id() {
    let (handler, calls) = handler(60, true);

    handler.handle(query(1, "example.org.")).await.unwrap();
    let response = handler.handle(query(2, "example.org.")).await.unwrap();

    assert_eq!(calls.load(Ordering::SeqCst), 1);
    let message = Message::from_vec(&response).unwrap();
    assert_eq!(message.id(), 2);
    assert_eq!(message.answers().len(), 1);
}

#[tokio::test]
async fn different_questions_are_not_mixed_up() {
    let (handler, calls) = handler(60, true);

    handler.handle(query(1, "example.org.")).await.unwrap();
    handler.handle(query(2, "example.net.")).await.unwrap();

    assert_eq!(calls.load(Ordering::SeqCst), 2);
}

#[tokio::test]
async fn zero_ttl_answer_is_not_cached() {
    let (handler, calls) = handler(0, true);

    handler.handle(query(1, "example.org.")).await.unwrap();
    handler.handle(query(2, "example.org.")).await.unwrap();

    assert_eq!(calls.load(Ordering::SeqCst), 2);
}

#[tokio::test]
async fn disabled_cache_always_asks_the_resolver() {
    let (handler, calls) = handler(60, false);

    handler.handle(query(1, "example.org.")).await.unwrap();
    handler.handle(query(2, "example.org.")).await.unwrap();

    assert_eq!(calls.load(Ordering::SeqCst), 2);
}
