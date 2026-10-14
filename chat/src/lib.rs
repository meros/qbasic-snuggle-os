//! The chat protocol and the hub that keeps names, rooms and direct messages.
//!
//! One line of ASCII per message, at most `MAX_LINE` characters, ended by `\n`
//! (a `\r` before it is ignored). The first word is the command.
//!
//! Client to server
//!   NAME <name>           take a name (1 to 12 of A-Z a-z 0-9 _ -), once, before
//!                         anything else
//!   JOIN <room>           join a room (made when the first one joins)
//!   LEAVE <room>
//!   MSG <room> <text>     to everyone in a room you are in, yourself included
//!   DM <name> <text>      to one user
//!   WHO <room>            who is in a room
//!   PING                  answered with PONG
//!
//! Server to client
//!   HELLO snuggle-chat 1  when the connection is made
//!   OK <command> [word]   the command worked
//!   ERR <number> <text>   it did not (1 name first, 2 bad name or room, 3 not
//!                         in that room, 4 name taken or leave rooms first,
//!                         5 no such user, 6 empty text, 9 unknown command)
//!   MSG <room> <from> <text>
//!   DM <from> <text>      a direct message for you
//!   SENT <to> <text>      your direct message went to <to>
//!   JOIN <room> <name>    somebody joined a room you are in (or you did)
//!   LEAVE <room> <name>   somebody left, or lost the connection
//!   USERS <room> <names>  the members of a room, space separated
//!   PONG
//!
//! The relay adds lines of its own, for the client only: `HB UP` or `HB DOWN`
//! every two seconds (the relay is alive, and has or has not its connection to
//! the server), `STATUS UP` / `STATUS DOWN` when that changes, and `ERR 0 server
//! down` for a line it could not pass on.

use std::collections::{BTreeMap, BTreeSet};
use std::sync::mpsc::Sender;

pub const MAX_LINE: usize = 200;
pub const MAX_NAME: usize = 12;

/// A received line made safe: printable ASCII only, trimmed, at most MAX_LINE.
pub fn clean_line(raw: &str) -> String {
    let s: String = raw
        .chars()
        .filter(|c| (' '..='~').contains(c))
        .take(MAX_LINE)
        .collect();
    s.trim().to_string()
}

/// A name or a room: 1 to 12 of A-Z a-z 0-9 _ -
pub fn valid_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= MAX_NAME
        && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
}

struct User {
    name: Option<String>,
    rooms: BTreeSet<String>,
    tx: Sender<String>,
}

#[derive(Default)]
pub struct Hub {
    next: u64,
    users: BTreeMap<u64, User>,
}

impl Hub {
    pub fn new() -> Hub {
        Hub::default()
    }

    /// A new connection: lines for it go to `tx`. Returns its id.
    pub fn connect(&mut self, tx: Sender<String>) -> u64 {
        self.next += 1;
        let id = self.next;
        let _ = tx.send("HELLO snuggle-chat 1".to_string());
        self.users.insert(id, User { name: None, rooms: BTreeSet::new(), tx });
        id
    }

    /// The connection is gone: tell the rooms it was in.
    pub fn disconnect(&mut self, id: u64) {
        if let Some(user) = self.users.remove(&id) {
            if let Some(name) = user.name {
                for room in user.rooms {
                    self.to_room(&room, &format!("LEAVE {} {}", room, name));
                }
            }
        }
    }

    fn send(&self, id: u64, line: String) {
        if let Some(u) = self.users.get(&id) {
            let _ = u.tx.send(line);
        }
    }

    fn to_room(&self, room: &str, line: &str) {
        for u in self.users.values() {
            if u.rooms.contains(room) {
                let _ = u.tx.send(line.to_string());
            }
        }
    }

    fn members(&self, room: &str) -> Vec<String> {
        self.users
            .values()
            .filter(|u| u.rooms.contains(room))
            .filter_map(|u| u.name.clone())
            .collect()
    }

    fn id_of(&self, name: &str) -> Option<u64> {
        self.users
            .iter()
            .find(|(_, u)| u.name.as_deref().map_or(false, |n| n.eq_ignore_ascii_case(name)))
            .map(|(id, _)| *id)
    }

    /// One line from a client.
    pub fn handle(&mut self, id: u64, line: &str) {
        let line = clean_line(line);
        if line.is_empty() || !self.users.contains_key(&id) {
            return;
        }
        let (cmd, rest) = match line.split_once(' ') {
            Some((c, r)) => (c.to_ascii_uppercase(), r.trim().to_string()),
            None => (line.to_ascii_uppercase(), String::new()),
        };
        if cmd == "PING" {
            return self.send(id, "PONG".into());
        }
        if cmd == "NAME" {
            return self.name(id, &rest);
        }
        let me = match self.users[&id].name.clone() {
            Some(n) => n,
            None => return self.send(id, "ERR 1 name first".into()),
        };
        match cmd.as_str() {
            "JOIN" => {
                if !valid_name(&rest) {
                    return self.send(id, "ERR 2 bad room".into());
                }
                self.users.get_mut(&id).unwrap().rooms.insert(rest.clone());
                self.to_room(&rest, &format!("JOIN {} {}", rest, me));
                self.send(id, format!("USERS {} {}", rest, self.members(&rest).join(" ")));
                self.send(id, format!("OK JOIN {}", rest));
            }
            "LEAVE" => {
                if !self.users[&id].rooms.contains(&rest) {
                    return self.send(id, "ERR 3 not in that room".into());
                }
                self.to_room(&rest, &format!("LEAVE {} {}", rest, me));
                self.users.get_mut(&id).unwrap().rooms.remove(&rest);
                self.send(id, format!("OK LEAVE {}", rest));
            }
            "MSG" => {
                let (room, text) = rest.split_once(' ').unwrap_or((rest.as_str(), ""));
                if !self.users[&id].rooms.contains(room) {
                    return self.send(id, "ERR 3 not in that room".into());
                }
                if text.trim().is_empty() {
                    return self.send(id, "ERR 6 empty text".into());
                }
                self.to_room(room, &format!("MSG {} {} {}", room, me, text.trim()));
            }
            "DM" => {
                let (to, text) = rest.split_once(' ').unwrap_or((rest.as_str(), ""));
                if text.trim().is_empty() {
                    return self.send(id, "ERR 6 empty text".into());
                }
                match self.id_of(to) {
                    Some(tid) => {
                        self.send(tid, format!("DM {} {}", me, text.trim()));
                        self.send(id, format!("SENT {} {}", to, text.trim()));
                    }
                    None => self.send(id, "ERR 5 no such user".into()),
                }
            }
            "WHO" => {
                if !valid_name(&rest) {
                    return self.send(id, "ERR 2 bad room".into());
                }
                self.send(id, format!("USERS {} {}", rest, self.members(&rest).join(" ")));
            }
            _ => self.send(id, "ERR 9 unknown command".into()),
        }
    }

