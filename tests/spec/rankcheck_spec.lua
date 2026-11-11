-- Rank check (P4-06). Spell IDs are the mock's test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.actions = { [1] = 14281, [2] = 75 } -- Arcane Shot rank 2 (rank 3 known), Auto Shot
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.Modules:Get("RankCheck")
end

T.describe("rank check", function()
  T.it("finds a bar button using an older rank and logs it at login", function()
    local game, ns, R = session()
    game:advance(4)
    T.eq(#R.old, 1)
    T.eq(R.old[1].slot, 1)
    T.eq(R.old[1].bestRank, 3)
    local found = false
    for _, l in ipairs(ns.Log:Tail(20)) do
      if ns.Log:FormatLine(l):find("rank check (login): 2 spell buttons, 1 old", 1, true) then found = true end
    end
    T.ok(found)
  end)

  T.it("the toast's Fix button upgrades the button out of combat", function()
    local game, ns, R = session()
    game:advance(4)
    local f = ns.Toast.visible[1]
    T.contains(f.title:GetText(), "1 button uses an old rank")
    f.action.__scripts.OnClick(f.action)
    T.eq(game.actions[1], 14282)
    T.eq(game.cursorSpell, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Fix refuses in combat", function()
    local game, ns, R = session()
    game:advance(4)
    game.combat = true
    T.eq(R:Fix(), 0)
    T.eq(game.actions[1], 14281)
  end)
end)
