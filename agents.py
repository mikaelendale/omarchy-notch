#!/usr/bin/env python3
"""Every coding agent's sessions, for the notch: Claude Code and the rest.

Prints one JSON object per line whenever something changes:

  {"sessions": [{"id", "agent", "label", "project", "cwd", "state", "window",
                 "workspace", "focused", "pid", "since"}...],
   "counts": {"needs", "done", "working", "watching", "idle", "total"}}

Claude Code reports exactly what it's doing (working, waiting on you, done),
read by claude_sessions.py (the claude-sessions bar widget's collector).

Codex logs every turn of a session (~/.codex/sessions/.../rollout-*.jsonl), so
it's read from there just as exactly: working from the turn starting until it
ends, waiting on you while it asks to run something, done when it finished in
a window you weren't looking at.

The other agents (OpenCode, Antigravity, Crush, Amp, Cursor, Copilot, Kimi,
Qwen, Grok, Devin...) don't say, so they're found as processes running in the
foreground of a terminal, and called "working" while they draw to it (a
spinner, streamed output) or use the CPU, "idle" otherwise. Only what runs on
the agent's own terminal counts: background helpers don't.

When an agent rings the bell in a window you're not looking at (agents do, to
ask for you), foot runs bell.sh, which notes the terminal; that session is
"needs you" until you go to it or it gets busy again.

  agents.py            stream
  agents.py --once     print one snapshot and exit
"""

import argparse
import importlib.util
import json
import os
import re
import sys
import time

HOME = os.path.expanduser("~")
HERE = os.path.dirname(os.path.realpath(__file__))
# Claude Code's sessions are read by claude_sessions.py, which ships with this
# plugin (it's the claude-sessions bar widget's collector).
SESSIONS_PY = os.path.join(HERE, "claude_sessions.py")

POLL_SECONDS = 1.0
HEARTBEAT_EVERY = 30.0
ACTIVE_WRITE_BYTES = 120      # tty output in the last few seconds that counts as working
ACTIVE_CPU_PERCENT = 4.0
ACTIVE_HOLD_SECONDS = 3.0     # stay "working" this long after the last sign of it

# Agent id -> executable or script names it runs as. The id names the mark in
# /usr/share/omarchy/shell/plugins/agents/assets/<id>.svg where there is one.
AGENTS = {
    "codex": {"codex"},
    "opencode": {"opencode"},
    "agy": {"agy", "antigravity"},
    "crush": {"crush"},
    "amp": {"amp"},
    "cursor": {"cursor-agent"},
    "copilot": {"copilot"},
    "kimi": {"kimi"},
    "qwen": {"qwen"},
    "gemini": {"gemini"},
    "grok": {"grok"},
    "devin": {"devin"},
    "kilo": {"kilo"},
    "hermes": {"hermes"},
    "muse": {"muse"},
    "goose": {"goose"},
    "aider": {"aider"},
    "omp": {"omp"},
    "pi": {"pi"},
}
NAMES = {name: agent for agent, names in AGENTS.items() for name in names}
INTERPRETERS = {"node", "bun", "deno", "python", "python3", "uv", "uvx", "npx", "bash", "sh"}
DISPLAY = {
    "codex": "Codex", "opencode": "OpenCode", "agy": "Antigravity", "crush": "Crush",
    "amp": "Amp", "cursor": "Cursor", "copilot": "Copilot", "kimi": "Kimi",
    "qwen": "Qwen", "gemini": "Gemini", "grok": "Grok", "devin": "Devin", "kilo": "Kilo",
    "hermes": "Hermes", "muse": "Muse", "goose": "Goose", "aider": "Aider",
    "omp": "Oh My Pi", "pi": "Pi",
}
BELLS = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "mike-notch/bells")
BELL_MAX_AGE = 3600.0
SPINNER = re.compile(r"^[\s⠀-⣿◐-◓✳✶✢✻✽·•*◐◑◒◓⠁-⣿|/\\-]+")
CLK = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100

CODEX_HOME = os.environ.get("CODEX_HOME") or os.path.join(HOME, ".codex")
CODEX_SESSIONS = os.path.join(CODEX_HOME, "sessions")
CODEX_INDEX = os.path.join(CODEX_HOME, "session_index.jsonl")
# Events in a Codex session log that say where the turn is.
TURN_STARTS = {"task_started", "turn_started"}
TURN_ENDS = {"task_complete", "turn_complete", "turn_aborted"}
ASKS = {"exec_approval_request", "apply_patch_approval_request", "request_user_input",
        "elicitation_request", "request_permissions"}