    fn name(&mut self, id: u64, wanted: &str) {
        if !valid_name(wanted) {
            return self.send(id, "ERR 2 bad name".into());
        }
        if let Some(other) = self.id_of(wanted) {
            if other != id {
                return self.send(id, "ERR 4 name taken".into());
            }
        }
        if !self.users[&id].rooms.is_empty() {
            return self.send(id, "ERR 4 leave rooms first".into());
        }
        self.users.get_mut(&id).unwrap().name = Some(wanted.to_string());
        self.send(id, format!("OK NAME {}", wanted));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc::{channel, Receiver};

    fn client(hub: &mut Hub) -> (u64, Receiver<String>) {
        let (tx, rx) = channel();
        let id = hub.connect(tx);
        (id, rx)
    }

    fn lines(rx: &Receiver<String>) -> Vec<String> {
        rx.try_iter().collect()
    }

    #[test]
    fn hello_name_and_errors() {
        let mut hub = Hub::new();
        let (a, ra) = client(&mut hub);
        assert_eq!(lines(&ra), ["HELLO snuggle-chat 1"]);
        hub.handle(a, "JOIN lobby");
        assert_eq!(lines(&ra), ["ERR 1 name first"]);
        hub.handle(a, "NAME bad name");
        assert_eq!(lines(&ra), ["ERR 2 bad name"]);
        hub.handle(a, "NAME ada");
        assert_eq!(lines(&ra), ["OK NAME ada"]);
        let (b, rb) = client(&mut hub);
        lines(&rb);
        hub.handle(b, "name ADA");
        assert_eq!(lines(&rb), ["ERR 4 name taken"]);
        hub.handle(a, "FLY");
        assert_eq!(lines(&ra), ["ERR 9 unknown command"]);
        hub.handle(a, "ping");
        assert_eq!(lines(&ra), ["PONG"]);
    }

    #[test]
    fn rooms_messages_and_dm() {
        let mut hub = Hub::new();
        let (a, ra) = client(&mut hub);
        let (b, rb) = client(&mut hub);
        hub.handle(a, "NAME ada");
        hub.handle(b, "NAME bob");
        lines(&ra);
        lines(&rb);
        hub.handle(a, "JOIN lobby");
        assert_eq!(lines(&ra), ["JOIN lobby ada", "USERS lobby ada", "OK JOIN lobby"]);
        hub.handle(b, "JOIN lobby");
        assert_eq!(lines(&ra), ["JOIN lobby bob"]);
        assert_eq!(lines(&rb), ["JOIN lobby bob", "USERS lobby ada bob", "OK JOIN lobby"]);
        hub.handle(a, "MSG lobby hello there");
        assert_eq!(lines(&ra), ["MSG lobby ada hello there"]);
        assert_eq!(lines(&rb), ["MSG lobby ada hello there"]);
        hub.handle(a, "MSG other hi");
        assert_eq!(lines(&ra), ["ERR 3 not in that room"]);
        hub.handle(a, "DM bob psst");
        assert_eq!(lines(&ra), ["SENT bob psst"]);
        assert_eq!(lines(&rb), ["DM ada psst"]);
        hub.handle(a, "DM nobody hi");
        assert_eq!(lines(&ra), ["ERR 5 no such user"]);
        hub.handle(a, "WHO lobby");
        assert_eq!(lines(&ra), ["USERS lobby ada bob"]);
    }

    #[test]
    fn leave_and_lost_connection() {
        let mut hub = Hub::new();
        let (a, ra) = client(&mut hub);
        let (b, rb) = client(&mut hub);
        hub.handle(a, "NAME ada");
        hub.handle(b, "NAME bob");
        hub.handle(a, "JOIN r1");
        hub.handle(b, "JOIN r1");
        lines(&ra);
        lines(&rb);
        hub.handle(b, "LEAVE r1");
        assert_eq!(lines(&rb), ["LEAVE r1 bob", "OK LEAVE r1"]);
        assert_eq!(lines(&ra), ["LEAVE r1 bob"]);
        hub.handle(b, "JOIN r1");
        lines(&ra);
        hub.disconnect(b);
        assert_eq!(lines(&ra), ["LEAVE r1 bob"]);
    }

    #[test]
    fn lines_are_made_safe() {
        assert_eq!(clean_line("  a\u{e5}b\r\n"), "ab");
        assert_eq!(clean_line(&"x".repeat(500)).len(), MAX_LINE);
        assert!(valid_name("a_b-1"));
        assert!(!valid_name("a b"));
        assert!(!valid_name("thirteenchars"));
    }
}
