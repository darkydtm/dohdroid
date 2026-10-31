use std::{
    fs,
    net::IpAddr,
    path::{Path, PathBuf},
    sync::{Arc, RwLock},
    time::Duration,
};

use serde::{Deserialize, Serialize};
use url::Url;

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum FallbackMode {
    #[default]
    System,
    Servfail,
    Disabled,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct ResolverConfig {
    pub name: String,
    pub url: String,
    pub bootstrap_ips: Vec<String>,
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_cooldown")]
    pub cooldown_seconds: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Config {
    #[serde(default = "default_listen_address")]
    pub listen_address: String,
    #[serde(default = "default_listen_port")]
    pub listen_port: u16,
    #[serde(default = "default_timeout")]
    pub connect_timeout_ms: u64,
    #[serde(default = "default_timeout")]
    pub request_timeout_ms: u64,
    #[serde(default = "default_true")]
    pub cache_enabled: bool,
    #[serde(default = "default_cache_capacity")]
    pub cache_capacity: usize,
    #[serde(default)]
    pub fallback_mode: FallbackMode,
    #[serde(default)]
    pub resolver_history: Vec<String>,
    #[serde(default)]
    pub resolvers: Vec<ResolverConfig>,
}

fn default_true() -> bool {
    true
}
fn default_listen_address() -> String {
    "127.0.0.1".into()
}
fn default_listen_port() -> u16 {
    5353
}
fn default_timeout() -> u64 {
    5000
}
fn default_cache_capacity() -> usize {
    4096
}
fn default_cooldown() -> u64 {
    30
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("read configuration: {0}")]
    Io(#[from] std::io::Error),
    #[error("parse configuration: {0}")]
    Parse(#[from] toml::de::Error),
    #[error("serialize configuration: {0}")]
    Serialize(#[from] toml::ser::Error),
    #[error("invalid configuration ({code:?}): {message}")]
    Invalid {
        code: ConfigErrorCode,
        message: String,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfigErrorCode {
    ListenAddress,
    Timeout,
    CacheCapacity,
    ResolverName,
    ResolverUrl,
    BootstrapIp,
}

fn invalid(code: ConfigErrorCode, message: impl Into<String>) -> ConfigError {
    ConfigError::Invalid {
        code,
        message: message.into(),
    }
}

impl Config {
    pub fn validate(&self) -> Result<(), ConfigError> {
        self.validate_address()?;
        self.validate_timeouts()?;
        self.validate_cache()?;
        self.validate_resolvers()
    }

    fn validate_address(&self) -> Result<(), ConfigError> {
        if self.listen_address != "127.0.0.1" {
            return Err(invalid(
                ConfigErrorCode::ListenAddress,
                "listen_address must be 127.0.0.1",
            ));
        }
        Ok(())
    }

    fn validate_timeouts(&self) -> Result<(), ConfigError> {
        if self.connect_timeout_ms == 0
            || self.connect_timeout_ms > 60_000
            || self.request_timeout_ms == 0
            || self.request_timeout_ms > 60_000
        {
            return Err(invalid(
                ConfigErrorCode::Timeout,
                "timeouts must be between 1 and 60000 ms",
            ));
        }
        Ok(())
    }

    fn validate_cache(&self) -> Result<(), ConfigError> {
        if self.cache_capacity == 0 || self.cache_capacity > 1_000_000 {
            return Err(invalid(
                ConfigErrorCode::CacheCapacity,
                "cache_capacity is out of bounds",
            ));
        }
        Ok(())
    }

    fn validate_resolvers(&self) -> Result<(), ConfigError> {
        let mut names = std::collections::HashSet::new();
        for resolver in &self.resolvers {
            if resolver.name.is_empty() || !names.insert(&resolver.name) {
                return Err(invalid(
                    ConfigErrorCode::ResolverName,
                    "resolver names must be unique and non-empty",
                ));
            }
            let url = Url::parse(&resolver.url)
                .map_err(|error| invalid(ConfigErrorCode::ResolverUrl, error.to_string()))?;
            if url.scheme() != "https" || url.host_str().is_none() {
                return Err(invalid(
                    ConfigErrorCode::ResolverUrl,
                    format!("resolver {} must use HTTPS", resolver.name),
                ));
            }
            for ip in &resolver.bootstrap_ips {
                ip.parse::<IpAddr>().map_err(|_| {
                    invalid(
                        ConfigErrorCode::BootstrapIp,
                        format!("invalid bootstrap IP: {ip}"),
                    )
                })?;
            }
        }
        Ok(())
    }

    pub fn connect_timeout(&self) -> Duration {
        Duration::from_millis(self.connect_timeout_ms)
    }
    pub fn request_timeout(&self) -> Duration {
        Duration::from_millis(self.request_timeout_ms)
    }
}

#[derive(Clone)]
pub struct ConfigStore {
    path: PathBuf,
    current: Arc<RwLock<Config>>,
}

fn normalize_history(history: impl IntoIterator<Item = String>) -> Vec<String> {
    let mut unique = std::collections::HashSet::new();
    history
        .into_iter()
        .filter(|url| !url.is_empty() && unique.insert(url.clone()))
        .take(50)
        .collect()
}

impl ConfigStore {
    pub fn load(path: impl AsRef<Path>) -> Result<Self, ConfigError> {
        let path = path.as_ref().to_path_buf();
        let mut config: Config = toml::from_str(&fs::read_to_string(&path)?)?;
        config.resolver_history = normalize_history(config.resolver_history);
        config.validate()?;
        Ok(Self {
            path,
            current: Arc::new(RwLock::new(config)),
        })
    }
    pub fn snapshot(&self) -> Config {
        self.current
            .read()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clone()
    }
    pub fn replace(&self, mut config: Config) -> Result<(), ConfigError> {
        config.validate()?;
        let previous_history = self
            .current
            .read()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .resolver_history
            .clone();
        config.resolver_history = normalize_history(previous_history);

        for resolver in config.resolvers.iter().filter(|resolver| resolver.enabled) {
            config.resolver_history.retain(|url| url != &resolver.url);
            config.resolver_history.insert(0, resolver.url.clone());
        }
        config.resolver_history = normalize_history(config.resolver_history);
        let data = toml::to_string_pretty(&config)?;
        let temp = self.path.with_extension("toml.tmp");
        fs::write(&temp, data)?;
        fs::rename(&temp, &self.path)?;
        *self
            .current
            .write()
            .unwrap_or_else(std::sync::PoisonError::into_inner) = config;
        Ok(())
    }
    pub fn reload(&self) -> Result<(), ConfigError> {
        let mut config: Config = toml::from_str(&fs::read_to_string(&self.path)?)?;
        config.resolver_history = normalize_history(config.resolver_history);
        config.validate()?;
        *self
            .current
            .write()
            .unwrap_or_else(std::sync::PoisonError::into_inner) = config;
        Ok(())
    }
}
