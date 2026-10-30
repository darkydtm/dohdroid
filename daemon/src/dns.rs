use std::sync::Arc;
use tokio::sync::{Mutex, Semaphore};

use anyhow::Result;
use async_trait::async_trait;
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
    pool: Mutex<(Vec<ResolverConfig>, FallbackMode, Arc<ResolverPool>)>,
}

impl DohHandler {
    pub fn new(config: ConfigStore) -> Result<Self> {
        let initial = config.snapshot();
        let pool = ResolverPool::new(initial.resolvers.clone())?;
        Ok(Self {
            config,
            pool: Mutex::new((initial.resolvers, initial.fallback_mode, Arc::new(pool))),
        })
    }
}

#[async_trait]
impl DnsHandler for DohHandler {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>> {
        let mut pool = self.pool.lock().await;
        let config = self.config.snapshot();
        let connect_timeout = config.connect_timeout();
        let request_timeout = config.request_timeout();
        if pool.0 != config.resolvers || pool.1 != config.fallback_mode {
            *pool = (
                config.resolvers.clone(),
                config.fallback_mode,
                Arc::new(ResolverPool::new(config.resolvers)?),
            );
        }
        let fallback = pool.1.clone();
        let resolver = Arc::clone(&pool.2);
        drop(pool);
        resolver
            .resolve(&query, &fallback, connect_timeout, request_timeout)
            .await
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
            let permit = Arc::clone(&permits).acquire_owned().await?;
            let (size, peer) = socket.recv_from(&mut buffer).await?;
            if size == 0 {
                continue;
            }
            let query = buffer[..size].to_vec();
            let socket = Arc::clone(&socket);
            let handler = Arc::clone(&self.handler);
            tokio::spawn(async move {
                let _permit = permit;
                match handler.handle(query).await {
                    Ok(response) if response.len() <= MAX_DNS_PACKET => {
                        if let Err(error) = socket.send_to(&response, peer).await {
                            tracing::warn!(%error, "DNS response failed");
                        }
                    }
                    Ok(_) => tracing::warn!("DNS response too large"),
                    Err(error) => tracing::warn!(%error, "DNS query failed"),
                }
            });
        }
    }

    pub async fn serve_tcp(&self, listener: TcpListener) -> Result<()> {
        loop {
            let (mut stream, _) = listener.accept().await?;
            let handler = Arc::clone(&self.handler);
            tokio::spawn(async move {
                loop {
                    let length = stream.read_u16().await? as usize;
                    if length == 0 || length > MAX_DNS_PACKET {
                        anyhow::bail!("invalid DNS TCP frame");
                    }
                    let mut query = vec![0u8; length];
                    stream.read_exact(&mut query).await?;
                    let response: Vec<u8> = handler.handle(query).await?;
                    if response.len() > MAX_DNS_PACKET {
                        anyhow::bail!("DNS response too large");
                    }
                    stream.write_u16(response.len() as u16).await?;
                    stream.write_all(&response).await?;
                }
                #[allow(unreachable_code)]
                Ok::<(), anyhow::Error>(())
            });
        }
    }
}
