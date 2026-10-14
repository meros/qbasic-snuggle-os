//! A scripted chat user for the tests: bob joins lobby, waits for carol, and
//! talks to her. Exits 0 when carol's direct message came back answered.
//!
//!   snuggle-chat-peer <server port> [seconds to wait, default 180]

use std::io::{Read, Write};
use std::net::TcpStream;
use std::process::exit;
use std::thread::sleep;
use std::time::{Duration, Instant};

fn send(s: &mut TcpStream, line: &str) {
    let _ = s.write_all(format!("{}\r\n", line).as_bytes());
}

fn main() {
    let mut args = std::env::args().skip(1);
    let port: u16 = args.next().and_then(|p| p.parse().ok()).unwrap_or_else(|| {
        eprintln!("usage: snuggle-chat-peer <port> [seconds]");
        exit(2)
    });
    let wait: u64 = args.next().and_then(|p| p.parse().ok()).unwrap_or(180);
    let mut s = TcpStream::connect(("127.0.0.1", port)).expect("cannot connect");
    s.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
    send(&mut s, "NAME bob");
    send(&mut s, "JOIN lobby");
    let deadline = Instant::now() + Duration::from_secs(wait);
    let mut buf = Vec::new();
    let mut sent = false;
    let mut chunk = [0u8; 1024];
    while Instant::now() < deadline {
        match s.read(&mut chunk) {
            Ok(0) => exit(1),
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
            Err(_) => continue, // the read timed out
        }
        while let Some(p) = buf.iter().position(|&b| b == b'\n') {
            let line: Vec<u8> = buf.drain(..=p).collect();
            let line = String::from_utf8_lossy(&line).trim().to_string();
            if line.starts_with("JOIN lobby carol") && !sent {
                sent = true;
                sleep(Duration::from_secs(1));
                send(&mut s, "MSG lobby hello from bob");
                sleep(Duration::from_secs(1));
                send(&mut s, "DM carol psst");
            }
            if line.starts_with("DM ") && line.contains("thanks") {
                sleep(Duration::from_secs(2));
                exit(0);
            }
        }
    }
    exit(1);
}