QUIET = {"token_count"}       # bookkeeping that says nothing about the turn


def load_claude_collector():
    """The bundled Claude sessions collector, or None if it fails to load."""
    try:
        spec = importlib.util.spec_from_file_location("claude_sessions", SESSIONS_PY)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    except Exception:
        return None


# ------------------------------------------------------------------ /proc

def read(path, binary=False):
    try:
        with open(path, "rb" if binary else "r") as handle:
            return handle.read()
    except OSError:
        return b"" if binary else ""


def stat_fields(pid):
    raw = read(f"/proc/{pid}/stat")
    end = raw.rfind(")")
    return raw[end + 2:].split() if end >= 0 else None


def boot_time():
    for line in read("/proc/stat").splitlines():
        if line.startswith("btime "):
            try:
                return float(line.split()[1])
            except (ValueError, IndexError):
                break
    return 0.0


BOOT = boot_time()


def started_at(pid):
    """Wall-clock time the process started."""
    fields = stat_fields(pid)
    try:
        return BOOT + int(fields[19]) / CLK
    except (TypeError, ValueError, IndexError):
        return 0.0


def agent_of(pid):
    """The agent this process is, by its executable or script name, or None."""
    args = [a for a in read(f"/proc/{pid}/cmdline", binary=True).split(b"\0") if a]
    if not args:
        return None
    names = []
    for arg in args[:3]:
        base = os.path.basename(arg.decode("utf-8", "replace"))
        base = re.sub(r"\.(js|mjs|cjs|py)$", "", base)
        names.append(base)
    if names[0] in NAMES:
        return NAMES[names[0]]
    if names[0] in INTERPRETERS:
        for name in names[1:]:
            if name in NAMES:
                return NAMES[name]
            # node .../node_modules/@openai/codex/bin/codex.js
        for arg in args[1:3]:
            parts = arg.decode("utf-8", "replace").split("/")
            for part in parts:
                if part in NAMES:
                    return NAMES[part]
    return None


def children_map():
    kids = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        fields = stat_fields(int(name))
        if not fields:
            continue
        try:
            kids.setdefault(int(fields[1]), []).append(int(name))
        except (ValueError, IndexError):
            pass
    return kids


def subtree(pid, kids):
    out, todo = [], [pid]
    while todo:
        p = todo.pop()
        out.append(p)
        todo.extend(kids.get(p, []))
    return out


def on_tty(pids, tty):
    """The ones running on this terminal: the agent and the commands it runs,
    not background helpers (Codex keeps an app server going, for one)."""
    out = []
    for p in pids:
        fields = stat_fields(p)
        try:
            if fields and int(fields[4]) == tty:
                out.append(p)
        except (ValueError, IndexError):
            pass
    return out


def usage(pids):
    """(cpu jiffies, bytes written) summed over these processes."""
    cpu = 0
    written = 0
    for p in pids:
        fields = stat_fields(p)
        if fields and len(fields) > 13:
            try:
                cpu += int(fields[11]) + int(fields[12])
            except ValueError:
                pass
        for line in read(f"/proc/{p}/io").splitlines():
            if line.startswith("wchar:"):
                try:
                    written += int(line.split()[1])
                except ValueError:
                    pass
    return cpu, written


# ------------------------------------------------------------------ Codex

class CodexLog:
    """One Codex session log, read as it grows: the session's id, its folder,
    and where the turn is (idle, working, or waiting on you)."""

    def __init__(self, path):
        self.path = path
        self.offset = 0
        self.partial = b""
        self.id = ""
        self.cwd = ""
        self.created = 0.0
        self.state = "idle"

    def update(self):
        try:
            size = os.path.getsize(self.path)
        except OSError:
            return
        if size < self.offset:            # rewritten: read it again
            self.offset, self.partial, self.state = 0, b"", "idle"
        if size == self.offset:
            return
        try:
            with open(self.path, "rb") as handle:
                handle.seek(self.offset)
                data = handle.read(size - self.offset)
        except OSError:
            return
        self.offset += len(data)
        lines = (self.partial + data).split(b"\n")
        self.partial = lines.pop()        # a line still being written waits for the rest
        for raw in lines:
            self.feed(raw)

    def feed(self, raw):
        head = raw[:160]
        # Most lines are the conversation itself; only these two kinds matter.
        if b'"session_meta"' not in head and b'"event_msg"' not in head:
            return
        try:
            entry = json.loads(raw)
        except ValueError:
            return
        payload = entry.get("payload") if isinstance(entry, dict) else None
        if not isinstance(payload, dict):
            return
        if entry.get("type") == "session_meta":
            self.id = str(payload.get("id") or "")
            self.cwd = str(payload.get("cwd") or "")
            self.created = parse_time(payload.get("timestamp") or entry.get("timestamp"))
            return
        event = payload.get("type")
        if event in TURN_STARTS:
            self.state = "working"
        elif event in TURN_ENDS:
            self.state = "idle"
        elif event in ASKS:
            self.state = "needs"
        elif self.state == "needs" and event not in QUIET:
            self.state = "working"        # whatever comes next means it was answered


