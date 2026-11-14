"""Windows clipboard through PowerShell (no extra packages). Local only.

Gary copies the snapshot code in game (Ctrl+C) and pastes the advice code
(Ctrl+V); the companion only reads and writes the clipboard when a tool is
called. Nothing is sent anywhere.
"""

import subprocess

MAX = 2 * 1024 * 1024


def read():
    out = subprocess.run(["powershell", "-NoProfile", "-Command", "Get-Clipboard -Raw"],
                         capture_output=True, text=True, timeout=20)
    if out.returncode != 0:
        raise RuntimeError("could not read the clipboard")
    text = out.stdout or ""
    if len(text) > MAX:
        raise RuntimeError("clipboard is too large")
    return text.strip()


def write(text):
    out = subprocess.run(["powershell", "-NoProfile", "-Command", "$input | Set-Clipboard"],
                         input=text, capture_output=True, text=True, timeout=20)
    if out.returncode != 0:
        raise RuntimeError("could not write the clipboard")
    return True
