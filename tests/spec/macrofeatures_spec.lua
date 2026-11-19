-- Macro features from the Forever macro addons, our own way (Gary, 2026-11-19).
local T, mock = ...

local function char(cls, level, spells, opts)
  opts = opts or {}
  opts.class, opts.level = cls, level
  local game = mock.new(opts)
  game.spells = {}
  for i, n in ipairs(spells) do game.spells[i] = { name = n, id = 700 + i } end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("macro features", function()
  T.it("places a spell by the client's trainer level and talent tree (SpellInfo)", function()
    local _, ns = char("ROGUE", 6, { "Sinister Strike", "Stealth" })
    local MT = ns.MacroTree
    T.eq(MT.LevelOf({ "Distract" }), 22)
    T.eq(MT.TreeOf({ "Premeditation" }), "subtlety")
    local icon = MT.Icon({ spells = { "Distract" }, tags = { "utility" } })
    T.contains(icon, "ability_rogue_distract", "the game icon before you know the spell")
  end)

  T.it("a planned build steers the fight plan until talents decide", function()
    local _, ns = char("ROGUE", 6, { "Sinister Strike", "Stealth" })
    T.eq(ns.FightPlan:Spec(), "levelling")
    ns.MacroTree:Settings().planned = "combat"
    T.eq(ns.FightPlan:Spec(), "combat")
    ns.MacroTree:Settings().planned = "nonsense"
    T.eq(ns.FightPlan:Spec(), "levelling", "an unknown build is ignored")
  end)

  T.it("macro check: renamed spells and exact copies in your own macros", function()
    local game, ns = char("WARLOCK", 20, { "Shadow Bolt" }, { macros = {
      { name = "MyDot", icon = 1, body = "/cast Curse of Agony" },
      { name = "Nuke", icon = 1, body = "/cast Shadow Bolt" },
      { name = "Nuke2", icon = 1, body = "/cast Shadow Bolt" },
    } })
    local list = ns.MacroTree:Audit()
    local text = ""
    for _, f in ipairs(list) do text = text .. f.name .. ": " .. f.problem .. ", " .. f.fix .. "\n" end
    T.contains(text, "MyDot: Curse of Agony")
    T.contains(text, "Bane of Agony")
    T.contains(text, "Nuke2: the same text as Nuke")
  end)

  T.it("after a respec the old build's macros are listed and cleared on request", function()
    local game, ns = char("ROGUE", 30, { "Sinister Strike", "Riposte" })
    local L = ns.MacroLibrary
    T.ok(L:Install({ id = "rogue-talent-riposte", name = "Riposte", class = "ROGUE", body = "#showtooltip\n/cast Riposte", scope = "char" }))
    L:Settings().installed["Riposte"].tree = "combat"
    ns.FightPlan.Spec = function() return "subtlety" end
    local old = ns.MacroTree:OldBuild()
    T.eq(#old, 1) T.eq(old[1].name, "Riposte")
    local n = ns.MacroTree:ClearOldBuild()
    T.eq(n, 1)
    T.eq(#game.macros, 0)
  end)

  T.it("slots, the new badge and one chat line when macros unlock", function()
    local game, ns = char("ROGUE", 6, { "Sinister Strike", "Stealth" })
    local MT = ns.MacroTree
    local used, max = MT.Slots()
    T.eq(used, 0) T.eq(max, 18)
    MT.baseline = MT:UnlockedIds()
    game.spells[#game.spells + 1] = { name = "Gouge", id = 900 }
    ns.Spellbook:Scan()
    local fresh = MT:CheckNew()
    local all = table.concat(fresh, ",")
    T.contains(all, "Gouge")
    T.eq(#MT:CheckNew(), 0, "told once")
  end)

  T.it("a macro on your bar gets Outrider's explanation in its tooltip", function()
    local game, ns = char("ROGUE", 12, { "Sinister Strike", "Kick" })
    local kick
    for _, it in ipairs(ns.MacroTree:Items("pve")) do if it.id == "rogue-kick" then kick = it end end
    T.ok(ns.MacroTree:PickUp(kick))
    game.env.GetActionInfo = function(slot) if slot == 5 then return "macro", 1 end end
    local lines = {}
    local tt = { AddLine = function(_, t) lines[#lines + 1] = t end, Show = function() end }
    ns.MacroTree:AddTooltip(tt, 5)
    T.contains(table.concat(lines, "\n"), "Outrider: When an enemy starts casting")
  end)

  T.it("missing-buffs row offers known self-buffs that are down, never unknown ones", function()
    local _, ns = char("MAGE", 20, { "Arcane Intellect", "Frost Armor" })
    local want = ns.BuffRow:Wanted()
    local names = {}
    for _, w in ipairs(want) do names[#names + 1] = w.spell end
    T.same(names, { "Arcane Intellect", "Frost Armor" })
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the potion macro fills in the best healthstone and potion in your bags", function()
    local game, ns = char("WARRIOR", 20, { "Battle Shout" })
    game.items = { [5512] = { name = "Minor Healthstone", sellPrice = 0 }, [929] = { name = "Healing Potion", sellPrice = 50 },
      [118] = { name = "Minor Healing Potion", sellPrice = 5 } }
    game.bags = { [0] = { 5512, 929, 118 } }
    local v = ns.MacroLibrary:Values()
    T.eq(v.HEALTHSTONE, "Minor Healthstone")
    T.eq(v.POTION, "Healing Potion")
  end)
end)
