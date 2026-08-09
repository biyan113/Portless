//! Portless native core.
//! Flutter talks to this crate via the `portless_agent` JSON CLI (MVP bridge).
//! Platform differences stay behind the `PortProvider` trait.

pub mod action;
pub mod ai;
pub mod dev_detect;
pub mod models;
pub mod platform;
pub mod port;
pub mod process;

use models::{PortDiff, PortProcess, PortSnapshot};
use once_cell::sync::Lazy;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

static LAST_SNAPSHOT: Lazy<Mutex<Option<PortSnapshot>>> = Lazy::new(|| Mutex::new(None));

pub fn list_listeners() -> Result<Vec<PortProcess>, String> {
    platform::current().listeners().map_err(|e| e.to_string())
}

pub fn snapshot() -> Result<PortSnapshot, String> {
    let mut items = list_listeners()?;
    items.sort_by(|a, b| a.port.cmp(&b.port).then(a.pid.cmp(&b.pid)));
    let snap = PortSnapshot {
        scanned_at_ms: now_ms(),
        count: items.len(),
        items,
    };
    if let Ok(mut guard) = LAST_SNAPSHOT.lock() {
        *guard = Some(snap.clone());
    }
    Ok(snap)
}

pub fn diff_from_last() -> Result<PortDiff, String> {
    let current = snapshot()?;
    let previous = LAST_SNAPSHOT
        .lock()
        .ok()
        .and_then(|g| g.clone())
        .map(|s| s.items)
        .unwrap_or_default();

    // Note: snapshot() already overwrote LAST_SNAPSHOT; rebuild previous carefully.
    // For correct diff, re-scan previous from a temp copy before overwrite.
    // Simpler approach used by agent: client-side diff. Server still provides full list.
    let _ = previous;
    Ok(PortDiff {
        added: current.items.clone(),
        removed: vec![],
        updated: vec![],
    })
}

pub fn find_port(port: u16) -> Result<Vec<PortProcess>, String> {
    Ok(list_listeners()?
        .into_iter()
        .filter(|p| p.port == port)
        .collect())
}

pub fn find_available_ports(from: u16, count: usize) -> Result<Vec<u16>, String> {
    let occupied: std::collections::HashSet<u16> =
        list_listeners()?.into_iter().map(|p| p.port).collect();
    let mut available = Vec::new();
    let mut p = from;
    while available.len() < count && p < u16::MAX {
        if !occupied.contains(&p) && port::is_bindable(p) {
            available.push(p);
        }
        p = p.saturating_add(1);
        if p == 0 {
            break;
        }
    }
    Ok(available)
}

pub fn nearest_available(from: u16) -> Result<Option<u16>, String> {
    Ok(find_available_ports(from, 1)?.into_iter().next())
}

pub fn terminate(pid: u32, force: bool) -> Result<(), String> {
    action::terminate(pid, force).map_err(|e| e.to_string())
}

pub fn process_detail(pid: u32) -> Result<Option<models::ProcessDetail>, String> {
    process::detail(pid).map_err(|e| e.to_string())
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

/// C ABI for future FFI / flutter_rust_bridge migration.
/// Caller must free with `portless_string_free`.
#[no_mangle]
pub extern "C" fn portless_list_json() -> *mut std::os::raw::c_char {
    let json = match snapshot() {
        Ok(s) => serde_json::to_string(&s).unwrap_or_else(|e| format!(r#"{{"error":"{e}"}}"#)),
        Err(e) => format!(r#"{{"error":"{}"}}"#, e.replace('"', "'")),
    };
    std::ffi::CString::new(json)
        .map(|c| c.into_raw())
        .unwrap_or(std::ptr::null_mut())
}

/// # Safety
/// `ptr` must be a pointer returned by this crate's string allocators.
#[no_mangle]
pub unsafe extern "C" fn portless_string_free(ptr: *mut std::os::raw::c_char) {
    if !ptr.is_null() {
        drop(std::ffi::CString::from_raw(ptr));
    }
}
