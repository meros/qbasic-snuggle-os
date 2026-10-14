//! Run a QBasic program in DOSBox, headless: in a virtual X server of its own,
//! with the X11 driver and the software renderer, so nothing opens on the
//! desktop of whoever runs it.
//!
//! The program says it is done by writing a line that starts with a given text
//! into a marker file. DOSBox 0.74 under Xvfb now and then crashes at start,
//! and a program can stop on a QBasic error and wait; both look like a run that
//! ends, or stops growing the marker, without the line, and are run again.

use std::fs;
use std::os::unix::process::ExitStatusExt;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::thread::sleep;
use std::time::{Duration, Instant};

pub struct Dos {
    /// The directory DOSBox mounts as C: (QBASIC.EXE and the program are here).
    pub work: PathBuf,
    /// DOSBox's `serial1` setting, for example `nullmodem port:7001 transparent:1`.
    pub serial1: Option<String>,
    /// How long a run may go without the marker file growing.
    pub stall: Duration,
    /// An environment variable for the program (`NAME=value`), set before it starts.
    pub env: Option<String>,
}

struct Xvfb {
    child: Child,
    display: String,
}

impl Xvfb {
    fn start() -> Result<Xvfb, String> {
        for n in 90..190 {
            if Path::new(&format!("/tmp/.X{}-lock", n)).exists() {
                continue;
            }
            let mut child = Command::new("Xvfb")
                .arg(format!(":{}", n))
                .args(["-screen", "0", "800x600x24", "-nolisten", "tcp", "-noreset"])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .map_err(|e| format!("cannot start Xvfb: {}", e))?;
            let socket = format!("/tmp/.X11-unix/X{}", n);
            let t0 = Instant::now();
            while t0.elapsed() < Duration::from_secs(10) {
                if Path::new(&socket).exists() {
                    return Ok(Xvfb {
                        child,
                        display: format!(":{}", n),
                    });
                }
                if let Ok(Some(_)) = child.try_wait() {
                    break; // the display was taken: try the next
                }
                sleep(Duration::from_millis(50));
            }
            let _ = child.kill();
            let _ = child.wait();
        }
        Err("no free X display for Xvfb".into())
    }
}

impl Drop for Xvfb {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[derive(Debug, PartialEq)]
enum Ended {
    Done,
    Crashed(String),
    Stalled,
    TooLong,
}

fn marker_has(path: &Path, pattern: &str) -> bool {
    fs::read_to_string(path)
        .map(|s| s.lines().any(|l| l.starts_with(pattern)))
        .unwrap_or(false)
}

impl Dos {
    fn write_conf(&self, bas: &str) -> Result<PathBuf, String> {
        let conf = format!(
            "[sdl]\nfullscreen=false\noutput=surface\n[dosbox]\nmachine=vgaonly\n[cpu]\ncycles=max\n[mixer]\nnosound=true\n[sblaster]\nsbtype=none\n[gus]\ngus=false\n[speaker]\npcspeaker=false\n[midi]\nmpu401=none\nmididevice=none\n[serial]\nserial1={}\n[autoexec]\nmount c {}\nc:\n{}QBASIC /RUN {}\nexit\n",
            self.serial1.as_deref().unwrap_or("dummy"),
            self.work.display(),
            self.env.as_deref().map(|e| format!("set {}\n", e)).unwrap_or_default(),
            bas
        );
        let p = self.work.join("dosbox.conf");
        fs::write(&p, conf).map_err(|e| e.to_string())?;
        Ok(p)
    }

    fn once(
        &self,
        bas: &str,
        marker: &str,
        pattern: &str,
        limit: Duration,
    ) -> Result<Ended, String> {
        let conf = self.write_conf(bas)?;
        let marker_path = self.work.join(marker);
        let _ = fs::remove_file(&marker_path);
        let xvfb = Xvfb::start()?;
        // DOSBox in nixpkgs is SDL 1.2 on sdl12-compat (SDL2), and SDL2 takes
        // Wayland first when WAYLAND_DISPLAY is set, whatever DISPLAY says; its
        // OpenGL renderer needs GLX, which Xvfb has not. A crash is not worth a
        // core dump (systemd-coredump compresses every one).
        // what DOSBox says goes to dosbox.log in the work directory
        let log = fs::File::create(self.work.join("dosbox.log")).map_err(|e| e.to_string())?;
        let mut dos = Command::new("sh")
            .args(["-c", "ulimit -c 0; exec dosbox -conf \"$0\" -noconsole"])
            .arg(&conf)
            .current_dir(&self.work)
            .env_remove("WAYLAND_DISPLAY")
            .env("DISPLAY", &xvfb.display)
            .env("SDL_VIDEODRIVER", "x11")
            .env("SDL_RENDER_DRIVER", "software")
            .env("SDL_AUDIODRIVER", "dummy")
            .stdin(Stdio::null())
            .stdout(log.try_clone().map_err(|e| e.to_string())?)
            .stderr(log)
            .spawn()
            .map_err(|e| format!("cannot start dosbox: {}", e))?;
        let t0 = Instant::now();
        let mut last_size = 0u64;
        let mut last_growth = Instant::now();
        let ended = loop {
            if marker_has(&marker_path, pattern) {
                break Ended::Done;
            }
            if let Some(status) = dos.try_wait().map_err(|e| e.to_string())? {
                if marker_has(&marker_path, pattern) {
                    break Ended::Done;
                }
                break Ended::Crashed(match status.signal() {
                    Some(s) => format!("signal {}", s),
                    None => format!("exit {}", status.code().unwrap_or(-1)),
                });
            }
            let size = fs::metadata(&marker_path).map(|m| m.len()).unwrap_or(0);
            if size != last_size {
                last_size = size;
                last_growth = Instant::now();
            }
            if last_growth.elapsed() >= self.stall {
                break Ended::Stalled;
            }
            if t0.elapsed() >= limit {
                break Ended::TooLong;
            }
            sleep(Duration::from_millis(200));
        };
        let _ = dos.kill();
        let _ = dos.wait();
        drop(xvfb);
        Ok(ended)
    }

    /// Run `bas` until it writes a line starting with `pattern` into `marker`,
    /// again when DOSBox crashed or stalled (at most five times).
    pub fn run(
        &self,
        bas: &str,
        marker: &str,
        pattern: &str,
        limit: Duration,
    ) -> Result<(), String> {
        let mut last = String::from("not started");
        for attempt in 1..=5 {
            let started = Instant::now();
            match self.once(bas, marker, pattern, limit)? {
                Ended::Done => return Ok(()),
                Ended::TooLong => {
                    return Err(format!("{} did not finish in {} s", bas, limit.as_secs()))
                }
                Ended::Stalled => last = "stalled".into(),
                Ended::Crashed(why) => last = why,
            }
            if let Ok(log) = fs::read_to_string(self.work.join("dosbox.log")) {
                for l in log
                    .lines()
                    .rev()
                    .take(6)
                    .collect::<Vec<_>>()
                    .into_iter()
                    .rev()
                {
                    eprintln!("  dosbox: {}", l);
                }
            }
            eprintln!(
                "DOSBox ended after {} s without finishing ({}, attempt {}), retrying",
                started.elapsed().as_secs(),
                last,
                attempt
            );
        }
        Err(format!(
            "{} did not finish: DOSBox {} five times",
            bas, last
        ))
    }
}
