-- Ordered tooltip block and tooltip style (P7-05).
local T, mock = ...

local function tipFor(game, unit)
  local tip = game.env.GameTooltip
  tip.__lines = {}
  tip.AddLine = function(self, text) self.__lines[#self.__lines + 1] = text end
  tip.GetUnit = function() return "x", unit end
  return tip
end

T.describe("tooltip lines", function()
  T.it("providers show in a fixed order, once, and only while their module is on", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local TL = ns.TooltipLines
    local fake = { enabled = true }
    TL:Add("item", "owned", fake, function() return { "you have 3" } end)
    TL:Add("item", "verdict", fake, function() return { { "+5% upgrade", "good" } } end)
    TL:Add("item", "owned", fake, function() return { "you have 4" } end) -- replaces, never duplicates
    local tip = tipFor(game)
    local only = {}
    for _, p in ipairs(TL.providers.item) do if p.owner == fake then only[#only + 1] = p end end
    TL.providers.item = only
    TL:Fill("item", tip, { id = 1 })
    T.same(tip.__lines, { "+5% upgrade", "you have 4" })
    fake.enabled = false
    tip.__lines = {}
    TL:Fill("item", tip, { id = 1 })
    T.eq(#tip.__lines, 0)
    TL:Add("item", "value", nil, function() error("boom") end)
    T.eq(TL:Fill("item", tip, { id = 1 }), 0, "a failing provider is contained")
  end)

  T.it("hides the primary tooltip in combat, but Shift allows it", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local tip = game.env.GameTooltip
    game:setCombat(true)
    tip:Hide()
    tip:Show()
    T.ok(not tip:IsShown(), "tooltip hidden without modifier")
    game.shift = true
    tip:Show()
    T.ok(tip:IsShown(), "Shift reveals tooltip")
    game:setCombat(false)
    game.shift = false
    tip:Hide()
    tip:Show()
    T.ok(tip:IsShown(), "tooltip restored after combat")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("shows exact remaining quest counts from typed NPC tooltip objectives", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game.units = { mouseover = { name = "Wolf", objectives = {
      " - Prairie Wolf slain: 3/8", " - Completed objective: 5/5"
    } } }
    local tip = tipFor(game, "mouseover")
    local lines = ns.Tooltips:QuestProgress("mouseover")
    T.eq(#lines, 1)
    T.contains(lines[1], "5 left")
    ns.TooltipLines:Fill("unit", tip, nil)
    T.contains(table.concat(tip.__lines, "|"), "Quest: Prairie Wolf slain (5 left)")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("unit tooltips get a target line and a class border for players", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game.units = { mouseover = { name = "Lumen", player = true }, mouseovertarget = { name = "Kobold" } }
    local tip = tipFor(game, "mouseover")
    ns.TooltipLines:Fill("unit", tip, nil)
    T.contains(table.concat(tip.__lines, "|"), "Target: Kobold")
    T.eq(ns.Tooltips.BorderFor("mouseovertarget"), nil, "not a player")
    T.eq(#ns.Errors.list, 0)
  end)
end)
