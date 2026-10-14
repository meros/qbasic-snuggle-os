//! The chat tests: the real server and relay with DOSBox's serial port on the
//! relay, a scripted peer, and the Chat app in QBasic. The programs are the
//! test groups `chat` and `chatloss`.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, sleep};
use std::time::Duration;

pub const SERVER_PORT: u16 = 17000;
pub const SERIAL_PORT: u16 = 17001;

/// Where the chat programs are: next to this one, or on PATH.
fn find(name: &str) -> PathBuf {
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let p = dir.join(name);
            if p.exists() {
                return p;
            }
        }
    }
    PathBuf::from(name)
}

fn spawn(name: &str, args: &[String]) -> Result<Child, String> {
    Command::new(find(name))
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("cannot start {}: {}", name, e))
}

pub fn server() -> Result<Child, String> {
    let c = spawn(
        "snuggle-chat-server",
        &["--listen".into(), format!("127.0.0.1:{}", SERVER_PORT)],
    )?;
    sleep(Duration::from_millis(400));
    Ok(c)
}

pub fn relay() -> Result<Child, String> {
    spawn(
        "snuggle-chat-relay",
        &[
            "--serial".into(),
            format!("127.0.0.1:{}", SERIAL_PORT),
            "--server".into(),
            format!("127.0.0.1:{}", SERVER_PORT),
        ],
    )
}

pub fn peer() -> Result<Child, String> {
    spawn("snuggle-chat-peer", &[SERVER_PORT.to_string()])
}

pub fn dosbox_serial() -> String {
    format!("nullmodem port:{} transparent:1", SERIAL_PORT)
}

fn kill(c: &mut Child) {
    let _ = c.kill();
    let _ = c.wait();
}

/// What the `chat` group needs while it runs: server, relay, peer.
pub struct ChatRig {
    children: Vec<Child>,
}

impl ChatRig {
    pub fn start() -> Result<ChatRig, String> {
        let s = server()?;
        let r = relay()?;
        sleep(Duration::from_millis(400));
        let p = peer()?;
        Ok(ChatRig {
            children: vec![s, r, p],
        })
    }
}

impl Drop for ChatRig {
    fn drop(&mut self) {
        for c in &mut self.children {
            kill(c);
        }
    }
}

/// What the `chatloss` group needs: a server, and a relay that the program
/// starts and stops by making files (START.TXT, STOP.TXT, START2.TXT).
pub struct LossRig {
    stop: Arc<AtomicBool>,
    watcher: Option<thread::JoinHandle<()>>,
    server: Child,
}

impl LossRig {
    pub fn start(work: &Path) -> Result<LossRig, String> {
        for f in ["START.TXT", "STOP.TXT", "START2.TXT"] {
            let _ = fs::remove_file(work.join(f));
        }
        let server = server()?;
        let stop = Arc::new(AtomicBool::new(false));
        let (flag, dir) = (stop.clone(), work.to_path_buf());
        let watcher = thread::spawn(move || {
            let wait_for = |f: &str| -> bool {
                while !flag.load(Ordering::SeqCst) {
                    if dir.join(f).exists() {
                        return true;
                    }
                    sleep(Duration::from_millis(250));
                }
                false
            };
            let mut relay: Option<Child> = None;
            if wait_for("START.TXT") {
                relay = relay_or_none();
                if wait_for("STOP.TXT") {
                    if let Some(r) = relay.as_mut() {
                        kill(r);
                    }
                    if wait_for("START2.TXT") {
                        relay = relay_or_none();
                    }
                }
            }
            while !flag.load(Ordering::SeqCst) {
                sleep(Duration::from_millis(250));
            }
            if let Some(r) = relay.as_mut() {
                kill(r);
            }
        });
        Ok(LossRig {
            stop,
            watcher: Some(watcher),
            server,
        })
    }
}

fn relay_or_none() -> Option<Child> {
    relay().ok()
}

impl Drop for LossRig {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        if let Some(w) = self.watcher.take() {
            let _ = w.join();
        }
        kill(&mut self.server);
    }
}
