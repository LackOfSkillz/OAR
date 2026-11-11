-- Sightings and respawn windows (P2-07). Times and IDs are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.Sightings
end

local function seen(ns, id, state, layer, t)
  ns.Events:Fire("OTR_RARE_SEEN", { npcID = id, name = "R", how = "target", layer = layer, mapID = 1, x = 0.5, y = 0.5,
    dead = state == "dead", t = t })
end

T.describe("sightings", function()
  T.it("records sightings, newest last, capped at 50", function()
    local _, ns, S = session()
    for i = 1, 55 do seen(ns, 7001, "alive", 10, 1000 + i) end
    local list = ns.db.global.sightings[7001]
    T.eq(#list, 50)
    T.eq(list[50].t, 1055)
    T.eq(list[50].by, "Torrant-Forever")
  end)

  T.it("pack respawn data gives waiting / open / overdue windows", function()
    local _, ns, S = session()
    ns.Data:Register("rare", "spec", { { npcID = 7002, name = "P", mapID = 1, verified = false, respawn = { min = 600, max = 1200 } } })
    seen(ns, 7002, "dead", 10, 10000)
    T.eq(S:Window(7002, 10, 10300).state, "waiting")
    T.eq(S:Window(7002, 10, 10300).opensIn, 300)
    T.eq(S:Window(7002, 10, 10900).state, "open")
    T.eq(S:Window(7002, 10, 12000).state, "overdue")
    T.contains(S:Describe(7002, 10, 10300), "opens in 5 min (pack (unverified))")
  end)

  T.it("layers are kept separate", function()
    local _, ns, S = session()
    seen(ns, 7003, "dead", 10, 1000)
    seen(ns, 7003, "alive", 20, 1100)
    T.eq(S:Window(7003, 10, 1200).state, "dead")
    T.eq(S:Window(7003, 20, 1200).state, "alive")
    T.eq(ns.db.global.respawnObs[7003], nil, "alive on another layer is not a respawn")
  end)

  T.it("learning needs 3 observed respawns before showing a range", function()
    local _, ns, S = session()
    local t = 0
    for i, gap in ipairs({ 1800, 2400, 2100 }) do
      seen(ns, 7004, "dead", 10, t)
      seen(ns, 7004, "alive", 10, t + gap)
      t = t + gap + 100
      if i < 3 then T.eq(S:Range(7004), nil) end
    end
    local lo, hi, src = S:Range(7004)
    T.eq(lo, 1800)
    T.eq(hi, 2400)
    T.eq(src, "observed x3")
    seen(ns, 7004, "dead", 10, 100000)
    T.contains(S:Describe(7004, 10, 100000 + 600), "opens in 20 min (observed x3)")
  end)

  T.it("taming a known rare records a tamed sighting", function()
    local game, ns, S = session()
    seen(ns, 7005, "alive", 10, 1000)
    game.units = { pet = { guid = "Pet-0-5250-0-777-7005-0100000001", name = "R" } }
    game:fire("UNIT_PET", "player")
    local last = S:Last(7005)
    T.eq(last.state, "tamed")
    T.eq(#ns.Errors.list, 0)
  end)
end)
