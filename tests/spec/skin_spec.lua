-- Clean dark skin (P7-04): cosmetic only, out of combat, reversible.
local T, mock = ...

local function window(game, name)
  local f = game.env.CreateFrame("Frame", name, game.env.UIParent)
  f.NineSlice = game.env.CreateFrame("Frame", nil, f)
  f.Bg = f:CreateTexture()
  f:Hide()
  return f
end

T.describe("skin", function()
  T.it("skins a window the first time it opens, never moves it, restores on disable", function()
    local game = mock.new()
    local ns
    game.onLoad = nil
    ns = game:loadAddon()
    local f = window(game, "MerchantFrame")
    game:login()
    local points = f:GetNumPoints()
    f:Show()
    T.ok(ns.Skin.done.MerchantFrame)
    T.eq(f.NineSlice:GetAlpha(), 0)
    T.eq(f.Bg:GetAlpha(), 0)
    T.eq(f:GetNumPoints(), points, "never re-anchored")
    T.ok(ns.Skin.panels.MerchantFrame:IsShown())
    ns.Modules:SetEnabled("Skin", false)
    T.eq(f.NineSlice:GetAlpha(), 1)
    T.no(ns.Skin.panels.MerchantFrame:IsShown())
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("waits for combat to end before touching a window", function()
    local game = mock.new()
    local ns = game:loadAddon()
    local f = window(game, "LootFrame")
    game:login()
    game:fire("PLAYER_REGEN_DISABLED")
    game.combat = true
    f:Show()
    T.no(ns.Skin.done.LootFrame)
    game.combat = false
    game:fire("PLAYER_REGEN_ENABLED")
    game:advance(1)
    T.ok(ns.Skin.done.LootFrame)
  end)

  T.it("steps aside when ElvUI is loaded", function()
    local game = mock.new({ addons = { "ElvUI" } })
    local ns = game:loadAddon()
    game:login()
    T.no(ns.Skin.enabled)
  end)
end)
