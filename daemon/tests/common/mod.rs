#![allow(dead_code)]

use std::{
    net::Ipv4Addr,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
};

use hickory_proto::{
    op::{Message, MessageType, Query, ResponseCode},
    rr::{rdata::A, Name, RData, Record, RecordType},
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};

pub fn query(id: u16, name: &str) -> Vec<u8> {
    let mut message = Message::new();
    message
        .set_id(id)
        .set_message_type(MessageType::Query)
        .set_recursion_desired(true);
    message.add_query(Query::query(Name::from_ascii(name).unwrap(), RecordType::A));
    message.to_vec().unwrap()
}

pub fn answer(query: &[u8], ttl: u32) -> Vec<u8> {
    let query = Message::from_vec(query).unwrap();
    let mut message = Message::new();
    message
        .set_id(query.id())
        .set_message_type(MessageType::Response)
        .set_response_code(ResponseCode::NoError);
    message.add_queries(query.queries().iter().cloned());
    message.add_answer(Record::from_rdata(
        query.queries()[0].name().clone(),
        ttl,
        RData::A(A(Ipv4Addr::new(192, 0, 2, 1))),
    ));
    message.to_vec().unwrap()
}

pub struct FakeDoh {
    pub port: u16,
    pub connections: Arc<AtomicUsize>,
    pub requests: Arc<AtomicUsize>,
}

impl FakeDoh {
    pub async fn start() -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        Self::serve(listener)
    }

    pub async fn start_on(port: u16) -> Self {
        let listener = TcpListener::bind(("127.0.0.1", port)).await.unwrap();
        Self::serve(listener)
    }

    fn serve(listener: TcpListener) -> Self {
        let port = listener.local_addr().unwrap().port();
        let connections = Arc::new(AtomicUsize::new(0));
        let requests = Arc::new(AtomicUsize::new(0));
        let accepted = Arc::clone(&connections);
        let served = Arc::clone(&requests);
        tokio::spawn(async move {
            loop {
                let Ok((mut stream, _)) = listener.accept().await else {
                    return;
                };
                accepted.fetch_add(1, Ordering::SeqCst);
                let served = Arc::clone(&served);
                tokio::spawn(async move {
                    let mut buffer = Vec::new();
                    loop {
                        let Some(body) = read_request(&mut stream, &mut buffer).await else {
                            return;
                        };
                        served.fetch_add(1, Ordering::SeqCst);
                        let body = answer(&body, 60);
                        let head = format!(
                            "HTTP/1.1 200 OK\r\ncontent-type: application/dns-message\r\ncontent-length: {}\r\n\r\n",
                            body.len()
                        );
                        if stream.write_all(head.as_bytes()).await.is_err()
                            || stream.write_all(&body).await.is_err()
                        {
                            return;
                        }
                    }
                });
            }
        });
        Self {
            port,
            connections,
            requests,
        }
    }

    pub fn url(&self) -> String {
        format!("http://doh.test:{}/dns-query", self.port)
    }
}

async fn read_request(stream: &mut tokio::net::TcpStream, buffer: &mut Vec<u8>) -> Option<Vec<u8>> {
    let head_end = loop {
        if let Some(position) = buffer.windows(4).position(|window| window == b"\r\n\r\n") {
            break position + 4;
        }
        let mut chunk = [0u8; 1024];
        let read = stream.read(&mut chunk).await.ok()?;
        if read == 0 {
            return None;
        }
        buffer.extend_from_slice(&chunk[..read]);
    };
    let head = String::from_utf8_lossy(&buffer[..head_end]).to_ascii_lowercase();
    let length = head
        .lines()
        .find_map(|line| line.strip_prefix("content-length:"))
        .and_then(|value| value.trim().parse::<usize>().ok())
        .unwrap_or(0);
    while buffer.len() < head_end + length {
        let mut chunk = [0u8; 1024];
        let read = stream.read(&mut chunk).await.ok()?;
        if read == 0 {
            return None;
        }
        buffer.extend_from_slice(&chunk[..read]);
    }
    let body = buffer[head_end..head_end + length].to_vec();
    buffer.drain(..head_end + length);
    Some(body)
}
