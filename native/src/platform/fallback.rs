use super::{PlatformError, PortProvider};
use crate::models::{PortProcess, ProcessDetail};

pub struct FallbackPortProvider;

impl PortProvider for FallbackPortProvider {
    fn listeners(&self) -> Result<Vec<PortProcess>, PlatformError> {
        Err(PlatformError::Message(
            "Portless core supports macOS and Windows only in this build".into(),
        ))
    }

    fn process_detail(&self, _pid: u32) -> Result<Option<ProcessDetail>, PlatformError> {
        Ok(None)
    }

    fn terminate(&self, _pid: u32, _force: bool) -> Result<(), PlatformError> {
        Err(PlatformError::Message("unsupported platform".into()))
    }

    fn reveal_path(&self, _path: &str) -> Result<(), PlatformError> {
        Err(PlatformError::Message("unsupported platform".into()))
    }
}
