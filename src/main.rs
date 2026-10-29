use dohd::{cache::DnsCache, config::ConfigStore, control, runtime::Runtime};
use std::{
    env,
    path::PathBuf,
    sync::{Arc, Mutex},
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();
    let config_path = env::var_os("DOHD_CONFIG")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("config/config.toml"));
    if !config_path.exists() {
        println!(
            "dohd {}: configuration missing at {}",
            dohd::VERSION,
            config_path.display()
        );
        return Ok(());
    }
    let config = ConfigStore::load(&config_path)?;
    let runtime = Arc::new(Mutex::new(Runtime::new()));
    let cache = Arc::new(Mutex::new(DnsCache::new(config.snapshot().cache_capacity)));
    let socket = env::var_os("DOHD_SOCKET")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("run/dohd.sock"));
    let config_value = config.snapshot();
    let pool = dohd::resolver::ResolverPool::new(config_value.resolvers.clone())?;
    let handler = Arc::new(dohd::dns::DohHandler::new(
        pool,
        config_value.fallback_mode.clone(),
    ));
    let udp = tokio::net::UdpSocket::bind((
        config_value.listen_address.as_str(),
        config_value.listen_port,
    ))
    .await?;
    let tcp = tokio::net::TcpListener::bind((
        config_value.listen_address.as_str(),
        config_value.listen_port,
    ))
    .await?;
    let dns_server = Arc::new(dohd::dns::DnsServer::new(handler));
    let udp_server = Arc::clone(&dns_server);
    let tcp_server = Arc::clone(&dns_server);
    tokio::spawn(async move { udp_server.serve_udp(udp).await });
    tokio::spawn(async move { tcp_server.serve_tcp(tcp).await });
    control::serve(&socket, config, cache, runtime).await?;
    Ok(())
}
