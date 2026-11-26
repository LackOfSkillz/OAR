-- Vanguard researched facts (Data/VanguardFacts.lua): boss mechanic tags
-- become per-boss checks with their source, keys and attunements feed the
-- access graph, raids not on Forever say so, known vendor prices replace
-- "unknown", and known flat enchants count in gear stats.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start(facts)
  local game = mock.new({ class = "HUNTER", level = 20 })
  game.units = {
    party1 = { name = "Khreos", player = true, guid = "Player-1-0000BEEF", level = 20, class = "WARRIOR", role = "TANK" },
    party2 = { name = "Mirae", player = true, guid = "Player-1-0000CAFE", level = 20, class = "PRIEST", role = "HEALER" },
  }
  local ns = game:loadAddon()
  game:login()
  game.inGroup = true
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "UnitIsConnected", function() return true end)
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  ns.DungeonGuide.ByName = function() return { ["The Deadmines"] = { bosses = { { 644, "Rhahk'Zor", 19, nil, {} },
    { 639, "Edwin VanCleef", 21, nil, {} } }, items = {} } } end
  if facts then ns.VanguardFacts = facts end
  ns.Vanguard.Facts.Reset()
  ns.Vanguard.Catalog.Reset()
  ns.Modules:SetEnabled("Vanguard", true)
  return game, ns, ns.Vanguard, ns.VanguardModule
end

local FIXTURE = {
  bosses = { ["The Deadmines"] = { kind = "classic", source = "https://example.test/dm", list = {
    { name = "Rhahk'Zor", tags = {} },
    { name = "Edwin VanCleef", tags = { adds = "calls two guards", dispel_poison = "a made-up poison" } },
    { name = "Cookie", tags = { interrupt = "heals", fear = "test" } },
  } } },
  access = { ["The Deadmines"] = { needs = "none", kind = "forever", source = "x" },
    ["Scholomance"] = { needs = "key", who = "one", item = 13704, itemName = "Skeleton Key", kind = "classic", source = "y" },
    ["Onyxia's Lair"] = { needs = "attunement", who = "each", itemName = "Drakefire Amulet", kind = "forever", source = "z" } },
  raids = { ["Barrow Deeps"] = { size = 10, min = 60, max = 60, status = "opens 2026-12-09", source = "b", kind = "forever" },
    ["Molten Core"] = { status = "not announced for WoW Forever", source = "b", kind = "forever" } },
  prices = { [159] = { name = "Refreshing Spring Water", copper = 5, per = 1, kind = "classic", source = "p" },
    [2512] = { name = "Rough Arrow", copper = 10, per = 200, kind = "classic", source = "p" } },
  enchants = { [1891] = { name = "+4 all stats", stats = { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_STRENGTH_SHORT = 4 } },
    [1900] = { name = "Crusader", proc = true } },
}