def parse_time(value):
    """Seconds since the epoch for an ISO 8601 time like 2026-11-12T09:30:10.808Z."""
    if not isinstance(value, str) or len(value) < 19:
        return 0.0
    try:
        import calendar
        base = time.strptime(value[:19], "%Y-%m-%dT%H:%M:%S")
        return float(calendar.timegm(base)) if value.endswith("Z") or "+00:00" in value else time.mktime(base)
    except ValueError:
        return 0.0


class Codex:
    """Finds each running Codex's session log and reads its state."""

    def __init__(self):
        self.logs = {}            # path -> CodexLog
        self.titles = {}          # session id -> the name Codex gave the thread
        self.index_seen = None

    def log(self, path):
        log = self.logs.get(path)
        if log is None:
            log = self.logs[path] = CodexLog(path)
        log.update()
        return log

    def held_open(self, pids):
        """The session log one of these processes has open, if any."""
        for p in pids:
            try:
                fds = os.listdir(f"/proc/{p}/fd")
            except OSError:
                continue
            for fd in fds:
                try:
                    target = os.readlink(f"/proc/{p}/fd/{fd}")
                except OSError:
                    continue
                if (target.startswith(CODEX_SESSIONS + "/") and target.endswith(".jsonl")
                        and os.path.basename(target).startswith("rollout-")):
                    return target
        return None

    def recent(self, since):
        """Session logs written to since then, from the last two days' folders."""
        out = []
        for days in (0, 1):
            day = time.localtime(time.time() - days * 86400)
            folder = os.path.join(CODEX_SESSIONS, time.strftime("%Y/%m/%d", day))
            try:
                names = os.listdir(folder)
            except OSError:
                continue
            for name in names:
                if not (name.startswith("rollout-") and name.endswith(".jsonl")):
                    continue
                path = os.path.join(folder, name)
                try:
                    if os.path.getmtime(path) >= since - 2:
                        out.append(path)
                except OSError:
                    pass
        return out

    def assign(self, tuis):
        """{pid: CodexLog or None} for running Codex TUIs [(pid, tree, cwd)].

        A log one of them holds open is its own. Otherwise each takes the newest
        log started in its folder after it started (newest Codex first), so two
        Codexes in one folder each get their own; one that hasn't been asked
        anything yet has no log, and is idle."""
        out, taken = {}, set()
        seen = set()
        waiting = []
        for pid, tree, cwd in tuis:
            path = self.held_open(tree)
            if path:
                out[pid] = self.log(path)
                taken.add(path)
                seen.add(path)
            else:
                waiting.append((started_at(pid), pid, cwd))
        if waiting:
            candidates = []
            for path in self.recent(min(start for start, _, _ in waiting)):
                if path in taken:
                    continue
                seen.add(path)
                candidates.append(self.log(path))
            for start, pid, cwd in sorted(waiting, reverse=True):
                best = None
                for log in candidates:
                    if log.path in taken or log.cwd != cwd or log.created < start - 2:
                        continue
                    if best is None or log.created > best.created:
                        best = log
                if best:
                    taken.add(best.path)
                out[pid] = best
        # Forget logs that aren't in play any more.
        for path in list(self.logs):
            if path not in seen:
                self.logs.pop(path, None)
        return out

    def title(self, session_id):
        """The name Codex gave a thread (in session_index.jsonl), or ""."""
        try:
            seen = os.stat(CODEX_INDEX).st_mtime
        except OSError:
            return ""
        if seen != self.index_seen:
            self.index_seen = seen
            titles = {}
            for line in read(CODEX_INDEX).splitlines():
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if isinstance(entry, dict) and entry.get("id"):
                    titles[str(entry["id"])] = str(entry.get("thread_name") or "")
            self.titles = titles
        return self.titles.get(session_id, "")


