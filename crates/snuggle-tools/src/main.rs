//! `snuggle`: builds the Snuggle OS program from its parts, writes its API
//! reference, and runs its tests in headless DOSBox.

mod bundle;
mod png;
mod runner;
mod serial;
mod testprog;
mod verify;

use bundle::Selection;
use runner::Dos;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{exit, Command};
use std::time::Duration;

const USAGE: &str = "\
usage: snuggle [--root DIR] <command>

  build [-o FILE] [--only a,b] [--fixtures] [--components c,d]
                          the program (default: SNUGGLE.BAS, CRLF line ends)
  docs [-o FILE]          docs/API.md, from the '@api lines of the kernel
  check                   fail when docs/API.md is not what `docs` writes
  testprog GROUP|smoke    the QBasic source of a test program, on stdout
  test [GROUP...] [--work DIR] [--limit SECONDS] [--floor BYTES]
                          the smoke run (memory floor) and the groups, headless
  shot -o FILE.png [--setup FILE.bas]
                          a picture of the desktop after its first paint
  verify DIR              compare the dumps of a test run in DIR
  render DIR PREFIX FILE  a PNG of dumps DIR/PREFIX0.BIN .. PREFIX3.BIN
  groups                  the test groups
";

fn fail(msg: &str) -> ! {
    eprintln!("snuggle: {}", msg);
    exit(1)
}

fn find_root(explicit: Option<PathBuf>) -> PathBuf {
    if let Some(r) = explicit.or_else(|| std::env::var_os("SNUGGLE_ROOT").map(PathBuf::from)) {
        return r;
    }
    let mut d = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    loop {
        if d.join("os/kernel").is_dir() {
            return d;
        }
        if !d.pop() {
            fail("not in a Snuggle OS tree (no os/kernel): use --root DIR or SNUGGLE_ROOT");
        }
    }
}

struct Args {
    rest: Vec<String>,
}

impl Args {
    fn flag(&mut self, name: &str) -> bool {
        match self.rest.iter().position(|a| a == name) {
            Some(i) => {
                self.rest.remove(i);
                true
            }
            None => false,
        }
    }
    fn value(&mut self, name: &str) -> Option<String> {
        let i = self.rest.iter().position(|a| a == name)?;
        self.rest.remove(i);
        if i >= self.rest.len() {
            fail(&format!("{} needs a value", name));
        }
        Some(self.rest.remove(i))
    }
}

fn write(path: &Path, data: &[u8]) {
    if let Err(e) = fs::write(path, data) {
        fail(&format!("{}: {}", path.display(), e));
    }
}

/// QBASIC.EXE into `dir`: from $SNUGGLE_QBASIC, or out of vendor/qb11.zip.
fn qbasic_into(root: &Path, dir: &Path) {
    let target = dir.join("QBASIC.EXE");
    if let Some(p) = std::env::var_os("SNUGGLE_QBASIC") {
        let _ = fs::remove_file(&target); // a store file is read only: copy over a fresh path
        if let Err(e) = fs::copy(&p, &target) {
            fail(&format!("cannot copy {:?}: {}", p, e));
        }
        return;
    }
    let ok = Command::new("unzip")
        .args(["-o", "-q", "-j"])
        .arg(root.join("vendor/qb11.zip"))
        .arg("QBASIC.EXE")
        .arg("-d")
        .arg(dir)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if !ok {
        fail("cannot get QBASIC.EXE: set SNUGGLE_QBASIC or install unzip");
    }
}

fn clean(dir: &Path) {
    if let Ok(rd) = fs::read_dir(dir) {
        for e in rd.flatten() {
            let n = e.file_name().to_string_lossy().to_string();
            let junk = n.ends_with(".BIN")
                || n.ends_with(".TXT")
                || n.ends_with(".png")
                || n == "dosbox.conf";
            if junk {
                let _ = fs::remove_file(e.path());
            }
        }
    }
}

struct Settings {
    root: PathBuf,
    work: PathBuf,
    limit: Duration,
    floor: u64,
}

fn dos(s: &Settings, serial1: Option<String>, env: Option<String>) -> Dos {
    Dos {
        work: s.work.clone(),
        serial1,
        stall: Duration::from_secs(120),
        env,
    }
}

