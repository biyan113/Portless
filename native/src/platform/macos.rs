//! macOS MVP: lsof for listeners + sysinfo / ps for process metadata.
//! Later: replace lsof with libproc / sysctl native APIs.

use super::{PlatformError, PortProvider};
use crate::dev_detect;
use crate::models::{PortProcess, PortState, ProcessDetail, Protocol};
use std::process::Command;
use sysinfo::{Pid, ProcessesToUpdate, System};

pub struct MacOsPortProvider;

impl PortProvider for MacOsPortProvider {
    fn listeners(&self) -> Result<Vec<PortProcess>, PlatformError> {
        let mut rows = Vec::new();
        rows.extend(parse_lsof(
            run_lsof(&["-iTCP", "-sTCP:LISTEN"])?,
            Protocol::Tcp,
        )?);
        // UDP has no LISTEN state in the same way; list bound UDP sockets.
        rows.extend(parse_lsof(run_lsof(&["-iUDP"])?, Protocol::Udp)?);

        let mut sys = System::new();
        sys.refresh_processes(ProcessesToUpdate::All, true);

        let mut enriched = Vec::with_capacity(rows.len());
        for mut row in rows {
            if let Some(proc) = sys.process(Pid::from_u32(row.pid)) {
                row.process_name = proc.name().to_string_lossy().to_string();
                row.executable_path = proc
                    .exe()
                    .map(|p| p.to_string_lossy().to_string());
                row.command_line = {
                    let args: Vec<String> = proc
                        .cmd()
                        .iter()
                        .map(|s| s.to_string_lossy().to_string())
                        .collect();
                    if args.is_empty() {
                        None
                    } else {
                        Some(args.join(" "))
                    }
                };
                row.working_directory = proc
                    .cwd()
                    .map(|p| p.to_string_lossy().to_string())
                    .or_else(|| cwd_via_lsof(row.pid));
                row.cpu_usage = Some(proc.cpu_usage());
                row.memory_usage = Some(proc.memory());
            } else {
                // Fallback: ps
                if let Some((name, cmdline)) = ps_info(row.pid) {
                    if row.process_name.is_empty() {
                        row.process_name = name;
                    }
                    if row.command_line.is_none() {
                        row.command_line = cmdline;
                    }
                }
                if row.working_directory.is_none() {
                    row.working_directory = cwd_via_lsof(row.pid);
                }
            }

            let id = dev_detect::identify(
                &row.process_name,
                row.command_line.as_deref(),
                row.working_directory.as_deref(),
                row.executable_path.as_deref(),
            );
            row.stack = Some(id.stack);
            row.project_name = id.project_name;
            row.is_dev = id.is_dev;

            if row.process_name.is_empty() {
                row.process_name = format!("pid-{}", row.pid);
            }

            enriched.push(row);
        }

        // Deduplicate same port/protocol/pid
        enriched.sort_by(|a, b| {
            a.port
                .cmp(&b.port)
                .then(a.protocol.to_string().cmp(&b.protocol.to_string()))
                .then(a.pid.cmp(&b.pid))
        });
        enriched.dedup_by(|a, b| a.port == b.port && a.protocol == b.protocol && a.pid == b.pid);

        Ok(enriched)
    }

    fn process_detail(&self, pid: u32) -> Result<Option<ProcessDetail>, PlatformError> {
        let mut sys = System::new();
        sys.refresh_processes(ProcessesToUpdate::All, true);
        let Some(proc) = sys.process(Pid::from_u32(pid)) else {
            return Ok(None);
        };
        let cmd: Vec<String> = proc
            .cmd()
            .iter()
            .map(|s| s.to_string_lossy().to_string())
            .collect();
        Ok(Some(ProcessDetail {
            pid,
            name: proc.name().to_string_lossy().to_string(),
            executable_path: proc.exe().map(|p| p.to_string_lossy().to_string()),
            command_line: if cmd.is_empty() {
                None
            } else {
                Some(cmd.join(" "))
            },
            working_directory: proc
                .cwd()
                .map(|p| p.to_string_lossy().to_string())
                .or_else(|| cwd_via_lsof(pid)),
            cpu_usage: Some(proc.cpu_usage()),
            memory_usage: Some(proc.memory()),
            parent_pid: proc.parent().map(|p| p.as_u32()),
            start_time_ms: Some(proc.start_time().saturating_mul(1000)),
        }))
    }

    fn terminate(&self, pid: u32, force: bool) -> Result<(), PlatformError> {
        use nix::sys::signal::{kill, Signal};
        use nix::unistd::Pid as NixPid;

        let signal = if force {
            Signal::SIGKILL
        } else {
            Signal::SIGTERM
        };
        kill(NixPid::from_raw(pid as i32), signal).map_err(|e| {
            PlatformError::Message(format!(
                "failed to {} pid {pid}: {e}",
                if force { "SIGKILL" } else { "SIGTERM" }
            ))
        })
    }

    fn reveal_path(&self, path: &str) -> Result<(), PlatformError> {
        let status = Command::new("open")
            .args(["-R", path])
            .status()
            .map_err(|e| PlatformError::Message(e.to_string()))?;
        if status.success() {
            Ok(())
        } else {
            Err(PlatformError::Message(format!(
                "open -R failed for {path}"
            )))
        }
    }
}

