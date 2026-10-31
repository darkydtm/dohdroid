use std::sync::Arc;
use tokio::sync::{Mutex, Semaphore};

use anyhow::Result;
use async_trait::async_trait;
use hickory_proto::op::{Message, MessageType, ResponseCode};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, UdpSocket};

use crate::config::{ConfigStore, FallbackMode, ResolverConfig};
use crate::resolver::ResolverPool;

pub const MAX_DNS_PACKET: usize = 4096;

#[async_trait]
pub trait DnsHandler: Send + Sync {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>>;
}

pub struct DohHandler {
    config: ConfigStore,
    pool: Mutex<ResolverPoolState>,
}

struct ResolverPoolState {
    resolver_configs: Vec<ResolverConfig>,
    fallback_mode: FallbackMode,
    resolver_pool: Arc<ResolverPool>,
}

impl DohHandler {
    pub fn new(config: ConfigStore) -> Result<Self> {
        let initial = config.snapshot();
        let pool = ResolverPool::new(initial.resolvers.clone())?;
        Ok(Self {
            config,
            pool: Mutex::new(ResolverPoolState {
                resolver_configs: initial.resolvers,
                fallback_mode: initial.fallback_mode,
                resolver_pool: Arc::new(pool),
            }),
        })
    }
}

#[async_trait]
impl DnsHandler for DohHandler {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>> {
        let config = self.config.snapshot();
        let connect_timeout = config.connect_timeout();
        let request_timeout = config.request_timeout();
        let (resolver_configs, fallback_mode) = {
            let state = self.pool.lock().await;
            (state.resolver_configs.clone(), state.fallback_mode.clone())
        };
        let replacement =
            if resolver_configs != config.resolvers || fallback_mode != config.fallback_mode {
                Some(Arc::new(ResolverPool::new(config.resolvers.clone())?))
            } else {
                None
            };
        let (fallback, resolver) = {
            let mut state = self.pool.lock().await;
            if state.resolver_configs != config.resolvers
                || state.fallback_mode != config.fallback_mode
            {
                let next_pool = match replacement {
                    Some(pool) => pool,
                    None => Arc::new(ResolverPool::new(config.resolvers.clone())?),
                };
                state.resolver_pool = next_pool;
                state.resolver_configs = config.resolvers;
                state.fallback_mode = config.fallback_mode;
            }
            (
                state.fallback_mode.clone(),
                Arc::clone(&state.resolver_pool),
            )
        };
        resolver
            .resolve(&query, &fallback, connect_timeout, request_timeout)
            .await
    }
}

fn servfail(query: &[u8]) -> Option<Vec<u8>> {
    let query = Message::from_vec(query).ok()?;
    let mut response = Message::new();
    response
        .set_id(query.id())
        .set_message_type(MessageType::Response)
        .set_op_code(query.op_code())
        .set_recursion_desired(query.recursion_desired())
        .set_recursion_available(true)
        .set_response_code(ResponseCode::ServFail);
    response.add_queries(query.queries().iter().cloned());
    response.to_vec().ok()
}

async fn answer<H: DnsHandler + ?Sized>(handler: &H, query: Vec<u8>) -> Option<Vec<u8>> {
    match handler.handle(query.clone()).await {
        Ok(response) if response.len() <= MAX_DNS_PACKET => Some(response),
        Ok(_) => {
            tracing::warn!("DNS response too large");
            servfail(&query)
        }
        Err(error) => {
            tracing::warn!(%error, "DNS query failed");
            servfail(&query)
        }
    }
}

pub struct DnsServer<H> {
    handler: Arc<H>,
}

impl<H: DnsHandler + 'static> DnsServer<H> {
    pub fn new(handler: Arc<H>) -> Self {
        Self { handler }
    }

    pub async fn serve_udp(&self, socket: UdpSocket) -> Result<()> {
        let socket = Arc::new(socket);
        let permits = Arc::new(Semaphore::new(128));
        let mut buffer = [0u8; MAX_DNS_PACKET];
        loop {
            let (size, peer) = socket.recv_from(&mut buffer).await?;
            if size == 0 {
                continue;
            }
            let permit = Arc::clone(&permits).acquire_owned().await?;
            let query = buffer[..size].to_vec();
            let socket = Arc::clone(&socket);
            let handler = Arc::clone(&self.handler);
            tokio::spawn(async move {
                let _permit = permit;
                if let Some(response) = answer(handler.as_ref(), query).await {
                    if let Err(error) = socket.send_to(&response, peer).await {
                        tracing::warn!(%error, "DNS response failed");
                    }
                }
            });
        }
    }

    pub async fn serve_tcp(&self, listener: TcpListener) -> Result<()> {
        loop {
            let (mut stream, _) = listener.accept().await?;
            let handler = Arc::clone(&self.handler);
            tokio::spawn(async move {
                if let Err(error) = handle_tcp_connection(&mut stream, handler.as_ref()).await {
                    tracing::debug!(%error, "DNS TCP connection closed");
                }
                if let Err(error) = stream.shutdown().await {
                    tracing::debug!(%error, "DNS TCP shutdown failed");
                }
            });
        }
    }
}

async fn handle_tcp_connection<H: DnsHandler + ?Sized>(
    stream: &mut tokio::net::TcpStream,
    handler: &H,
) -> Result<()> {
    loop {
        let length = stream.read_u16().await? as usize;
        if length == 0 || length > MAX_DNS_PACKET {
            anyhow::bail!("invalid DNS TCP frame");
        }
        let mut query = vec![0u8; length];
        stream.read_exact(&mut query).await?;
        let Some(response) = answer(handler, query).await else {
            anyhow::bail!("DNS query could not be answered");
        };
        stream.write_u16(response.len() as u16).await?;
        stream.write_all(&response).await?;
    }
}
