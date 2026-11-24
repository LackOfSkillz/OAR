-- OI03-08: the chronicle of milestones and decisions.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("Outcomes", true)
  return game, ns, ns.Chronicle, ns.Outcomes
end
local function texts(H, O, f) local t = {} for i, e in ipairs(H:Entries(O, f)) do t[i] = e.text end return t end

T.describe("chronicle (OI03-08)", function()
  T.it("milestones from outcomes, in time order; ordinary events are not milestones", function()
    local game, ns, H, O = session()
    game:fire("PLAYER_LEVEL_UP", 13)
    game:advance(10)
    game:fire("QUEST_TURNED_IN", 7, 100)
    game:advance(10)
    game:fire("PLAYER_DEAD")
    game.money = 50 game:fire("PLAYER_MONEY") -- money is not a milestone
    local list = H:Entries(O)
    T.eq(#list, 3)
    T.eq(list[1].text, "Reached level 13")
    T.ok(list[2].text:find("^Turned in"))
    T.ok(list[3].text:find("^Died"))
    for i = 2, #list do T.ok(list[i].at >= list[i - 1].at) end
  end)

  T.it("a replay or duplicate never adds an entry twice; a late one is filed in time order", function()
    local game, ns, H, O = session()
    game:fire("PLAYER_LEVEL_UP", 14)
    local rec = O:Store().events[#O:Store().events]
    H:FromOutcome(O, rec) H:FromOutcome(O, rec)
    T.eq(#H:Entries(O), 1)
    game:advance(100)
    H:Add(O, "zone", 9999, "First visit to Somewhere", game.now - 500)
    local list = H:Entries(O)
    T.eq(list[1].text, "First visit to Somewhere", "the earlier event comes first")
  end)

  T.it("order and dedup survive a reload", function()
    local game, ns, H, O = session()
    game:fire("PLAYER_LEVEL_UP", 15)
    game:advance(5)
    game:fire("PLAYER_LEVEL_UP", 16)
    local saved = game:logout()
    local g2 = mock.new({ savedVariables = saved })
    local ns2 = g2:loadAddon()
    g2:fire("ADDON_LOADED", "Outrider") g2:fire("PLAYER_LOGIN") g2:fire("PLAYER_ENTERING_WORLD", false, true)
    local H2, O2 = ns2.Chronicle, ns2.Outcomes
    local before = #H2:Entries(O2)
    for _, e in ipairs(O2:Store().events) do H2:FromOutcome(O2, e) end -- a full replay
    T.eq(#H2:Entries(O2), before, "replay adds nothing")
    local t = texts(H2, O2, { kinds = { level = true } })
    T.eq(t[1], "Reached level 15") T.eq(t[2], "Reached level 16")
  end)

  T.it("a Go on a plan step is a decision with its plan and step ids", function()
    local game, ns, H, O = session()
    ns.Events:Fire("OTR_NEXUS_ACTED", { planId = "plan:1:4", stepId = "opp:quests:quest:A", at = game.now, title = "Pick up A" })
    local e = H:Entries(O, { kinds = { decision = true } })[1]
    T.eq(e.text, "Chose a plan step: Pick up A")
    T.eq(e.ref.planId, "plan:1:4") T.eq(e.ref.stepId, "opp:quests:quest:A")
  end)

  T.it("first zone visit and first time on an item only once", function()
    local game, ns, H, O = session()
    game:fire("ZONE_CHANGED_NEW_AREA") game:advance(30)
    game:fire("ZONE_CHANGED_NEW_AREA")
    game.env.GetInventoryItemID = function() return 4321 end
    game:fire("PLAYER_EQUIPMENT_CHANGED", 5, false) game:advance(30)
    game:fire("PLAYER_EQUIPMENT_CHANGED", 5, false)
    T.eq(#H:Entries(O, { kinds = { zone = true } }), 1)
    T.eq(#H:Entries(O, { kinds = { gear = true } }), 1)
  end)

  T.it("hidden kinds are not recorded", function()
    local game, ns, H, O = session()
    O:Settings().chronicleHide = { death = true }
    game:fire("PLAYER_DEAD")
    T.eq(#H:Entries(O, { kinds = { death = true } }), 0)
  end)

  T.it("clearing selected entries archives them first; export is plain text", function()
    local game, ns, H, O = session()
    game:fire("PLAYER_LEVEL_UP", 20) game:advance(5)
    game:fire("PLAYER_DEAD")
    local txt = H:Export(O)
    T.ok(txt:find("Reached level 20") and txt:find("Died"), txt)
    T.eq(H:Clear(O, { kinds = { death = true } }), 1)
    T.eq(#H:Entries(O, { kinds = { death = true } }), 0)
    T.eq(#H:Entries(O, { kinds = { level = true } }), 1, "only the selected kind is cleared")
    T.eq(ns.Archive:Rows("chronicleCleared")[1].row[1].kind, "death", "kept in the archive")
    game:advance(60) -- (two deaths within seconds are one duplicate event)
    game:fire("PLAYER_DEAD") -- a new death after the clear is a new entry
    T.eq(#H:Entries(O, { kinds = { death = true } }), 1)
  end)

  T.it("the 301st entry archives the oldest", function()
    local game, ns, H, O = session()
    for i = 1, H.MAX + 1 do H:Add(O, "zone", i, "Zone " .. i, game.now + i) end
    T.eq(#H:Entries(O), H.MAX)
    T.ok(#ns.Archive:Rows("chronicleEntries") >= 1)
  end)
end)
