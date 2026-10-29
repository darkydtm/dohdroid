pub const VERSION: &str = env!("CARGO_PKG_VERSION");

pub mod cache;
pub mod config;
pub mod control;
pub mod dns;
pub mod doh;
pub mod resolver;
pub mod runtime;
pub mod web;
