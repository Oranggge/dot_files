#!/usr/bin/env python3
"""Move the focused herdr space up or down in the sidebar.

herdr has no `move_workspace` key action and no `herdr workspace move` CLI
subcommand — reordering exists only as the raw socket method `workspace.move`.
This script is the missing piece, wired to prefix+shift+j / prefix+shift+k in
~/.config/herdr/config.toml via [[keys.command]].

`insert_index` is 0-based and indexes the list AS IT IS NOW, i.e. "put this
space where the space currently at insert_index sits". Removing the space
first shifts everything after it left by one, so a downward move needs
target+1 while an upward move needs plain target. Passing target for a
downward move is a silent no-op, not an error. Verified against herdr 0.7.3
on 2026-07-09.

Usage: move-space.py up|down
"""
import json
import os
import socket
import sys

SOCKET = os.environ.get(
    "HERDR_SOCKET_PATH",
    os.path.expanduser("~/.config/herdr/herdr.sock"),
)


def call(method, params):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCKET)
    s.sendall((json.dumps({"id": "move-space", "method": method, "params": params}) + "\n").encode())
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


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("up", "down"):
        sys.exit(f"usage: {os.path.basename(sys.argv[0])} up|down")
    direction = sys.argv[1]

    spaces = call("workspace.list", {})["workspaces"]
    focused = next((w for w in spaces if w.get("focused")), None)
    if focused is None:
        return  # nothing focused (detached?) — do nothing rather than guess

    pos = spaces.index(focused)  # 0-based position in sidebar order
    if direction == "down":
        if pos >= len(spaces) - 1:
            return  # already last
        insert_index = pos + 2  # +1 to step down, +1 for the post-removal shift
    else:
        if pos == 0:
            return  # already first
        insert_index = pos - 1

    call("workspace.move", {"workspace_id": focused["workspace_id"], "insert_index": insert_index})


if __name__ == "__main__":
    main()
