-- OI03-11: the After action report.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("Outcomes", true)
  ns.Modules:SetEnabled("SessionXP", true)
  return game, ns, ns.AfterAction
end

T.describe("after action report (OI03-11)", function()
  T.it("totals come straight from their sources and add up", function()
    local game, ns, A = session()
    game.money = 1000 ns.Outcomes.money = 1000
    game:fire("MERCHANT_SHOW")
    game.money = 1600 game:fire("PLAYER_MONEY")
    game:fire("MERCHANT_CLOSED")
    game:advance(20)
    game.money = 1400 game:fire("PLAYER_MONEY")
    game:fire("QUEST_ACCEPTED", 3)
    game:advance(600)
    game:fire("PLAYER_DEAD")
    local ps = ns.PlaySession:Id()
    local rep = A.Report(ps)
    -- gold: +600 vendor, -200 other
    T.eq(rep.gold.realizedNet, 400)
    T.eq(rep.gold.realized["vendor sale"], 600)
    -- activity totals equal the wall time the timeline covered
    local live, sum = ns.ActivityTimeline:Totals()
    T.eq(rep.played, sum)
    local s = 0 for _, v in pairs(rep.activity) do s = s + v end
    T.eq(s, rep.played)
    T.eq(rep.deaths, 1)
  end)

  T.it("XP per hour is wall clock, from the merged XP record, and an unfinished session says so", function()
    local game, ns, A = session()
    local X = ns.SessionXP
    X.current.durationSeconds = 1800
    X.current.xpEarned = 6000
    X:Checkpoint(false)
    local rep = A.Report(ns.PlaySession:Id())
    T.eq(math.floor(rep.xp.xpPerHour + 0.5), 12000)
    T.ok(table.concat(rep.xp.labels, ","):find("in progress"))
    local L = A.Lines(rep)
    T.ok(L.labels:find("in progress"), L.labels)
  end)

  T.it("with no XP record or too few earlier sessions it says so instead of inventing a number", function()
    local game, ns, A = session()
    ns.Modules:SetEnabled("SessionXP", false)
    local rep = A.Report("ps:none")
    T.ok(rep.xp.why)
    local L = A.Lines(rep)
    T.ok(L.compare:find("Not enough earlier sessions"))
    T.ok(L.quest:find("Not enough finished quests") or L.quest:find("default"), L.quest)
    T.eq(L.stats[1].value, "-")
  end)

  T.it("compared only with your own earlier sessions, as numbers, never as a claim", function()
    local _, ns, A = session()
    local L = A.Lines(A.Demo())
    T.ok(L.compare:find("Your earlier sessions: 10800 XP an hour %(median of 6%)"), L.compare)
    for _, k in ipairs({ "compare", "quest", "walk", "gold", "ideas" }) do
      local t = L[k]:lower()
      T.ok(not t:find("improv") and not t:find("because") and not t:find("thanks to"), k .. ": " .. L[k])
    end
  end)

  T.it("example data is clearly labelled and loot value is called an estimate", function()
    local game, ns, A = session()
    local L = A.Lines(A.Demo())
    T.ok(L.labels:find("example data"))
    T.ok(L.gold:find("an estimate"))
    A.showDemo = true
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("afteraction")
    A.showDemo = false
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the page builds without errors and every button has a tooltip", function()
    local game, ns = session()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("afteraction")
    T.eq(#ns.Errors.list, 0)
    local missing = {}
    for label in pairs(ns.UI.untipped or {}) do missing[#missing + 1] = label end
    T.eq(#missing, 0, "no tooltip for: " .. table.concat(missing, ", "))
    for _, label in ipairs({ "Record outcomes (private, opt-in)", "Export the chronicle", "Show an example", "After action" }) do
      T.ok(ns.Tips.controls[label], label)
    end
    T.ok(ns.Tips.pages.afteraction, "page tip")
  end)
end)