fn smoke(s: &Settings) -> bool {
    println!("== smoke: the program starts and paints");
    clean(&s.work);
    qbasic_into(&s.root, &s.work);
    let src = testprog::smoke(&s.root).unwrap_or_else(|e| fail(&e));
    write(
        &s.work.join("SMOKE.BAS"),
        src.replace('\n', "\r\n").as_bytes(),
    );
    if let Err(e) = dos(s, None, None).run("SMOKE.BAS", "SMOKE.TXT", "started", s.limit) {
        println!("FAIL the program did not reach its main loop: {}", e);
        return false;
    }
    let text = fs::read_to_string(s.work.join("SMOKE.TXT")).unwrap_or_default();
    let free: u64 = text
        .split_whitespace()
        .nth(1)
        .and_then(|n| n.parse().ok())
        .unwrap_or(0);
    println!("PASS the program starts, opens its windows and paints");
    println!(
        "     free memory after the first paint: {} bytes (floor {})",
        free, s.floor
    );
    if free < s.floor {
        println!("FAIL less than {} bytes of QBasic memory left", s.floor);
        return false;
    }
    true
}

fn group(s: &Settings, name: &str) -> bool {
    println!("== cases: {}", name);
    let g = testprog::group(name).unwrap_or_else(|e| fail(&e));
    clean(&s.work);
    qbasic_into(&s.root, &s.work);
    let src = testprog::cases(&s.root, name).unwrap_or_else(|e| fail(&e));
    write(
        &s.work.join("TEST.BAS"),
        src.replace('\n', "\r\n").as_bytes(),
    );
    let rig_chat;
    let rig_loss;
    let serial1 = if g.serial {
        Some(serial::dosbox_serial())
    } else {
        None
    };
    match name {
        "chat" => {
            rig_chat = serial::ChatRig::start().unwrap_or_else(|e| fail(&e));
            let _ = &rig_chat;
        }
        "chatloss" => {
            rig_loss = serial::LossRig::start(&s.work).unwrap_or_else(|e| fail(&e));
            let _ = &rig_loss;
        }
        _ => {}
    }
    let ran = dos(
        s,
        serial1,
        if name == "chatweb" {
            Some("SNUGGLE=web".into())
        } else {
            None
        },
    )
    .run("TEST.BAS", "RESULT.TXT", "DONE", s.limit);
    let result = fs::read_to_string(s.work.join("RESULT.TXT")).unwrap_or_default();
    let mut ok = true;
    if let Err(e) = ran {
        for l in result.lines().filter(|l| !l.starts_with("SNAP ")) {
            println!("{}", l);
        }
        println!("FAIL group {} did not finish: {}", name, e);
        return false;
    }
    match verify::verify(&s.work) {
        Ok(r) => {
            for l in &r.lines {
                println!("{}", l);
                ok &= !l.starts_with("FAIL");
            }
        }
        Err(e) => {
            println!("FAIL {}", e);
            ok = false;
        }
    }
    for l in result
        .lines()
        .filter(|l| !l.starts_with("SNAP ") && !l.starts_with("DONE"))
    {
        println!("{}", l);
        ok &= !l.starts_with("FAIL");
    }
    ok
}

