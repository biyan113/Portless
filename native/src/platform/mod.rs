use crate::models::{PortProcess, ProcessDetail};
use thiserror::Error;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;
#[cfg(not(any(target_os = "macos", target_os = "windows")))]
mod fallback;

#[derive(Debug, Error)]
pub enum PlatformError {
    #[error("{0}")]
    Message(String),
}

pub trait PortProvider: Send + Sync {
    fn listeners(&self) -> Result<Vec<PortProcess>, PlatformError>;
    fn process_detail(&self, pid: u32) -> Result<Option<ProcessDetail>, PlatformError>;
    fn terminate(&self, pid: u32, force: bool) -> Result<(), PlatformError>;
    fn reveal_path(&self, path: &str) -> Result<(), PlatformError>;
}

pub fn current() -> Box<dyn PortProvider> {
    #[cfg(target_os = "macos")]
    {
        Box::new(macos::MacOsPortProvider)
    }
    #[cfg(target_os = "windows")]
    {
        Box::new(windows::WindowsPortProvider)
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        Box::new(fallback::FallbackPortProvider)
    }
}
