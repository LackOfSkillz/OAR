-- Small switches (gap analysis 2026-11-17).
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local CF = game.base.CreateFrame
  for _, name in ipairs({ "ZoneTextFrame", "SubZoneTextFrame", "UIErrorsFrame" }) do
    local f = CF("Frame")
    rawset(game.env, name, f)
    game.base[name] = f
  end
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Tweaks
end

T.describe("small switches", function()
  T.it("all off by default; clutter fades and comes back", function()
    local game, ns, M = start()
    for _, v in pairs(M:Settings()) do T.eq(v, false) end
    M:Settings().zoneText = true
    M:ApplyClutter()
    T.eq(game.env.ZoneTextFrame:GetAlpha(), 0)
    T.eq(game.env.UIErrorsFrame:GetAlpha(), 1)
    M:Settings().zoneText = false
    M:ApplyClutter()
    T.eq(game.env.ZoneTextFrame:GetAlpha(), 1)
  end)

  T.it("camera zoom sets the game setting and puts it back", function()
    local game, ns, M = start()
    M:Settings().zoom = true
    M:ApplyZoom()
    T.eq(game.env.C_CVar.GetCVar("cameraDistanceMaxZoomFactor"), "2.6")
    M:Settings().zoom = false
    M:ApplyZoom()
    T.eq(game.env.C_CVar.GetCVar("cameraDistanceMaxZoomFactor"), "1.9")
  end)

  T.it("wowhead address for a hovered item; a hint when nothing is hovered", function()
    local game, ns, M = start()
    local tt = { IsShown = function() return true end, GetItem = function() return "Old Bow", "|Hitem:101::|h[Old Bow]|h" end }
    T.eq(M.WowheadFor(tt), "https://www.wowhead.com/forever/item=101")
    game:slash("wowhead")
    T.contains(game:chatText(), "hover an item")
  end)

  T.it("chat history is saved at logout and comes back greyed", function()
    local game, ns, M = start()
    M:Settings().history = true
    local lines = { "hello there", "second line" }
    local f = { GetNumMessages = function() return #lines end, GetMessageInfo = function(_, i) return lines[i] end,
      AddMessage = function(_, t) lines[#lines + 1] = t end }
    rawset(game.env, "ChatFrame1", f)
    M:SaveHistory()
    T.ok(#(ns.db.char.chatHistory or {}) > 0)
    lines = {}
    M:RestoreHistory()
    T.eq(ns.db.char.chatHistory, nil)
    T.eq(#lines, 2)
    T.contains(lines[1], "[before] hello there")
  end)
end)
