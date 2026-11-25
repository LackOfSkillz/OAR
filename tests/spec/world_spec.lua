-- OI06-01..07 world observations, sources, conflicts, rare forecasts, explorer, export and import; OI06-12 plan references.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.World
end

local NOW = 2000000000
local function obs(t)
  local o = { kind = "npc", subject = 100, mapID = 1412, x = 0.5, y = 0.5, at = NOW - 10, build = "1.60.1.70862", method = "interact" }
  for k, v in pairs(t or {}) do o[k] = v end
  return o
end

T.describe("world observations and sources (OI06-01, OI06-02)", function()
  T.it("valid observations carry precision and say the position is the player's", function()
    local _, _, W = session()
    local o = W.Observation(obs({ method = "nameplate" }), NOW)
    T.eq(o.positionOf, "player") T.eq(o.precision, 40)
    T.eq(select(2, W.Observation(obs({ subject = -1 }), NOW)), "subject must be an id")
    T.ok(select(2, W.Observation(obs({ x = 50 }), NOW)):find("fractions"))
    T.ok(select(2, W.Observation(obs({ at = NOW + 3600 }), NOW)):find("future"))
    T.eq(select(2, W.Observation(obs({ build = "" }), NOW)), "build missing")
    T.eq(select(2, W.Observation(obs({ mapID = 1.5 }), NOW)), "map must be a whole id")
  end)

  T.it("an unknown map is refused when the client can tell", function()
    local game, _, W = session()
    game.env.C_Map = game.env.C_Map or {}
    game.env.C_Map.GetMapInfo = function(id) if id == 1412 then return { name = "Mulgore" } end end
    T.ok(W.Observation(obs(), NOW))
    T.ok(select(2, W.Observation(obs({ mapID = 99999 }), NOW)):find("doesn't know"))
  end)

  T.it("adapters read Discovery and Sightings records", function()
    local _, _, W = session()
    local d = W.FromDiscovery(100, { mapID = 1412, x = 0.4, y = 0.6, quality = "near", lastSeen = NOW - 5 }, "1.60.1", NOW)
    T.eq(d.method, "near") T.eq(d.precision, 10)
    local s = W.FromSighting(200, { mapID = 1412, x = 0.3, y = 0.3, t = NOW - 5, how = "target", layer = 7 }, "1.60.1", NOW)
    T.eq(s.kind, "rare") T.eq(s.layer, 7)
  end)

  T.it("packs without a license or evidence class are quarantined; Classic labelled; old builds outdated", function()
    local _, ns, W = session()
    local n, cls = W.RegisterPack("poi", "nolicense", { evidence = "cited" }, { { id = "q1", kind = "vendor", mapID = 1, x = 0.5, y = 0.5, verified = false } })
    T.eq(n, 0) T.ok(cls.quarantined) T.ok(W.quarantine.nolicense.entries[1], "kept, not used")
    T.eq(ns.Data:Get("poi", "q1"), nil)
    local _, c2 = W.RegisterPack("poi", "classicpack", { license = "CC-BY", evidence = "cited", flavor = "classic" },
      { { id = "c1", kind = "vendor", mapID = 1, x = 0.5, y = 0.5, verified = true, confidence = "verified" } })
    T.ok(c2.label:find("Classic")) T.eq(ns.Data:Get("poi", "c1").verified, false)
    W.Manifest("oldpack", { license = "x", evidence = "observed", build = "1.59.0" })
    T.ok(W.Classify("oldpack", { minBuild = "1.60.0" }).outdated)
    T.ok(W.Classify("seed").firstParty)
  end)

  T.it("review OI-FR11: a rejected import never displaces the pack in use; every version is saved", function()
    local _, ns, W = session()
    local good = { license = "CC-BY", evidence = "observed", revision = 1 }
    T.eq((W.RegisterPack("poi", "shared", good, { { id = "g1", kind = "vendor", mapID = 1, x = 0.5, y = 0.5, verified = false } })), 1)
    local n, cls = W.RegisterPack("poi", "shared", { evidence = "observed", revision = 2 }, { { id = "b1", kind = "vendor", mapID = 1, x = 0.1, y = 0.1, verified = false } })
    T.eq(n, 0) T.ok(cls.protected, "the pack in use is protected")
    T.ok(ns.Data:Get("poi", "g1"), "still in use")
    T.eq(W.Classify("shared").usable, true, "its manifest wasn't replaced by the rejected one")
    T.ok(W.quarantine.shared.rejectedImport)
    W.RegisterPack("poi", "shared", { revision = 3 }, { { id = "b2" } })
    T.eq(#W.QuarantineHistory("shared"), 2, "both rejected versions kept")
    -- a reload: memory is gone, the saved records are not
    W.quarantine, W.loaded = {}, nil
    T.ok(W.Quarantined().shared, "back after a reload")
    T.eq(W.QuarantineHistory("shared")[1].entries[1].id, "b1")
    -- a newer usable version archives the one it replaces
    W.RegisterPack("poi", "shared", { license = "CC-BY", evidence = "observed", revision = 4 }, { { id = "g2", kind = "vendor", mapID = 1, x = 0.6, y = 0.6, verified = false } })
    local archived = false
    for _, e in ipairs(ns.Archive:Rows("worldPackReplaced")) do if e.row.revision == 1 and e.row.entries[1].id == "g1" then archived = true end end
    T.ok(archived, "revision 1 in the archive")
    local events = {}
    for _, r in ipairs(W.Store().log) do events[#events + 1] = r.event .. ":" .. tostring(r.revision) end
    T.ok(#events >= 4, table.concat(events, ","))
  end)
end)

T.describe("conflicts, rare forecasts and the explorer (OI06-03..05)", function()
  T.it("keeps every observation, separates layers, flags spoofed sources and notices a move", function()
    local _, _, W = session()
    local list = {
      W.Observation(obs({ at = NOW - 86400 * 20, layer = 1 }), NOW), W.Observation(obs({ at = NOW - 86400 * 19, layer = 1 }), NOW),
      W.Observation(obs({ layer = 2, x = 0.9 }), NOW),
      W.Observation(obs({ x = 0.2, y = 0.2, layer = 1, at = NOW - 100 }), NOW), W.Observation(obs({ x = 0.2, y = 0.2, layer = 1, at = NOW - 50 }), NOW),
      W.Observation(obs({ x = 0.7, y = 0.7, layer = 1, provenance = { source = "trust-me" } }), NOW),
    }
    local r = W.Resolve(list, { now = NOW })
    T.eq(r.kept, 6) T.eq(#r.audit, 6)
    T.ok(r.best.moved, "two newer observations in a new spot") T.eq(r.best.center.x, 0.2)
    local flagged
    for _, g in ipairs(r.groups) do if g.flagged then flagged = g end end
    T.ok(flagged and flagged.weight == 0, "spoofed source weighs nothing")
    local layers = {}
    for _, g in ipairs(r.groups) do layers[g.layer] = true end
    T.ok(layers[1] and layers[2], "another layer is its own group")
  end)

  T.it("forecasts need gaps on the same layer and build; sightings and censored deaths are apart", function()
    local _, _, W = session()
    local s = { { state = "dead", t = 0, layer = 1 }, { state = "alive", t = 600, layer = 1 }, { state = "alive", t = 700, layer = 1 },
      { state = "dead", t = 1000, layer = 2 }, { state = "dead", t = 2000, layer = 1 } }
    local f = W.RareForecast(s, 1, 3000)
    T.eq(f.gaps, 1) T.eq(f.censored, 1) T.eq(f.sightingsOnly, 1) T.ok(f.why:find("not enough"))
    T.ok(W.RareForecast(s, nil).unknown)
    local many = {}
    for i = 1, 8 do many[#many + 1] = { state = "dead", t = i * 10000, layer = 1 } many[#many + 1] = { state = "alive", t = i * 10000 + 600 + i * 10, layer = 1 } end
    many[#many + 1] = { state = "dead", t = 100000, layer = 1 }
    local g = W.RareForecast(many, 1, 100000 + 650)
    T.eq(g.gaps, 8) T.ok(g.chanceUp and g.chanceUp > 0 and g.chanceUp < 1) T.ok(g.chanceNote:find("of 8"))
    many[#many + 1] = { state = "dead", t = 200000, layer = 1, build = "new" }
    T.eq(W.RareForecast(many, 1, 200100).gaps, 0, "a build change starts again")
  end)

  T.it("unseen is apart from unavailable and removed; the route uses verified places, straight lines marked", function()
    local _, ns, W = session()
    ns.Data:Register("poi", "spec", {
      { id = "a", kind = "vendor", mapID = 77, x = 0.1, y = 0.1, verified = true },
      { id = "b", kind = "vendor", mapID = 77, x = 0.9, y = 0.9, verified = true },
      { id = "c", kind = "vendor", mapID = 77, x = 0.5, y = 0.5, verified = false },
      { id = "d", kind = "vendor", mapID = 77, x = 0.5, y = 0.5, verified = true, faction = "Alliance" },
      { id = "e", kind = "vendor", mapID = 77, x = 0.5, y = 0.5, verified = true, removed = true } })
    local u = W.Unseen(77, { seen = { b = true }, faction = "Horde" })
    T.eq(#u.unseen, 2) T.eq(#u.unavailable, 1) T.eq(#u.removed, 1) T.eq(u.seen, 1)
    local route, note = W.Route(u.unseen, { x = 0, y = 0 })
    T.eq(#route, 1, "only the verified one") T.ok(route[1].straight and note:find("straight"))
  end)
end)

T.describe("contribution export and import (OI06-06, OI06-07)", function()
  T.it("off by default; needs the preview's token; carries no names, gold or trail", function()
    local _, ns, W = session()
    local K = ns.Contribute
    local list = { W.Observation(obs({ realm = "Mograine", x = 0.123456 }), NOW) }
    T.ok(select(2, K.Preview(list)):find("off"))
    K.Store().on = true
    local pv = K.Preview(list)
    T.eq(pv.rows[1].x, 0.123) T.eq(pv.rows[1].realm, nil)
    T.eq(select(2, K.Export(list, "nope")), "consent needed: preview, then export that preview")
    local text = K.Export(list, pv.token)
    local decoded = ns.Serialize.Import(text)
    local flat = ns.Serialize.Encode(decoded)
    for _, bad in ipairs({ "Torrant", "money", "trail", "chat" }) do T.ok(not flat:find(bad, 1, true), bad) end
  end)

  T.it("imports into a queue: malformed rejected, duplicates dropped, approval needed, deterministic builds kept", function()
    local _, ns, W = session()
    local K = ns.Contribute
    K.Store().on = true
    local list = { W.Observation(obs(), NOW), W.Observation(obs({ subject = 101 }), NOW) }
    local text = K.Export(list, K.Preview(list).token)
    T.eq(select(2, K.Import("print('hi')")), "not an Outrider export string")
    T.ok(not K.Import(string.rep("x", K.MAX_TEXT + 1)))
    local evil = ns.Serialize.Export({ tag = K.TAG, v = 1, rows = { { kind = "npc", subject = 1, mapID = 1, x = 9, y = 9, build = "b", method = "interact" } } })
    T.eq(#K.Import(evil, "bad").rejected, 1)
    local r = K.Import(text, "friend", NOW)
    T.eq(r.added, 2)
    T.eq(K.Import(text, "again", NOW).duplicates, 2)
    T.eq(K.Store().queue[1].status, "pending")
    local m0 = K.Build("r0")
    T.eq(m0.rows, 0, "nothing approved yet")
    K.Decide(1, true) K.Decide(2, true)
    local m1 = K.Build("r1")
    local m2 = K.Build("r1")
    T.eq(m1.hash, m2.hash) T.eq(m1.rows, 2) T.eq(m1.publishable, false)
    T.ok(K.Build("r2", true).publishable)
    T.eq(K.BuildAt(1).rows, 0, "earlier builds kept for rollback")
  end)
end)

T.describe("plan references (OI06-12)", function()
  T.it("data only; wrong class, level and bad ids refused; old build or expiry marked stale; accepting is manual", function()
    local _, ns = session()
    local PS = ns.PlanShare
    local text = PS.Export({ title = "Barrens run", steps = { "quest:871", "gear:Bow" }, classes = { "HUNTER" }, minLevel = 15, maxLevel = 25, build = "1.59.0" })
    local rec = PS.Import(text)
    T.eq(rec.status, "offered") T.ok(rec.stale:find("build"))
    T.ok(PS.Decide(1, true)) T.eq(PS.Store().offered[1].status, "accepted")
    T.eq(select(2, PS.Import(PS.Export({ steps = { "x" }, classes = { "MAGE" } }))), "made for another class")
    T.ok(select(2, PS.Import(PS.Export({ steps = { "x" }, minLevel = 40 }))):find("levels"))
    T.eq(select(2, PS.Export({ steps = { "/run x()" } })), "step 1 isn't a plain id")
    local raw = ns.Serialize.Export({ v = 1, steps = { "bad step!" } })
    T.ok(select(2, PS.Import(raw)):find("plain id"))
    T.ok(PS.Import(PS.Export({ steps = { "a" }, expires = 1 })).stale == "expired")
    T.eq(#ns.Errors.list, 0)
  end)
end)
