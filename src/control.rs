use std::{path::Path, sync::{Arc, Mutex}};
use serde::{Deserialize, Serialize};
use tokio::{io::{AsyncBufReadExt, AsyncWriteExt, BufReader}, net::UnixListener};
use crate::{cache::DnsCache, config::ConfigStore, runtime::Runtime};

#[derive(Debug, Deserialize)]
struct Request { api_version: u32, operation: String }
#[derive(Serialize)]
struct Response<T> { ok: bool, api_version: u32, result: Option<T>, error_code: Option<String> }

pub async fn serve(path: &Path, config: ConfigStore, cache: Arc<Mutex<DnsCache>>, runtime: Arc<Mutex<Runtime>>) -> std::io::Result<()> {
	if path.exists() { std::fs::remove_file(path)?; }
	if let Some(parent) = path.parent() { std::fs::create_dir_all(parent)?; }
	let listener = UnixListener::bind(path)?;
	loop {
		let (stream, _) = listener.accept().await?;
		let config = config.clone(); let cache = Arc::clone(&cache); let runtime = Arc::clone(&runtime);
		tokio::spawn(async move {
			let (reader, mut writer) = stream.into_split(); let mut lines = BufReader::new(reader).lines();
			while let Ok(Some(line)) = lines.next_line().await {
				let result = serde_json::from_str::<Request>(&line).ok().filter(|r| r.api_version == 1).and_then(|r| match r.operation.as_str() { "status" => Some(serde_json::to_value(runtime.lock().unwrap().status()).unwrap()), "get_config" => Some(serde_json::to_value(config.snapshot()).unwrap()), "clear_cache" => { cache.lock().unwrap().clear(); Some(serde_json::json!({"cleared": true})) }, _ => None });
				let response = if let Some(result) = result { serde_json::to_vec(&Response { ok: true, api_version: 1, result: Some(result), error_code: None }).unwrap() } else { serde_json::to_vec(&Response::<serde_json::Value> { ok: false, api_version: 1, result: None, error_code: Some("invalid_request".into()) }).unwrap() };
				if writer.write_all(&response).await.is_err() || writer.write_all(b"\n").await.is_err() { break; }
			}
		});
	}
}
