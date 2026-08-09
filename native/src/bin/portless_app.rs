//! Local desktop UI (HTTP) when Flutter macOS cannot build without full Xcode.
//! Opens in the default browser and uses the same Rust core.

use portless_core::ai;
use portless_core::models::PortProcess;
use portless_core::{find_available_ports, find_port, nearest_available, snapshot, terminate};
use serde_json::json;
use std::io::{Cursor, Read};
use std::net::SocketAddr;
use std::process::Command;
use tiny_http::{Header, Method, Response, Server, StatusCode};

fn main() {
    let port = pick_ui_port();
    // 0.0.0.0 so phones / other machines on LAN can open the UI.
    // Override: PORTLESS_HOST=127.0.0.1 for localhost-only.
    let host = std::env::var("PORTLESS_HOST").unwrap_or_else(|_| "0.0.0.0".into());
    let addr = format!("{host}:{port}");
    let server = Server::http(&addr).expect("failed to bind Portless UI server");
    let local_url = format!("http://127.0.0.1:{port}");
    println!("Portless UI → {local_url}");
    for lan in lan_urls(port) {
        println!("         LAN → {lan}");
    }
    open_browser(&local_url);

    for mut request in server.incoming_requests() {
        let method = request.method().clone();
        let url_path = request.url().to_string();
        let (path, query) = split_query(&url_path);

        // POST needs body first
        if method == Method::Post {
            let mut body = String::new();
            let _ = request.as_reader().read_to_string(&mut body);
            let response = handle_post(&path, &body);
            let _ = request.respond(response);
            continue;
        }

        let response = match (method, path.as_str()) {
            (Method::Get, "/") | (Method::Get, "/index.html") => html_response(INDEX_HTML),
            (Method::Get, "/api/list") => json_response(match snapshot() {
                Ok(s) => serde_json::to_value(s).unwrap_or(json!({"error":"encode"})),
                Err(e) => json!({"error": e}),
            }),
            (Method::Get, "/api/find") => {
                let p = query_u16(&query, "port").unwrap_or(3000);
                json_response(match find_port(p) {
                    Ok(items) => json!({"port": p, "count": items.len(), "items": items}),
                    Err(e) => json!({"error": e}),
                })
            }
            (Method::Get, "/api/free") => {
                let from = query_u16(&query, "from").unwrap_or(3000);
                let count = query_u16(&query, "count").unwrap_or(5) as usize;
                json_response(match find_available_ports(from, count) {
                    Ok(available) => {
                        let nearest = nearest_available(from).ok().flatten();
                        json!({"requested": from, "available": available, "nearest": nearest})
                    }
                    Err(e) => json!({"error": e}),
                })
            }
            (Method::Get, "/api/ping") => {
                json_response(json!({"ok": true, "name": "portless_app"}))
            }
            (Method::Get, "/api/ai/status") => {
                json_response(serde_json::to_value(ai::status()).unwrap_or(json!({})))
            }
            _ => Response::from_string("not found").with_status_code(StatusCode(404)),
        };
        let _ = request.respond(response);
    }
}

fn handle_post(path: &str, body: &str) -> Response<Cursor<Vec<u8>>> {
    let v: serde_json::Value = serde_json::from_str(body).unwrap_or(json!({}));
    match path {
        "/api/kill" => {
            let pid = v.get("pid").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
            let force = v.get("force").and_then(|x| x.as_bool()).unwrap_or(false);
            if pid == 0 {
                return json_response(json!({"ok": false, "message": "missing pid"}));
            }
            json_response(match terminate(pid, force) {
                Ok(()) => json!({
                    "ok": true,
                    "message": if force {
                        format!("SIGKILL sent to {pid}")
                    } else {
                        format!("SIGTERM sent to {pid}")
                    }
                }),
                Err(e) => json!({"ok": false, "message": e}),
            })
        }
        "/api/reveal" => {
            let p = v.get("path").and_then(|x| x.as_str()).unwrap_or("");
            if p.is_empty() {
                return json_response(json!({"ok": false, "message": "missing path"}));
            }
            json_response(
                match portless_core::action::reveal_in_file_manager(p) {
                    Ok(()) => json!({"ok": true, "message": "revealed"}),
                    Err(e) => json!({"ok": false, "message": e.to_string()}),
                },
            )
        }
        "/api/explain" => {
            // Prefer full process object from client; fallback by port+pid from live list.
            let model = v.get("model").and_then(|x| x.as_str());
            let item = if let Some(obj) = v.get("process").cloned() {
                serde_json::from_value::<PortProcess>(obj).ok()
            } else {
                None
            };
            let item = item.or_else(|| {
                let port = v.get("port").and_then(|x| x.as_u64()).unwrap_or(0) as u16;
                let pid = v.get("pid").and_then(|x| x.as_u64()).unwrap_or(0) as u32;
                if port == 0 {
                    return None;
                }
                find_port(port)
                    .ok()
                    .and_then(|list| list.into_iter().find(|p| pid == 0 || p.pid == pid))
            });
            match item {
                Some(p) => {
                    let result = ai::explain_process(&p, model);
                    json_response(serde_json::to_value(result).unwrap_or(json!({
                        "ok": false,
                        "message": "encode error"
                    })))
                }
                None => json_response(json!({
                    "ok": false,
                    "message": "缺少 process 或 port/pid"
                })),
            }
        }
        _ => Response::from_string("not found").with_status_code(StatusCode(404)),
    }
}