# ------------------------------------------------------------------ others

class Others:
    """Every agent but Claude, in terminals."""

    def __init__(self, hypr):
        self.hypr = hypr
        self.codex = Codex()
        self.last = {}        # pid -> (time, cpu, written)
        self.active_until = {}
        self.active_at = {}   # pid -> wall-clock time it was last seen working
        self.memory = {}      # pid -> {"state", "done"} for agents with a log

    def bells(self):
        """terminal pid -> wall-clock time its bell rang."""
        out = {}
        try:
            names = os.listdir(BELLS)
        except OSError:
            return out
        now = time.time()
        for name in names:
            path = os.path.join(BELLS, name)
            try:
                rang = float(read(path).strip() or 0)
            except ValueError:
                rang = 0
            if not name.isdigit() or now - rang > BELL_MAX_AGE or not os.path.exists(f"/proc/{name}"):
                try:
                    os.remove(path)
                except OSError:
                    pass
                continue
            out[int(name)] = rang
        return out

    def clear_bell(self, term_pid):
        try:
            os.remove(os.path.join(BELLS, str(term_pid)))
        except OSError:
            pass

    def window_for(self, pid, windows):
        current = pid
        for _ in range(10):
            if current in windows:
                return windows[current]
            fields = stat_fields(current)
            try:
                parent = int(fields[1]) if fields else 0
            except ValueError:
                parent = 0
            if parent <= 1 or parent == current:
                return None
            current = parent
        return None

    def guess(self, pid, tree, tty, now):
        """Working or idle, from what it draws to its terminal and its CPU."""
        cpu, written = usage(on_tty(tree, tty))
        before = self.last.get(pid)
        self.last[pid] = (now, cpu, written)
        if before:
            dt = max(0.001, now - before[0])
            cpu_pct = 100.0 * (cpu - before[1]) / CLK / dt
            wrote = written - before[2]
            if cpu_pct >= ACTIVE_CPU_PERCENT or wrote >= ACTIVE_WRITE_BYTES:
                self.active_until[pid] = now + ACTIVE_HOLD_SECONDS
                self.active_at[pid] = time.time()
        return "working" if self.active_until.get(pid, 0) > now else "idle"

    def snapshot(self, now):
        windows = {}
        clients = self.hypr.clients() if self.hypr else None
        if clients:
            windows = clients
        kids = children_map()
        found = []
        for name in os.listdir("/proc"):
            if not name.isdigit():
                continue
            pid = int(name)
            agent = agent_of(pid)
            if not agent:
                continue
            fields = stat_fields(pid)
            if not fields or len(fields) < 8:
                continue
            try:
                ppid, pgrp, tty, tpgid = int(fields[1]), int(fields[2]), int(fields[4]), int(fields[5])
            except ValueError:
                continue
            # Interactive: on a terminal, in its foreground.
            if tty == 0 or tpgid != pgrp:
                continue
            # The same agent's helper processes count as the one session.
            if agent_of(ppid) == agent:
                continue
            found.append((pid, agent, tty))

        codex_tuis = []
        for pid, agent, tty in found:
            if agent == "codex":
                cwd = os.path.realpath(f"/proc/{pid}/cwd") if os.path.exists(f"/proc/{pid}/cwd") else ""
                codex_tuis.append((pid, subtree(pid, kids), cwd))
        codex_logs = self.codex.assign(codex_tuis) if codex_tuis else {}

        bells = self.bells()
        focused = self.hypr.active_address() if self.hypr else ""
        alive = set()
        sessions = []
        for pid, agent, tty in found:
            alive.add(pid)
            tree = subtree(pid, kids)
            window = self.window_for(pid, windows)
            address = (window or {}).get("address", "")
            is_focused = bool(address) and address == focused
            log = codex_logs.get(pid) if agent == "codex" else None
            label = ""
            if agent == "codex":
                # Its own log says exactly; no log yet means nothing asked yet.
                state = log.state if log else "idle"
                label = self.codex.title(log.id) if log else ""
                if state == "working":
                    self.active_at[pid] = time.time()
            else:
                state = self.guess(pid, tree, tty, now)

            # Finished while you were looking elsewhere: "done" until you look.
            if agent == "codex":
                memory = self.memory.get(pid, {"state": None, "done": False})
                done = memory["done"]
                if state == "idle" and memory["state"] == "working" and not is_focused:
                    done = True
                if is_focused or state != "idle":
                    done = False
                self.memory[pid] = {"state": state, "done": done}
                if done:
                    state = "done"

            # Its terminal rang the bell: needs you, until you go to it or it
            # gets busy again after the bell.
            term = (window or {}).get("pid")
            reason = "approval" if state == "needs" else ""
            if term in bells:
                rang = bells[term]
                if is_focused:
                    self.clear_bell(term)
                elif self.active_at.get(pid, 0) > rang + ACTIVE_HOLD_SECONDS:
                    self.clear_bell(term)
                else:
                    state, reason = "needs", "bell"

            cwd = os.path.realpath(f"/proc/{pid}/cwd") if os.path.exists(f"/proc/{pid}/cwd") else ""
            if not label:
                label = SPINNER.sub("", (window or {}).get("title", "") or "").strip()
            if not label or label.lower() in ("foot", agent, DISPLAY.get(agent, "").lower(), os.path.basename(cwd).lower()):
                where = cwd.replace(HOME, "~", 1) if cwd.startswith(HOME) else cwd
                label = f"{DISPLAY.get(agent, agent)} in {where or '~'}"
            sessions.append({
                "id": f"{agent}:{pid}",
                "agent": agent,
                "agentName": DISPLAY.get(agent, agent),
                "label": label[:120],
                "project": os.path.basename(cwd),
                "cwd": cwd,
                "state": state,
                "reason": reason,
                "detail": "",
                "window": address,
                "workspace": (window or {}).get("workspace", ""),
                "focused": is_focused,
                "pid": pid,
            })
        for pid in list(self.last) + list(self.memory) + list(self.active_at):
            if pid not in alive:
                self.last.pop(pid, None)
                self.active_until.pop(pid, None)
                self.active_at.pop(pid, None)
                self.memory.pop(pid, None)
        return sessions


