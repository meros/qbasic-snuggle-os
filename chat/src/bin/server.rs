//! The chat server: names, rooms and direct messages over plain TCP lines.
//!
//!   snuggle-chat-server [--listen 127.0.0.1:7000]

use snuggle_chat::{clean_line, Hub, MAX_LINE};
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::mpsc::channel;
use std::sync::{Arc, Mutex};
use std::thread;

fn serve(stream: TcpStream, hub: Arc<Mutex<Hub>>) {
    let (tx, rx) = channel::<String>();
    let id = hub.lock().unwrap().connect(tx);
    let mut out = match stream.try_clone() {
        Ok(s) => s,
        Err(_) => return,
    };
    thread::spawn(move || {
        for line in rx {
            if out.write_all(format!("{}\r\n", line).as_bytes()).is_err() {
                break;
            }
        }
    });
    let mut input = BufReader::new(stream);
    loop {
        let mut raw = Vec::new();
        // a line, at most MAX_LINE bytes more than it needs
        match (&mut input).take(MAX_LINE as u64 * 2).read_until(b'\n', &mut raw) {
            Ok(0) | Err(_) => break,
            Ok(_) => {}
        }
        let line = clean_line(&String::from_utf8_lossy(&raw));
        hub.lock().unwrap().handle(id, &line);
    }
    hub.lock().unwrap().disconnect(id);
}

fn main() {
    let mut listen = "127.0.0.1:7000".to_string();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        if a == "--listen" {
            listen = args.next().expect("--listen needs an address");
        } else {
            eprintln!("usage: snuggle-chat-server [--listen ADDR]");
            std::process::exit(2);
        }
    }
    let listener = TcpListener::bind(&listen).expect("cannot listen");
    eprintln!("snuggle-chat-server listening on {}", listener.local_addr().unwrap());
    let hub = Arc::new(Mutex::new(Hub::new()));
    for stream in listener.incoming().flatten() {
        let hub = hub.clone();
        thread::spawn(move || serve(stream, hub));
    }
}
