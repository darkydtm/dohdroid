use dohd::{cache::DnsCache, config::ConfigStore, control, runtime::Runtime};
use std::{
    env,
    path::PathBuf,
    sync::{Arc, Mutex},
};
use tokio::io::{self, AsyncBufReadExt, AsyncWriteExt, BufReader};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.get(1).map(String::as_str) == Some("control") {
        let socket = args
            .get(2)
            .ok_or_else(|| anyhow::anyhow!("socket path is required"))?;
        let stream = tokio::net::UnixStream::connect(socket).await?;
        let (reader, mut writer) = stream.into_split();
        let mut input = BufReader::new(io::stdin()).lines();
        let mut output = BufReader::new(reader).lines();
        while let Some(line) = input.next_line().await? {
            writer.write_all(line.as_bytes()).await?;
            writer.write_all(b"\n").await?;
            if let Some(response) = output.next_line().await? {
                println!("{response}");
            }
        }
        return Ok(());
    }

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
    let handler = Arc::new(dohd::dns::DohHandler::new(config.clone())?);
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
    let web_address = env::var("DOHD_WEB_ADDRESS")
        .unwrap_or_else(|_| "127.0.0.1:8080".to_string())
        .parse()?;
    let web_root = env::var_os("DOHD_WEB_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("webroot"));
    let web_state = dohd::web::WebState {
        config: config.clone(),
        cache: Arc::clone(&cache),
        runtime: Arc::clone(&runtime),
        web_root,
    };
    tokio::spawn(async move {
        if let Err(error) = dohd::web::serve_web(web_state, web_address).await {
            tracing::error!(%error, "web UI stopped");
        }
    });
    control::serve(&socket, config, cache, runtime).await?;
    Ok(())
}
