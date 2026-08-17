//! Windows: IP Helper API for TCP/UDP tables + process metadata via sysinfo.

use super::{PlatformError, PortProvider};
use crate::dev_detect;
use crate::models::{PortProcess, PortState, ProcessDetail, Protocol};
use std::process::Command;
use sysinfo::{Pid, ProcessesToUpdate, System};
use windows::Win32::Foundation::{CloseHandle, NO_ERROR};
use windows::Win32::NetworkManagement::IpHelper::{
    GetExtendedTcpTable, GetExtendedUdpTable, MIB_TCPROW_OWNER_PID, MIB_TCPTABLE_OWNER_PID,
    MIB_UDPROW_OWNER_PID, MIB_UDPTABLE_OWNER_PID, TCP_TABLE_OWNER_PID_LISTENER,
    UDP_TABLE_OWNER_PID,
};
use windows::Win32::Networking::WinSock::AF_INET;
use windows::Win32::System::Threading::{
    OpenProcess, TerminateProcess, PROCESS_QUERY_LIMITED_INFORMATION, PROCESS_TERMINATE,
};

pub struct WindowsPortProvider;

impl PortProvider for WindowsPortProvider {
    fn listeners(&self) -> Result<Vec<PortProcess>, PlatformError> {
        let mut rows = Vec::new();
        rows.extend(tcp_listeners()?);
        rows.extend(udp_bound()?);

        let mut sys = System::new();
        sys.refresh_processes(ProcessesToUpdate::All, true);

        let mut enriched = Vec::with_capacity(rows.len());
        for mut row in rows {
            if let Some(proc) = sys.process(Pid::from_u32(row.pid)) {
                row.process_name = proc.name().to_string_lossy().to_string();
                row.executable_path = proc.exe().map(|p| p.to_string_lossy().to_string());
                let args: Vec<String> = proc
                    .cmd()
                    .iter()
                    .map(|s| s.to_string_lossy().to_string())
                    .collect();
                row.command_line = if args.is_empty() {
                    None
                } else {
                    Some(args.join(" "))
                };
                row.working_directory = proc.cwd().map(|p| p.to_string_lossy().to_string());
                row.cpu_usage = Some(proc.cpu_usage());
                row.memory_usage = Some(proc.memory());
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

        enriched.sort_by(|a, b| a.port.cmp(&b.port).then(a.pid.cmp(&b.pid)));
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
            working_directory: proc.cwd().map(|p| p.to_string_lossy().to_string()),
            cpu_usage: Some(proc.cpu_usage()),
            memory_usage: Some(proc.memory()),
            parent_pid: proc.parent().map(|p| p.as_u32()),
            start_time_ms: Some(proc.start_time().saturating_mul(1000)),
        }))
    }

    fn terminate(&self, pid: u32, _force: bool) -> Result<(), PlatformError> {
        unsafe {
            let handle = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
                .map_err(|e| PlatformError::Message(format!("OpenProcess({pid}): {e}")))?;
            let result = TerminateProcess(handle, 1);
            let _ = CloseHandle(handle);
            result.map_err(|e| PlatformError::Message(format!("TerminateProcess({pid}): {e}")))
        }
    }

    fn reveal_path(&self, path: &str) -> Result<(), PlatformError> {
        let status = Command::new("explorer")
            .arg(format!("/select,{path}"))
            .status()
            .map_err(|e| PlatformError::Message(e.to_string()))?;
        if status.success() {
            Ok(())
        } else {
            Err(PlatformError::Message(format!(
                "explorer failed for {path}"
            )))
        }
    }
}

fn tcp_listeners() -> Result<Vec<PortProcess>, PlatformError> {
    unsafe {
        let mut size: u32 = 0;
        let _ = GetExtendedTcpTable(
            None,
            &mut size,
            false,
            AF_INET.0 as u32,
            TCP_TABLE_OWNER_PID_LISTENER,
            0,
        );
        if size == 0 {
            return Ok(vec![]);
        }
        let mut buf = vec![0u8; size as usize];
        let err = GetExtendedTcpTable(
            Some(buf.as_mut_ptr() as *mut _),
            &mut size,
            false,
            AF_INET.0 as u32,
            TCP_TABLE_OWNER_PID_LISTENER,
            0,
        );
        if err != NO_ERROR.0 {
            return Err(PlatformError::Message(format!(
                "GetExtendedTcpTable error {err:?}"
            )));
        }
        let table = &*(buf.as_ptr() as *const MIB_TCPTABLE_OWNER_PID);
        let count = table.dwNumEntries as usize;
        let rows_ptr = std::ptr::addr_of!(table.table) as *const MIB_TCPROW_OWNER_PID;
        let mut out = Vec::with_capacity(count);
        for i in 0..count {
            let row = &*rows_ptr.add(i);
            let port = u16::from_be(row.dwLocalPort as u16);
            let addr = u32_to_ipv4(row.dwLocalAddr);
            out.push(PortProcess {
                port,
                protocol: Protocol::Tcp,
                address: addr,
                pid: row.dwOwningPid,
                process_name: String::new(),
                executable_path: None,
                command_line: None,
                working_directory: None,
                cpu_usage: None,
                memory_usage: None,
                state: PortState::Listen,
                stack: None,
                project_name: None,
                is_dev: false,
            });
        }
        Ok(out)
    }
}

fn udp_bound() -> Result<Vec<PortProcess>, PlatformError> {
    unsafe {
        let mut size: u32 = 0;
        let _ = GetExtendedUdpTable(
            None,
            &mut size,
            false,
            AF_INET.0 as u32,
            UDP_TABLE_OWNER_PID,
            0,
        );
        if size == 0 {
            return Ok(vec![]);
        }
        let mut buf = vec![0u8; size as usize];
        let err = GetExtendedUdpTable(
            Some(buf.as_mut_ptr() as *mut _),
            &mut size,
            false,
            AF_INET.0 as u32,
            UDP_TABLE_OWNER_PID,
            0,
        );
        if err != NO_ERROR.0 {
            return Err(PlatformError::Message(format!(
                "GetExtendedUdpTable error {err:?}"
            )));
        }
        let table = &*(buf.as_ptr() as *const MIB_UDPTABLE_OWNER_PID);
        let count = table.dwNumEntries as usize;
        let rows_ptr = std::ptr::addr_of!(table.table) as *const MIB_UDPROW_OWNER_PID;
        let mut out = Vec::with_capacity(count);
        for i in 0..count {
            let row = &*rows_ptr.add(i);
            let port = u16::from_be(row.dwLocalPort as u16);
            // Skip ephemeral client-ish UDP noise above common range if desired later
            let addr = u32_to_ipv4(row.dwLocalAddr);
            out.push(PortProcess {
                port,
                protocol: Protocol::Udp,
                address: addr,
                pid: row.dwOwningPid,
                process_name: String::new(),
                executable_path: None,
                command_line: None,
                working_directory: None,
                cpu_usage: None,
                memory_usage: None,
                state: PortState::Listen,
                stack: None,
                project_name: None,
                is_dev: false,
            });
        }
        Ok(out)
    }
}

fn u32_to_ipv4(addr: u32) -> String {
    let b = addr.to_ne_bytes();
    format!("{}.{}.{}.{}", b[0], b[1], b[2], b[3])
}
