#!/usr/bin/env python3
"""Jump to the herdr space whose Claude summary is speaking (or spoke last).

Companion to ~/.claude/hooks/speak-summary.sh, which marks the speaking pane
with `pane.report_metadata --source speak-summary` for the duration of playback.
Bound to prefix+o in ~/.config/herdr/config.toml via [[keys.command]].

Why a script and not herdr's own `open_notification_target` (the stock prefix+o):
that action jumps to the target of herdr's LAST NOTIFICATION, and the target is
set by herdr's internal agent-state notifications. `notification.show` — the only
notification the CLI can raise — takes title/body/position/sound and no target at
all, so a toast fired by the speak hook would leave prefix+o aimed wherever it
already pointed. There is no way to aim it from outside. Hence: read the mark
back off the snapshot and focus that space directly.

Two sources, in order:
  1. A live speaker — the pane currently carrying the speak-summary mark. Playback
     is serialized by a global flock, so at most one pane is ever marked.
  2. The last speaker — $SPEAKER_FILE, written when the mark goes up and left
     behind after it comes down. Lets you chase a summary you only half-heard.

Exits quietly when nothing has spoken yet. Verified against herdr 0.7.3.

Usage: speak-focus.py
"""
import json
import os
import socket
import sys

SOCKET = os.environ.get(
    "HERDR_SOCKET_PATH",
    os.path.expanduser("~/.config/herdr/herdr.sock"),
)
SPEAKER_FILE = os.path.expanduser("~/.claude/speak-summary-speaker")
MARK = os.environ.get("SPEAK_MARK", "\N{SPEAKER WITH THREE SOUND WAVES}")


def call(method, params):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCKET)
    s.sendall((json.dumps({"id": "speak-focus", "method": method, "params": params}) + "\n").encode())
    buf = b""
    while not buf.endswith(b"\n"):
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    s.close()
    reply = json.loads(buf.decode())
    if "error" in reply:
        sys.exit(f"herdr {method} failed: {reply['error']}")
    return reply["result"]


def live_speaker():
    """The pane wearing the mark right now, if any."""
    agents = call("session.snapshot", {})["snapshot"].get("agents", [])
    for a in agents:
        if (a.get("custom_status") or "").startswith(MARK):
            return a.get("workspace_id"), a.get("pane_id")
    return None


def last_speaker():
    """Whoever spoke most recently, from the state file the hook leaves behind."""
    try:
        with open(SPEAKER_FILE, encoding="utf-8") as fh:
            workspace_id, pane_id = fh.read().split()[:2]
        return workspace_id, pane_id
    except Exception:
        return None


def main():
    target = live_speaker() or last_speaker()
    if target is None:
        return  # nothing has ever spoken — do nothing rather than guess
    workspace_id, pane_id = target

    call("workspace.focus", {"workspace_id": workspace_id})
    # A space can hold several panes; land on the one that actually spoke.
    try:
        call("pane.focus", {"pane_id": pane_id})
    except SystemExit:
        pass  # pane died since it spoke; the space focus above is good enough


if __name__ == "__main__":
    main()
