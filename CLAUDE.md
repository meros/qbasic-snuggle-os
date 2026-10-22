# Snuggle OS: notes for working in this repo

- Shell tooling is Nix: `nix develop` (cargo, clippy, dosbox, xvfb), `nix flake check`
  (what CI runs), `nix run .#test` (the QBasic groups in headless DOSBox, slow, and
  DOSBox can segfault or stall in a headless run: the runner retries).
- Rust workspace, edition 2024, no external crates: `snuggle-chat` (protocol and hub),
  `snuggle-tools` (`snuggle` build, docs and test tool), `snuggle-web` (HTTP server and
  the chat calls of the page, std only). Keep it std only unless there is a reason.
- `docs/API.md` is generated: run `snuggle docs -o docs/API.md` after changing an `'@api`
  line, or `nix flake check` fails.
- `snuggle-web` serves `/health` (not `/healthz`: Cloud Run reserves paths ending in z),
  sets the security headers in `SECURITY_HEADERS`, and checks `Origin` on POST. Read
  `docs/WEB.md` (Security) before changing them; a CSP change needs a real browser run
  of the page (type `SNUGGLE`), js-dos needs `unsafe-eval`.
- Deploy: `.github/workflows/deploy.yml`. The `deploy` job and its `uses:` belong to the
  shared meros/deploy-workflows; do not change them here. Pushes to master deploy.
- The page has no analytics or tracking, and none is to be added without asking.
- Keep å, ä, ö in text.
