-- I2 first slice: universal profiles, evidence validation, offline Radar.
local T, mock = ...
local function session(class)
  local game = mock.new({ class = class or "HUNTER", ammo = 1000 })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end
T.describe("intelligence 2.0 profiles", function()
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
