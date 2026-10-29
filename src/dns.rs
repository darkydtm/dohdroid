use anyhow::Result;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, UdpSocket};

pub const MAX_DNS_PACKET: usize = 4096;

#[async_trait::async_trait]
pub trait DnsHandler: Send + Sync {
    async fn handle(&self, query: Vec<u8>) -> Result<Vec<u8>>;
}

pub struct DnsServer<H> {
    handler: Arc<H>,
}

impl<H: DnsHandler + 'static> DnsServer<H> {
    pub fn new(handler: Arc<H>) -> Self {
        Self { handler }
    }
    pub async fn serve_udp(&self, socket: UdpSocket) -> Result<()> {
        let mut buffer = [0u8; MAX_DNS_PACKET];
        loop {
            let (size, peer) = socket.recv_from(&mut buffer).await?;
            if size == 0 {
                continue;
            }
            let response = self.handler.handle(buffer[..size].to_vec()).await?;
            if response.len() <= MAX_DNS_PACKET {
                socket.send_to(&response, peer).await?;
            }
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
                    let response = handler.handle(query).await?;
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
