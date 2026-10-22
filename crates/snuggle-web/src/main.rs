//! The web host: the page that offers the original and the modern Snuggle OS,
//! and the chat server the modern one talks to. std only.
//!
//!   snuggle-web [--listen 127.0.0.1:8080] [--root DIR] [--chat-listen ADDR]
//!
//! Static files come from --root. The chat hub runs inside this process. A
//! browser has no serial port and no TCP, so the page plays the relay: it
//! carries the lines of the QBasic program (two files in the emulated disk)
//! to these two calls, one session per page:
//!
//!   POST /api/chat/<session>/send            lines for the hub, one per line
//!   GET  /api/chat/<session>/poll?since=N&epoch=E
//!                                            "<next> <epoch>\n" and the lines from N on
//!
//! The epoch names the hub connection of the session. When the server made a new
//! one (the session was dropped as idle), the page's epoch is stale: the reply
//! then starts with STATUS DOWN and STATUS UP, so the app takes its name and room
//! again, and carries every line from 0.
//!
//! A session that has not polled for 20 seconds is disconnected (its rooms see
//! LEAVE). --chat-listen also opens the plain TCP protocol (docs/CHAT.md), so
//! a native relay and a browser can share one hub.

use snuggle_chat::{Hub, MAX_LINE, clean_line};
use std::collections::{BTreeMap, VecDeque};
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Component, Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::mpsc::channel;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

const MAX_SESSIONS: usize = 200;
const MAX_LOG: usize = 400;
const IDLE: Duration = Duration::from_secs(20);
const MAX_BODY: usize = 4096;
const MAX_SESSIONS_PER_PEER: usize = 20;
const MAX_HEADERS: usize = 64;
const REQUEST_TIME: Duration = Duration::from_secs(15);
/// Open HTTP connections at once (a thread each); more are turned away with 503.
const MAX_CONNECTIONS: usize = 256;
/// Lines one session may send to the hub per RATE_WINDOW.
const MAX_LINES_PER_WINDOW: u32 = 100;
const RATE_WINDOW: Duration = Duration::from_secs(10);
/// After SIGTERM: how long running requests get before the process exits.
const DRAIN: Duration = Duration::from_secs(5);

/// Sent with every response. The CSP lets the page run js-dos (WebAssembly,
/// a worker or blob for the emulator's files) and nothing from other origins.
/// js-dos 6 starts the emulator with eval(), so 'unsafe-eval' is needed; inline
/// scripts and other origins stay blocked.
const SECURITY_HEADERS: &str = "X-Content-Type-Options: nosniff\r\n\
Referrer-Policy: no-referrer\r\n\
Cross-Origin-Opener-Policy: same-origin\r\n\
Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()\r\n\
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval'; \
style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; \
worker-src 'self' blob:; object-src 'none'; base-uri 'none'; form-action 'none'; \
frame-ancestors 'none'\r\n";

static STOP: AtomicBool = AtomicBool::new(false);
static OPEN: AtomicUsize = AtomicUsize::new(0);

struct Session {
    hub_id: u64,
    peer: String,
    log: VecDeque<String>,
    /// the number of lines dropped from the front of `log` so far
    base: usize,
    seen: Instant,
    /// start of the current rate window, and the lines sent in it
    window: Instant,
    sent: u32,
}

impl Session {
    /// Counts `n` lines against the window; false when the session sends too much.
    fn allow(&mut self, n: u32) -> bool {
        if self.window.elapsed() >= RATE_WINDOW {
            self.window = Instant::now();
            self.sent = 0;
        }
        if self.sent.saturating_add(n) > MAX_LINES_PER_WINDOW {
            return false;
        }
        self.sent += n;
        true
    }
}

struct State {
    hub: Mutex<Hub>,
    sessions: Mutex<BTreeMap<String, Arc<Mutex<Session>>>>,
}

