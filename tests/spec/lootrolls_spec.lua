-- Loot roll advice (dungeon module phase 3): Need / Greed for an alt / Greed / Pass.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("loot rolls", function()
  T.it("advises Need for your upgrade, Greed for an alt, Greed or Pass otherwise", function()
    local _, ns = session()
    local L = ns.LootRolls
    local G, K = ns.GearScore, ns.KitShare
    local realCompare, realBest = G.Compare, K.BestFor
    G.Compare = function(_, link)
      if link:find("item:1:") then return { pct = 20 } end
      if link:find("item:2:") then return { pct = 15, why = "learn Maces" } end
      return { pct = 0 }
    end
    K.BestFor = function(_, id) if id == 3 then return { name = "Torrant-Mcluvin", pct = 30, tier = "alt" } end end
    local function adv(id, extra)
      local info = { link = "|Hitem:" .. id .. ":|h[x]|h" }
      for k, v in pairs(extra or {}) do info[k] = v end
      return L:Advice(info)
    end
    T.eq(adv(1), "Need")
    T.eq(adv(1, { canNeed = false }), "Greed")
    T.eq(adv(2), "Greed")                   -- can't use it yet: no Need
    local roll, why = adv(3)
    T.eq(roll, "Greed")
    T.contains(why, "Torrant")
    T.eq(adv(3, { bop = true }), "Greed")    -- soulbound: no mail, plain Greed
    T.eq(adv(4, { canGreed = false }), "Pass")
    G.Compare, K.BestFor = realCompare, realBest
  end)

  T.it("a roll shows its advice on the item tooltip until it ends, and is logged", function()
    local game, ns = session()
    local G = ns.GearScore
    local realCompare = G.Compare
    G.Compare = function() return { pct = 25 } end
    game.lootRolls = { [7] = { link = "|cff1eff00|Hitem:555::::|h[Sword]|h|r", name = "Sword", quality = 2 } }
    game:fire("START_LOOT_ROLL", 7, 60000)
    local tip = { GetItem = function() return "Sword", "|cff1eff00|Hitem:555::::|h[Sword]|h|r" end }
    local lines = ns.TooltipLines:Lines("item", tip)
    local found
    for _, l in ipairs(lines or {}) do if type(l) == "table" and tostring(l[1]):find("Roll: Need") then found = true end end
    T.ok(found)
    game:fire("CANCEL_LOOT_ROLL", 7)
    T.eq(ns.LootRolls:ForLink("item:555"), nil)
    G.Compare = realCompare
    T.eq(#ns.Errors.list, 0)
  end)
end)
