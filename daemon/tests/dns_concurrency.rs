use std::{sync::Arc, time::Duration};

use anyhow::Result;
use async_trait::async_trait;
use dohd::dns::{DnsHandler, DnsServer};
use tokio::net::UdpSocket;

struct SlowHandler;

#[async_trait]
impl DnsHandler for SlowHandler {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>> {
        if query == [1] {
            tokio::time::sleep(Duration::from_secs(2)).await;
        }
        Ok(query)
    }
}

#[tokio::test]
async fn slow_udp_request_does_not_block_following_query() {
    let socket = UdpSocket::bind("127.0.0.1:0").await.unwrap();
    let address = socket.local_addr().unwrap();
    let server = Arc::new(DnsServer::new(Arc::new(SlowHandler)));
    let task = tokio::spawn(async move { server.serve_udp(socket).await });
    let first = UdpSocket::bind("127.0.0.1:0").await.unwrap();
    let second = UdpSocket::bind("127.0.0.1:0").await.unwrap();
    first.send_to(&[1], address).await.unwrap();
    tokio::time::sleep(Duration::from_millis(100)).await;
    second.send_to(&[2], address).await.unwrap();
    let mut response = [0u8; 8];
    let result = tokio::time::timeout(Duration::from_millis(500), second.recv(&mut response)).await;
    task.abort();
    assert!(result.is_ok(), "a slow request blocked the next DNS query");
    assert_eq!(response[0], 2);
}