fn session(state: &Arc<State>, sid: &str, peer: &str) -> Option<Arc<Mutex<Session>>> {
    let mut all = state.sessions.lock().unwrap();
    if let Some(s) = all.get(sid) {
        return Some(s.clone());
    }
    if all.len() >= MAX_SESSIONS {
        return None;
    }
    // one visitor cannot fill the table
    if all
        .values()
        .filter(|s| s.lock().unwrap().peer == peer)
        .count()
        >= MAX_SESSIONS_PER_PEER
    {
        return None;
    }
    let (tx, rx) = channel::<String>();
    let hub_id = state.hub.lock().unwrap().connect(tx);
    let s = Arc::new(Mutex::new(Session {
        hub_id,
        peer: peer.to_string(),
        log: VecDeque::new(),
        base: 0,
        seen: Instant::now(),
        window: Instant::now(),
        sent: 0,
    }));
    let sink = s.clone();
    // ends when the hub drops the sender (disconnect)
    thread::spawn(move || {
        for line in rx {
            let mut s = sink.lock().unwrap();
            s.log.push_back(line);
            while s.log.len() > MAX_LOG {
                s.log.pop_front();
                s.base += 1;
            }
        }
    });
    all.insert(sid.to_string(), s.clone());
    Some(s)
}

fn reap(state: Arc<State>) {
    loop {
        thread::sleep(Duration::from_secs(5));
        let mut all = state.sessions.lock().unwrap();
        let gone: Vec<String> = all
            .iter()
            .filter(|(_, s)| s.lock().unwrap().seen.elapsed() > IDLE)
            .map(|(k, _)| k.clone())
            .collect();
        for k in gone {
            if let Some(s) = all.remove(&k) {
                let id = s.lock().unwrap().hub_id;
                state.hub.lock().unwrap().disconnect(id);
            }
        }
    }
}

fn valid_sid(s: &str) -> bool {
    !s.is_empty() && s.len() <= 32 && s.chars().all(|c| c.is_ascii_alphanumeric())
}

struct Request {
    method: String,
    path: String,
    query: String,
    body: Vec<u8>,
    /// the last address of X-Forwarded-For (the one the front end added), if any
    forwarded: Option<String>,
    host: Option<String>,
    origin: Option<String>,
}

fn read_request(stream: &TcpStream) -> Option<Request> {
    let mut r = BufReader::new(stream.try_clone().ok()?);
    let mut first = String::new();
    r.by_ref().take(2048).read_line(&mut first).ok()?;
    let mut it = first.split_whitespace();
    let method = it.next()?.to_string();
    let target = it.next()?.to_string();
    let mut len = 0usize;
    let mut forwarded = None;
    let (mut host, mut origin) = (None, None);
    let started = Instant::now();
    for _ in 0..=MAX_HEADERS {
        if started.elapsed() > REQUEST_TIME {
            return None;
        }
        let mut h = String::new();
        r.by_ref().take(2048).read_line(&mut h).ok()?;
        let h = h.trim();
        if h.is_empty() {
            break;
        }
        if let Some((k, v)) = h.split_once(':') {
            if k.eq_ignore_ascii_case("content-length") {
                len = v.trim().parse().ok()?;
            } else if k.eq_ignore_ascii_case("x-forwarded-for") {
                forwarded = v.rsplit(',').next().map(|s| s.trim().to_string());
            } else if k.eq_ignore_ascii_case("host") {
                host = Some(v.trim().to_string());
            } else if k.eq_ignore_ascii_case("origin") {
                origin = Some(v.trim().to_string());
            }
        }
    }
    if len > MAX_BODY {
        return None;
    }
    let mut body = vec![0u8; len];
    r.read_exact(&mut body).ok()?;
    let (path, query) = match target.split_once('?') {
        Some((p, q)) => (p.to_string(), q.to_string()),
        None => (target, String::new()),
    };
    Some(Request {
        method,
        path,
        query,
        body,
        forwarded,
        host,
        origin,
    })
}

fn respond(mut s: &TcpStream, code: &str, ctype: &str, body: &[u8]) {
    let head = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nCache-Control: no-cache\r\n{}Connection: close\r\n\r\n",
        code,
        ctype,
        body.len(),
        SECURITY_HEADERS
    );
    let _ = s.write_all(head.as_bytes());
    let _ = s.write_all(body);
}

fn mime(p: &Path) -> &'static str {
    match p.extension().and_then(|e| e.to_str()).unwrap_or("") {
        "html" => "text/html; charset=utf-8",
        "js" => "text/javascript; charset=utf-8",
        "css" => "text/css; charset=utf-8",
        "json" => "application/json",
        "wasm" => "application/wasm",
        "zip" | "jsdos" => "application/zip",
        "png" => "image/png",
        "txt" | "bas" | "md" => "text/plain; charset=utf-8",
        _ => "application/octet-stream",
    }
}

