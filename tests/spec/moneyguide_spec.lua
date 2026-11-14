-- Money guide: guide tips fitted to level, professions and faction; Gary's own
-- loot turns into a measured gold per hour that outranks the guide.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("money guide", function()
  T.it("fits tips to level, profession and faction", function()
    local _, ns = session()
    local G = ns.MoneyGuide
    local function ids(level, owned, faction)
      local out = {}
      for _, r in ipairs(G:Rank(level, owned, faction)) do out[r.entry.id] = true end
      return out
    end
    local a = ids(18, { Skinning = true }, "Alliance")
    T.ok(a["skin-loch-modan"], "Loch Modan skinning for an Alliance skinner at 18")
    T.ok(a["loot-everything"], "the no-profession tip is always there")
    T.ok(not a["mine-tin-silver"], "no mining tip without Mining")
    T.ok(not a["zones-45-60"], "no level 45-60 zones at 18")
    local h = ids(18, { Skinning = true }, "Horde")
    T.ok(not h["skin-loch-modan"], "Alliance-only tip hidden from Horde")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("loot builds a measured gold per hour that replaces the guide figure", function()
    local game, ns = session({ now = 1794700000 })
    local G = ns.MoneyGuide
    ns.Prices.Get = function(_, id) if id == 2318 then return 1000, "seen at AH", 50 end return nil, nil, 20 end
    for i = 0, 16 do
      game.now = 1794700000 + i * 60
      ns.Events:Fire("OTR_LOOT", "skin", { { id = 2318, count = 2, name = "Light Leather" } })
    end
    local r = G:Rate("skin")
    T.ok(r and r > 0, "measured after 15 minutes")
    -- 17 loots x 2 x 950 copper over 17 minutes (first one counts a minute)
    T.eq(r, math.floor(17 * 2 * 950 / (17 * 60) * 3600))
    local top
    for _, x in ipairs(G:Rank(18, { Skinning = true }, "Alliance")) do
      if x.entry.id == "skin-route" then top = x end
    end
    T.ok(top and top.measured, "the skinning tip now shows your own number")
    T.contains(G.RateText(top), "your own loot")
    T.contains(table.concat(G:YourLines(), "\n"), "Light Leather")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a break longer than 5 minutes doesn't count as farming time", function()
    local game, ns = session({ now = 1794700000 })
    local G = ns.MoneyGuide
    ns.Prices.Get = function() return nil, nil, 100 end
    ns.Events:Fire("OTR_LOOT", "herb", { { id = 765, count = 1, name = "Silverleaf" } })
    game.now = game.now + 3600
    ns.Events:Fire("OTR_LOOT", "herb", { { id = 765, count = 1, name = "Silverleaf" } })
    T.eq(ns.db.global.moneyLog.herb.secs, 60 + 300)
  end)

  T.it("the Money page opens and lists tips", function()
    local game, ns = session()
    ns.Modules:SetEnabled("AutoCheck", false)
    game:slash("")
    ns.Hub.frame.tabBar:Select("money")
    T.ok(ns.Hub.byId.money and ns.Hub.byId.money.panel, "Money page built")
    T.eq(#ns.Errors.list, 0)
  end)
end)
