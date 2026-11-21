-- Bug reports and ideas (Gary, 2026-11-21): the game can't post to GitHub,
-- so Outrider builds a ready-made issue link the player copies.
local T, mock = ...

local function start()
  local game = mock.new({ class = "ROGUE", level = 14 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Feedback
end

local function decode(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

T.describe("feedback", function()
  T.it("a bug report becomes a GitHub link with the bug template and what a fix needs", function()
    local game, ns, M = start()
    ns.Errors.list[#ns.Errors.list + 1] = { where = "Spec", msg = "Outrider/Modules/Spec.lua:1: boom", count = 2 }
    ns.Errors.list[#ns.Errors.list + 1] = { where = "Unknown", msg = "Blizzard_ChatFrameBase/ChatFrameOverrides.lua:32: bad argument", count = 1 }
    local url = M:Make("bug", "Arrow points the wrong way", "I clicked Go and it pointed to Orgrimmar.", false)
    T.ok(url, "a link")
    T.contains(url, "github.com/LackOfSkillz/outrider-releases/issues/new?template=bug_report.md")
    local text = decode(url)
    T.contains(text, "[Bug] Arrow points the wrong way")
    T.contains(text, "I clicked Go and it pointed to Orgrimmar.")
    T.contains(text, "Outrider:")
    T.contains(text, "level 14")
    T.contains(text, "Spec: Outrider/Modules/Spec.lua:1: boom (x2)")
    T.ok(not text:find("ChatFrameOverrides", 1, true), "Blizzard's own errors stay out")
    T.ok(not text:find(game.base.UnitName("player"), 1, true), "no character name unless asked")
    T.eq(#ns.db.global.feedback, 1, "kept on this PC")
    T.eq(#ns.Errors.list, 2, "only the errors the spec added")
  end)

  T.it("an idea uses the idea template, and the name is added only when switched on", function()
    local game, ns, M = start()
    local url = M:Make("idea", "", "Show herb timers on the minimap please", true)
    T.contains(url, "template=feature_request.md")
    local text = decode(url)
    T.contains(text, "[Idea] Show herb timers on the minimap please", "the title comes from the words")
    T.contains(text, game.base.UnitName("player"))
    T.ok(not text:find("Recent Outrider errors", 1, true), "ideas carry no error list")
  end)

  T.it("says what's missing instead of making an empty report", function()
    local _, ns, M = start()
    local url, why = M:Make(nil, "x", "y")
    T.eq(url, nil) T.contains(why, "Pick one")
    url, why = M:Make("bug", " ", "  ")
    T.eq(url, nil) T.contains(why, "few words")
    T.eq(#ns.db.global.feedback, 0)
  end)

  T.it("a very long report is trimmed to a link browsers accept", function()
    local _, ns, M = start()
    for i = 1, 40 do ns.Errors.list[#ns.Errors.list + 1] = { where = "Spec" .. i, msg = "Outrider " .. string.rep("x", 400), count = 1 } end
    local url = M:Make("bug", "Long", string.rep("words and more words ", 200), false)
    T.ok(#url <= M.URL_MAX, "under the limit: " .. #url)
    for i = 1, 30 do M:Make("idea", "n" .. i, "t") end
    T.eq(#ns.db.global.feedback, M.MAX, "only the last reports are kept")
  end)

  T.it("the page opens from Help and from /ride report, and walks the three steps", function()
    local game, ns = start()
    game:slash("report")
    local p = ns.Hub.byId.feedback.panel
    T.ok(p and p:IsShown(), "Report or idea page shown")
    p.make:Click()
    T.contains(p.status:GetText(), "Pick one", "the button answers even with no choice (Gary: nothing happened)")
    p.bug:Click()
    T.eq(p.kind, "bug")
    p.title.edit:SetText("Map pins missing")
    p.text.edit:SetText("No pins on Zephras Isle.")
    p.make:Click()
    T.ok(ns.UI.dialog and ns.UI.dialog:IsShown(), "the copy box opened")
    T.contains(ns.UI.dialog.edit:GetText(), "issues/new")
    T.eq(#ns.Errors.list, 0)
  end)
end)