/// The file for a URL path under root, None when it escapes root.
fn resolve(root: &Path, url: &str) -> Option<PathBuf> {
    let mut p = root.to_path_buf();
    for c in Path::new(url.trim_start_matches('/')).components() {
        match c {
            Component::Normal(n) => p.push(n),
            Component::CurDir => {}
            _ => return None,
        }
    }
    if p.is_dir() {
        p.push("index.html");
    }
    Some(p)
}

/// A browser sends Origin on a cross-site POST. It must name this host, or the
/// request is another site's page talking to our chat on a visitor's behalf.
/// No Origin (curl, a native client) passes: it is not a browser request.
fn same_origin(origin: Option<&str>, host: Option<&str>) -> bool {
    match (origin, host) {
        (None, _) => true,
        (Some(o), Some(h)) => o
            .split_once("://")
            .is_some_and(|(_, rest)| rest.eq_ignore_ascii_case(h)),
        (Some(_), None) => false,
    }
}

fn param(query: &str, name: &str) -> u64 {
    query
        .split('&')
        .find_map(|kv| kv.strip_prefix(name).and_then(|r| r.strip_prefix('=')))
        .and_then(|v| v.parse().ok())
        .unwrap_or(0)
}

fn api(state: &Arc<State>, stream: &TcpStream, req: &Request) {
    // /api/chat/<sid>/<send|poll>
    let parts: Vec<&str> = req.path.trim_matches('/').split('/').collect();
    if parts.len() != 4 || parts[1] != "chat" || !valid_sid(parts[2]) {
        return respond(stream, "404 Not Found", "text/plain", b"not found\n");
    }
    if !matches!(
        (req.method.as_str(), parts[3]),
        ("POST", "send") | ("GET", "poll")
    ) {
        return respond(stream, "405 Method Not Allowed", "text/plain", b"no\n");
    }
    if req.method == "POST" && !same_origin(req.origin.as_deref(), req.host.as_deref()) {
        return respond(stream, "403 Forbidden", "text/plain", b"cross-origin\n");
    }
    let peer = match &req.forwarded {
        Some(f) => f.clone(),
        None => stream
            .peer_addr()
            .map(|a| a.ip().to_string())
            .unwrap_or_default(),
    };
    let s = match session(state, parts[2], &peer) {
        Some(s) => s,
        None => return respond(stream, "503 Service Unavailable", "text/plain", b"full\n"),
    };
    s.lock().unwrap().seen = Instant::now();
    match (req.method.as_str(), parts[3]) {
        ("POST", "send") => {
            let id = s.lock().unwrap().hub_id;
            let text = String::from_utf8_lossy(&req.body).to_string();
            let n = text
                .split('\n')
                .take(20)
                .filter(|l| !l.trim().is_empty())
                .count();
            if !s.lock().unwrap().allow(n as u32) {
                return respond(
                    stream,
                    "429 Too Many Requests",
                    "text/plain",
                    b"slow down\n",
                );
            }
            for raw in text.split('\n').take(20) {
                let line = clean_line(raw);
                if !line.is_empty() && line.len() <= MAX_LINE {
                    state.hub.lock().unwrap().handle(id, &line);
                }
            }
            respond(stream, "200 OK", "text/plain", b"ok\n");
        }
        ("GET", "poll") => {
            let epoch = param(&req.query, "epoch");
            let s = s.lock().unwrap();
            // a page that knows an older connection starts over, from line 0
            let stale = epoch != 0 && epoch != s.hub_id;
            let from = if stale {
                0
            } else {
                param(&req.query, "since") as usize
            };
            let next = s.base + s.log.len();
            let skip = from.saturating_sub(s.base);
            let mut out = format!("{} {}\n", next, s.hub_id);
            if stale {
                out.push_str("STATUS DOWN\nSTATUS UP\n");
            }
            for l in s.log.iter().skip(skip) {
                out.push_str(l);
                out.push('\n');
            }
            respond(stream, "200 OK", "text/plain", out.as_bytes());
        }
        _ => respond(stream, "405 Method Not Allowed", "text/plain", b"no\n"),
    }
}

