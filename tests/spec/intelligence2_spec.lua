-- I2 first slice: universal profiles, evidence validation, offline Radar.
local T, mock = ...
local function session(class)
  local game = mock.new({ class = class or "HUNTER", ammo = 1000 })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end
T.describe("intelligence 2.0 profiles", function()
  T.it("9 x 6 universal goal contracts and unknown class fallback", function()
    for _, token in ipairs({"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
                            "SHAMAN", "MAGE", "WARLOCK", "DRUID", "UNKNOWN"}) do
      local _, ns = session(token)
      local P = ns.ClassProfiles
      local profile = P.Current()
      T.eq(profile.class, token)
      for _, goal in ipairs(P.GOALS) do
        T.ok(P.GoalValid(goal), "missing universal goal")
        T.ok(P.Allows(profile.class, profile.role, "universal"))
        T.ok(P.Allows(profile.class, profile.role, nil))
      end
    end
  end)
  T.it("all nine classes and UNKNOWN have six universal goals", function()
    local _, ns = session()
    local P = ns.ClassProfiles
    local count = 0
    for token in pairs(P.ROLES) do
      count = count + 1
      for _, goal in ipairs(P.GOALS) do
        T.ok(P.GoalValid(goal))
        T.ok(P.Allows(token, "UNKNOWN", "universal"))
      end
    end
    T.eq(count, 10)
    T.eq(P.Resolve("INVALID"), "UNKNOWN")
    T.no(P.CanPlay("INVALID", "tank"))
  end)
  T.it("explicit role survives migration and wrong role fails safely", function()
    local _, ns = session("DRUID")
    local P = ns.ClassProfiles
    T.eq(P.Current().role, "UNKNOWN")
    T.ok(P.SetRole("healer"))
    T.eq(P.Current().role, "healer")
    T.no(P.SetRole("rogue"))
    T.eq(P.Current().role, "healer")
    ns.db.char.intelligenceProfile.schema = 1
    T.eq(P.Current().role, "healer")
    T.eq(ns.db.char.intelligenceProfile.schema, 3)
    T.no(P.Allows("DRUID", "healer", {class="DRUID",role="tank"}))
    T.ok(P.Allows("DRUID", "healer", {class="DRUID",role="healer"}))
  end)
end)
T.describe("intelligence 2.0 evidence", function()
  T.it("only exports bounded metadata, not private fact values", function()
    local _, ns = session()
    local E = ns.IntelEvidence
    E:Register("WhatNow")
    local e = E:Record("WhatNow", "quest:A B", "quest",
      { money = 42, name = "Hidden", note = "Private detail" }, "observed")
    T.ok(e)
    local out = E:Exportable({e.id, e.id})
    T.eq(#out, 1)
    T.eq(out[1].evidenceId, e.id)
    T.eq(out[1].facts, nil)
    T.eq(out[1].value, nil)
  end)
  T.it("validates and expires data without leaking names", function()
    local game, ns = session()
    local E = ns.IntelEvidence
    T.ok(E:Register("WhatNow", "ready"))
    T.eq(E:Record("missing", "x", "gear", {}, "observed"), nil)
    T.eq(E:Record("WhatNow", "x", "bad", {}, "observed"), nil)
    local ev = E:Record("WhatNow", "gear:one", "gear",
      { name = "Private", realm = "Private", benefit = 0.8, nested = { clue = 1 } }, "observed", 5)
    T.ok(ev)
    T.eq(ev.value.name, nil)
    T.eq(ev.value.realm, nil)
    T.eq(ev.value.benefit, 0.8)
    T.ok(E:Get(ev.id, game.now + 5))
    T.eq(E:Get(ev.id, game.now + 6), nil)
  end)
  T.it("invalidates only one category", function()
    local _, ns = session()
    local E = ns.IntelEvidence
    E:Register("WhatNow")
    local a = E:Record("WhatNow", "quest:a", "quest", {}, "community")
    local b = E:Record("WhatNow", "gear:b", "gear", {}, "observed")
    E:Invalidate("quest")
    T.eq(E:Get(a.id), nil)
    T.ok(E:Get(b.id))
  end)
end)
T.describe("intelligence 2.0 native radar", function()
  T.it("offers Why, Later, Useful, Wrong, Done, Dismiss and Mute controls", function()
    local game, ns = session()
    local R = ns.OpportunityRadar
    ns.Modules:SetEnabled("OpportunityRadar", true)
    local original = ns.WhatNow.Candidates
    ns.WhatNow.Candidates = function()
      return {{ key="quest:First Step", kind="quest", title="Quest |cff00ff00One|r",
        benefit=1, confidence=1, label="observed", go=function() return true end }}, {}
    end
    R:Open()
    local row = R.window.rows[1]
    T.ok(row.why and row.go and row.later and row.useful and row.wrong)
    T.ok(row.done and row.dismiss and row.mute)
    T.eq(row.card.title:find("|", 1, true), nil)
    row.useful:Click()
    T.eq(ns.db.char.radarFeedback["quest:First Step"].verdict, "useful")
    row.mute:Click()
    T.ok(R:Settings().muted.quest)
    T.eq(#R:Cards(), 0)
    R:ClearFeedback()
    T.eq(R:FeedbackCount(), 0)
    ns.WhatNow.Candidates = original
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("coalesces bursts and unregisters on disable", function()
    local game, ns = session("WARRIOR")
    local R = ns.OpportunityRadar
    ns.Modules:SetEnabled("OpportunityRadar", true)
    local orig = ns.WhatNow.Candidates
    local count = 0
    ns.WhatNow.Candidates = function()
      count = count + 1
      return {{key="quest:Coming of Age",kind="quest",title="Quest A",benefit=1,
                confidence=1,label="observed"}}, {}
    end
    R:Refresh()
    T.eq(count, 1)
    game:fire("QUEST_LOG_UPDATE")
    game:fire("QUEST_LOG_UPDATE")
    game:fire("BAG_UPDATE_DELAYED")
    T.eq(count, 1)
    game:advance(1)
    T.eq(count, 1)
    game:advance(1)
    T.eq(count, 2)
    T.eq(R:Cards()[1].candidateId, "quest:Coming of Age")
    game:setCombat(true)
    game:fire("QUEST_LOG_UPDATE")
    game:advance(3)
    T.eq(count, 2)
    game:setCombat(false)
    game:advance(2)
    T.eq(count, 3)
    ns.Modules:SetEnabled("OpportunityRadar", false)
    game:fire("QUEST_LOG_UPDATE")
    game:advance(3)
    T.eq(count, 3)
    ns.WhatNow.Candidates = orig
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("is OFF by default and cannot operate when disabled", function()
    local _, ns = session("WARRIOR")
    T.no(ns.OpportunityRadar.enabled)
    T.eq(#ns.OpportunityRadar:Refresh(), 0)
  end)
  T.it("produces bounded class-neutral candidates for three classes", function()
    for _, token in ipairs({"WARRIOR", "DRUID", "HUNTER"}) do
      local game, ns = session(token)
      ns.Modules:SetEnabled("OpportunityRadar", true)
      local W = ns.WhatNow
      local orig = W.Candidates
      W.Candidates = function()
        return {
          { key = "quest:one", kind = "quest", title = "Quest one", benefit = 1, confidence = 1, why = "Player has quest", label = "observed" },
          { key = "gear:two", kind = "gear", title = "Gear two", benefit = 0.8, confidence = 0.8, label = "community" },
          { key = "errand:three", kind = "errand", title = "Repair", benefit = 0.7, confidence = 1, label = "observed" },
          { key = "gold:four", kind = "gold", title = "Gold", benefit = 0.5, confidence = 1, label = "inferred" },
          { key = "bad id", kind = "quest", title = "Bad", benefit = 1, confidence = 1, label = "observed" },
          { key = "class:wrong", kind = "gear", title = "Wrong class", benefit = 1, confidence = 1, label = "observed", roleHint = {class = "PRIEST", role = "healer"} },
        }, {}
      end
      local cards = ns.OpportunityRadar:Refresh()
      T.eq(#cards, 3)
      for _, card in ipairs(cards) do
        T.ok(ns.IntelOpportunity:Valid(card))
        T.no(card.candidateId == "bad id")
        T.no(card.candidateId == "class:wrong")
      end
      T.ok(ns.OpportunityRadar:Feedback(cards[1], "snooze"))
      local nextCards = ns.OpportunityRadar:Refresh()
      T.eq(#nextCards, 3)
      for _, c in ipairs(nextCards) do T.no(c.candidateId == cards[1].candidateId) end
      W.Candidates = orig
      T.eq(#ns.Errors.list, 0)
    end
  end)
end)
