"""tools/import_mob_res.py -- what each mob resists, is immune to and casts (smart loadout, SL-00).

Sources (private copy, decision D10; verified = false until seen in game):
  * VMaNGOS world database (GPL-2.0-or-later), SQLite dump from
    github.com/vmangos/core releases "db_latest", unpacked in private/vmangos-source/.
    creature_template: holy/fire/nature/frost/shadow/arcane resistance,
    school_immune_mask, mechanic_immune_mask, damage_school (its melee school);
    creature_spells + creature_ai_events/scripts (command 15 = cast): spells it casts.
  * WoW Forever client SpellMisc.SchoolMask (wago.tools, private/wago-source):
    the school of each spell on Forever; VMaNGOS spell_template.school fills gaps.

These are 1.12 server values. Forever's new mobs and changes are not in them:
Outrider's own fights override them in game.

Writes private/Outrider_Data_Mobs/Res.lua (Outrider_DataMobRes).
Usage:  py tools/import_mob_res.py
"""
import csv, os, sqlite3, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "private", "vmangos-source", "sqlite-dump", "mangos.sqlite")
WAGO = os.path.join(ROOT, "private", "wago-source")
OUT = os.path.join(ROOT, "private", "Outrider_Data_Mobs", "Res.lua")

SCHOOLS = ["physical", "holy", "fire", "nature", "frost", "shadow", "arcane"]  # bit i = 1 << i
RES_COLS = [("holy", "holy_res"), ("fire", "fire_res"), ("nature", "nature_res"),
            ("frost", "frost_res"), ("shadow", "shadow_res"), ("arcane", "arcane_res")]
# Mechanic ids (1.12 SpellMechanic); mask bit = 1 << (id - 1). Only the ones a player plans around.
MECH = {1: "charm", 2: "disorient", 5: "fear", 7: "root", 9: "silence", 10: "sleep",
        11: "snare", 12: "stun", 13: "freeze", 15: "bleed", 17: "polymorph", 18: "banish",
        20: "shackle", 23: "turn", 24: "horror", 26: "interrupt", 27: "daze"}
