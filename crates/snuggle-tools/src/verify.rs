//! Compare the screen dumps a test run wrote.
//!
//! The QBasic test program writes, for every `SNAP <n> <label>` line of
//! RESULT.TXT, the four bit planes of side A (the incremental code) and side B
//! (the reference) as S<nnn><A|B><plane>.BIN: BSAVE files with a 7 byte header
//! and 38400 bytes of a plane. SCREEN 12 is 640 x 480 in 16 colours.

use crate::png;
use std::fs;
use std::path::Path;

pub const W: usize = 640;
pub const H: usize = 480;
const PLANE: usize = 38400;

/// DAC values (6 bit) of attributes 0 to 15: the ones the program sets in Init
/// for 0 to 7, QBasic's own for 8 to 15.
const DAC: [(u8, u8, u8); 16] = [
    (0, 0, 0),
    (22, 22, 22),
    (32, 32, 32),
    (42, 42, 42),
    (0, 40, 40),
    (0, 0, 22),
    (0, 0, 32),
    (0, 0, 42),
    (21, 21, 21),
    (21, 21, 63),
    (21, 63, 21),
    (21, 63, 63),
    (63, 21, 21),
    (63, 21, 63),
    (63, 63, 21),
    (63, 63, 63),
];

fn rgb(attr: u8) -> [u8; 3] {
    let (r, g, b) = DAC[attr as usize & 15];
    let f = |c: u8| ((c as u32 * 255 + 31) / 63) as u8;
    [f(r), f(g), f(b)]
}

fn load_planes(dir: &Path, prefix: &str) -> Result<Vec<Vec<u8>>, String> {
    (0..4)
        .map(|p| {
            let path = dir.join(format!("{}{}.BIN", prefix, p));
            let data = fs::read(&path).map_err(|e| format!("{}: {}", path.display(), e))?;
            if data.len() != PLANE + 7 {
                return Err(format!(
                    "{}: {} bytes, expected {}",
                    path.display(),
                    data.len(),
                    PLANE + 7
                ));
            }
            Ok(data[7..].to_vec())
        })
        .collect()
}

/// The attribute of every pixel, row by row.
fn pixels(planes: &[Vec<u8>]) -> Vec<u8> {
    let mut out = vec![0u8; W * H];
    for row in 0..H {
        for col in 0..80 {
            let i = row * 80 + col;
            for bit in 0..8 {
                let m = 0x80u8 >> bit;
                let mut v = 0u8;
                for (p, plane) in planes.iter().enumerate() {
                    if plane[i] & m != 0 {
                        v |= 1 << p;
                    }
                }
                out[row * W + col * 8 + bit] = v;
            }
        }
    }
    out
}

fn picture(px: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(px.len() * 3);
    for &v in px {
        out.extend_from_slice(&rgb(v));
    }
    out
}

/// A as it is, B as it is, and where they differ (red).
fn diff_picture(a: &[u8], b: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(W * 3 * H * 3);
    for y in 0..H {
        let (ra, rb) = (&a[y * W..(y + 1) * W], &b[y * W..(y + 1) * W]);
        for img in [ra, rb] {
            for &v in img {
                out.extend_from_slice(&rgb(v));
            }
        }
        for x in 0..W {
            out.extend_from_slice(if ra[x] != rb[x] {
                &[255, 0, 0]
            } else {
                &[32, 32, 32]
            });
        }
    }
    out
}

/// Render dumps `<prefix>0.BIN` .. `<prefix>3.BIN` as a PNG.
pub fn render(dir: &Path, prefix: &str, out: &Path) -> Result<(), String> {
    let px = pixels(&load_planes(dir, prefix)?);
    fs::write(out, png::encode(W, H, &picture(&px))).map_err(|e| e.to_string())
}

pub struct Report {
    pub snapshots: usize,
    pub failed: usize,
    pub lines: Vec<String>,
}

/// Compare every snapshot of RESULT.TXT. A snapshot that differs gets
/// `diff_<nnn>.png` in `dir`; one whose label starts with `look` also gets
/// `look_<nnn>.png`, a picture of what the incremental code drew.
pub fn verify(dir: &Path) -> Result<Report, String> {
    let result =
        fs::read_to_string(dir.join("RESULT.TXT")).map_err(|e| format!("RESULT.TXT: {}", e))?;
    let mut report = Report {
        snapshots: 0,
        failed: 0,
        lines: Vec::new(),
    };
    for line in result.lines() {
        let Some(rest) = line.strip_prefix("SNAP ") else {
            continue;
        };
        let mut words = rest.split_whitespace();
        let num: usize = words
            .next()
            .and_then(|n| n.parse().ok())
            .ok_or("bad SNAP line")?;
        let label = words.collect::<Vec<_>>().join(" ");
        let nnn = format!("{:03}", num);
        report.snapshots += 1;
        let loaded = (|| -> Result<(Vec<u8>, Vec<u8>), String> {
            Ok((
                pixels(&load_planes(dir, &format!("S{}A", nnn))?),
                pixels(&load_planes(dir, &format!("S{}B", nnn))?),
            ))
        })();
        let (a, b) = match loaded {
            Ok(p) => p,
            Err(e) => {
                report.failed += 1;
                report.lines.push(format!("FAIL {}: {}", label, e));
                continue;
            }
        };
        if label.starts_with("look") {
            let _ = fs::write(
                dir.join(format!("look_{}.png", nnn)),
                png::encode(W, H, &picture(&a)),
            );
        }
        let bad: Vec<usize> = (0..W * H).filter(|i| a[*i] != b[*i]).collect();
        if bad.is_empty() {
            report.lines.push(format!("PASS {}", label));
            continue;
        }
        report.failed += 1;
        let xs = bad.iter().map(|i| i % W);
        let ys = bad.iter().map(|i| i / W);
        report.lines.push(format!(
            "FAIL {}: {} pixels differ, x {}-{}, y {}-{} (see diff_{}.png)",
            label,
            bad.len(),
            xs.clone().min().unwrap(),
            xs.max().unwrap(),
            ys.clone().min().unwrap(),
            ys.max().unwrap(),
            nnn
        ));
        let _ = fs::write(
            dir.join(format!("diff_{}.png", nnn)),
            png::encode(W * 3, H, &diff_picture(&a, &b)),
        );
    }
    Ok(report)
}
