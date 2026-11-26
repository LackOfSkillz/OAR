"""VG07-03: a local vault for Vanguard run history (SQLite, standard library).

The Command Center's Knowledge Vault (docs/command-center, OCC-02) is not
built yet, so this is a small vault in the same style (data contracts
sections 5 and 6): STRICT tables, canonical JSON with sha256, one transaction
per import, provenance for every row, revisions instead of overwrites, and
nothing is ever deleted. It lives in its own file so the Command Center can
adopt it later without a clash:
  %LOCALAPPDATA%\\Outrider\\CommandCenter\\vanguard.sqlite  (configurable)
Outside the repository, the game folder and the program folder.

Rules:
  * importing the same file again changes nothing;
  * the same run with different content becomes revision n+1 (old kept);
  * queries are scoped to one exporter unless everyone is asked for;
  * a damaged vault opens read-only; restore writes a new file and keeps the
    damaged one beside it.
"""
import json
import os
import shutil
import sqlite3
import time
from pathlib import Path

from . import contract

SCHEMA_VERSION = 1
APP_VERSION = "vg07-1"

SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) STRICT;
CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY, sha256 TEXT NOT NULL UNIQUE, path TEXT NOT NULL, size INTEGER NOT NULL,
  exporter TEXT NOT NULL, created_at INTEGER NOT NULL, imported_at INTEGER NOT NULL,
  consent_json TEXT NOT NULL, profile_json TEXT, synthetic INTEGER NOT NULL DEFAULT 0) STRICT;
CREATE TABLE IF NOT EXISTS ingest_runs (
  id INTEGER PRIMARY KEY, source_id INTEGER REFERENCES sources(id), started_at INTEGER NOT NULL,
  finished_at INTEGER, status TEXT NOT NULL CHECK (status IN ('ok','failed','skipped')),
  app_version TEXT NOT NULL, counts_json TEXT, error TEXT) STRICT;
CREATE TABLE IF NOT EXISTS runs (
  id INTEGER PRIMARY KEY, exporter TEXT NOT NULL, run_id TEXT NOT NULL, revision INTEGER NOT NULL,
  instance TEXT NOT NULL, outcome TEXT NOT NULL, started_at INTEGER NOT NULL, build TEXT,
  row_json TEXT NOT NULL, row_sha256 TEXT NOT NULL, source_id INTEGER NOT NULL REFERENCES sources(id),
  UNIQUE (exporter, run_id, revision)) STRICT;
CREATE TABLE IF NOT EXISTS provenance (
  id INTEGER PRIMARY KEY, tbl TEXT NOT NULL, row_id INTEGER NOT NULL,
  ingest_run_id INTEGER NOT NULL REFERENCES ingest_runs(id), source_id INTEGER NOT NULL REFERENCES sources(id),
  revision INTEGER NOT NULL, UNIQUE (tbl, row_id, revision)) STRICT;
