#!/usr/bin/env python3
"""A test peer for the chat: bob joins lobby, waits for carol, and talks to her."""
import socket
import sys
import time

port = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", port), timeout=2)


def send(line):
    s.sendall((line + "\r\n").encode())


send("NAME bob")
send("JOIN lobby")
buf = b""
sent = False
deadline = time.time() + 180
while time.time() < deadline:
    try:
        data = s.recv(1024)
    except socket.timeout:
        continue
    if not data:
        break
    buf += data
    while b"\n" in buf:
        raw, buf = buf.split(b"\n", 1)
        line = raw.decode(errors="replace").strip()
        if line.startswith("JOIN lobby carol") and not sent:
            sent = True
            time.sleep(1)
            send("MSG lobby hello from bob")
            time.sleep(1)
            send("DM carol psst")
        if line.startswith("DM carol") or (line.startswith("DM ") and "thanks" in line):
            time.sleep(2)
            sys.exit(0)
