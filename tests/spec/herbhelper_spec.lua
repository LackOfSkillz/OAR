-- Herbalism helper: Find Herbs reminder, pin nodes you mouse over. Names are test data.
local T, mock = ...

local function session(tracking)
  local game = mock.new()
  game.prof = { name = "Herbalism", skill = 4, max = 75, line = 182, recipes = {} }
  game.tracking = tracking
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(6)
  return game, ns
end

local function objectHook(game)
  for _, h in ipairs(game.tooltipHooks or {}) do if h.kind == 33 then return h.fn end end
end

local function said(game, text)
  local n = 0
  for _, l in ipairs(game.chat) do if l:find(text, 1, true) then n = n + 1 end end
  return n
end

T.describe("herb helper", function()
  T.it("says once when Find Herbs is off, and logs the tracking list", function()
    local game, ns = session({ { name = "Find Herbs", active = false }, { name = "Track Beasts", active = true } })
    T.eq(said(game, "Find Herbs is off"), 1)
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    game:advance(6)
    T.eq(said(game, "Find Herbs is off"), 1, "once per session")
    local logged
    for _, l in ipairs(ns.Log:Tail(40)) do
      if ns.Log:FormatLine(l):find("minimap tracking: Find Herbs, Track Beasts (on)", 1, true) then logged = true end
    end
    T.ok(logged)
  end)

  T.it("quiet when Find Herbs is on", function()
    local game = session({ { name = "Find Herbs", active = true } })
    T.eq(said(game, "is off"), 0)
  end)

  T.it("mousing over a herb pins it once; other objects are only logged", function()
    local game, ns = session({})
    local hook = objectHook(game)
    T.ok(hook, "object tooltip hooked")
    local before = #ns.db.global.nodes
    hook(game.env.GameTooltip, { lines = { { leftText = "Silverleaf" }, { leftText = "Herbalism" } } })
    hook(game.env.GameTooltip, { lines = { { leftText = "Silverleaf" }, { leftText = "Herbalism" } } })
    hook(game.env.GameTooltip, { lines = { { leftText = "Mailbox" } } })
    T.eq(#ns.db.global.nodes, before + 1)
    local n = ns.db.global.nodes[#ns.db.global.nodes]
    T.eq(n.name, "Silverleaf")
    T.eq(n.kind, "herb")
    T.ok(n.seenOnly and n.verified == false)
    T.eq(#ns.Errors.list, 0)
  end)
end)