# implicit targets that hit an enemy: single enemy, enemy areas, cone, dynamic object, chain
HOSTILE_TARGETS = {6, 15, 16, 24, 28, 53, 77}
DISPEL = {1: "magic", 2: "curse", 3: "disease", 4: "poison"}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def forever_schools():
    out = {}
    path = os.path.join(WAGO, "SpellMisc.csv")
    if not os.path.exists(path):
        return out
    with open(path, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r.get("DifficultyID", "0") in ("0", ""):
                out[int(r["SpellID"])] = int(r["SchoolMask"] or 0)
    return out


def forever_names():
    out = {}
    path = os.path.join(WAGO, "SpellName.csv")
    if os.path.exists(path):
        with open(path, newline="", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                out[int(r["ID"])] = r["Name_lang"]
    return out


def main():
    if not os.path.exists(DB):
        sys.exit("no VMaNGOS dump at " + DB)
    c = sqlite3.connect(DB)
    fmask, fname = forever_schools(), forever_names()

    # newest patch row per spell / creature
    spells = {}
    tcols = ",".join("effectImplicitTarget%s%d" % (ab, i) for ab in "AB" for i in (1, 2, 3))
    for row in c.execute(
            "select entry, build, school, dispel, mechanic, name, effect1, effect2, effect3, %s "
            "from spell_template order by entry, build" % tcols):
        entry, build, school, dispel, mech, name = row[:6]
        effects, targets = row[6:9], row[9:]
        # aimed at an enemy (you): an enemy target or enemy area, or direct damage / leech
        hostile = any(t in HOSTILE_TARGETS for t in targets) or any(e in (2, 9) for e in effects)
        spells[entry] = (school, dispel, mech, name, hostile)
    mobs = {}
    for row in c.execute(
            "select entry, patch, name, damage_school, holy_res, fire_res, nature_res, frost_res, shadow_res, "
            "arcane_res, school_immune_mask, mechanic_immune_mask, spell_list_id from creature_template order by entry, patch"):
        mobs[row[0]] = row

    lists = {}
    for row in c.execute("select * from creature_spells"):
        ids = [row[2 + 11 * i] for i in range(8)]
        lists[row[0]] = [s for s in ids if s]
    casts = {}
    for mob, s in c.execute(
            "select e.creature_id, s.datalong from creature_ai_events e join creature_ai_scripts s "
            "on s.id in (e.action1_script, e.action2_script, e.action3_script) where s.command = 15 and s.datalong > 0"):
        casts.setdefault(mob, set()).add(s)

    used, rows = {}, []
    for entry, r in sorted(mobs.items()):
        _, _, name, dmg, *res = r[:10]
        imm, mech, listid = r[10] or 0, r[11] or 0, r[12] or 0
        resist = {k: v for (k, _), v in zip(RES_COLS, res) if v}
        cast = set(casts.get(entry, ())) | set(lists.get(listid, ()))
        cast = sorted(s for s in cast if s in spells or s in fmask)
        if not (resist or imm or mech or cast or (dmg or 0) > 0):
            continue
        for s in cast:
            used[s] = True
        rows.append((entry, name, dmg or 0, resist, imm, mech, cast))

    def school_mask(s):
        if s in fmask and fmask[s]:
            return fmask[s]
        return 1 << (spells[s][0] or 0) if s in spells else 0

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/import_mob_res.py from the VMaNGOS world database (GPL-2.0-or-later,\n"
                "-- github.com/vmangos/core db_latest) + WoW Forever client SpellMisc/SpellName (wago.tools).\n"
                "-- Private copy (D10), do not redistribute. 1.12 server values: verified = false;\n"
                "-- Outrider's own fights override them.\n"
                "-- mobs[npcID] = { res = {school = value}, imm = schoolMask, mech = mechanicMask, melee = schoolIndex, casts = {spellID...} }\n"
                "-- spells[spellID] = { name, schoolMask, dispel (1 magic 2 curse 3 disease 4 poison), mechanic, hostile (1 = aimed at you) }\n"
                "-- schoolMask bits: 1 physical 2 holy 4 fire 8 nature 16 frost 32 shadow 64 arcane\n")
        f.write("Outrider_DataMobRes = { source = %s, verified = false, mobs = {\n" % lua_str("VMaNGOS db_latest + Forever SpellMisc"))
        for entry, name, dmg, resist, imm, mech, cast in rows:
            parts = []
            if resist:
                parts.append("res={" + ",".join("%s=%d" % kv for kv in sorted(resist.items())) + "}")
            if imm:
                parts.append("imm=%d" % imm)
            if mech:
                parts.append("mech=%d" % mech)
            if dmg:
                parts.append("melee=%d" % dmg)
            if cast:
                parts.append("casts={" + ",".join(str(s) for s in cast) + "}")
            f.write("[%d]={%s}, -- %s\n" % (entry, ",".join(parts), name.replace("\n", " ")))
        f.write("}, spells = {\n")
        for s in sorted(used):
            school, dispel, mechid, name, hostile = spells.get(s, (0, 0, 0, "", False))
            name = fname.get(s, name) or ""
            f.write("[%d]={%s,%d,%d,%d,%d},\n" % (s, lua_str(name), school_mask(s), dispel or 0, mechid or 0,
                                                1 if hostile else 0))
        f.write("}, mechanics = {")
        f.write(",".join("[%d]=%s" % (k, lua_str(v)) for k, v in sorted(MECH.items())))
        f.write("}, dispels = {" + ",".join("[%d]=%s" % (k, lua_str(v)) for k, v in sorted(DISPEL.items())) + "} }\n")
    print("mobs %d, spells %d -> %s (%d KB)" % (len(rows), len(used), OUT, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
