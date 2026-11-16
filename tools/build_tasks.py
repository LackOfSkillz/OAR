#!/usr/bin/env python3
"""Regenerate TASKS.md from phases/*.md, keeping existing status marks and notes.

    python tools/build_tasks.py

Task headings in phase files look like:
    ### P2-04 · RareAlerts · Claude · deps: P2-03, P1-05
Status lives only in TASKS.md (lines like "- [x] P2-04 ... — 2026-11-20: note").
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PHASES = sorted((ROOT / "phases").glob("P*.md"))
TASKS = ROOT / "TASKS.md"

HEAD = re.compile(r"^### ((?:P\d|R)-\d+) · (.+?) · (.+?)(?: · deps: (.+))?$")
GATE = re.compile(r"^\*\*Gate (G\d):\*\* (.+)$")
TITLE = re.compile(r"^# (.+)$")

old = {}
if TASKS.exists():
    for line in TASKS.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^- \[(.)\] \**((?:P\d|R)-\d+|G\d)\**(.*)$", line)
        if m:
            note = ""
            if " — " in m.group(3):
                note = m.group(3).split(" — ", 1)[1]
            else:
                # some notes were written as " · 2026-11-11: ..."; keep them too
                # (a rebuild dropped them, 2026-11-15)
                d = re.search(r" · (\d{4}-\d\d-\d\d.*)$", m.group(3))
                if d:
                    note = d.group(1)
            old[m.group(2)] = (m.group(1), note)

out = [
    "# TASKS",
    "",
    "Master checklist. Details, steps and acceptance checks for each task are in the phase file linked in each heading.",
    "Claude Code: work top to bottom, skip tasks whose deps are not done, and update the status here when a task closes.",
    "",
    "Status: `[ ]` to do · `[~]` in progress · `[x]` done · `[!]` blocked. Append ` — <date>: <note>` when closing or blocking.",
    "Owners: **Claude** works alone · **Gary** needs Gary · **Both** code first, then a short in-game check.",
    "",
    "Already built in this package (verify in P0/P1, don't rebuild): module loader, per-character settings, export/import/copy,",
    "error catcher, debug log, API probe, hub window, minimap button, settings page, snapshot + advice loader (dormant),",
    "data registry, hunter macro pack (unverified), test harness, deploy/read-logs/backup/package tools.",
    "",
    "Regenerate the list after editing phase files: `python tools/build_tasks.py` (keeps statuses and notes).",
    "",
]
summary = []
for path in PHASES:
    lines = path.read_text(encoding="utf-8").splitlines()
    title = next((TITLE.match(l).group(1) for l in lines if TITLE.match(l)), path.stem)
    rel = path.relative_to(ROOT).as_posix()
    out.append(f"## {title}  ([{rel}]({rel}))")
    out.append("")
    count = 0
    gate = None

    def flush_gate():
        global gate
        if gate:
            out.append(gate)
            gate = None

    for l in lines:
        t = TITLE.match(l)
        if t and t.group(1) != title:
            flush_gate()
            out.append("")
            out.append(f"### {t.group(1)}")
            out.append("")
            continue
        m = HEAD.match(l)
        if m:
            tid, name, owner, deps = m.groups()
            mark, note = old.get(tid, (" ", ""))
            line = f"- [{mark}] {tid} {name} · {owner} · deps: {deps or 'none'}"
            if note:
                line += f" — {note}"
            out.append(line)
            count += 1
            continue
        g = GATE.match(l)
        if g:
            gid, text = g.groups()
            mark, note = old.get(gid, (" ", ""))
            gate = f"- [{mark}] **{gid}** gate: {text}" + (f" — {note}" if note else "")
    flush_gate()
    out.append("")
    summary.append((title, count))

out.append("## Totals")
out.append("")
out.append("| Phase | Tasks |")
out.append("|---|---|")
for title, count in summary:
    out.append(f"| {title} | {count} |")
out.append(f"| **All** | **{sum(c for _, c in summary)}** |")
out.append("")
TASKS.write_text("\n".join(out), encoding="utf-8")
print(f"wrote {TASKS.relative_to(ROOT)}: {sum(c for _, c in summary)} tasks in {len(summary)} phase files")