CREATE INDEX IF NOT EXISTS runs_scope ON runs (exporter, instance, started_at);
"""


class VaultError(RuntimeError):
    pass


def default_path():
    base = os.environ.get("LOCALAPPDATA") or str(Path.home())
    return str(Path(base) / "Outrider" / "CommandCenter" / "vanguard.sqlite")


class Vault:
    def __init__(self, path=None):
        self.path = Path(path or default_path())
        if contract._inside_game(self.path):
            raise VaultError("the vault can't live inside the game folder")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.read_only = False
        self.problem = None
        fresh = not self.path.exists()
        self.db = sqlite3.connect(str(self.path))
        try:
            self.db.execute("PRAGMA foreign_keys=ON")
            if not fresh:
                ok = self.db.execute("PRAGMA integrity_check").fetchone()[0]
                if ok != "ok":
                    raise sqlite3.DatabaseError(ok)
            ver = self.db.execute("PRAGMA user_version").fetchone()[0]
            if ver > SCHEMA_VERSION:
                self.read_only, self.problem = True, "made by a newer Outrider; opened read-only"
                return
            with self.db:
                self.db.executescript(SCHEMA)
                self.db.execute("PRAGMA user_version=%d" % SCHEMA_VERSION)
                self.db.execute("INSERT OR IGNORE INTO meta VALUES ('schema_version', ?)", (str(SCHEMA_VERSION),))
                self.db.execute("INSERT OR IGNORE INTO meta VALUES ('created_at', ?)", (str(int(time.time())),))
        except sqlite3.DatabaseError as exc:
            self.db.close()
            self.db = sqlite3.connect("file:%s?mode=ro" % self.path.as_posix(), uri=True)
            self.read_only, self.problem = True, "the vault file is damaged (%s); opened read-only, restore a backup" % exc

    def close(self):
        self.db.close()

    # ------------------------------------------------------------ import
    def import_envelope(self, env, sha, path, *, now=None):
        if self.read_only:
            raise VaultError(self.problem or "read-only")
        now = int(time.time() if now is None else now)
        known = self.db.execute("SELECT id FROM sources WHERE sha256=?", (sha,)).fetchone()
        if known:
            with self.db:
                self.db.execute("INSERT INTO ingest_runs (source_id, started_at, finished_at, status, app_version,"
                                " counts_json) VALUES (?,?,?,?,?,?)",
                                (known[0], now, now, "skipped", APP_VERSION, '{"reason":"same file"}'))
            return {"status": "skipped", "new": 0, "revised": 0, "unchanged": len(env["runs"])}
        counts = {"new": 0, "revised": 0, "unchanged": 0}
        try:
            with self.db:  # one transaction: all or nothing
                cur = self.db.execute(
                    "INSERT INTO sources (sha256, path, size, exporter, created_at, imported_at, consent_json,"
                    " profile_json, synthetic) VALUES (?,?,?,?,?,?,?,?,?)",
                    (sha, str(path), len(contract.canonical(env)), env["exporter"], env["createdAt"], now,
                     contract.canonical(env["consent"]).decode(), json.dumps(env.get("profile"), sort_keys=True)
                     if "profile" in env else None, 1 if env.get("synthetic") else 0))
                src = cur.lastrowid
                run_row = self.db.execute("INSERT INTO ingest_runs (source_id, started_at, status, app_version)"
                                          " VALUES (?,?,?,?)", (src, now, "ok", APP_VERSION)).lastrowid
                for r in env["runs"]:
                    body = contract.canonical(r).decode()
                    digest = contract.sha256(r)
                    last = self.db.execute("SELECT revision, row_sha256 FROM runs WHERE exporter=? AND run_id=?"
                                           " ORDER BY revision DESC LIMIT 1", (env["exporter"], r["runId"])).fetchone()
                    if last and last[1] == digest:
                        counts["unchanged"] += 1
                        continue
                    rev = (last[0] + 1) if last else 1
                    rid = self.db.execute(
                        "INSERT INTO runs (exporter, run_id, revision, instance, outcome, started_at, build, row_json,"
                        " row_sha256, source_id) VALUES (?,?,?,?,?,?,?,?,?,?)",
                        (env["exporter"], r["runId"], rev, r["instance"], r["outcome"], int(r["startedAt"]),
                         r.get("build"), body, digest, src)).lastrowid
                    self.db.execute("INSERT INTO provenance (tbl, row_id, ingest_run_id, source_id, revision)"
                                    " VALUES ('runs',?,?,?,?)", (rid, run_row, src, rev))
                    counts["revised" if last else "new"] += 1
                self.db.execute("UPDATE ingest_runs SET finished_at=?, counts_json=? WHERE id=?",
                                (now, json.dumps(counts, sort_keys=True), run_row))
        except sqlite3.DatabaseError as exc:
            with self.db:
                self.db.execute("INSERT INTO ingest_runs (started_at, finished_at, status, app_version, error)"
                                " VALUES (?,?,?,?,?)", (now, now, "failed", APP_VERSION, str(exc)[:200]))
            raise VaultError("import failed and was rolled back: %s" % exc) from exc
        counts["status"] = "ok"
        return counts

    def import_file(self, path, *, now=None):
        env, sha = contract.read_import(path)
        return self.import_envelope(env, sha, path, now=now)

    # ------------------------------------------------------------ queries
    def runs(self, *, exporter=None, everyone=False, instance=None, include_synthetic=False, guild_only=False):
        """Latest revision of each run. Scoped to one exporter unless everyone=True."""
        if not everyone and not exporter:
            raise VaultError("say whose runs (an exporter id) or ask for everyone")
        sql = ("SELECT r.row_json, r.exporter, s.synthetic, s.consent_json FROM runs r JOIN sources s ON s.id = r.source_id"
               " WHERE r.revision = (SELECT MAX(revision) FROM runs x WHERE x.exporter = r.exporter AND x.run_id = r.run_id)")
        args = []
        if not everyone:
            sql += " AND r.exporter = ?"
            args.append(exporter)
        if instance:
            sql += " AND r.instance = ?"
            args.append(instance)
        if not include_synthetic:
            sql += " AND s.synthetic = 0"
        sql += " ORDER BY r.started_at, r.run_id"
        out = []
        for body, who, synth, consent in self.db.execute(sql, args):
            if guild_only and not json.loads(consent).get("guild"):
                continue
            row = json.loads(body)
            row["_exporter"], row["_synthetic"] = who, bool(synth)
            out.append(row)
        return out

    def exporters(self):
        return [r[0] for r in self.db.execute("SELECT DISTINCT exporter FROM sources ORDER BY exporter")]

    def revisions(self, exporter, run_id):
        return [r[0] for r in self.db.execute("SELECT revision FROM runs WHERE exporter=? AND run_id=? ORDER BY revision",
                                              (exporter, run_id))]

    def status(self):
        q = lambda s: self.db.execute(s).fetchone()[0]  # noqa: E731
        return {"path": str(self.path), "readOnly": self.read_only, "problem": self.problem,
                "schema": q("PRAGMA user_version"), "sources": q("SELECT COUNT(*) FROM sources"),
                "runRows": q("SELECT COUNT(*) FROM runs"), "exporters": q("SELECT COUNT(DISTINCT exporter) FROM sources"),
                "imports": q("SELECT COUNT(*) FROM ingest_runs"),
                "failedImports": q("SELECT COUNT(*) FROM ingest_runs WHERE status='failed'")}

    # ------------------------------------------------------------ backup / restore
    def backup(self, *, stamp=None):
        stamp = stamp or time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
        d = self.path.parent / "backups"
        d.mkdir(exist_ok=True)
        out = d / ("vanguard-%s.sqlite" % stamp)
        if out.exists():
            raise VaultError("a backup with that name exists; not overwriting it")
        dest = sqlite3.connect(str(out))
        try:
            self.db.backup(dest)
        finally:
            dest.close()
        return str(out)


def restore(vault_path, backup_file, *, stamp=None):
    """Put a backup in place. The current file is kept beside it, never deleted."""
    vault_path, backup_file = Path(vault_path), Path(backup_file)
    if not backup_file.is_file():
        raise VaultError("no such backup")
    check = sqlite3.connect("file:%s?mode=ro" % backup_file.as_posix(), uri=True)
    try:
        if check.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise VaultError("that backup is damaged too")
    finally:
        check.close()
    kept = None
    if vault_path.exists():
        stamp = stamp or time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
        kept = vault_path.with_name(vault_path.stem + ".before-restore-%s.sqlite" % stamp)
        if kept.exists():
            raise VaultError("a kept copy with that name exists")
        os.replace(vault_path, kept)
    shutil.copyfile(backup_file, vault_path)
    return {"restored": str(vault_path), "kept": str(kept) if kept else None}
