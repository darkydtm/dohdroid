mod common;

use std::{sync::Arc, time::Duration};

use anyhow::Result;
use async_trait::async_trait;
use common::query;
use dohd::dns::{DnsHandler, DnsServer};
use hickory_proto::op::{Message, MessageType, ResponseCode};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpListener, TcpStream, UdpSocket},
};

struct FailingHandler;

#[async_trait]
impl DnsHandler for FailingHandler {
    async fn handle(&self, _query: Vec<u8>) -> Result<Vec<u8>> {
        anyhow::bail!("all DoH resolvers failed")
    }
}

fn assert_servfail(response: &[u8], id: u16) {
    let message = Message::from_vec(response).unwrap();
    assert_eq!(message.id(), id);
    assert_eq!(message.message_type(), MessageType::Response);
    assert_eq!(message.response_code(), ResponseCode::ServFail);
    assert_eq!(message.queries().len(), 1);
}

#[tokio::test]
async fn udp_failure_is_answered_with_servfail() {
    let socket = UdpSocket::bind("127.0.0.1:0").await.unwrap();
    let address = socket.local_addr().unwrap();
    let server = Arc::new(DnsServer::new(Arc::new(FailingHandler)));
    let task = tokio::spawn(async move { server.serve_udp(socket).await });
    let client = UdpSocket::bind("127.0.0.1:0").await.unwrap();

    client
        .send_to(&query(7, "example.org."), address)
        .await
        .unwrap();
    let mut buffer = [0u8; 512];
    let size = tokio::time::timeout(Duration::from_millis(500), client.recv(&mut buffer))
        .await
        .expect("no reply to a failed query")
        .unwrap();
    assert_servfail(&buffer[..size], 7);

    client.send_to(&[1], address).await.unwrap();
    let silent = tokio::time::timeout(Duration::from_millis(300), client.recv(&mut buffer)).await;
    task.abort();
    assert!(silent.is_err(), "an unparseable packet got a reply");
}

#[tokio::test]
async fn tcp_failure_is_answered_with_servfail() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let server = Arc::new(DnsServer::new(Arc::new(FailingHandler)));
    let task = tokio::spawn(async move { server.serve_tcp(listener).await });
    let mut stream = TcpStream::connect(address).await.unwrap();

    let packet = query(9, "example.org.");
    stream.write_u16(packet.len() as u16).await.unwrap();
    stream.write_all(&packet).await.unwrap();
    let length = tokio::time::timeout(Duration::from_millis(500), stream.read_u16())
        .await
        .expect("no reply to a failed query")
        .unwrap();
    let mut response = vec![0u8; length as usize];
    stream.read_exact(&mut response).await.unwrap();
    task.abort();
    assert_servfail(&response, 9);
}
