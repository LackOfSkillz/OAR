-- Vanguard VG02: role registry, gear stat ranges, tank/healer/damage
-- indicators, class utility and stacking, personal prep, equipment, access
-- and journal links. Unknown never counts as zero, missing or short.
local T, mock = ...

local function link(id, ench)
  return string.format("|Hitem:%d:%s::::::::60:::::|h[Item %d]|h", id, ench and tostring(ench) or "", id)
end

local function load()
  local game = mock.new({ class = "HUNTER", level = 40 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Vanguard
end

local function member(V, class, level, extra)
  local Obs = V.Obs
  local m = { key = class .. level, class = Obs.New("class", class, "native"), level = Obs.New("level", level, "native") }
  for k, v in pairs(extra or {}) do m[k] = v end
  return m
end

-- a profile with given slots { [slot] = { state, id, ench } }
local function profile(slots)
  local p = { rev = 1, slots = {} }
  for _, slot in ipairs({ 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }) do
    local d = slots[slot]
    if d then
      p.slots[#p.slots + 1] = { slot = slot, state = d[1], itemId = d[2], link = d[2] and link(d[2], d[3]), enchant = d[3] }
    else
      p.slots[#p.slots + 1] = { slot = slot, state = "empty" }
    end
  end
  return p
end

T.describe("vanguard roles and prep (VG02)", function()
  T.it("covers all nine classes, hybrids, and says what it can't model", function()
    local _, ns, V = load()
    local R = V.Roles
    T.eq(#R.CLASSES, 9)
    for _, cls in ipairs(R.CLASSES) do
      local roles = R.Roles(cls)
      T.ok(roles and #roles >= 1, cls .. " has a role")
      for _, role in ipairs(roles) do
        local p = R.Get(cls, role)
        T.ok(p and #p.indicators > 0, cls .. " " .. role)
        T.ok(#p.missing > 0, "lists what isn't modeled")
        T.eq(p.verified, false)
      end
    end
    T.eq(R.Get("DRUID", "DAMAGER").hybrid, true, "feral or balance: both kinds")
    local none, why = R.Get("MAGE", "TANK")
    T.eq(none, nil)
    T.ok(why:find("no tank"), why)
    T.eq((R.Get(nil, "TANK")), nil, "unknown class: nothing")
    T.eq((R.Get("WARRIOR", nil)), nil, "unknown role: nothing")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("derives gear stats as ranges: empty is zero, unread opens the top, enchants are not guessed", function()
    local game, _, V = load()
    game.itemStats = { [10] = { ITEM_MOD_STAMINA_SHORT = 10, RESISTANCE0_NAME = 300 }, [11] = { ITEM_MOD_STAMINA_SHORT = 5 },
      [16] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 25.5, ITEM_MOD_STRENGTH_SHORT = 4 } }
    -- complete: all read, no enchants
    local full = V.Stats.Derive(profile({ [5] = { "known", 10 }, [7] = { "known", 11 }, [16] = { "known", 16 } }))
    T.eq(full.complete, true)
    T.eq(full.totals.ITEM_MOD_STAMINA_SHORT.lo, 15)
    T.eq(full.totals.ITEM_MOD_STAMINA_SHORT.hi, 15)
    local w = V.Stats.Range(full, V.Roles.INDICATORS.weapon)
    T.eq(w.lo, 25.5)
    T.eq(V.Stats.Range(full, V.Roles.INDICATORS.ranged).empty, true, "empty ranged slot is a known empty")
    -- a pending slot and an enchant: totals become lower bounds
    -- 99991: an enchant not in the researched table
    local part = V.Stats.Derive(profile({ [5] = { "known", 10, 99991 }, [7] = { "pending", 11 }, [16] = { "unreadable" } }))
    T.eq(part.complete, false)
    T.eq(part.totals.ITEM_MOD_STAMINA_SHORT.lo, 10)
    T.eq(part.totals.ITEM_MOD_STAMINA_SHORT.hi, nil, "open top")
    T.eq(part.enchants.known, 1)
    T.eq(V.Stats.RangeText(V.Stats.Range(part, V.Roles.INDICATORS.stamina)), "at least 10")
    -- an item whose stats don't come back is not zero
    local unread = V.Stats.Derive(profile({ [5] = { "known", 99 } }))
    T.eq(unread.statsUnread, 1)
    T.eq(unread.complete, false)
    -- a stat nobody has, with every slot read, is a known zero
    T.eq(V.Stats.Range(full, V.Roles.INDICATORS.defense).hi, 0)
  end)

  T.it("tank, healer and damage indicators compare only against a target; missing data widens, never fails", function()
    local game, _, V = load()
    game.itemStats = { [10] = { ITEM_MOD_STAMINA_SHORT = 40, RESISTANCE0_NAME = 900 }, [20] = { ITEM_MOD_INTELLECT_SHORT = 30, ITEM_MOD_SPIRIT_SHORT = 12 },
      [30] = { ITEM_MOD_AGILITY_SHORT = 20 }, [31] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 } }
    local A = V.Adequacy
    local warrior = member(V, "WARRIOR", 40)
    local tank = A.Assess(warrior, profile({ [5] = { "known", 10 } }), "TANK")
    T.eq(tank.state, "reference", "no targets: shown for reference only")
    for _, i in ipairs(tank.indicators) do T.eq(i.state, "no target") end
    T.ok(#tank.missing >= 2, "armor and threat formulas listed as not modeled")
    -- with a target
    local met = A.Assess(warrior, profile({ [5] = { "known", 10 } }), "TANK", { stamina = { value = 35, source = "catalog" } })
    T.eq(met.indicators[1].state, "met")
    local short = A.Assess(warrior, profile({ [5] = { "known", 10 } }), "TANK", { stamina = { value = 60, source = "catalog" } })
    T.eq(short.indicators[1].state, "short")
    T.eq(short.state, "short")
    -- the same target with an unread slot: unknown, not short
    local wide = A.Assess(warrior, profile({ [5] = { "known", 10 }, [7] = { "pending", 11 } }), "TANK", { stamina = { value = 60, source = "catalog" } })
    T.eq(wide.indicators[1].state, "unknown")
    T.eq(wide.complete, false)
    -- healer: mana and spirit, no healing per second number anywhere
    local healer = A.Assess(member(V, "PRIEST", 40), profile({ [5] = { "known", 20 } }), "HEALER")
    T.eq(healer.indicators[1].id, "intellect")
    for _, i in ipairs(healer.indicators) do T.ok(not i.label:lower():find("per second") or i.id == "mp5", "no hps") end
    -- damage: melee, ranged and caster read different things
    local hunter = A.Assess(member(V, "HUNTER", 40), profile({ [18] = { "known", 31 }, [7] = { "known", 30 } }), "DAMAGER")
    local ids = {}
    for _, i in ipairs(hunter.indicators) do ids[i.id] = i end
    T.ok(ids.ranged and ids.ranged.range.lo == 30, "ranged weapon dps from the bow")
    T.ok(not ids.weapon, "a hunter's melee weapon isn't a damage indicator")
    local mage = A.Assess(member(V, "MAGE", 40), profile({}), "DAMAGER")
    T.ok(mage.indicators[1].id == "intellect")
    local rogue = A.Assess(member(V, "ROGUE", 40), profile({}), "DAMAGER")
    T.ok(rogue.indicators[1].id == "strength")
    -- a class with no such role, and a member not scanned
    T.eq(A.Assess(member(V, "MAGE", 40), nil, "TANK").state, "unsupported")
    T.eq(A.Assess(warrior, nil, "TANK").state, "not checked")
    T.eq(A.Assess(warrior, nil, "TANK").indicators[1].state, "unknown")
  end)

  T.it("class utility: spellbook data decides, levels gate, talents and unknowns stay unknown", function()
    local _, ns, V = load()
    local U = V.Utility
    local mage20 = member(V, "MAGE", 20)
    T.eq(U.Member(mage20, "interrupt").state, "unlikely", "Counterspell is learned at 24 in the data")
    T.eq(U.Member(member(V, "MAGE", 30), "interrupt").state, "potential")
    T.eq(U.Member(member(V, "PRIEST", 40), "interrupt").state, "talent", "Silence is a talent")
    T.eq(U.Member(member(V, "HUNTER", 40), "interrupt").state, "none", "no hunter interrupt in the data")
    local unknownClass = { key = "x", class = V.Obs.Unknown("class"), level = V.Obs.New("level", 40, "native") }
    T.eq(U.Member(unknownClass, "interrupt").state, "unknown")
    -- only spells in the Forever data count
    for cap, c in pairs(U.CAPS) do
      for class, list in pairs(c.spells) do
        for _, s in ipairs(U.Spells(cap, class)) do T.ok(ns.SpellInfo[class][s.name], s.name) end
        T.ok(#list >= 1)
      end
    end
    -- your own spellbook verifies
    ns.db.char.spellbook = { spells = { ["arcane intellect"] = { name = "Arcane Intellect" } } }
    local me = member(V, "MAGE", 40, { self = true })
    T.eq(U.Member(me, "buff_intellect").state, "verified")
  end)

  T.it("coverage: duplicates don't stack, nobody vs unknown, party scope by subgroup", function()
    local _, _, V = load()
    local U = V.Utility
    local group = { member(V, "PRIEST", 40), member(V, "PRIEST", 41), member(V, "WARRIOR", 40), member(V, "MAGE", 40) }
    local cov = U.Coverage(group)
    T.eq(cov.buff_stamina.count, 1, "two priests give one stamina buff")
    T.eq(cov.buff_stamina.state, "potential")
    T.eq(cov.interrupt.count, 2, "each interrupt counts (warrior and mage)")
    T.eq(cov.battle_rez.state, "none", "every class known and none has it")
    T.eq(cov.dispel_curse.state, "potential")
    -- one member we can't read makes "nobody" into "unknown"
    group[#group + 1] = { key = "?", class = V.Obs.Unknown("class"), level = V.Obs.Unknown("level") }
    T.eq(U.Coverage(group).battle_rez.state, "unknown")
    -- party scope remembers which subgroups have it
    local raid = { member(V, "WARRIOR", 40, { subgroup = V.Obs.New("subgroup", 1, "native") }),
      member(V, "WARRIOR", 40, { subgroup = V.Obs.New("subgroup", 3, "native") }) }
    local r = U.Coverage(raid)
    T.eq(r.shout.scope, "party")
    T.ok(r.shout.groups[1] and r.shout.groups[3] and not r.shout.groups[2])
    T.eq(r.shout.count, 1)
  end)

  T.it("personal prep: duration sets amounts, carried vs bank, missing vs unknown, reagents only when known", function()
    local game, ns, V = load()
    local P = V.Prep
    local pf = P.Profile("dungeon", "DAMAGER", 120)
    T.eq(pf.food, 20)
    T.eq(pf.drink, 20, "hunters use mana")
    T.eq(pf.ammo, 2000)
    T.eq(P.Profile("raid").minutes, 180)
    T.eq(P.Profile("dungeon", nil, 5).minutes, 10, "clamped")
    -- food from the bag scan, counted carried only
    ns.BagFood.Scan = function() return "Roasted Quail", nil end
    game.counts = { ["Roasted Quail"] = 12 }
    game.bankCounts = { ["Roasted Quail"] = 40 }
    game.ammo = 3000
    game.durability = { [1] = { 10, 100 } }
    local list = P.Supplies(pf)
    local by = {}
    for _, r in ipairs(list) do by[r.id] = r end
    T.eq(by.food.state, "missing", "12 carried < 20 even with 40 in the bank")
    T.ok(by.food.text:find("40 more in the bank"), by.food.text)
    T.eq(by.food.have, 12)
    T.eq(by.drink.state, "missing", "no drink in bags")
    T.eq(by.ammo.state, "ok")
    T.eq(by.repair.state, "missing", "10% durability")
    -- a bag scan that fails is unknown, not missing
    ns.BagFood.Scan = function() error("bags not ready") end
    local list2 = P.Supplies(pf)
    for _, r in ipairs(list2) do if r.id == "food" then T.eq(r.state, "unknown") end end
    -- warlock reagents show only when the spell is known
    pf.class = "WARLOCK"
    local function hasShard(l) for _, r in ipairs(l) do if r.id == "reagent:Soul Shard" then return r end end end
    T.eq(hasShard(P.Supplies(pf)), nil)
    ns.db.char.spellbook = { spells = { ["create healthstone"] = { name = "Create Healthstone" } } }
    game.counts["Soul Shard"] = 2
    T.eq(hasShard(P.Supplies(pf)).state, "missing")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("equipment and access: empty is missing, unread is unknown, your own items are marked as yours", function()
    local _, ns, V = load()
    local P = V.Prep
    local pf = P.Profile("dungeon", "DAMAGER")
    local self = profile({ [1] = { "known", 1 }, [5] = { "known", 5, 1891 }, [8] = { "known", 8 }, [9] = { "unreadable" }, [16] = { "known", 16 }, [18] = { "known", 18 } })
    local st = { access = { ["Scholomance"] = false }, custom = { { text = "Bring fire resistance gear", done = false } } }
    local list = P.Equipment(pf, self, st, "Scholomance")
    local by = {}
    for _, r in ipairs(list) do by[r.id] = r end
    T.eq(by["slot:2"].state, "missing", "no neck worn")
    T.eq(by["slot:9"].state, "unknown", "wrist unreadable")
    T.eq(by["enchant:5"].state, "ok")
    T.eq(by["enchant:8"].state, "missing", "boots without enchant")
    T.eq(by["enchant:8"].after, "slot:8", "enchant depends on the item being there")
    T.eq(by["enchant:9"], nil, "unreadable wrist: no enchant claim at all")
    T.eq(by.access.state, "missing")
    T.eq(by.access.source, "manual")
    T.eq(by.level.state, "missing", "level 40 below Scholomance's reference range")
    T.eq(by.level.verified, false)
    T.eq(by["custom:1"].custom, true)
    T.ok(by["custom:1"].text:find("your own item"))
    -- access never set: unknown, not denied
    local open = P.Equipment(pf, self, {}, "Scholomance")
    for _, r in ipairs(open) do if r.id == "access" then T.eq(r.state, "unknown") end end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("journal links reuse the dungeon guide and fail soft without data", function()
    local _, ns, V = load()
    local j = V.Prep.Journal("No Such Place")
    T.ok(j.reason)
    T.eq(#j.quests, 0)
    ns.DungeonGuide.ByName = function() return { Deadmines = { bosses = {}, items = {} } } end
    ns.DungeonGuide.QuestList = function() return { { id = 1, name = "Red Silk", complete = false, active = true, source = "boss objective" },
      { id = 2, name = "Done one", complete = true } } end
    ns.DungeonGuide.Upgrades = function() return { { itemID = 5, name = "Cloak", boss = "Van", pct = 12 } } end
    local d = V.Prep.Journal("Deadmines")
    T.eq(#d.quests, 1, "finished quests left out")
    T.eq(d.upgrades[1].name, "Cloak")
    T.eq(#ns.Errors.list, 0)
  end)
end)
