use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Protocol {
    Tcp,
    Udp,
}

impl std::fmt::Display for Protocol {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Protocol::Tcp => write!(f, "tcp"),
            Protocol::Udp => write!(f, "udp"),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum PortState {
    Listen,
    Established,
    CloseWait,
    TimeWait,
    Other,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PortProcess {
    pub port: u16,
    pub protocol: Protocol,
    pub address: String,
    pub pid: u32,
    pub process_name: String,
    pub executable_path: Option<String>,
    pub command_line: Option<String>,
    pub working_directory: Option<String>,
    pub cpu_usage: Option<f32>,
    pub memory_usage: Option<u64>,
    pub state: PortState,
    /// Friendly stack name e.g. Vite / Next.js / PostgreSQL
    pub stack: Option<String>,
    /// Project folder name when cwd is known
    pub project_name: Option<String>,
    /// Whether this looks like a local dev service
    pub is_dev: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PortSnapshot {
    pub scanned_at_ms: u64,
    pub count: usize,
    pub items: Vec<PortProcess>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PortDiff {
    pub added: Vec<PortProcess>,
    pub removed: Vec<PortProcess>,
    pub updated: Vec<PortProcess>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProcessDetail {
    pub pid: u32,
    pub name: String,
    pub executable_path: Option<String>,
    pub command_line: Option<String>,
    pub working_directory: Option<String>,
    pub cpu_usage: Option<f32>,
    pub memory_usage: Option<u64>,
    pub parent_pid: Option<u32>,
    pub start_time_ms: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FreePortResult {
    pub requested: u16,
    pub available: Vec<u16>,
    pub nearest: Option<u16>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActionResult {
    pub ok: bool,
    pub message: String,
}
