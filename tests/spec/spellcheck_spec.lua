-- Chat spell check. A tiny word list stands in for Outrider_Data_Words.
local T, mock = ...

local function session()
  local game = mock.new()
  game.env.Outrider_DataWords = { source = "test", count = 9, chunks = {
    th = "\nthe\nthen\nthere\n", he = "\nhello\nhelp\n", wo = "\nworld\nword\n", go = "\ngoing\n",
    to = "\ntown\n", we = "\nwell\n", be = "\nbeing\n", co = "\ncolour\ncolor\n",
  } }
  local ns = game:loadAddon()
  local edit = game.env.CreateFrame("EditBox", "ChatFrame1EditBox", game.env.UIParent)
  game:login()
  return game, ns, ns.SpellCheck, edit
end

T.describe("spell check", function()
  T.it("flags finished unknown words only, with suggestions", function()
    local _, _, S = session()
    local m = S:Check("hello wrold going to teh town")
    T.eq(#m, 2)
    T.eq(m[1].word, "wrold")
    T.eq(S:Suggest("wrold")[1], "world")
    T.eq(S:Suggest("teh")[1], "the")
    T.eq(#S:Check("hello wrol"), 0, "word still being typed")
    T.eq(#S:Check("/cast Wrold Ender "), 0, "slash commands are skipped")
    T.eq(#S:Check("LFG hello world "), 0, "all-caps skipped")
    T.eq(#S:Check("Hello Wolrd"), 0, "last word waits for a pause")
    local m2 = S:Check("Hello Wolrd", true)
    T.eq(m2[1] and m2[1].word, "Wolrd", "Gary's case: capitalized typo after a pause")
    T.eq(S:Suggest("Wolrd")[1], "World")
    T.eq(#S:Check("color colour "), 0, "both spellings")
  end)

  T.it("Add and /ride spell add make a word known; chat teaches names", function()
    local game, _, S = session()
    T.eq(#S:Check("hello zug "), 1)
    game:slash("spell add zug")
    T.eq(#S:Check("hello zug "), 0)
    game:fire("CHAT_MSG_CHANNEL", "selling stuff", "Bobbington-Forever")
    T.ok(S:Known("bobbington"))
    for _ = 1, 3 do game:fire("CHAT_MSG_SAY", "kekw moment", "Ann") end
    T.ok(S:Known("kekw"))
  end)

  T.it("strip shows above the chat box and a click swaps the word", function()
    local _, ns, S, edit = session()
    edit:SetText("hello wrold")
    T.eq(#S:Update(edit), 0, "still typing")
    local misses = S:Update(edit, true)
    T.ok(S.strip:IsShown())
    T.eq(S.strip.buttons[1]:GetText(), "world")
    S:Replace(edit, misses[1], "world")
    T.eq(edit:GetText(), "hello world")
    S:Update(edit, true)
    T.no(S.strip:IsShown())
    T.eq(#ns.Errors.list, 0)
  end)
end)