fn handle(state: Arc<State>, root: PathBuf, stream: TcpStream) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(10)));
    let req = match read_request(&stream) {
        Some(r) => r,
        None => return respond(&stream, "400 Bad Request", "text/plain", b"bad request\n"),
    };
    // Cloud Run reserves paths that end in z, so not /healthz
    if req.path == "/health" {
        return respond(&stream, "200 OK", "text/plain", b"ok\n");
    }
    if req.path.starts_with("/api/") {
        return api(&state, &stream, &req);
    }
    if req.method != "GET" {
        return respond(&stream, "405 Method Not Allowed", "text/plain", b"no\n");
    }
    match resolve(&root, &req.path).and_then(|p| fs::read(&p).ok().map(|b| (p, b))) {
        Some((p, b)) => respond(&stream, "200 OK", mime(&p), &b),
        None => respond(&stream, "404 Not Found", "text/plain", b"not found\n"),
    }
}

/// The plain TCP chat protocol on the same hub (what snuggle-chat-server does).
fn tcp_chat(state: Arc<State>, listener: TcpListener) {
    for stream in listener.incoming().flatten() {
        let state = state.clone();
        thread::spawn(move || {
            let (tx, rx) = channel::<String>();
            let id = state.hub.lock().unwrap().connect(tx);
            if let Ok(mut out) = stream.try_clone() {
                thread::spawn(move || {
                    for line in rx {
                        if out.write_all(format!("{}\r\n", line).as_bytes()).is_err() {
                            break;
                        }
                    }
                });
            }
            let mut input = BufReader::new(stream);
            loop {
                let mut raw = Vec::new();
                match (&mut input)
                    .take(MAX_LINE as u64 * 2)
                    .read_until(b'\n', &mut raw)
                {
                    Ok(0) | Err(_) => break,
                    Ok(_) => {}
                }
                let line = clean_line(&String::from_utf8_lossy(&raw));
                state.hub.lock().unwrap().handle(id, &line);
            }
            state.hub.lock().unwrap().disconnect(id);
        });
    }
}

fn main() {
    let mut listen = "127.0.0.1:8080".to_string();
    let mut root = PathBuf::from("web");
    let mut chat: Option<String> = None;
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--listen" => listen = args.next().expect("--listen needs an address"),
            "--root" => root = PathBuf::from(args.next().expect("--root needs a directory")),
            "--chat-listen" => chat = Some(args.next().expect("--chat-listen needs an address")),
            _ => {
                eprintln!("usage: snuggle-web [--listen ADDR] [--root DIR] [--chat-listen ADDR]");
                std::process::exit(2);
            }
        }
    }
    let state = Arc::new(State {
        hub: Mutex::new(Hub::new()),
        sessions: Mutex::new(BTreeMap::new()),
    });
    {
        let state = state.clone();
        thread::spawn(move || reap(state));
    }
    if let Some(addr) = chat {
        let l = TcpListener::bind(&addr).expect("cannot listen for chat");
        eprintln!("snuggle-web: chat protocol on {}", l.local_addr().unwrap());
        let state = state.clone();
        thread::spawn(move || tcp_chat(state, l));
    }
    let listener = TcpListener::bind(&listen).expect("cannot listen");
    eprintln!(
        "snuggle-web: http://{} (files from {})",
        listener.local_addr().unwrap(),
        root.display()
    );
    install_sigterm();
    listener
        .set_nonblocking(true)
        .expect("cannot make the listener non-blocking");
    while !STOP.load(Ordering::SeqCst) {
        let stream = match listener.accept() {
            Ok((s, _)) => s,
            Err(_) => {
                thread::sleep(Duration::from_millis(20));
                continue;
            }
        };
        let _ = stream.set_nonblocking(false);
        if OPEN.fetch_add(1, Ordering::SeqCst) >= MAX_CONNECTIONS {
            OPEN.fetch_sub(1, Ordering::SeqCst);
            respond(&stream, "503 Service Unavailable", "text/plain", b"busy\n");
            continue;
        }
        let (state, root) = (state.clone(), root.clone());
        thread::spawn(move || {
            handle(state, root, stream);
            OPEN.fetch_sub(1, Ordering::SeqCst);
        });
    }
    // SIGTERM: no new connections; let the running requests finish
    eprintln!("snuggle-web: stopping");
    let until = Instant::now() + DRAIN;
    while OPEN.load(Ordering::SeqCst) > 0 && Instant::now() < until {
        thread::sleep(Duration::from_millis(50));
    }
}

extern "C" fn on_sigterm(_: i32) {
    STOP.store(true, Ordering::SeqCst);
}

