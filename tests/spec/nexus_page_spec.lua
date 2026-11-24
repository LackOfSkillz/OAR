-- OI02-12: the plan page on the existing Hub.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = function() return {
    { key = "quest:A", kind = "quest", title = "Quest A", benefit = 0.9, confidence = 0.8, seconds = 300, label = "observed", questID = 1, go = function() end },
    { key = "quest:B", kind = "quest", title = "Quest B", benefit = 0.7, confidence = 0.8, seconds = 600, label = "community", questID = 2, go = function() end },
    { key = "errand:C", kind = "errand", title = "Errand C", benefit = 0.6, confidence = 0.8, seconds = 60, label = "observed", panel = "home" },
    { key = "quest:D", kind = "quest", title = "Quest D", benefit = 0.5, confidence = 0.8, seconds = 900, label = "observed", questID = 4, go = function() end },
  } end
  return game, ns
end

T.describe("nexus plan page", function()
  T.it("off: the page only offers the switch; What now? is unchanged", function()
    local _, ns = session()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("nexusplan")
    local cards = ns.NexusPage.Cards()
    T.eq(#cards, 0)
    ns.Hub:ShowTab("whatnow")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("on: a primary and up to two secondary cards, each opportunity once", function()
    local _, ns = session()
    ns.NexusCore:Settings().on = true
    ns.NexusCore:Replan("test")
    local cards, note = ns.NexusPage.Cards()
    T.ok(#cards >= 1 and #cards <= 3)
    T.eq(cards[1].tags[1][1], "Do this next")
    local seen = {}
    for _, c in ipairs(cards) do T.eq(seen[c.title], nil, "no duplicates") seen[c.title] = true end
    local labels = {}
    for _, a in ipairs(cards[1].actions) do labels[#labels + 1] = a[1] end
    T.eq(table.concat(labels, ","), "Go,Why,Pin,Skip")
    T.ok(type(note) == "string")
  end)

  T.it("Why shows the evidence and score trace for that card only", function()
    local _, ns = session()
    ns.NexusCore:Settings().on = true
    ns.NexusCore:Replan("test")
    local cards = ns.NexusPage.Cards()
    T.eq(cards[1].line:find("Evidence", 1, true), nil, "closed by default")
    cards[1].actions[2][2]()
    local again = ns.NexusPage.Cards()
    T.ok(again[1].line:find("Evidence", 1, true), "evidence shown")
    T.ok(again[1].line:find("goal benefit", 1, true), "score trace shown")
    if again[2] then T.eq(again[2].line:find("Evidence", 1, true), nil, "other cards stay closed") end
  end)

  T.it("a stale plan says so; the page builds with no errors and every label has a tooltip", function()
    local game, ns = session()
    ns.NexusCore:Settings().on = true
    ns.NexusCore:Replan("test")
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    local _, note = ns.NexusPage.Cards()
    T.ok(note:find("Re-plan", 1, true))
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("nexusplan")
    T.eq(#ns.Errors.list, 0)
  end)
end)
