const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "public");
const PORT = process.env.PORT || 8080;

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".zip": "application/zip",
  ".css": "text/css",
  ".map": "application/json",
  ".symbols": "text/plain",
};

http.createServer((req, res) => {
  const urlPath = decodeURI(req.url.split("?")[0]);
  let filePath = path.join(ROOT, urlPath);
  if (!filePath.startsWith(ROOT)) { res.writeHead(403); return res.end(); }
  if (urlPath.endsWith("/")) filePath = path.join(filePath, "index.html");

  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); return res.end("not found"); }
    res.writeHead(200, {
      "Content-Type": TYPES[path.extname(filePath)] || "application/octet-stream",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
      "Cache-Control": "no-cache",
    });
    res.end(data);
  });
}).listen(PORT, "0.0.0.0", () => console.log("snuggle-os on :" + PORT));
