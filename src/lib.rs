pub const VERSION: &str = env!("CARGO_PKG_VERSION");

pub mod config {}
pub mod dns {}
pub mod doh {}
pub mod resolver {}
pub mod cache {}
pub mod control {}
pub mod runtime {}
