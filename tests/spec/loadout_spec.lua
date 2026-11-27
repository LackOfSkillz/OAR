-- Smart loadout (Modules/Loadout.lua): the fight keys pick the imbue, totems
-- and shock that suit the targeted mob, from the creatures pack. Pack rows
-- here are test data in the pack's shape, not game data.
local T, mock = ...

local function sp(...)
  local out = {}
  for i, n in ipairs({ ... }) do out[i] = { name = n, id = 8000 + i } end
  return out
end

local PACK = { mobs = {
  [900] = { imm = 1, casts = { 1, 2, 3 } },            -- shrugs off physical; Fireball, Fear, a self buff
  [901] = { imm = 8, res = { fire = 300 } },          -- immune nature, heavy fire resistance
  [902] = { casts = { 4 } },                          -- poisons
}, spells = {
  [1] = { "Fireball", 4, 0, 0, 1 },
  [2] = { "Fear", 32, 1, 5, 1 },
  [3] = { "Frost Armor", 16, 1, 0, 0 },              -- on itself: not aimed at you
  [4] = { "Poison", 8, 4, 0, 1 },
} }

local function shaman(spells)
  local game = mock.new({ class = "SHAMAN", level = 20 })
  game.spells = spells
  game.worn = {}
  local ns = game:loadAddon()
  game.env.Outrider_DataMobRes = PACK
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
  game:slash("fight")
  game:advance(3)
  return game, ns
end

local function macro(game, name)
  for _, m in ipairs(game.macros) do if m.name == name then return m.body end end
  return ""
end

local function target(game, npc, name)
  game.units = game.units or {}
  game.units.target = { guid = "Creature-0-1-2-3-" .. npc .. "-0000ABCD", name = name, canAttack = true }
  game:fire("PLAYER_TARGET_CHANGED")
  game:advance(3)
end

local ALL = sp("Lightning Bolt", "Rockbiter Weapon", "Flametongue Weapon", "Lightning Shield", "Earth Shock",
  "Frost Shock", "Searing Totem", "Strength of Earth Totem", "Tremor Totem", "Mana Spring Totem",
  "Fire Resistance Totem", "Poison Cleansing Totem", "Healing Wave")

T.describe("smart loadout", function()
  T.it("resistance math: Classic average resist, capped at 75%", function()
    local game, ns = shaman(ALL)
    local L = ns.Loadout
    T.eq(L.ResistMult(0, 20), 1)
    T.eq(L.ResistMult(50, 20), 1 - 0.75 * 50 / 100)
    T.eq(L.ResistMult(1000, 20), 0.25, "capped")
    local P = L:Profile(901, 20)
    T.eq(P.mult("nature"), 0, "immune")
    T.eq(P.mult("fire"), 0.25)
    T.eq(P.mult("frost"), 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a mob that shrugs off physical: Flametongue, Fire Resistance and Tremor before the pull", function()
    local game, ns = shaman(ALL)
    local f = macro(game, "Fight")
    T.contains(f, "Rockbiter Weapon", "plan's own imbue with no target")
    target(game, 900, "Stone Wraith")
    f = macro(game, "Fight")
    T.contains(f, "/cast [nocombat] Flametongue Weapon")
    T.ok(not f:find("Rockbiter", 1, true), "no Rockbiter on a physical-immune mob: " .. f)
    T.contains(f, "Tremor Totem", "it fears")
    T.ok(not f:find("Strength of Earth", 1, true), "Tremor replaces the earth totem")
    T.contains(f, "Fire Resistance Totem", "it casts Fireball: " .. f)
    T.ok(not f:find("Mana Spring", 1, true))
    T.ok(#f <= 255, "fits a macro")
    local P = ns.Loadout:Profile(900, 20)
    T.ok(P.casts.frost == nil, "Frost Armor on itself is not aimed at you")
    T.contains(ns.Loadout.Describe(P), "immune physical")
    T.contains(ns.Loadout.Describe(P), "Fireball (fire)")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the wrong imbue on the weapon counts as missing; the right one is left alone", function()
    local game, ns = shaman(ALL)
    target(game, 900, "Stone Wraith")
    game.mhEnchant, game.mhEnchantID = true, 7568 -- Rockbiter on
    game:fire("UNIT_INVENTORY_CHANGED", "player")
    game:advance(4)
    T.contains(macro(game, "Fight"), "Flametongue Weapon", "Rockbiter on, Flametongue wanted")
    game.mhEnchantID = 7567
    game:fire("UNIT_INVENTORY_CHANGED", "player")
    game:advance(4)
    T.ok(not macro(game, "Fight"):find("Flametongue Weapon", 1, true), "right imbue on: no wasted press")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("immune to nature: Frost Shock for Earth Shock; heavy fire resist: no Searing Totem", function()
    local game, ns = shaman(ALL)
    target(game, 901, "Bog Beast")
    T.eq(ns.Loadout:Apply("/cast Earth Shock"), "/cast Frost Shock")
    T.eq(ns.Loadout:Apply("/cast Lightning Shield"), "/cast Lightning Shield", "untouched")
    T.eq(ns.Loadout:Totem(1), false, "fire totem dropped")
    T.ok(not macro(game, "Fight"):find("Searing Totem", 1, true))
    -- a mob not in the pack: back to the plan
    target(game, 999, "Somebody New")
    T.eq(ns.Loadout:Apply("/cast Earth Shock"), "/cast Earth Shock")
    T.contains(macro(game, "Fight"), "Searing Totem")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("poison: Poison Cleansing Totem; friendly or no target keeps the last picks", function()
    local game, ns = shaman(ALL)
    target(game, 902, "Venom Spitter")
    T.eq(ns.Loadout:Totem(3), "Poison Cleansing Totem")
    game.units.target = { guid = "Creature-0-1-2-3-555-0000", name = "Guard", canAttack = false }
    game:fire("PLAYER_TARGET_CHANGED")
    game:advance(3)
    T.eq(ns.Loadout:Totem(3), "Poison Cleansing Totem", "a friendly target changes nothing")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("no pack installed: nothing changes, nothing breaks", function()
    local game = mock.new({ class = "SHAMAN", level = 20 })
    game.spells = ALL
    game.worn = {}
    local ns = game:loadAddon()
    game:login()
    game:advance(3)
    game:slash("fight")
    game:advance(3)
    target(game, 900, "Stone Wraith")
    T.contains(macro(game, "Fight"), "Rockbiter Weapon")
    T.eq(#ns.Errors.list, 0)
  end)
end)
