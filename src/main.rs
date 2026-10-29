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
    control::serve(&socket, config, cache, runtime).await?;
    Ok(())
}