fn main() {
    let mut a = Args {
        rest: std::env::args().skip(1).collect(),
    };
    let root_flag = a.value("--root").map(PathBuf::from);
    if a.rest.is_empty() || a.rest[0] == "-h" || a.rest[0] == "--help" {
        print!("{}", USAGE);
        return;
    }
    let cmd = a.rest.remove(0);
    match cmd.as_str() {
        "groups" => {
            for g in testprog::GROUPS {
                println!(
                    "{}  (apps: {}{})",
                    g.name,
                    g.apps.join(", "),
                    if g.serial { "; serial" } else { "" }
                );
            }
        }
        "build" => {
            let root = find_root(root_flag);
            let out = a.value("-o").unwrap_or_else(|| "SNUGGLE.BAS".into());
            let sel = Selection {
                only: a
                    .value("--only")
                    .map(|s| s.split(',').map(String::from).collect()),
                fixtures: a.flag("--fixtures"),
                components: a
                    .value("--components")
                    .map(|s| s.split(',').map(String::from).collect())
                    .unwrap_or_default(),
            };
            let data = bundle::build(&root, &sel).unwrap_or_else(|e| fail(&e));
            write(Path::new(&out), &data);
            println!("wrote {} ({} bytes)", out, data.len());
        }
        "docs" => {
            let root = find_root(root_flag);
            let doc = bundle::api_doc(&root).unwrap_or_else(|e| fail(&e));
            match a.value("-o") {
                Some(o) => write(Path::new(&o), doc.as_bytes()),
                None => print!("{}", doc),
            }
        }
        "check" => {
            let root = find_root(root_flag);
            let want = bundle::api_doc(&root).unwrap_or_else(|e| fail(&e));
            let have = fs::read_to_string(root.join("docs/API.md")).unwrap_or_default();
            if have != want {
                fail("docs/API.md is not up to date: run `snuggle docs -o docs/API.md`");
            }
            println!("docs/API.md is up to date");
        }
        "testprog" => {
            let root = find_root(root_flag);
            let name = a
                .rest
                .first()
                .cloned()
                .unwrap_or_else(|| fail("testprog needs a group or smoke"));
            let src = match name.as_str() {
                "smoke" => testprog::smoke(&root),
                other => testprog::cases(&root, other),
            }
            .unwrap_or_else(|e| fail(&e));
            print!("{}", src);
        }
        "test" => {
            let root = find_root(root_flag);
            let work = a.value("--work").map(PathBuf::from).unwrap_or_else(|| {
                std::env::temp_dir().join(format!("snuggle-test-{}", std::process::id()))
            });
            fs::create_dir_all(&work).unwrap_or_else(|e| fail(&e.to_string()));
            let s = Settings {
                root,
                work,
                limit: Duration::from_secs(
                    a.value("--limit")
                        .and_then(|v| v.parse().ok())
                        .unwrap_or(900),
                ),
                floor: a
                    .value("--floor")
                    .and_then(|v| v.parse().ok())
                    .unwrap_or(25000),
            };
            let names: Vec<String> = if a.rest.is_empty() {
                let mut v = vec!["smoke".to_string()];
                v.extend(testprog::GROUPS.iter().map(|g| g.name.to_string()));
                v
            } else {
                a.rest.clone()
            };
            let mut ok = true;
            for n in &names {
                ok &= if n == "smoke" {
                    smoke(&s)
                } else {
                    group(&s, n)
                };
            }
            println!("{}", if ok { "All cases passed." } else { "FAILED" });
            exit(if ok { 0 } else { 1 });
        }
        "shot" => {
            let root = find_root(root_flag);
            let out = PathBuf::from(
                a.value("-o")
                    .unwrap_or_else(|| fail("shot needs -o FILE.png")),
            );
            let setup = a
                .value("--setup")
                .map(|p| fs::read_to_string(&p).unwrap_or_else(|e| fail(&format!("{}: {}", p, e))))
                .unwrap_or_default();
            let work = std::env::temp_dir().join(format!("snuggle-shot-{}", std::process::id()));
            fs::create_dir_all(&work).unwrap_or_else(|e| fail(&e.to_string()));
            let s = Settings {
                root: root.clone(),
                work: work.clone(),
                limit: Duration::from_secs(300),
                floor: 0,
            };
            qbasic_into(&root, &work);
            let src = testprog::shot(&root, &setup).unwrap_or_else(|e| fail(&e));
            write(&work.join("SHOT.BAS"), src.replace('\n', "\r\n").as_bytes());
            dos(&s, None, None)
                .run("SHOT.BAS", "SHOT.TXT", "done", s.limit)
                .unwrap_or_else(|e| fail(&e));
            verify::render(&work, "SHOT", &out).unwrap_or_else(|e| fail(&e));
            let _ = fs::remove_dir_all(&work);
            println!("{}", out.display());
        }
        "verify" => {
            let dir = PathBuf::from(
                a.rest
                    .first()
                    .cloned()
                    .unwrap_or_else(|| fail("verify needs a directory")),
            );
            let r = verify::verify(&dir).unwrap_or_else(|e| fail(&e));
            for l in &r.lines {
                println!("{}", l);
            }
            println!("{} snapshot(s), {} differ", r.snapshots, r.failed);
            exit(if r.failed > 0 { 1 } else { 0 });
        }
        "render" => {
            if a.rest.len() < 3 {
                fail("render needs DIR PREFIX FILE");
            }
            verify::render(Path::new(&a.rest[0]), &a.rest[1], Path::new(&a.rest[2]))
                .unwrap_or_else(|e| fail(&e));
        }
        other => {
            eprint!("snuggle: unknown command {}\n\n{}", other, USAGE);
            exit(2);
        }
    }
}
