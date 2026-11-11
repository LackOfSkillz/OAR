"""Config and read-only access to Outrider's SavedVariables (P9-03)."""

import json
import os

from . import luadata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, "companion", "config.json")
LOCAL = os.path.join(ROOT, "tools", "local.json")
MAX_FILE = 20 * 1024 * 1024


class NotConfigured(RuntimeError):
    pass


def load_config(path=CONFIG):
    """The companion only runs when companion/config.json says enabled: true.
    Paths default to the ones tools/find-wow.ps1 wrote into tools/local.json."""
    if not os.path.exists(path):
        raise NotConfigured("companion/config.json is missing: copy config.example.json and set enabled to true")
    with open(path, encoding="utf-8-sig") as f:
        cfg = json.load(f)
    if cfg.get("enabled") is not True:
        raise NotConfigured("companion/config.json has enabled: false")
    local = {}
    if os.path.exists(LOCAL):
        with open(LOCAL, encoding="utf-8-sig") as f:
            local = json.load(f)
    sv = cfg.get("savedVariablesFile") or (local.get("wtfAccountDir") and
                                           os.path.join(local["wtfAccountDir"], "SavedVariables", "Outrider.lua"))
    addons = cfg.get("addonsDir") or local.get("addonsDir")
    if not sv or not addons:
        raise NotConfigured("set savedVariablesFile and addonsDir in companion/config.json")
    return {"savedVariablesFile": sv,
            "adviceFile": os.path.join(addons, "Outrider", "Advisor", "Advice.lua")}


class Store:
    """Parses Outrider.lua again whenever it changed on disk (WoW writes it on
    /reload and logout). Never writes to it."""

    def __init__(self, sv_file):
        self.path, self.mtime, self.data = sv_file, None, {}

    def load(self):
        try:
            st = os.stat(self.path)
        except OSError:
            raise RuntimeError("no Outrider.lua yet: log in once with Outrider enabled, then /reload")
        if st.st_size > MAX_FILE:
            raise RuntimeError("Outrider.lua is unexpectedly large; not reading it")
        if self.mtime != st.st_mtime:
            with open(self.path, encoding="utf-8", errors="replace") as f:
                self.data = luadata.parse(f.read())
            self.mtime = st.st_mtime
        return self.data

    def _db(self):
        db = self.load().get("Outrider_DB")
        return db if isinstance(db, dict) else {}

    def _global(self):
        g = self._db().get("global")
        return g if isinstance(g, dict) else {}

    def characters(self):
        out = []
        snaps = self.load().get("Outrider_Snapshots") or {}
        for key, c in (self._db().get("chars") or {}).items():
            meta = (c or {}).get("meta") or {}
            snap = snaps.get(key) if isinstance(snaps, dict) else None
            out.append({"character": key, "class": meta.get("class"), "level": meta.get("level"),
                        "race": meta.get("race"), "faction": meta.get("faction"),
                        "snapshotTakenAt": snap.get("takenAt") if isinstance(snap, dict) else None})
        return sorted(out, key=lambda c: c["character"])

    def snapshot(self, char):
        snaps = self.load().get("Outrider_Snapshots") or {}
        snap = snaps.get(char) if isinstance(snaps, dict) else None
        if not isinstance(snap, dict):
            raise KeyError("no snapshot for %s: type /ride ask in game on that character" % char)
        return snap

    def rare_log(self, char, limit=50):
        g = self._global()
        names = ((g.get("discovered") or {}).get("npcs") or {})
        rows = []
        for npc, sightings in (g.get("sightings") or {}).items():
            if not isinstance(sightings, list) or not sightings:
                continue
            last = sightings[-1]
            d = names.get(npc) or {}
            rows.append({"npcID": npc, "name": d.get("name"), "sightings": len(sightings), "last": last,
                         "respawnObservations": len((g.get("respawnObs") or {}).get(npc) or [])})
        rows.sort(key=lambda r: (r["last"] or {}).get("t", 0), reverse=True)
        snap = None
        try:
            snap = self.snapshot(char)
        except KeyError:
            pass
        watch = (((snap or {}).get("modules") or {}).get("RareScan") or {}).get("watch")
        return {"watchlist": watch or [], "rares": rows[:limit]}

    def gear(self, char):
        snap = self.snapshot(char)
        mods = snap.get("modules") or {}
        return {"worn": snap.get("gear") or {}, "role": (mods.get("GearScore") or {}).get("role"),
                "weights": (mods.get("GearScore") or {}).get("weights") or {},
                "candidates": (mods.get("Nearby") or {}).get("candidates") or []}

    def professions(self, char):
        c = (self._db().get("chars") or {}).get(char)
        if not isinstance(c, dict):
            raise KeyError("unknown character %s" % char)
        out = {}
        for name, p in (c.get("professions") or {}).items():
            recipes = (p or {}).get("recipes") or {}
            out[name] = {"skill": p.get("skill"), "max": p.get("max"),
                         "recipes": sorted(r.get("name") for r in recipes.values() if isinstance(r, dict) and r.get("name"))}
        snap = None
        try:
            snap = self.snapshot(char)
        except KeyError:
            pass
        queue = (((snap or {}).get("modules") or {}).get("CraftQueue")) or {}
        return {"professions": out, "craftQueue": queue}
