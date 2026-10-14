# Chat

Names, rooms and direct messages between Snuggle OS and anything that can open a
TCP socket. Three parts:

```
Snuggle OS (Chat app, QBasic)     COM1 ──serial──▶ DOSBox "nullmodem" port 7001
                                                         ▲ dials
                                              snuggle-chat-relay (Rust, host)
                                                         │ TCP
                                              snuggle-chat-server (Rust)
```

- **`crates/snuggle-chat` snuggle-chat-server** keeps the names, the rooms and the
  direct messages. Plain TCP, one line of ASCII per message.
- **`crates/snuggle-chat` snuggle-chat-relay** is the host side of the serial port. DOSBox
  listens (`serial1=nullmodem port:7001 transparent:1`) and the relay dials it,
  because DOSBox as a client never retries. The relay keeps its own link to the
  server, cleans the lines (printable ASCII, 200 characters), and tells the OS
  what is going on.
- **`os/apps/chat.bas`** is the app: a log of 12 lines, a status line, an input box.
  Text goes to the room; `/name x`, `/join room`, `/dm user text` and `/who` are
  commands.

## Run it

```
nix run .#chat-server                  # listens on 127.0.0.1:7000
nix run .#chat-relay                   # dials DOSBox on 7001, the server on 7000
nix run .                              # the launcher's DOSBox listens on 7001
# without nix: cargo build --release, then the same two binaries in target/release
```

In a browser the lines go through two files and the page instead of COM1 (docs/WEB.md).

Start the Chat app from its desktop icon. The relay can be started before DOSBox, after
it, or again after a stop: it dials until DOSBox answers.

## Protocol

Lines end with `\n`; a `\r` before it is ignored. The first word is the command.

| Client to server | Meaning |
| --- | --- |
| `NAME <name>` | take a name (1 to 12 of `A-Z a-z 0-9 _ -`); first, and not while in a room |
| `JOIN <room>` / `LEAVE <room>` | enter or leave a room (the first to join makes it) |
| `MSG <room> <text>` | to everyone in a room you are in, yourself included |
| `DM <name> <text>` | to one user |
| `WHO <room>` | the members of a room |
| `PING` | answered with `PONG` |

| Server to client | Meaning |
| --- | --- |
| `HELLO snuggle-chat 1` | the connection was made |
| `OK <command> [word]` | it worked |
| `ERR <n> <text>` | it did not: 1 name first, 2 bad name or room, 3 not in that room, 4 name taken or leave rooms first, 5 no such user, 6 empty text, 9 unknown command |
| `MSG <room> <from> <text>` | a message to a room |
| `DM <from> <text>` / `SENT <to> <text>` | a direct message for you / yours went out |
| `JOIN <room> <name>` / `LEAVE <room> <name>` | somebody entered or left (or lost the connection) |
| `USERS <room> <names>` | the members, space separated |

The relay adds, for the OS only: `HB UP` or `HB DOWN` every two seconds (the relay
is alive, and has or has not its link to the server), `STATUS UP` / `STATUS DOWN`
when the link changes, and `ERR 0 server down` for a line it could not pass on.

## Losing the connection

The OS decides by the heartbeat. No line of any kind from the relay for six
seconds is **Disconnected: no relay**: it shows in the status line and the log,
and a message is refused with `! not connected`. `HB DOWN` is **Relay up, server
down**. When the relay comes back, the next `HB UP` makes the app take its name
and room again. The heartbeat repeats the link status because the OS may open
its port after the relay made the link and miss `STATUS UP`.

## Tests

`snuggle test chat chatloss` runs the Rust unit tests (the hub: names, rooms, direct
messages, lost connections), then two QBasic programs in headless DOSBox with the
real server and relay and a scripted peer: **chat** (connect, join, message, direct
message, `/who`, `/join`, an error) and **chatloss** (no relay at start, a relay
that comes up later, one that is stopped and started again).

## Limits

- A line is at most 200 characters, and the input box takes 40.
- One chat window, one serial port.
- No encryption and no authentication: a name is just a name. The server and the
  relay are for a local network or localhost. Anything facing the internet
  (TLS, a real service such as IRC or Matrix) belongs in the relay, so the
  credentials stay on the host.
