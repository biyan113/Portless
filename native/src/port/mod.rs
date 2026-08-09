//! Port helpers independent of OS listing.

use std::net::{SocketAddr, TcpListener, UdpSocket};

/// True if we can currently bind this TCP port on localhost (ephemeral check).
pub fn is_bindable(port: u16) -> bool {
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    match TcpListener::bind(addr) {
        Ok(listener) => {
            drop(listener);
            // Also try UDP lightly — if TCP is free it's usually enough for "available".
            let _ = UdpSocket::bind(addr);
            true
        }
        Err(_) => false,
    }
}