#[cfg(unix)]
fn install_sigterm() {
    unsafe extern "C" {
        fn signal(signum: i32, handler: extern "C" fn(i32)) -> usize;
    }
    // SIGINT 2, SIGTERM 15. The handler only sets an atomic flag.
    unsafe {
        signal(15, on_sigterm);
        signal(2, on_sigterm);
    }
}

#[cfg(not(unix))]
fn install_sigterm() {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn paths_cannot_leave_the_root() {
        let root = Path::new("/srv/web");
        assert!(resolve(root, "/../etc/passwd").is_none());
        assert!(resolve(root, "/a/../../b").is_none());
        assert_eq!(
            resolve(root, "/js/app.js").unwrap(),
            Path::new("/srv/web/js/app.js")
        );
    }

    #[test]
    fn params_are_read_from_the_query() {
        assert_eq!(param("since=12", "since"), 12);
        assert_eq!(param("x=1&since=3&epoch=9", "epoch"), 9);
        assert_eq!(param("", "since"), 0);
        assert_eq!(param("xsince=4", "since"), 0);
    }

    #[test]
    fn one_peer_cannot_fill_the_session_table() {
        let state = Arc::new(State {
            hub: Mutex::new(Hub::new()),
            sessions: Mutex::new(BTreeMap::new()),
        });
        for i in 0..MAX_SESSIONS_PER_PEER {
            assert!(session(&state, &format!("s{}", i), "10.0.0.2").is_some());
        }
        assert!(session(&state, "extra", "10.0.0.2").is_none());
        assert!(session(&state, "other", "10.0.0.3").is_some());
        // a session that exists stays reachable
        assert!(session(&state, "s0", "10.0.0.2").is_some());
    }

    #[test]
    fn only_same_origin_posts_pass() {
        assert!(same_origin(None, Some("snuggle.meros.vip")));
        assert!(same_origin(
            Some("https://snuggle.meros.vip"),
            Some("snuggle.meros.vip")
        ));
        assert!(same_origin(
            Some("http://127.0.0.1:8080"),
            Some("127.0.0.1:8080")
        ));
        assert!(!same_origin(
            Some("https://evil.example"),
            Some("snuggle.meros.vip")
        ));
        assert!(!same_origin(
            Some("https://snuggle.meros.vip.evil.example"),
            Some("snuggle.meros.vip")
        ));
        assert!(!same_origin(Some("null"), Some("snuggle.meros.vip")));
        assert!(!same_origin(Some("https://snuggle.meros.vip"), None));
    }

    #[test]
    fn a_session_cannot_flood_the_hub() {
        let state = Arc::new(State {
            hub: Mutex::new(Hub::new()),
            sessions: Mutex::new(BTreeMap::new()),
        });
        let a = session(&state, "aaa", "10.0.0.1").unwrap();
        let mut s = a.lock().unwrap();
        assert!(s.allow(MAX_LINES_PER_WINDOW));
        assert!(!s.allow(1));
        s.window = Instant::now() - RATE_WINDOW;
        assert!(s.allow(1));
    }

    #[test]
    fn responses_carry_security_headers() {
        for h in [
            "X-Content-Type-Options: nosniff",
            "Referrer-Policy: no-referrer",
            "frame-ancestors 'none'",
            "object-src 'none'",
        ] {
            assert!(SECURITY_HEADERS.contains(h), "{}", h);
        }
        // every header line ends in CRLF, and the block adds no blank line
        assert!(SECURITY_HEADERS.ends_with("\r\n"));
        assert!(!SECURITY_HEADERS.contains("\r\n\r\n"));
    }

    #[test]
    fn session_ids_are_plain() {
        assert!(valid_sid("a1B2"));
        assert!(!valid_sid(""));
        assert!(!valid_sid("../x"));
    }

    #[test]
    fn a_session_gets_the_hub_lines_and_polls_resume() {
        let state = Arc::new(State {
            hub: Mutex::new(Hub::new()),
            sessions: Mutex::new(BTreeMap::new()),
        });
        let a = session(&state, "aaa", "10.0.0.1").unwrap();
        let id = a.lock().unwrap().hub_id;
        state.hub.lock().unwrap().handle(id, "NAME erin");
        state.hub.lock().unwrap().handle(id, "JOIN lobby");
        thread::sleep(Duration::from_millis(100));
        let s = a.lock().unwrap();
        assert!(s.log.iter().any(|l| l == "HELLO snuggle-chat 1"));
        assert!(s.log.iter().any(|l| l == "JOIN lobby erin"));
    }
}