T.describe("vanguard researched facts", function()
  T.it("the shipped pack loads, every row has a source, and nothing is marked verified", function()
    local _, ns = start()
    local f = ns.VanguardFacts
    T.ok(type(f) == "table")
    T.eq(f.verified, false)
    for inst, b in pairs(f.bosses) do
      T.ok(type(b.source) == "string" and b.source ~= "", inst .. " has a source")
      T.ok(b.kind == "forever" or b.kind == "classic", inst .. " kind")
      for _, boss in ipairs(b.list) do
        T.ok(type(boss.name) == "string")
        for tag in pairs(boss.tags or {}) do
          T.ok(ns.Vanguard.Facts.TAG_CAP[tag] or ns.Vanguard.Facts.TAG_NOTE[tag], inst .. ": known tag " .. tag)
        end
      end
    end
    for inst, a in pairs(f.access) do
      T.ok(a.needs == "none" or a.needs == "key" or a.needs == "attunement" or a.needs == "quest", inst .. " needs")
      T.ok(type(a.source) == "string", inst .. " access source")
    end
    -- the shipped pack really holds the research (an empty build once slipped through)
    local function n(t) local c = 0 for _ in pairs(t) do c = c + 1 end return c end
    T.ok(n(f.bosses) >= 29, "boss lists for 29+ places, got " .. n(f.bosses))
    T.ok(n(f.access) >= 30, "access for 30+ places, got " .. n(f.access))
    T.ok(n(f.prices) >= 40, "40+ prices, got " .. n(f.prices))
    T.ok(n(f.enchants) >= 75, "75+ enchants, got " .. n(f.enchants))
    T.eq(f.enchants[1892].stats.ITEM_MOD_STAMINA_SHORT, 10, "Forever's chest enchant 1892 is Stamina, not Classic's Health")
    T.eq(f.access["Scholomance"].item, 13704)
    T.eq(f.raids["Barrow Deeps"].size, 10)
    -- end to end on the real pack: the Deadmines' Greenskin needs a poison removal
    local V = ns.Vanguard
    ns.DungeonGuide.ByName = function() return { ["The Deadmines"] = { bosses = { { 647, "Captain Greenskin", 20, nil, {} }, { 1, "Defias Pirate", 18, nil, {} } }, items = {} } } end
    V.Catalog.Reset()
    local dm = V.Catalog.Find("The Deadmines")
    local green
    for _, e in ipairs(dm.encounters) do if e.name == "Captain Greenskin" then green = e end T.ok(e.name ~= "Defias Pirate", "loot mobs aren't bosses") end
    T.ok(green and green.level == 20, "pack level kept")
    local poison
    for _, r in ipairs(green.reqs) do if r.cap == "dispel_poison" then poison = r end end
    T.ok(poison and poison.verification == "classic", "Greenskin: poison removal, from a Classic-based guide")
    for id, p in pairs(f.prices) do T.ok(type(id) == "number" and type(p.copper) == "number" and p.copper >= 0 and type(p.source) == "string", "price " .. tostring(id)) end
    for id, e in pairs(f.enchants) do
      T.ok(type(id) == "number" and type(e.source) == "string", "enchant " .. tostring(id))
      for tok, v in pairs(e.stats or {}) do T.ok(type(tok) == "string" and type(v) == "number", "enchant stat " .. tostring(id)) end
    end
  end)

  T.it("boss tags become that boss's checks with their source; notes become risks; new bosses are added", function()
    local _, _, V, M = start(FIXTURE)
    local e = V.Catalog.Find("The Deadmines")
    T.eq(#e.encounters, 3, "Cookie added from the facts")
    T.ok(table.concat(e.unknowns, ";"):find("Classic sources"), "labeled as Classic")
    local a = M:Assessment("The Deadmines")
    local van = a.bosses[2]
    local found
    for _, r in ipairs(van.results) do if r.id == "boss:dispel_poison" then found = r end end
    T.ok(found, "VanCleef's poison is a check")
    T.eq(found.verification, "classic")
    T.ok(table.concat(van.risks, ";"):find("adds join"), table.concat(van.risks, ";"))
    T.ok(van.mechanics:find("Classic"))
    local cookie = a.bosses[3]
    local int
    for _, r in ipairs(cookie.results) do if r.id == "boss:interrupt" then int = r end end
    T.ok(int and int.u == 1 and int.text:find("likely"), "a warrior could interrupt (likely, not verified)")
    T.ok(table.concat(cookie.risks, ";"):find("fears"))
    -- your own rule replaces the researched one for the same need
    M:Settings().bossNeeds = { ["Edwin VanCleef"] = { dispel_poison = true } }
    local b = M:Assessment("The Deadmines")
    local n = 0
    for _, r in ipairs(b.bosses[2].results) do if r.id == "boss:dispel_poison" then n = n + 1 T.eq(r.verification, "manual") end end
    T.eq(n, 1, "once, yours")
  end)

  T.it("access: none, a key one member can hold, an attunement everyone needs", function()
    local game, _, V, M = start(FIXTURE)
    local dm = M:Assessment("The Deadmines")
    for _, r in ipairs(dm.results) do T.ok(r.id ~= "access", "no key needed: no access check") end
    game.counts = {}
    local scholo = V.Catalog.Find("Scholomance")
    local s, why = V.Access.Check(scholo, {})
    T.eq(s, "unmet", "level 20 is below Scholomance anyway")
    local g = V.Access.ForInstance(scholo, {})
    T.eq(g.access.kind, "holder")
    T.eq((V.Access.Eval(g, "access", V.Access.Env({}))), "unknown", "you don't carry it; someone else may")
    game.counts[13704] = 1
    T.eq((V.Access.Eval(g, "access", V.Access.Env({}))), "met")
    local ony = V.Access.ForInstance(V.Catalog.Find("Onyxia's Lair"), {})
    T.eq(ony.access.kind, "item")
    T.eq(ony.access.value, "Drakefire Amulet")
    T.eq((V.Access.Eval(ony, "access", V.Access.Env({}))), "unmet", "everyone needs it and you don't have it")
    -- your answer wins
    local mine = V.Access.ForInstance(V.Catalog.Find("Onyxia's Lair"), { access = { ["Onyxia's Lair"] = true } })
    T.eq(mine.access.kind, "manual")
    T.ok(why)
  end)

  T.it("raids: new ones added with their size, ones not on Forever say so", function()
    local _, _, V = start(FIXTURE)
    local bd = V.Catalog.Find("Barrow Deeps")
    T.ok(bd, "Barrow Deeps from the facts")
    T.eq(bd.size, 10)
    T.eq(bd.raid, true)
    local mc = V.Catalog.Find("Molten Core")
    T.eq(mc.announced, false)
    T.ok(mc.unknowns[1]:find("not announced"))
  end)

  T.it("known vendor prices fill in the cost; anything else stays unknown", function()
    local _, _, V = start(FIXTURE)
    local acts = V.Plan.Actions({
      { id = "drink", state = "missing", action = "drink", have = 2, want = 12, priceKey = "Refreshing Spring Water", text = "d" },
      { id = "ammo", state = "missing", action = "ammo", have = 100, want = 1000, priceKey = 2512, text = "a" },
      { id = "food", state = "missing", action = "food", have = 0, want = 10, priceKey = "Mystery Meat", text = "f" },
    })
    local by = {}
    for _, a in ipairs(acts) do by[a.id] = a end
    T.eq(by.drink.costCopper, 50)
    T.ok(by.drink.costSource:find("check the vendor"))
    T.eq(by.ammo.costCopper, 50, "900 arrows = 5 stacks of 200 at 10 copper")
    T.eq(by.food.costUnknown, true)
  end)

  T.it("a known flat enchant counts in gear stats; a proc enchant still opens the range", function()
    local game, _, V = start(FIXTURE)
    game.itemStats = { [10] = { ITEM_MOD_STAMINA_SHORT = 10 }, [16] = { ITEM_MOD_STRENGTH_SHORT = 5 } }
    local function p(ench5, ench16)
      return { slots = { { slot = 5, state = "known", itemId = 10, link = "|Hitem:10:" .. (ench5 or "") .. ":|h[x]|h", enchant = ench5 },
        { slot = 16, state = "known", itemId = 16, link = "|Hitem:16:" .. (ench16 or "") .. ":|h[y]|h", enchant = ench16 } } }
    end
    local d = V.Stats.Derive(p(1891, nil))
    T.eq(d.complete, true, "a known enchant doesn't open the range")
    T.eq(d.totals.ITEM_MOD_STAMINA_SHORT.lo, 14)
    T.eq(d.enchants.counted, 1)
    local d2 = V.Stats.Derive(p(1891, 1900))
    T.eq(d2.complete, false, "Crusader is a proc: still open")
    local d3 = V.Stats.Derive(p(9999, nil))
    T.eq(d3.complete, false, "an enchant not in the table: open")
  end)
end)
