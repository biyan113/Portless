use thiserror::Error;

#[derive(Debug, Error)]
pub enum ActionError {
    #[error("process {0} not found")]
    NotFound(u32),
    #[error("permission denied for pid {0}")]
    PermissionDenied(u32),
    #[error("{0}")]
    Message(String),
}

/// Soft stop (SIGTERM / graceful) or force kill (SIGKILL / TerminateProcess).
pub fn terminate(pid: u32, force: bool) -> Result<(), ActionError> {
    crate::platform::current()
        .terminate(pid, force)
        .map_err(|e| ActionError::Message(e.to_string()))
}

pub fn reveal_in_file_manager(path: &str) -> Result<(), ActionError> {
    crate::platform::current()
        .reveal_path(path)
        .map_err(|e| ActionError::Message(e.to_string()))
}
