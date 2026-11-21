"""Publish the six *generated* QuestieDB-derived data addons to public git.

Run from the OAR checkout after generators have built private/Outrider_Data_*.
The source directory is local, never committed verbatim. Only known generated
Data.lua and .toc files are copied. No SavedVariables, Shared observations, user
config, chat, logs, or local QuestieDB source ZIP are included.

Example:
    py tools/publish_public_packs.py --release-repo D:\\dev\\outrider-releases
    py tools/publish_public_packs.py --release-repo D:\\dev\\outrider-releases --commit --push

The first command STAGES and prints a preview; read the git diff before using
--commit/--push. Use --commit without --push if you want to review the commit.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKS = (
    "Outrider_Data_NPC",
    "Outrider_Data_Gear",
    "Outrider_Data_Mobs",
    "Outrider_Data_Nodes",
    "Outrider_Data_Dungeons",
    "Outrider_Data_Quests",
    "Outrider_Data_Reagents",
    "Outrider_Data_Paths",
)
ORIGIN = "https://github.com/Questie/QuestieDB"
GPL_ORIGIN = "https://github.com/Questie/QuestieDB/blob/master/LICENSE.md"

# Source files can embed a legacy PRIVATE label in their generated header.
# Make these public copies accurate, without rewriting any data record.
LEGACY_LABELS = (
    "Private copy (D10), do not redistribute.",
    "Private copy (D10/D13), do not redistribute.",
    "Private copy (D10), do not redistribute",
    "Private copy of",
    "Not for redistribution.",
    "Private quest objectives pack",
)
SENSITIVE = re.compile(
    r"(?:BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY|"
    r"(?i:api[_-]?key|access[_-]?token|password)\s*[:=]\s*['\"][^'\"]+['\"]|"
    r"(?i:savedvariables|\\\\users\\\\|/users/[^/]+/|private/questie-source))"
)


def git(where: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(where), *args],
                            capture_output=True, text=True, check=True)
    return result.stdout.strip()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require_public_target(repo: Path) -> None:
    if not (repo / ".git").exists():
        raise SystemExit("Release path is not an existing git checkout.")
    remote = git(repo, "remote", "get-url", "origin")
    if "LackOfSkillz/outrider-releases" not in remote.lower().replace(
        "lackofskillz", "LackOfSkillz"
    ):
        raise SystemExit("Refusing to write outside the public outrider-releases checkout.")
    if git(repo, "branch", "--show-current") != "main":
        raise SystemExit("Check out outrider-releases/main before export.")
    for line in git(repo, "status", "--porcelain").splitlines():
        changed = line[3:].replace("\\", "/")
        if changed != "data-packs/" and not changed.startswith("data-packs/"):
            raise SystemExit("Target checkout has changes outside data-packs; review before exporting.")


def clean_header(raw: bytes) -> bytes:
    text = raw.decode("utf-8-sig")
    # Generated pack text is checked, not mass-scrubbed: only *known* stale
    # redistribution claims in comments/TOC labels are updated.
    lines = text.splitlines(keepends=True)
    cleaned = []
    for line in lines:
        if any(term in line for term in LEGACY_LABELS):
            if not (line.lstrip().startswith("--") or line.lstrip().startswith("## Notes:")):
                raise SystemExit("Legacy private label appears outside a comment; review manually.")
            line = re.sub(r"Private copy(?: of)?", "Public GPLv3-derived copy", line)
            line = re.sub(r"Private quest objectives pack", "Public quest objectives pack", line)
            line = line.replace("Not for redistribution.", "Redistributed under GPLv3, subject to upstream rights.")
            line = line.replace("do not redistribute.", "GPLv3 redistribution; preserve upstream rights notices.")
        cleaned.append(line)
    result = "".join(cleaned)
    if SENSITIVE.search(result):
        raise SystemExit("Potential secret or local path in generated pack. Stop and review.")
    return result.encode("utf-8")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--release-repo", type=Path, required=True,
                   help="checked-out public LackOfSkillz/outrider-releases repository")
    p.add_argument("--commit", action="store_true", help="git add and commit exported source")
    p.add_argument("--push", action="store_true", help="push to public origin/main (requires --commit)")
    args = p.parse_args()
    if args.push and not args.commit:
        p.error("--push requires --commit")
    destrepo = args.release_repo.resolve()
    require_public_target(destrepo)
    license_text = (ROOT / "LICENSE").read_bytes()
    if b"GNU GENERAL PUBLIC LICENSE" not in license_text or len(license_text) < 33000:
        raise SystemExit("Full root GPLv3 license is missing.")

    # Validate ALL packs before copying ANY to the public checkout.
    pending = {}
    for name in PACKS:
        src = ROOT / "private" / name
        toc, lua = src / (name + ".toc"), src / "Data.lua"
        if not toc.is_file() or not lua.is_file():
            raise SystemExit(f"Missing generated pack: {name}. Run its tools/import_*.py generator first.")
        files = [toc, lua]
        size = sum(x.stat().st_size for x in files)
        if size < 80:
            raise SystemExit(f"Unexpectedly empty pack {name}")
        generated = {file.name: clean_header(file.read_bytes()) for file in files}
        toc_text = generated[toc.name].decode("utf-8")
        if "Data.lua" not in toc_text or "QuestieDB" not in toc_text:
            raise SystemExit(f"Missing provenance in {toc.name}; review generator output.")
        ver = re.search(r"## X-Source:\s*([^\n\r]+)", toc_text)
        source_version = ver.group(1) if ver else "unrecorded"
        pending[name] = (generated, source_version)
    print("Validated all six generated data packs; publishing source, not personal SavedVariables.")

    manifest = []
    for name, (generated, version) in pending.items():
        target = destrepo / "data-packs" / name
        target.mkdir(parents=True, exist_ok=True)
        for filename, data in generated.items():
            (target / filename).write_bytes(data)
            manifest.append((name, filename, len(data), sha(data)))
        (target / "COPYING").write_bytes(license_text)
        (target / "SOURCE.md").write_text(
            "# " + name + " — provenance\n\n"
            "Data converted from [QuestieDB](" + ORIGIN + ") (" + version + ") "
            "using the matching converter in LackOfSkillz/OAR/tools. "
            "Published by Gary Mix with project modifications under GPLv3.\n\n"
            "The underlying Questie and QuestieDB data retains its original authors' "
            "copyright. See the upstream [LICENSE.md](" + GPL_ORIGIN + ") and "
            "PROVENANCE.md; its maintainers disclose unresolved historic-contributor "
            "rights. Publication does not cure that uncertainty.\n\n"
            "The pack is original-source-derived, NOT gameplay-verified for every "
            "WoW Forever location. No personal observation data is included.\n",
            encoding="utf-8",
        )
        print(f"{name}: {version}, " + ", ".join(
            f"{k} {len(v)} bytes" for k, v in generated.items()))
    stamp = dt.date.today().isoformat()
    lines = [
        "# Data-pack publication manifest", "",
        "Generated packs exported from the local OAR generators on " + stamp + ".",
        "This file is source provenance, not a guarantee that each record is accurate.",
        "Only fixed, allowlisted Lua/TOC files are published.", "",
        "| Pack | File | Bytes | SHA-256 |", "|---|---|---:|---|",
    ]
    for name, filename, size, digest in manifest:
        lines.append(f"| {name} | {filename} | {size} | {digest} |")
    (destrepo / "data-packs" / "MANIFEST.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )
    print("\nReview changes first: git -C", destrepo, "diff --stat")
    public_readme = destrepo / "data-packs" / "README.md"
    if public_readme.is_file():
        lines = public_readme.read_text(encoding="utf-8").splitlines()
        for name in PACKS:
            for idx, line in enumerate(lines):
                if "| " + name + " |" in line and "| **Not yet committed** |" in line:
                    lines[idx] = line.replace(
                        "| **Not yet committed** |",
                        "| **Committed**: [" + name + "](" + name + "/) |"
                    )
        public_readme.write_text("\n".join(lines) + "\n", encoding="utf-8")
    main_readme = destrepo / "README.md"
    if main_readme.is_file():
        data = main_readme.read_text(encoding="utf-8")
        data = data.replace(
            "The QuestieDB-derived **NPC, Gear, Mobs, Nodes, Dungeons and Quests** data pack files have **not yet been committed as standalone sources**; only build archives are available under Releases.",
            "The QuestieDB-derived **NPC, Gear, Mobs, Nodes, Dungeons and Quests** source packs are now published in [data-packs](data-packs/), with the original upstream attribution and license; check the per-pack provenance."
        )
        data = data.replace(
            "The remaining six generated QuestieDB packs must be exported from the local build with their source revision, license and attribution intact before their public-source publication can be claimed.",
            "The six generated QuestieDB packs were exported from locally built sources with per-pack provenance, attribution and GPLv3 terms. Verify provenance before repackaging or redistribution."
        )
        main_readme.write_text(data, encoding="utf-8")
    if args.commit:
        git(destrepo, "add", "--", "data-packs", "README.md")
        commit = git(destrepo, "commit", "-m",
                     "Publish six generated GPLv3 QuestieDB-derived Outrider data packs")
        print(commit)
        if args.push:
            print(git(destrepo, "push", "origin", "main"))
    else:
        print("Changes prepared but NOT committed or pushed. Run again with --commit [--push].")


if __name__ == "__main__":
    main()
