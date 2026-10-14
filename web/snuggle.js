// A DOS computer in the page. It boots with a few lines, shows a C:\> prompt,
// and the visitor types the commands. SNUGGLE starts the modern Snuggle OS and
// ORIGINAL the first version, both in js-dos (DOSBox compiled to WebAssembly).
// The modern one also gets a chat relay: a browser has no serial port, so the
// Chat app writes its lines to CHATOUT.TXT and reads CHATIN.TXT, and startRelay
// carries them to the chat server of the site (crates/snuggle-web, docs/WEB.md).
"use strict";

const $ = (id) => document.getElementById(id);
const term = $("term"), kbd = $("kbd"), canvas = $("screen");

const PROGRAMS = {
  SNUGGLE: { title: "Snuggle OS", bundle: "modern.jsdos", chat: true, size: 213000, date: "10-14-26" },
  ORIGINAL: { title: "Snuggle OS (original)", bundle: "original.jsdos", chat: false, size: 196000, date: "03-21-20" },
};

// ---- the terminal ---------------------------------------------------------
let line = "";          // what is typed
let history = [], hpos = 0;
let accepting = false;  // the prompt is live
let running = false;

function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;"); }
let html = "";
function out(text = "", cls = "") {
  html += (cls ? `<span class="${cls}">${esc(text)}</span>` : esc(text)) + "\n";
  draw();
}
function draw() {
  const cur = accepting ? `${esc(line)}<span class="cur"> </span>` : "";
  term.innerHTML = html + (accepting ? `<span class="hi">C:\\&gt;</span>${cur}` : "");
  term.scrollTop = term.scrollHeight;
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const quick = matchMedia("(prefers-reduced-motion: reduce)").matches;

async function boot() {
  const lines = [
    ["SNUGGLE BIOS v1.1  (C) 1999 Snuggle Systems", "hi", 200],
    ["", "", 0],
    ["Memory test: 640K OK", "", 450],
    ["Video: VGA 640 x 480, 16 colours", "", 150],
    ["Pointing device: mouse found", "", 150],
    ["Network: serial port COM1 on the chat relay (this page)", "", 250],
    ["", "", 0],
    ["Starting MS-DOS...", "", 700],
    ["", "", 0],
    ["HIMEM is testing extended memory... done.", "", 250],
    ["", "", 0],
    ["Microsoft(R) MS-DOS(R) Version 6.22", "", 0],
    ["", "", 0],
    ["QBASIC 1.1 found on drive C:", "acc", 200],
    ["Type HELP for the list of commands.", "warn", 0],
    ["", "", 0],
  ];
  for (const [t, c, ms] of lines) {
    out(t, c);
    if (!quick) await sleep(ms);
  }
  accepting = true;
  draw();
  kbd.focus();
}

const COMMANDS = {
  HELP() {
    out("SNUGGLE    Start Snuggle OS (modern, with chat)");
    out("ORIGINAL   Start the first version, as it was before the rewrite");
    out("DIR        List the files");
    out("TYPE name  Show a text file (README.TXT)");
    out("VER        Show the version");
    out("CLS        Clear the screen");
    out("REBOOT     Start the computer again");
  },
  DIR() {
    out(" Volume in drive C is SNUGGLE");
    out(" Directory of C:\\");
    out("");
    out("QBASIC   EXE       254,000  03-21-20  12:00a");
    for (const [name, p] of Object.entries(PROGRAMS)) {
      out(`${name.padEnd(8)} BAS ${String(p.size).padStart(13)}  ${p.date}  12:00a`);
    }
    out("README   TXT           620  10-14-26  12:00a");
    out("        4 file(s)");
  },
  TYPE(arg) {
    if (arg.toUpperCase() !== "README.TXT") return out(arg ? "File not found" : "Required parameter missing");
    out("Snuggle OS is a 1999 window desktop written in QBasic 1.1.");
    out("SNUGGLE starts the rebuilt one: windows that repaint without flicker,");
    out("icons that start apps, and Clock, Calc, Notepad, Flappy and Chat.");
    out("ORIGINAL starts the first version. Chat is connected to the chat");
    out("server of this site: open the page twice to talk to yourself.");
    out("Click the screen once so the keys go to it. R repaints, Q quits.");
  },
  VER() { out("Microsoft(R) MS-DOS(R) Version 6.22, Snuggle OS 0.1 (modern) / 1999 (original)"); },
  CLS() { html = ""; draw(); },
  REBOOT() { location.hash = ""; location.reload(); },
  SNUGGLE() { launch("SNUGGLE"); },
  ORIGINAL() { launch("ORIGINAL"); },
};
COMMANDS.CHAT = () => out("Start SNUGGLE, then the Chat icon on the desktop.");
COMMANDS.EXIT = COMMANDS.REBOOT;

function run(text) {
  out(`C:\\>${text}`, "hi");
  const t = text.trim();
  if (!t) return;
  const [cmd, ...rest] = t.split(/\s+/);
  const name = cmd.toUpperCase().replace(/\.(EXE|BAS|COM|BAT)$/, "");
  const fn = COMMANDS[name];
  if (fn) fn(rest.join(" "));
  else out("Bad command or file name");
}

term.addEventListener("click", () => kbd.focus());
document.addEventListener("keydown", (e) => {
  if (!accepting || running) return;
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key === "Enter") {
    e.preventDefault();
    const t = line;
    line = "";
    if (t.trim()) { history.push(t); hpos = history.length; }
    accepting = false;
    draw();
    run(t);
    if (!running) { accepting = true; draw(); }
  } else if (e.key === "Backspace") {
    e.preventDefault();
    line = line.slice(0, -1);
    draw();
  } else if (e.key === "ArrowUp" && hpos > 0) {
    e.preventDefault();
    line = history[--hpos];
    draw();
  } else if (e.key === "ArrowDown") {
    e.preventDefault();
    hpos = Math.min(hpos + 1, history.length);
    line = history[hpos] || "";
    draw();
  } else if (e.key.length === 1) {
    e.preventDefault();
    if (line.length < 70) line += e.key;
    draw();
  }
});
// a phone keyboard sends input events instead of keydown with a key
kbd.addEventListener("input", () => {
  if (kbd.value) { if (accepting && line.length < 70) { line += kbd.value.slice(-1); draw(); } kbd.value = ""; }
});