fn run_lsof(args: &[&str]) -> Result<String, PlatformError> {
    // -F: machine-readable (p=pid, c=command, P=protocol, n=name)
    let mut full = vec!["-nP", "-FpcPn"];
    full.extend_from_slice(args);
    let output = Command::new("lsof")
        .args(&full)
        .output()
        .map_err(|e| PlatformError::Message(format!("lsof failed: {e}")))?;
    // lsof exits 1 when no matches — treat as empty
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn parse_lsof(stdout: String, protocol: Protocol) -> Result<Vec<PortProcess>, PlatformError> {
    // lsof -F records: each process starts with `p`, then fields for each FD.
    // p1234
    // cnode
    // PTCP
    // n*:5173 (LISTEN)
    let mut out = Vec::new();
    let mut pid: u32 = 0;
    let mut command = String::new();
    let mut current_proto: Option<Protocol> = None;

    for line in stdout.lines() {
        if line.is_empty() {
            continue;
        }
        let (tag, value) = line.split_at(1);
        match tag {
            "p" => {
                pid = value.parse().unwrap_or(0);
                command.clear();
                current_proto = None;
            }
            "c" => {
                command = value.to_string();
            }
            "P" => {
                current_proto = match value.to_ascii_uppercase().as_str() {
                    "TCP" => Some(Protocol::Tcp),
                    "UDP" => Some(Protocol::Udp),
                    _ => None,
                };
            }
            "n" => {
                let Some(proto) = current_proto else {
                    continue;
                };
                // Filter to requested protocol stream
                if proto != protocol {
                    continue;
                }
                if protocol == Protocol::Udp && value.contains("->") {
                    continue;
                }
                let Some((address, port, state)) = parse_name_field(value, protocol) else {
                    continue;
                };
                if pid == 0 {
                    continue;
                }
                out.push(PortProcess {
                    port,
                    protocol,
                    address,
                    pid,
                    process_name: command.clone(),
                    executable_path: None,
                    command_line: None,
                    working_directory: None,
                    cpu_usage: None,
                    memory_usage: None,
                    state,
                    stack: None,
                    project_name: None,
                    is_dev: false,
                });
            }
            _ => {}
        }
    }
    Ok(out)
}

fn parse_name_field(name: &str, protocol: Protocol) -> Option<(String, u16, PortState)> {
    // Strip state suffix: " (LISTEN)". With `-sTCP:LISTEN`, lsof -F often omits it.
    let (endpoint, state) = if let Some(idx) = name.find(" (") {
        let state_str = &name[idx..];
        let state = if state_str.contains("LISTEN") {
            PortState::Listen
        } else if state_str.contains("ESTABLISHED") {
            PortState::Established
        } else if state_str.contains("CLOSE_WAIT") {
            PortState::CloseWait
        } else if state_str.contains("TIME_WAIT") {
            PortState::TimeWait
        } else {
            PortState::Other
        };
        (&name[..idx], state)
    } else {
        // No explicit state: treat as listening/bound (our lsof filters already constrain).
        (name, PortState::Listen)
    };

    // Drop non-listen TCP if state is present and not LISTEN
    if protocol == Protocol::Tcp && state != PortState::Listen {
        return None;
    }

    // Skip wildcard-only UDP `*:*`
    if name == "*:*" || name.ends_with(":*") && !name.contains('.') && !name.contains('[') {
        // keep *:PORT but drop *:*
        if name.ends_with(":*") {
            return None;
        }
    }

    // Take left side of ->
    let local = endpoint.split("->").next()?.trim();

    // IPv6 [::1]:8080 or *:5173 or 127.0.0.1:3000
    if let Some(rest) = local.strip_prefix('[') {
        let end = rest.find(']')?;
        let addr = format!("[{}]", &rest[..end]);
        let port_part = rest[end + 1..].strip_prefix(':')?;
        let port: u16 = port_part.parse().ok()?;
        return Some((addr, port, state));
    }

    if let Some((host, port_s)) = local.rsplit_once(':') {
        let port: u16 = port_s.parse().ok()?;
        let address = if host == "*" {
            "0.0.0.0".into()
        } else {
            host.to_string()
        };
        return Some((address, port, state));
    }

    None
}

fn cwd_via_lsof(pid: u32) -> Option<String> {
    let output = Command::new("lsof")
        .args(["-a", "-p", &pid.to_string(), "-d", "cwd", "-Fn"])
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    for line in text.lines() {
        if let Some(path) = line.strip_prefix('n') {
            if path.starts_with('/') {
                return Some(path.to_string());
            }
        }
    }
    None
}

fn ps_info(pid: u32) -> Option<(String, Option<String>)> {
    let output = Command::new("ps")
        .args(["-p", &pid.to_string(), "-o", "comm=,args="])
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if text.is_empty() {
        return None;
    }
    let mut parts = text.splitn(2, char::is_whitespace);
    let comm = parts.next()?.to_string();
    let args = parts.next().map(|s| s.trim().to_string());
    Some((comm, args))
}


