-- Faster paste route (2026-11-15): Ask and Paste keys, Ctrl+V applies at once.
local T, mock = ...

local function session()
  local game = mock.new({ ammo = 1000 })
  local ns = game:loadAddon()
  game:login()
  local snap = ns.Snapshot:Collect(true)
  return game, ns, snap
end

local function advice(ns, snap)
  return ns.Serialize.Export({ kind = "advice", schema = 2, forCharacter = ns.db.key, answersSnapshot = snap.askedAt,
    answersSnapshotId = snap.snapshotId, answer = { headline = "Open your gear", summary = "s" },
    items = { { title = "Open gear", action = "open_panel", args = { panel = "gear" } } } })
end

-- what WoW does on Ctrl+V: set the text and call OnTextChanged with userInput = true
local function paste(d, text)
  d.edit.__text = text
  d.edit.__scripts.OnTextChanged(d.edit, true)
end

T.describe("fast paste", function()
  T.it("knows an Outrider code by its shape", function()
    local _, ns = session()
    T.ok(ns.UI.LooksLikeCode("OTR1:0a1b2c3d:QUJD"))
    T.ok(ns.UI.LooksLikeCode("  OTR1:0A1B2C3D:QUJD\n"))
    T.ok(not ns.UI.LooksLikeCode("OTR1:0a1b:QUJD"))
    T.ok(not ns.UI.LooksLikeCode("hello"))
    T.ok(not ns.UI.LooksLikeCode(nil))
  end)

  T.it("applies the advice on Ctrl+V without an Accept click", function()
    local _, ns, snap = session()
    local d = ns.Advisor:OpenPaste()
    T.ok(d:IsShown())
    paste(d, advice(ns, snap))
    T.ok(not d:IsShown())
    local items, why = ns.Advice:Load()
    T.eq(why, "ok")
    T.eq(items[1].title, "Open gear")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("keeps the box open with the reason when the code is wrong", function()
    local _, ns = session()
    local d = ns.Advisor:OpenPaste()
    paste(d, ns.Serialize.Export({ kind = "snapshot" }))
    T.ok(d:IsShown())
    T.ok(d.hint:GetText():find("not advice", 1, true) ~= nil)
  end)

  T.it("does nothing while typing, or for text that isn't a code", function()
    local _, ns, snap = session()
    local d = ns.Advisor:OpenPaste()
    paste(d, "hello")
    T.ok(d:IsShown())
    d.edit.__text = advice(ns, snap)
    d.edit.__scripts.OnTextChanged(d.edit, false)   -- set by code, not by Gary
    T.ok(d:IsShown())
  end)

  T.it("the copy box doesn't auto-accept", function()
    local _, ns = session()
    ns.Snapshot:AskAdvisor()
    local d = ns.UI.dialog
    T.ok(d:IsShown())
    T.eq(d.edit.__scripts.OnTextChanged, nil)
  end)

  T.it("Ask key refuses in combat; binding labels exist", function()
    local game, ns = session()
    T.ok(game.env.BINDING_NAME_OUTRIDER_ASK ~= nil and game.env.BINDING_NAME_OUTRIDER_PASTE ~= nil)
    game.combat = true
    ns.Advisor:AskKey()
    T.ok(not (ns.UI.dialog and ns.UI.dialog:IsShown()))
  end)
end)
