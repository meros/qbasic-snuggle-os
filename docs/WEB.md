# The web host

`nix run .#web` serves a DOS-style page. It boots with a few lines, shows a
`C:\>` prompt, and the visitor types the commands:

| Command | Does |
| --- | --- |
| `SNUGGLE` | starts the modern Snuggle OS, with the Chat app connected to the site's chat server |
| `ORIGINAL` | starts the first version (`vendor/original/SNUGGLE.BAS`, the code base before the rewrite) |
| `DIR`, `TYPE README.TXT`, `VER`, `HELP`, `CLS`, `REBOOT` | what they say |

`/#snuggle` and `/#original` type the command for the visitor.

## Parts

| Part | Is |
| --- | --- |
| `web/` | the page: `index.html`, `snuggle.css`, `snuggle.js` (terminal, js-dos start, chat relay) |
| js-dos 6.22 | DOSBox compiled to WebAssembly, fetched from the npm registry by `nix/web.nix` |
| `crates/snuggle-web` | the HTTP server: the static files, the chat hub, and the two chat calls |
| `nix/web.nix` | the site (page, js-dos, one `.jsdos` bundle per variant), the runner and a container image |
| `.github/workflows/deploy.yml` | Cloud Run, from the image (the service itself is defined in meros/hosting) |

## The chat relay in the page

A browser has no serial port and cannot open a TCP connection, so the chat
does not go through COM1 there. The Chat app sees `SNUGGLE=web` in its
environment (set in the bundle's `dosbox.conf`) and uses two files instead:

```
Chat app (QBasic) --append--> CHATOUT.TXT --read by snuggle.js--> POST /api/chat/<id>/send --> hub
Chat app (QBasic) <--reads--- CHATIN.TXT  <--written by snuggle.js-- GET  /api/chat/<id>/poll?since=N&epoch=E <-- hub
```

`snuggle.js` plays the relay of docs/CHAT.md: it adds `HB UP` or `HB DOWN` every
two seconds, `STATUS UP` and `STATUS DOWN` when the server comes and goes, so
the app's disconnected state works the same as with the native relay.
`CHATIN.TXT` only grows, and the app keeps the number of bytes it has read.

The server (`snuggle-web`) holds one hub connection per page session and drops it
20 seconds after the last poll. A page that polls again after that
is told so by the epoch (the id of its hub connection): the reply starts with
`STATUS DOWN` and `STATUS UP`, so the app takes its name and room again. One
peer address can hold 20 sessions (the last `X-Forwarded-For` entry on Cloud Run). `--chat-listen ADDR` opens the plain TCP protocol
on the same hub, so a native relay and a browser can share rooms.

## Security

What `snuggle-web` does on every request:

- `GET /health` answers `200 ok`. Use it for checks: Cloud Run reserves paths
  that end in `z`, so there is no `/healthz`.
- Every response carries `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: no-referrer`, a `Permissions-Policy` that turns the
  camera, microphone and location off, and a Content-Security-Policy: only
  same-origin scripts, styles, images and connections, `frame-ancestors 'none'`,
  `object-src 'none'`. `script-src` has `'unsafe-eval'` and `'wasm-unsafe-eval'`
  because js-dos 6 starts the emulator with `eval()`; inline scripts stay blocked.
  The page was loaded with this policy in Chrome, js-dos started and the chat
  relay connected with no CSP violation.
- A POST with an `Origin` header must name the request's own `Host`, or it gets
  403 (another site's page cannot post to a visitor's chat session). Requests
  without `Origin` (curl, a native client) pass.
- Limits: 4096 bytes of body, 20 lines per send, 100 lines per session per 10
  seconds (429 after that), 20 sessions per peer, 200 sessions, 256 open
  connections (503 after that).
- Static files: only plain path components under `--root` (no `..`, no
  absolute paths); nothing is percent-decoded, so `%2e%2e` is a file name.
- The page puts only its own fixed strings into the DOM (HTML-escaped); chat
  text goes to the emulated screen, never into the DOM.
- SIGTERM and SIGINT stop accepting connections, give running requests up to 5
  seconds and exit 0.

## Limits

- One server process holds the rooms, so Cloud Run is pinned to one instance
  (`maxScale = 1`); a restart empties the rooms.
- No TLS or authentication of its own; Cloud Run terminates TLS.
- The page polls every 250 ms per visitor.
- Tested in a desktop Chrome by loading the page, typing `SNUGGLE`, and chatting.
  The container image and the deploy workflow have not been run.
