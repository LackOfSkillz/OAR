"""VG07-04: hypothetical group analysis, offline.

"What if we went in with these classes and roles?" Uses only:
  * the addon's own tables (addon_tables.json, generated from the addon by
    tools/vanguard_tables.lua and checked against it by a spec): which class
    can fill which role and which class can bring which utility;
  * the researched boss needs (verified = false: shown as "from a guide",
    never as fact);
  * past runs in your vault that match the group's shape, described with a
    Wilson interval and counts, and only from 5 known runs up.
It says what's covered, what isn't and what isn't known. "Can bring" means
the class can learn it; whether that player trained or will use it is not
known. It is not a chance of success and it controls nothing in the game.
"""
import json
import math
from pathlib import Path

TABLES = Path(__file__).with_name("addon_tables.json")
MIN_RUNS = 5
LIMITS = ["Class abilities are what a class can learn; trained spells, talents and gear are not known here.",
          "Boss needs come from guides (unverified in game on WoW Forever); Classic-based guides may differ.",
          "Past results describe your own imported runs, not odds for the next run.",
          "Nothing here is a success probability."]


class ScenarioError(ValueError):
    pass


def tables():
    with open(TABLES, encoding="utf-8") as f:
        return json.load(f)


def wilson(k, n, z=1.96):
    if n <= 0:
        return None
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return {"low": round((c - r) / d, 3), "high": round((c + r) / d, 3), "k": k, "n": n}


def _members(group, t):
    if not isinstance(group, list) or not 1 <= len(group) <= 40:
        raise ScenarioError("a group is 1 to 40 members")
    out = []
    for i, m in enumerate(group):
        if not isinstance(m, dict):
            raise ScenarioError("member %d is not a table" % (i + 1))
        cls, role, lvl = m.get("class"), m.get("role"), m.get("level")
        if cls not in t["roles"]:
            raise ScenarioError("member %d: unknown class %r" % (i + 1, cls))
        if role is not None and role not in ("TANK", "HEALER", "DAMAGER"):
            raise ScenarioError("member %d: role must be TANK, HEALER or DAMAGER" % (i + 1))
        if role is not None and role not in t["roles"][cls]:
            raise ScenarioError("member %d: a %s can't fill %s" % (i + 1, cls.lower(), role))
        if lvl is not None and (isinstance(lvl, bool) or not isinstance(lvl, int) or not 1 <= lvl <= 100):
            raise ScenarioError("member %d: level must be 1 to 100" % (i + 1))
        out.append({"class": cls, "role": role, "level": lvl})
    return out


def _shape(members):
    s = {"members": len(members), "tank": 0, "healer": 0, "damage": 0, "unknownRole": 0}
    for m in members:
        key = {"TANK": "tank", "HEALER": "healer", "DAMAGER": "damage"}.get(m["role"], "unknownRole")
        s[key] += 1
    lv = [m["level"] for m in members if m["level"]]
    s["levelMin"], s["levelMax"] = (min(lv), max(lv)) if lv else (None, None)
    return s


def _similar(run, shape):
    f = run.get("features") or {}
    for k in ("members", "tank", "healer"):
        if f.get(k) != shape[k]:
            return False
    if shape["levelMin"] and f.get("levelMin") and abs(f["levelMin"] - shape["levelMin"]) > 3:
        return False
    if shape["levelMax"] and f.get("levelMax") and abs(f["levelMax"] - shape["levelMax"]) > 3:
        return False
    return True


def analyse(group, instance=None, past_runs=None):
    t = tables()
    members = _members(group, t)
    shape = _shape(members)
    classes = {m["class"] for m in members}
    caps = {}
    for cap, c in t["caps"].items():
        who = sorted(classes & set(c["classes"]))
        caps[cap] = {"label": c["label"], "canBring": who, "state": "potential" if who else "none in group"}
    out = {"shape": shape, "capabilities": caps, "limits": list(LIMITS), "instance": instance, "bosses": [],
           "notes": []}
    size = None
    if instance:
        raid = t["raids"].get(instance)
        size = raid and raid.get("size")
        if raid and raid.get("status"):
            out["notes"].append("%s: %s" % (instance, raid["status"]))
        if size and shape["members"] > size:
            out["notes"].append("more members (%d) than the place allows (%d)" % (shape["members"], size))
        facts = t["bosses"].get(instance)
        if not facts:
            out["notes"].append("no researched boss needs for %s" % instance)
        else:
            label = "Classic-based guide (Forever may differ)" if facts["kind"] == "classic" else "WoW Forever guide"
            for b in facts["list"]:
                needs, watch = [], []
                for tag in b["tags"]:
                    cap = t["tagCap"].get(tag)
                    if cap:
                        who = caps.get(cap, {}).get("canBring", [])
                        needs.append({"need": cap, "covered": bool(who), "by": who})
                    elif tag in t["tagNote"]:
                        watch.append(t["tagNote"][tag])
                out["bosses"].append({"name": b["name"], "optional": bool(b.get("optional")), "needs": needs,
                                      "watch": watch, "source": label, "verified": False})
    if shape["members"] <= 5 and not (size and size > 5):
        if shape["tank"] == 0:
            out["notes"].append("no tank named")
        if shape["healer"] == 0:
            out["notes"].append("no healer named")
    if past_runs is not None:
        same = [r for r in past_runs if (not instance or r.get("instance") == instance) and _similar(r, shape)]
        known = [r for r in same if r.get("outcome") in ("completed", "incomplete", "abandoned")]
        past = {"similarRuns": len(same), "known": len(known),
                "unknownOutcome": len(same) - len(known)}
        if len(known) >= MIN_RUNS:
            past["fullClear"] = wilson(sum(1 for r in known if r["outcome"] == "completed"), len(known))
        else:
            past["fullClear"] = None
            past["why"] = "fewer than %d similar runs with a known outcome" % MIN_RUNS
        out["past"] = past
    return out


def text(result):
    s = result["shape"]
    lines = ["Group: %d members (tank %d, healer %d, damage %d, role not set %d)" %
             (s["members"], s["tank"], s["healer"], s["damage"], s["unknownRole"])]
    have = sorted(c["label"] for c in result["capabilities"].values() if c["canBring"])
    lines.append("Can bring (if trained): " + (", ".join(have) or "nothing listed"))
    for b in result["bosses"]:
        miss = [result["capabilities"].get(n["need"], {}).get("label", n["need"]) for n in b["needs"] if not n["covered"]]
        lines.append("  %s: %s%s" % (b["name"], ("missing " + ", ".join(miss)) if miss else "needs covered",
                                     ("; watch: " + ", ".join(b["watch"])) if b["watch"] else ""))
    for n in result["notes"]:
        lines.append("Note: " + n)
    p = result.get("past")
    if p:
        if p["fullClear"]:
            w = p["fullClear"]
            lines.append("Past similar runs: %d of %d full clears (between %.0f%% and %.0f%%, your runs only)" %
                         (w["k"], w["n"], w["low"] * 100, w["high"] * 100))
        else:
            lines.append("Past similar runs: %d known; %s" % (p["known"], p["why"]))
    lines.extend("Limit: " + x for x in result["limits"])
    return "\n".join(lines)
