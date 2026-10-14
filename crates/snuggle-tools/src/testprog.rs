//! The test programs: the real program with its run section, drawing layer,
//! mouse and palette setup swapped for test versions (tests/qbasic), and the
//! test cases added. The marker lines (`'@@NAME-BEGIN` .. `'@@NAME-END`) in
//! os/kernel say what can be swapped.

use crate::bundle::{self, Selection};
use std::fs;
use std::path::Path;

/// A group of cases, and the apps and parts its program has. The program does
/// not fit in QBasic's memory together with the test code and all of its apps.
pub struct Group {
    pub name: &'static str,
    pub apps: &'static [&'static str],
    /// Needs the chat server, the relay and DOSBox's serial port.
    pub serial: bool,
}

pub const GROUPS: &[Group] = &[
    Group {
        name: "window",
        apps: &["hello"],
        serial: false,
    },
    Group {
        name: "controls",
        apps: &["hello"],
        serial: false,
    },
    Group {
        name: "heap",
        apps: &["hello"],
        serial: false,
    },
    Group {
        name: "apps",
        apps: &["clock", "calc", "flappy"],
        serial: false,
    },
    Group {
        name: "input",
        apps: &["hello", "calc", "notepad"],
        serial: false,
    },
    Group {
        name: "speed",
        apps: &["hello"],
        serial: false,
    },
    Group {
        name: "chat",
        apps: &["chat"],
        serial: true,
    },
    Group {
        name: "chatloss",
        apps: &["chat"],
        serial: true,
    },
    Group {
        name: "chatweb",
        apps: &["chat"],
        serial: false,
    },
];

pub fn group(name: &str) -> Result<&'static Group, String> {
    GROUPS
        .iter()
        .find(|g| g.name == name)
        .ok_or_else(|| format!("no test group {}", name))
}

fn part(root: &Path, name: &str) -> Result<String, String> {
    let p = root.join("tests/qbasic").join(name);
    fs::read_to_string(&p)
        .map(|s| s.replace("\r\n", "\n"))
        .map_err(|e| format!("{}: {}", p.display(), e))
}

/// Replace the lines from `'@@<begin>` to `'@@<end>` with `body`.
fn swap(text: &str, begin: &str, end: &str, body: &str) -> Result<String, String> {
    let b = format!("'@@{}", begin);
    let e = format!("'@@{}", end);
    let lines: Vec<&str> = text.split('\n').collect();
    let starts: Vec<usize> = (0..lines.len()).filter(|i| lines[*i] == b).collect();
    if starts.len() != 1 {
        return Err(format!(
            "marker {} not found exactly once in the program",
            b
        ));
    }
    let s = starts[0];
    let t = (s..lines.len())
        .find(|i| lines[*i] == e)
        .ok_or_else(|| format!("marker {} not found", e))?;
    let mut out: Vec<String> = lines[..s].iter().map(|l| l.to_string()).collect();
    out.push(body.trim_end_matches('\n').to_string());
    out.extend(lines[t + 1..].iter().map(|l| l.to_string()));
    Ok(out.join("\n"))
}

const LOOP_START: &str = "refresh\n\nDO\n";

/// The program as shipped, except that it stops once its first paint is done
/// and writes the memory it has left (SMOKE.TXT).
pub fn smoke(root: &Path) -> Result<String, String> {
    let src = bundle::build_text(root, &Selection::default())?;
    if src.matches(LOOP_START).count() != 1 {
        return Err("start of the main loop not found".into());
    }
    Ok(src.replace(
        LOOP_START,
        "refresh\nOPEN \"SMOKE.TXT\" FOR OUTPUT AS #1\nPRINT #1, \"started\"; FRE(-1)\nCLOSE #1\nSYSTEM\n\nDO\n",
    ))
}

/// The program as shipped, with a dump of the screen after its first paint
/// (SHOT0.BIN .. SHOT3.BIN, a bit plane each) and a stop. `setup` is QBasic
/// code that runs before the dump.
pub fn shot(root: &Path, setup: &str) -> Result<String, String> {
    let src = bundle::build_text(root, &Selection::default())?;
    if src.matches(LOOP_START).count() != 1 {
        return Err("start of the main loop not found".into());
    }
    let dump = format!(
        "{}refresh\nFOR sp = 0 TO 3\nOUT &H3CE, 4\nOUT &H3CF, sp\nDEF SEG = &HA000\nBSAVE \"SHOT\" + CHR$(48 + sp) + \".BIN\", 0, 38400\nDEF SEG\nNEXT\nOPEN \"SHOT.TXT\" FOR OUTPUT AS #1\nPRINT #1, \"done\"\nCLOSE #1\nSYSTEM\n\nDO\n",
        setup
    );
    Ok(src.replace(LOOP_START, &dump))
}

/// The program for a group of cases.
pub fn cases(root: &Path, group_name: &str) -> Result<String, String> {
    let g = group(group_name)?;
    let sel = Selection {
        only: Some(g.apps.iter().map(|s| s.to_string()).collect()),
        fixtures: true,
        components: Vec::new(),
    };
    let src = bundle::build_text(root, &sel)?;
    let mut out = swap(&src, "RUN-BEGIN", "RUN-END", &part(root, "run_body.bas")?)?;
    out = swap(&out, "GFX-BEGIN", "GFX-END", &part(root, "gfx.bas")?)?;
    out = swap(
        &out,
        "MOUSE-BEGIN",
        "MOUSE-END",
        &part(root, "mouse_stub.bas")?,
    )?;
    out = swap(
        &out,
        "INIT-BEGIN",
        "INIT-END",
        "SUB Init\nCoutSetup\nEND SUB\n",
    )?;
    let marker = "'***************\n";
    if !out.contains(marker) {
        return Err("declare marker not found".into());
    }
    out = out.replacen(
        marker,
        &format!("{}{}", part(root, "declares.bas")?, marker),
        1,
    );
    if out.matches("DEFINT A-Z\n").count() != 1 {
        return Err("DEFINT A-Z not found exactly once".into());
    }
    out = out.replacen(
        "DEFINT A-Z\n",
        &format!("{}DEFINT A-Z\n", part(root, "globals.bas")?),
        1,
    );
    for name in [
        "ref.bas".to_string(),
        "lib.bas".to_string(),
        format!("cases/{}.bas", g.name),
    ] {
        out = format!("{}\n\n{}", out.trim_end_matches('\n'), part(root, &name)?);
    }
    Ok(out)
}