// ---- the emulator ----------------------------------------------------------
let relayTimer = null;

function sessionId() {
  const a = new Uint8Array(8);
  crypto.getRandomValues(a);
  return Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
}

// Lines between the emulated disk and the server.
function startRelay(fs) {
  const sid = sessionId();
  const em = fs.fs; // the Emscripten file system of DOSBox
  const decoder = new TextDecoder("ascii");
  let outRead = 0;      // bytes of CHATOUT.TXT passed on
  let cursor = 0;       // lines of the server seen
  let epoch = 0;        // the server's connection for this page; a new one starts the chat over
  let inText = "";      // everything appended to CHATIN.TXT so far
  let up = false;       // the last call to the server worked
  let beat = 0;
  let busy = false;
  const status = $("relay");

  const exists = (p) => { try { return em.analyzePath(p).exists; } catch (e) { return false; } };

  async function tick() {
    if (busy) return;
    busy = true;
    const lines = [];
    try {
      // from the OS to the server: whole lines only
      if (exists("/CHATOUT.TXT")) {
        const bytes = em.readFile("/CHATOUT.TXT");
        if (bytes.length > outRead) {
          const text = decoder.decode(bytes.subarray(outRead));
          const end = text.lastIndexOf("\n");
          if (end >= 0) {
            outRead += end + 1;
            const r = await fetch(`/api/chat/${sid}/send`, { method: "POST", body: text.slice(0, end + 1) });
            if (!r.ok) throw new Error("send " + r.status);
          }
        }
      }
      // from the server to the OS
      const r = await fetch(`/api/chat/${sid}/poll?since=${cursor}&epoch=${epoch}`);
      if (!r.ok) throw new Error("poll " + r.status);
      const got = (await r.text()).split("\n");
      const [next, ep] = got[0].split(" ").map((n) => parseInt(n, 10));
      cursor = next || 0;
      epoch = ep || epoch;
      for (const l of got.slice(1)) if (l) lines.push(l);
      if (!up) lines.push("STATUS UP");
      up = true;
    } catch (e) {
      if (up) lines.push("STATUS DOWN");
      up = false;
    }
    // the relay is alive every two seconds, and says if the server is there
    if (Date.now() - beat >= 2000) {
      beat = Date.now();
      lines.push(up ? "HB UP" : "HB DOWN");
    }
    if (lines.length) {
      inText += lines.join("\r\n") + "\r\n";
      em.writeFile("/CHATIN.TXT", inText);
    }
    status.textContent = up ? "chat relay: connected" : "chat relay: server not reachable";
    busy = false;
  }

  try { em.unlink("/CHATIN.TXT"); } catch (e) { /* not there */ }
  try { em.unlink("/CHATOUT.TXT"); } catch (e) { /* not there */ }
  relayTimer = setInterval(tick, 250);
}

function launch(name) {
  const p = PROGRAMS[name];
  running = true;
  out(`Loading ${p.title}... QBasic compiles it first, which takes a while.`, "acc");
  $("reboot").hidden = false;
  Dos(canvas, { wdosboxUrl: "wdosbox.js" }).ready((fs, main) => {
    fs.extract(p.bundle).then(() => {
      term.hidden = true;
      canvas.hidden = false;
      if (p.chat) startRelay(fs);
      main(["-conf", ".jsdos/dosbox.conf"]).then((ci) => { window.snuggle = { ci, fs }; });
    });
  });
}

$("reboot").addEventListener("click", () => COMMANDS.REBOOT());

boot().then(() => {
  // a link like /#snuggle types the command for the visitor
  const want = location.hash.slice(1).toUpperCase();
  if (PROGRAMS[want]) { line = want; draw(); document.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" })); }
});
