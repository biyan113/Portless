//! JSON CLI bridge for Flutter (MVP). Replaceable by flutter_rust_bridge later.
//!
//! Commands:
//!   list
//!   find --port 3000
//!   free --from 3000 --count 5
//!   kill --pid 123 [--force]
//!   detail --pid 123
//!   reveal --path /path/to/bin
//!   explain --port 3000

use clap::{Parser, Subcommand};
use portless_core::ai::explain_process;
use portless_core::models::{ActionResult, FreePortResult};
use portless_core::{find_available_ports, find_port, list_listeners, nearest_available, process_detail, snapshot, terminate};
use serde_json::json;

#[derive(Parser)]
#[command(name = "portless_agent", version, about = "Portless native agent")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Full listening snapshot
    List,
    /// Find processes on a port
    Find {
        #[arg(long)]
        port: u16,
    },
    /// Find free ports near a preferred number
    Free {
        #[arg(long, default_value_t = 3000)]
        from: u16,
        #[arg(long, default_value_t = 5)]
        count: usize,
    },
    /// Terminate process (SIGTERM) or force (SIGKILL)
    Kill {
        #[arg(long)]
        pid: u32,
        #[arg(long, default_value_t = false)]
        force: bool,
    },
    /// Process detail by PID
    Detail {
        #[arg(long)]
        pid: u32,
    },
    /// Reveal path in Finder / Explorer
    Reveal {
        #[arg(long)]
        path: String,
    },
    /// AI (DeepSeek) 解读指定端口进程
    Explain {
        #[arg(long)]
        port: u16,
    },
    /// Quick health
    Ping,
}

fn main() {
    let cli = Cli::parse();
    let result = match cli.command {
        Commands::List => snapshot().map(|s| serde_json::to_value(s).unwrap_or(json!({}))),
        Commands::Find { port } => find_port(port).map(|items| {
            json!({
                "port": port,
                "count": items.len(),
                "items": items,
            })
        }),
        Commands::Free { from, count } => find_available_ports(from, count).and_then(|available| {
            nearest_available(from).map(|nearest| {
                serde_json::to_value(FreePortResult {
                    requested: from,
                    available,
                    nearest,
                })
                .unwrap_or(json!({}))
            })
        }),
        Commands::Kill { pid, force } => match terminate(pid, force) {
            Ok(()) => Ok(serde_json::to_value(ActionResult {
                ok: true,
                message: if force {
                    format!("SIGKILL sent to {pid}")
                } else {
                    format!("SIGTERM sent to {pid}")
                },
            })
            .unwrap()),
            Err(e) => Ok(serde_json::to_value(ActionResult {
                ok: false,
                message: e,
            })
            .unwrap()),
        },
        Commands::Detail { pid } => process_detail(pid).map(|d| serde_json::to_value(d).unwrap_or(json!(null))),
        Commands::Reveal { path } => {
            match portless_core::action::reveal_in_file_manager(&path) {
                Ok(()) => Ok(json!({"ok": true, "message": "revealed"})),
                Err(e) => Ok(json!({"ok": false, "message": e.to_string()})),
            }
        }
        Commands::Ping => {
            let _ = list_listeners();
            Ok(json!({"ok": true, "name": "portless_agent"}))
        }
        Commands::Explain { port } => match snapshot() {
            Ok(snap) => {
                if let Some(p) = snap.items.iter().find(|p| p.port == port) {
                    let result = explain_process(p, None);
                    Ok(serde_json::to_value(&result).unwrap_or_else(|_| {
                        json!({"ok": false, "message": "解读结果序列化失败"})
                    }))
                } else {
                    Ok(json!({
                        "ok": false,
                        "model": "",
                        "summary": "",
                        "raw": "",
                        "data": serde_json::Value::Null,
                        "message": format!("端口 {port} 没有监听进程")
                    }))
                }
            }
            Err(e) => Ok(json!({
                "ok": false,
                "model": "",
                "summary": "",
                "raw": "",
                "data": serde_json::Value::Null,
                "message": e
            })),
        },
    };

    match result {
        Ok(value) => {
            println!("{}", serde_json::to_string(&value).unwrap_or_else(|_| "{}".into()));
        }
        Err(e) => {
            eprintln!("{}", e);
            println!("{}", json!({"error": e}));
            std::process::exit(1);
        }
    }
}
