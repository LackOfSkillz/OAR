-- Gear for alts, family and other Outrider users: alts first, then family,
-- then everyone else; only people who can use the item; sharing opt-in.
local T, mock = ...

local function session(share)
  local game = mock.new({ level = 15, faction = "Alliance" })
  game.items = {
    [801] = { name = "Agile Boots", equipLoc = "INVTYPE_FEET", class = 4, subclass = 2, bind = 2 },
    [802] = { name = "Soulbound Hat", equipLoc = "INVTYPE_HEAD", class = 4, subclass = 2, bind = 1 },
  }
  game.itemStats = { [801] = { ITEM_MOD_AGILITY_SHORT = 6 }, [802] = { ITEM_MOD_AGILITY_SHORT = 9 } }
  game.bags = { [0] = { [1] = 801, [2] = 802 } }
  local ns = game:loadAddon()
  game:login()
  ns.KitShare:Settings().share = share
  local now = game.now or time()
  local function card(name, cls, armor, feet, tier)
    return { name = name, class = cls, level = 20, faction = "Alliance", armor = armor, weapons = { [2] = true },
      slots = { [8] = feet }, t = now, tier = tier }
  end
  ns.db.global.kits["Torrant-Realm"] = card("Torrant-Realm", "HUNTER", 2, 2, "alt")
  ns.db.global.kits["Lily-Realm"] = card("Lily-Realm", "PRIEST", 1, 0)
  ns.db.global.kits["Bob-Realm"] = card("Bob-Realm", "HUNTER", 2, 0)
  ns.KitShare:SetFamily("lily", true)
  return game, ns
end

T.describe("kit share", function()
  T.it("an alt who can use it comes first, even when someone else gains more", function()
    local _, ns = session(true)
    local best = ns.KitShare:BestFor(801)
    T.eq(best.name, "Torrant-Realm")
    T.eq(best.tier, "alt")
  end)

  T.it("then family (only if they can use it), then other Outrider users", function()
    local _, ns = session(true)
    ns.db.global.kits["Torrant-Realm"] = nil
    local best = ns.KitShare:BestFor(801)
    T.eq(best.name, "Bob-Realm", "Lily is a priest: no leather")
    T.eq(best.tier, "outrider")
    ns.db.global.kits["Lily-Realm"].class, ns.db.global.kits["Lily-Realm"].armor = "DRUID", 2
    T.eq(ns.KitShare:BestFor(801).name, "Lily-Realm", "family before other Outrider users")
  end)

  T.it("with sharing off only alts are considered; soulbound items are never offered", function()
    local game, ns = session(false)
    ns.db.global.kits["Torrant-Realm"] = nil
    T.eq(ns.KitShare:BestFor(801), nil)
    local mailable = ns.KitShare:Mailable()
    T.eq(#mailable, 1)
    T.eq(mailable[1].itemID, 801)
  end)

  T.it("a card from another Outrider user is kept and answered with ours", function()
    local game, ns = session(true)
    ns.KitShare:OnComm(nil, "KIT", { class = "MAGE", level = 12, slots = { [8] = 1 }, weapons = {} }, "Ann-Realm")
    T.ok(ns.db.global.kits["Ann-Realm"])
    local whispered = false
    for _, m in ipairs(game.sent or {}) do if m.channel == "WHISPER" and m.target == "Ann-Realm" then whispered = true end end
    T.ok(whispered, "replied with our card")
    T.eq(#ns.Errors.list, 0)
  end)
end)
