-- Review OI-FR02: learning and reports read archived records as well as the
-- active lists (Archive:WithActive), scoped to the character.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("archive-aware history (review OI-FR02)", function()
  T.it("archived rows come first, then active; other characters' rows are left out", function()
    local _, ns = session()
    local A = ns.Archive
    local list = { { n = 1 }, { n = 2 }, { n = 3 } }
    T.ok(A:Shift("travelTrips", list, { path = "char.outcomes.travel", scope = "char" }))
    A:Put("travelTrips", { n = 99 }, { scope = "char" })
    A:Sets().travelTrips[#A:Sets().travelTrips].char = "Someone-Else"
    local rows = A:WithActive("travelTrips", list)
    T.eq(#rows, 3)
    T.eq(rows[1].n, 1) T.eq(rows[3].n, 3)
    T.eq(#A:WithActive("travelTrips", list, { char = false }), 4, "every character on request")
    T.eq(#A:WithActive("travelTrips", list, { max = 2 }), 2, "bounded")
    T.eq(A:WithActive("travelTrips", list, { max = 2 })[2].n, 3, "the newest kept")
  end)

  T.it("the cache follows rows moving to the archive", function()
    local _, ns = session()
    local A = ns.Archive
    local list = { { n = 1 }, { n = 2 } }
    local a = A:WithActive("travelTrips", list)
    T.eq(A:WithActive("travelTrips", list), a, "same lists: same answer, not rebuilt")
    list[#list + 1] = { n = 3 }
    T.eq(#A:WithActive("travelTrips", list), 3)
    A:Shift("travelTrips", list, {})
    local b = A:WithActive("travelTrips", list)
    T.eq(#b, 3) T.eq(b[1].n, 1)
  end)

  T.it("a quest taken before the diary cap still pairs with its hand-in", function()
    local _, ns = session()
    local QI = ns.Modules:Get("QuestInfo")
    local h = QI:History()
    for i = #h, 1, -1 do h[i] = nil end
    h[1] = { t = 1000, id = 77, what = "took", lvl = 10, ps = "s1" }
    -- the cap moves the "took" row to the archive
    ns.Archive:Shift("questDiary", h, { path = "global.questHistory[character]", keys = { character = ns.db.key }, scope = "char" })
    h[#h + 1] = { t = 1600, id = 77, what = "handed in", lvl = 10, ps = "s1" }
    local found
    for _, s in ipairs(ns.QuestTimes:Mine()) do if s.questID == 77 then found = s end end
    T.ok(found, "a sample")
    T.eq(found.kind, "complete")
    T.eq(found.seconds, 600)
  end)

  T.it("preferences and the session report count archived outcomes", function()
    local _, ns = session()
    ns.Modules:SetEnabled("Outcomes", true)
    local O = ns.Outcomes
    local store = O:Store()
    local psId = ns.PlaySession:Id()
    store.events[#store.events + 1] = { kind = "death", sessionId = psId, at = 1 }
    ns.Archive:Shift("outcomeEvents", store.events, { path = "char.outcomes.events", scope = "char" })
    local rep = ns.AfterAction.Report(psId)
    T.eq(rep.deaths, 1, "the archived death is in this session's report")
    local P = ns.NexusPreferences or ns.Preferences
    if P and P.Sources then
      local src = P.Sources()
      local n = 0
      for _, e in ipairs(src.outcomes) do if e.kind == "death" then n = n + 1 end end
      T.eq(n, 1, "preferences see it")
    end
  end)
end)
