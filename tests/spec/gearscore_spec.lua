-- Gear advisor (P6-01..03). Items and stats are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  game.items = {
    [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [102] = { name = "New Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [103] = { name = "Future Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2, reqLevel = 30 },
    [201] = { name = "Ring A", equipLoc = "INVTYPE_FINGER" },
    [202] = { name = "Ring B", equipLoc = "INVTYPE_FINGER" },
    [203] = { name = "Ring C", equipLoc = "INVTYPE_FINGER" },
    [301] = { name = "Mail Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 3 },
    [302] = { name = "Plate Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 4 },
  }
  game.itemStats = {
    [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
    [102] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, ITEM_MOD_AGILITY_SHORT = 2 },
    [103] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
    [201] = { ITEM_MOD_AGILITY_SHORT = 5 }, [202] = { ITEM_MOD_STAMINA_SHORT = 2 }, [203] = { ITEM_MOD_AGILITY_SHORT = 3 },
    [301] = { ITEM_MOD_AGILITY_SHORT = 3 }, [302] = { ITEM_MOD_STRENGTH_SHORT = 9 },
  }
  game.worn = { [18] = 101, [11] = 201, [12] = 202 }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.GearScore
end

local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::24:::::|h[x]|h|r" end

T.describe("gear advisor", function()
  T.it("a better bow is an upgrade, weighted by ranged DPS for hunters", function()
    local _, _, G = session()
    local text, color = G:Verdict(link(102))
    T.contains(text, "upgrade")
    T.eq(color, "good")
  end)

  T.it("a ring is compared with the weaker of the two worn", function()
    local _, _, G = session()
    local r = G:Compare(link(203))
    T.ok(r.pct > 0, "3 Agility beats the 2-Stamina ring, not the 5-Agility one")
  end)

  T.it("future items say when they become usable", function()
    local _, _, G = session()
    local text, color = G:Verdict(link(103))
    T.contains(text, "usable at 30")
    T.eq(color, "warn")
  end)

  T.it("armor types: a level 24 hunter waits for mail, never wears plate", function()
    local _, _, G = session()
    T.contains(G:Verdict(link(301)), "usable at 40")
    T.eq(G:Verdict(link(302)), "can't wear this armor type")
  end)

  T.it("weights load for every class", function()
    for _, cls in ipairs({ "HUNTER", "ROGUE", "WARRIOR", "PALADIN", "SHAMAN", "DRUID", "PRIEST", "MAGE", "WARLOCK" }) do
      local _, ns = session({ class = cls })
      T.ok(ns.GearScore:Weights().role, cls)
    end
  end)
end)
