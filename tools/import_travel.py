"""tools/import_travel.py -- travel network for the route planner, from ForeverDB.

ForeverDB's copy of Shortest Path Forever (GPL-3.0-or-later,
github.com/cjber/shortest-path-forever) has WoW Forever's travel network in
world coordinates:
  TaxiNodes   flight masters (id = the client's taxi node id)
  TaxiPaths   direct flight legs with their real flight time in seconds
  Docks       where boats and zeppelins stop, and the spot you walk on from
  Routes      boats/zeppelins/trams: period and arrive/depart time per stop
  Portals     portals and passages with their seconds; Hops = lifts
World positions become map positions with the client's own UI map bounds
(ForeverDB 'umaa'), using the smallest zone map that holds the point.

Writes private/Outrider_Data_Travel (load on demand, GPLv3). verified = false.
Usage:  py tools/import_travel.py
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import foreverdb as fdb  # noqa: E402

ROOT = fdb.ROOT
OUT = os.path.join(ROOT, "private", "Outrider_Data_Travel")
ZONE_TYPES = (3, 4, 5)   # zone, dungeon-ish, micro: smallest holding map wins; continents only as a last resort


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


class Maps:
    def __init__(self, d):
        self.bounds = []
        for row in d["umaa"].values():
            ui, cont = row[0], row[1]
            minx, miny, maxx, maxy = row[7], row[8], row[10], row[11]
            info = d["umap"].get(str(ui))
            mtype = info[2] if info else 3
            if maxx > minx and maxy > miny:
                self.bounds.append((ui, cont, minx, miny, maxx, maxy, mtype, (maxx - minx) * (maxy - miny)))

    def to_map(self, cont, wx, wy):
        """World (continent, X, Y) -> (uiMapID, x, y) map fractions, or None."""
        best = None
        for ui, c, minx, miny, maxx, maxy, mtype, area in self.bounds:
            if c != cont or not (minx <= wx <= maxx and miny <= wy <= maxy):
                continue
            rank = (0 if mtype in ZONE_TYPES else 1, area)
            if best is None or rank < best[0]:
                best = (rank, ui, (maxy - wy) / (maxy - miny), (maxx - wx) / (maxx - minx))
        return (best[1], best[2], best[3]) if best else None


def pt(maps, p):
    if not p:
        return None
    return maps.to_map(p.get("map"), p.get("x"), p.get("y"))


def fmt(p):
    return "{%d,%.4f,%.4f}" % p


def main():
    d = fdb.load()
    if not d:
        sys.exit("no ForeverDB download: py tools/foreverdb.py --fetch")
    spf = d["spf"]
    maps = Maps(d)
    lines, counts = [], {}

    def count(k):
        counts[k] = counts.get(k, 0) + 1

    lines.append("taxi = {")
    for nid, n in sorted(spf["TaxiNodes"].items(), key=lambda kv: int(kv[0])):
        p = pt(maps, n)
        if p:
            lines.append("[%s]={%s,%s,%s}," % (nid, lua_str(n.get("name", "?")),
                         lua_str(n["faction"]) if n.get("faction") in ("Horde", "Alliance") else "nil", fmt(p)))
            count("flight masters")
    lines.append("},")
    lines.append("-- direct flight legs: {from, to, seconds}")
    lines.append("flights = {")
    for leg in spf["TaxiPaths"].values():
        if leg.get("from") and leg.get("to") and leg.get("seconds"):
            lines.append("{%d,%d,%d}," % (leg["from"], leg["to"], leg["seconds"]))
            count("flight legs")
    lines.append("},")
    lines.append("-- docks: [id] = {stand on the dock {map,x,y}, name}")
    lines.append("docks = {")
    docks_ok = set()
    for did, dk in spf["Docks"].items():
        p = pt(maps, dk.get("walk") or dk)
        if p:
            docks_ok.add(int(did))
            name = dk.get("site") or dk.get("name")
            lines.append("[%s]={%s,%s}," % (did, fmt(p), lua_str(name) if name else "nil"))
            count("docks")
    lines.append("},")
    lines.append("-- boats, zeppelins, trams: {kind, faction, period seconds, {{dock, arrive, depart}, ...}} (seconds into the period)")
    lines.append("rides = {")
    for rid, r in sorted(spf["Routes"].items(), key=lambda kv: int(kv[0])):
        stops = [r["stops"][k] for k in sorted(r.get("stops", {}), key=int)]
        stops = [s for s in stops if s.get("dock") in docks_ok]
        if len(stops) >= 2 and r.get("period"):
            lines.append("{%s,%s,%d,{%s}}, -- route %s" % (lua_str(r.get("kind", "boat")),
                         lua_str(r["faction"]) if r.get("faction") in ("Horde", "Alliance") else "nil",
                         round(r["period"] / 1000),
                         ",".join("{%d,%d,%d}" % (s["dock"], round(s["arrive"] / 1000), round(s["depart"] / 1000)) for s in stops), rid))
            count("rides")
    lines.append("},")
    lines.append("-- portals, passages and lifts: {kind, name, from {map,x,y}, to {map,x,y}, seconds}")
    lines.append("portals = {")
    for p in spf["Portals"].values():
        a, b = pt(maps, p.get("from")), pt(maps, p.get("to"))
        if a and b:
            lines.append("{%s,%s,%s,%s,%d}," % (lua_str(p.get("kind", "portal")), lua_str(p.get("name", "Portal")), fmt(a), fmt(b),
                                               p.get("seconds") or 5))
            count("portals")
    for h in spf["Hops"].values():
        a, b = pt(maps, h.get("from")), pt(maps, h.get("to"))
        if a and b:
            lines.append("{\"lift\",\"Lift\",%s,%s,20}," % (fmt(a), fmt(b)))
            count("lifts")
    lines.append("},")

    os.makedirs(OUT, exist_ok=True)
    version = fdb.version(d)
    with open(os.path.join(OUT, "Outrider_Data_Travel.toc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("## Interface: 16001\n## Title: Outrider Data: travel network\n")
        f.write("## Notes: Flight paths, boats, zeppelins, docks and portals from ForeverDB / Shortest Path Forever (GPLv3).\n")
        f.write("## LoadOnDemand: 1\n## X-Source: %s\n\nData.lua\n" % version)
    with open(os.path.join(OUT, "Data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/import_travel.py from %s.\n" % version)
        f.write("-- Travel network from Shortest Path Forever (GPL-3.0-or-later, github.com/cjber/shortest-path-forever) via ForeverDB (GPLv3).\n")
        f.write("-- Map points are {uiMapID, x, y} map fractions. verified = false.\n")
        f.write("Outrider_DataTravel = { source = %s,\n" % lua_str(version))
        f.write("\n".join(lines))
        f.write("\n}\n")
    print("travel pack:", ", ".join("%s %d" % kv for kv in sorted(counts.items())),
          "| Data.lua %d KB" % (os.path.getsize(os.path.join(OUT, "Data.lua")) // 1024))


if __name__ == "__main__":
    main()
