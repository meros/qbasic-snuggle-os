//! The host relay between Snuggle OS and the chat server.
//!
//! DOSBox listens on a TCP port for its serial port (serial1=nullmodem
//! port:7001 transparent:1) and the relay dials it. The relay keeps its own
//! connection to the chat server, reconnecting when it is lost, and tells the OS
//! what is going on:
//!   HB UP | HB DOWN   every two seconds: the relay is alive, and the connection
//!                     to the server is up or down. The status is repeated
//!                     because the OS may open its serial port after the relay
//!                     made the connection, and miss the change.
//!   STATUS UP | DOWN  when the connection to the server changes
//!   ERR 0 server down for a line from the OS that could not be sent
//! Lines are cleaned (printable ASCII, at most 200 characters) both ways, since
//! the other end is a 1999 program with a small serial buffer.
//!
//!   snuggle-chat-relay [--serial 127.0.0.1:7001] [--server 127.0.0.1:7000]

use snuggle_chat::clean_line;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{channel, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

type Uplink = Arc<Mutex<Option<TcpStream>>>;

fn session(client: TcpStream, server_addr: String) {
    let alive = Arc::new(AtomicBool::new(true));
    let up = Arc::new(AtomicBool::new(false));
    let (to_client, rx) = channel::<String>();
    let uplink: Uplink = Arc::new(Mutex::new(None));

    // everything for the OS goes through one writer
    let mut out = client.try_clone().expect("clone");
    thread::spawn(move || {
        for line in rx {
            if out.write_all(format!("{}\r\n", line).as_bytes()).is_err() {
                break;
            }
        }
    });

    // heartbeat
    {
        let (tx, alive, up) = (to_client.clone(), alive.clone(), up.clone());
        thread::spawn(move || {
            while alive.load(Ordering::SeqCst) {
                let hb = if up.load(Ordering::SeqCst) {
                    "HB UP"
                } else {
                    "HB DOWN"
                };
                if tx.send(hb.into()).is_err() {
                    break;
                }
                thread::sleep(Duration::from_secs(2));
            }
        });
    }

    // the connection to the server, kept up
    {
        let (tx, alive, uplink, up) =
            (to_client.clone(), alive.clone(), uplink.clone(), up.clone());
        thread::spawn(move || {
            while alive.load(Ordering::SeqCst) {
                match TcpStream::connect(&server_addr) {
                    Ok(s) => {
                        *uplink.lock().unwrap() = s.try_clone().ok();
                        up.store(true, Ordering::SeqCst);
                        let _ = tx.send("STATUS UP".into());
                        for line in BufReader::new(s).lines().map_while(Result::ok) {
                            let line = clean_line(&line);
                            if std::env::var_os("RELAY_TRACE").is_some() {
                                eprintln!("server -> os: {}", line);
                            }
                            if !line.is_empty() && tx.send(line).is_err() {
                                break;
                            }
                        }
                        *uplink.lock().unwrap() = None;
                        up.store(false, Ordering::SeqCst);
                        let _ = tx.send("STATUS DOWN".into());
                    }
                    Err(_) => {
                        let _ = tx.send("STATUS DOWN".into());
                    }
                }
                thread::sleep(Duration::from_secs(2));
            }
        });
    }

    // lines from the OS to the server
    forward(client, &uplink, &to_client);
    alive.store(false, Ordering::SeqCst);
}

fn forward(client: TcpStream, uplink: &Uplink, to_client: &Sender<String>) {
    for line in BufReader::new(client).lines().map_while(Result::ok) {
        let line = clean_line(&line);
        if line.is_empty() {
            continue;
        }
        if std::env::var_os("RELAY_TRACE").is_some() {
            eprintln!("os -> server: {}", line);
        }
        let sent = match uplink.lock().unwrap().as_mut() {
            Some(s) => s.write_all(format!("{}\r\n", line).as_bytes()).is_ok(),
            None => false,
        };
        if !sent {
            let _ = to_client.send("ERR 0 server down".into());
        }
    }
}

fn main() {
    let mut serial = "127.0.0.1:7001".to_string();
    let mut server = "127.0.0.1:7000".to_string();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--serial" => serial = args.next().expect("--serial needs an address"),
            "--server" => server = args.next().expect("--server needs an address"),
            _ => {
                eprintln!("usage: snuggle-chat-relay [--serial ADDR] [--server ADDR]");
                std::process::exit(2);
            }
        }
    }
    eprintln!(
        "snuggle-chat-relay: DOSBox serial {} to server {}",
        serial, server
    );
    // DOSBox listens (serial1=nullmodem port:7001); the relay dials it, and dials
    // again whenever the connection ends, so it can be started before DOSBox,
    // after it, or again after a stop. (DOSBox as a client does not retry.)
    loop {
        match TcpStream::connect(&serial) {
            Ok(client) => session(client, server.clone()),
            Err(_) => thread::sleep(Duration::from_secs(1)),
        }
    }
}
