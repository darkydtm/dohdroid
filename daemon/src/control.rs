use crate::{
    cache::DnsCache,
    config::{Config, ConfigStore},
    runtime::Runtime,
};
use serde::{Deserialize, Serialize};
use std::{
    io,
    path::Path,
    sync::{Arc, Mutex},
};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
};

#[derive(Debug, Deserialize)]
struct Request {
    api_version: u32,
    operation: String,
    config: Option<Config>,
}

#[derive(Serialize)]
struct Response<T> {
    ok: bool,
    api_version: u32,
    result: Option<T>,
    error_code: Option<String>,
}

#[derive(Debug)]
enum ControlError {
    ParseError,
    UnsupportedApiVersion,
    UnknownOperation,
    PutConfigFailed,
    SerializationFailed,
}

impl ControlError {
    fn code(&self) -> &'static str {
        match self {
            Self::ParseError => "parse_error",
            Self::UnsupportedApiVersion => "unsupported_api_version",
            Self::UnknownOperation => "unknown_operation",
            Self::PutConfigFailed => "put_config_failed",
            Self::SerializationFailed => "serialization_failed",
        }
    }
}

pub async fn serve(
    path: &Path,
    config: ConfigStore,
    cache: Arc<Mutex<DnsCache>>,
    runtime: Arc<Mutex<Runtime>>,
) -> std::io::Result<()> {
    if path.exists() {
        std::fs::remove_file(path)?;
    }
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let listener = UnixListener::bind(path)?;
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    loop {
        let (stream, _) = listener.accept().await?;
        let config = config.clone();
        let cache = Arc::clone(&cache);
        let runtime = Arc::clone(&runtime);
        tokio::spawn(async move {
            if let Err(error) = handle_client(stream, config, cache, runtime).await {
                tracing::warn!(%error, "control client connection failed");
            }
        });
    }
}

async fn handle_client(
    stream: UnixStream,
    config: ConfigStore,
    cache: Arc<Mutex<DnsCache>>,
    runtime: Arc<Mutex<Runtime>>,
) -> io::Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    while let Some(line) = lines.next_line().await? {
        let response = match parse_request(&line) {
            Ok(request) => match execute_request(request, &config, &cache, &runtime) {
                Ok(result) => success_response(result),
                Err(error) => error_response(error),
            },
            Err(error) => error_response(error),
        };
        write_response(&mut writer, response).await?;
    }
    Ok(())
}

fn parse_request(line: &str) -> Result<Request, ControlError> {
    let request: Request = serde_json::from_str(line).map_err(|_| ControlError::ParseError)?;
    if request.api_version != 1 {
        return Err(ControlError::UnsupportedApiVersion);
    }
    Ok(request)
}

fn execute_request(
    request: Request,
    config: &ConfigStore,
    cache: &Arc<Mutex<DnsCache>>,
    runtime: &Arc<Mutex<Runtime>>,
) -> Result<serde_json::Value, ControlError> {
    match request.operation.as_str() {
        "status" => serde_json::to_value(runtime.lock().unwrap().status())
            .map_err(|_| ControlError::SerializationFailed),
        "get_config" => {
            serde_json::to_value(config.snapshot()).map_err(|_| ControlError::SerializationFailed)
        }
        "put_config" => {
            let value = request.config.ok_or(ControlError::ParseError)?;
            config
                .replace(value)
                .map_err(|_| ControlError::PutConfigFailed)?;
            Ok(serde_json::json!({"saved": true}))
        }
        "clear_cache" => {
            cache.lock().unwrap().clear();
            Ok(serde_json::json!({"cleared": true}))
        }
        _ => Err(ControlError::UnknownOperation),
    }
}

fn success_response(result: serde_json::Value) -> Response<serde_json::Value> {
    Response {
        ok: true,
        api_version: 1,
        result: Some(result),
        error_code: None,
    }
}

fn error_response(error: ControlError) -> Response<serde_json::Value> {
    Response {
        ok: false,
        api_version: 1,
        result: None,
        error_code: Some(error.code().to_owned()),
    }
}

async fn write_response(
    writer: &mut tokio::net::unix::OwnedWriteHalf,
    response: Response<serde_json::Value>,
) -> io::Result<()> {
    let bytes = serde_json::to_vec(&response).map_err(io::Error::other)?;
    writer.write_all(&bytes).await?;
    writer.write_all(b"\n").await
}

#[cfg(test)]
mod tests {
    use super::{parse_request, ControlError};

    #[test]
    fn request_errors_have_distinct_codes() {
        let parse_error = parse_request("{").unwrap_err();
        let version_error = parse_request(r#"{"api_version":2,"operation":"status"}"#).unwrap_err();

        assert_eq!(parse_error.code(), "parse_error");
        assert_eq!(version_error.code(), "unsupported_api_version");
        assert_eq!(ControlError::UnknownOperation.code(), "unknown_operation");
        assert_eq!(ControlError::PutConfigFailed.code(), "put_config_failed");
        assert_ne!(parse_error.code(), version_error.code());
    }
}
