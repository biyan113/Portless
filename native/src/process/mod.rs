use crate::models::ProcessDetail;
use crate::platform;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ProcessError {
    #[error("{0}")]
    Message(String),
}

pub fn detail(pid: u32) -> Result<Option<ProcessDetail>, ProcessError> {
    platform::current()
        .process_detail(pid)
        .map_err(|e| ProcessError::Message(e.to_string()))
}