fn pick_ui_port() -> u16 {
    if let Ok(p) = std::env::var("PORTLESS_PORT") {
        if let Ok(n) = p.parse::<u16>() {
            return n;
        }
    }
    for p in 17870..17900 {
        // Probe on all interfaces so free-port check matches LAN bind.
        if std::net::TcpListener::bind(SocketAddr::from(([0, 0, 0, 0], p))).is_ok() {
            return p;
        }
    }
    17870
}

fn lan_urls(port: u16) -> Vec<String> {
    let mut urls = Vec::new();
    if let Ok(ifaces) = list_ipv4_addrs() {
        for ip in ifaces {
            if ip.starts_with("127.") {
                continue;
            }
            urls.push(format!("http://{ip}:{port}"));
        }
    }
    urls
}

fn list_ipv4_addrs() -> Result<Vec<String>, ()> {
    // Lightweight: parse `ifconfig` / `ip` without extra crates.
    #[cfg(target_os = "macos")]
    {
        let out = Command::new("ifconfig").output().map_err(|_| ())?;
        let s = String::from_utf8_lossy(&out.stdout);
        let mut ips = Vec::new();
        for line in s.lines() {
            let line = line.trim();
            if let Some(rest) = line.strip_prefix("inet ") {
                let ip = rest.split_whitespace().next().unwrap_or("");
                if !ip.is_empty() && ip != "127.0.0.1" {
                    ips.push(ip.to_string());
                }
            }
        }
        return Ok(ips);
    }
    #[cfg(not(target_os = "macos"))]
    {
        Ok(Vec::new())
    }
}

fn open_browser(url: &str) {
    #[cfg(target_os = "macos")]
    {
        let _ = Command::new("open").arg(url).spawn();
    }
    #[cfg(target_os = "windows")]
    {
        let _ = Command::new("cmd").args(["/C", "start", url]).spawn();
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        let _ = Command::new("xdg-open").arg(url).spawn();
    }
}

fn split_query(url: &str) -> (String, String) {
    match url.split_once('?') {
        Some((p, q)) => (p.to_string(), q.to_string()),
        None => (url.to_string(), String::new()),
    }
}

fn query_u16(query: &str, key: &str) -> Option<u16> {
    for pair in query.split('&') {
        if let Some((k, v)) = pair.split_once('=') {
            if k == key {
                return v.parse().ok();
            }
        }
    }
    None
}

fn html_response(html: &str) -> Response<Cursor<Vec<u8>>> {
    let mut res = Response::from_string(html);
    res.add_header(
        Header::from_bytes(&b"Content-Type"[..], &b"text/html; charset=utf-8"[..]).unwrap(),
    );
    res
}

fn json_response(value: serde_json::Value) -> Response<Cursor<Vec<u8>>> {
    let body = value.to_string();
    let mut res = Response::from_string(body);
    res.add_header(
        Header::from_bytes(&b"Content-Type"[..], &b"application/json; charset=utf-8"[..]).unwrap(),
    );
    res.add_header(Header::from_bytes(&b"Access-Control-Allow-Origin"[..], &b"*"[..]).unwrap());
    res
}

const INDEX_HTML: &str = include_str!("../../ui/index.html");