class Hypr:
    """pid -> {pid, address, title, workspace} from hyprctl, and the focused window."""

    def active_address(self):
        import subprocess
        try:
            out = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=3).stdout
            return (json.loads(out) or {}).get("address", "") or ""
        except Exception:
            return ""

    def clients(self):
        import subprocess
        try:
            out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=3).stdout
            data = json.loads(out)
        except Exception:
            return {}
        result = {}
        for c in data if isinstance(data, list) else []:
            pid = c.get("pid")
            if isinstance(pid, int):
                result[pid] = {
                    "pid": pid,
                    "address": c.get("address", ""),
                    "title": c.get("title", ""),
                    "workspace": str((c.get("workspace") or {}).get("name", "")),
                }
        return result


# ------------------------------------------------------------------ main

ORDER = {"needs": 0, "done": 1, "working": 2, "watching": 3, "idle": 4}


def combine(claude, others):
    sessions = []
    for s in (claude or {}).get("sessions", []):
        s = dict(s)
        s.setdefault("agent", "claude")
        s.setdefault("agentName", "Claude")
        sessions.append(s)
    sessions.extend(others)
    sessions.sort(key=lambda s: (ORDER.get(s.get("state"), 9), s.get("agentName", "")))
    counts = {"needs": 0, "done": 0, "working": 0, "watching": 0, "idle": 0}
    for s in sessions:
        if s.get("state") in counts:
            counts[s["state"]] += 1
    counts["total"] = len(sessions)
    return {"sessions": sessions, "counts": counts}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args(argv)

    cs = load_claude_collector()
    claude = None
    if cs:
        try:
            claude = cs.Collector(cs.config_homes(), hypr=cs.Hyprland(), notifier=None, notify_mode="off")
        except Exception:
            claude = None
    others = Others(Hypr())

    def snapshot(now):
        c = None
        if claude:
            try:
                c = claude.snapshot(now)
            except Exception:
                c = None
        return combine(c, others.snapshot(time.monotonic()))

    if args.once:
        snapshot(time.monotonic())
        time.sleep(1.0)  # a second look, so working/idle has something to compare
        print(json.dumps(snapshot(time.monotonic()), indent=2))
        return 0

    parent = os.getppid()
    last_text, last_emit = None, 0.0
    while True:
        now = time.monotonic()
        payload = snapshot(now)
        text = json.dumps(payload, sort_keys=True)
        if text != last_text or now - last_emit >= HEARTBEAT_EVERY:
            try:
                sys.stdout.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")
                sys.stdout.flush()
            except BrokenPipeError:
                return 0
            last_text, last_emit = text, now
        if os.getppid() != parent:
            return 0
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
