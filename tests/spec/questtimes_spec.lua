-- OI03-04: quest time observations from the quest diary.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.QuestTimes
end
local function row(id, what, t, extra)
  local r = { id = id, what = what, t = t, lvl = 12, zone = "Darkshore", gb = "70862" }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end
local function byKind(samples)
  local out = {}
  for _, s in ipairs(samples) do out[s.questID] = s end
  return out
end

T.describe("quest time observations (OI03-04)", function()
  T.it("each kind from the diary; only complete one-session quests get a duration", function()
    local _, _, Q = session()
    local h = {
      row(1, "took", 100, { ps = "ps:a" }), row(1, "handed in", 700, { ps = "ps:a" }),   -- complete, 600 s
      row(2, "took", 100, { ps = "ps:a" }), row(2, "handed in", 9000, { ps = "ps:b" }),  -- multi-session
      row(3, "took", 200, { ps = "ps:a" }), row(3, "abandoned", 300, { ps = "ps:a" }),   -- abandoned
      row(4, "took", 400, { ps = "ps:a" }),                                               -- open
      row(5, "handed in", 500, { ps = "ps:a" }),                                          -- no "took" seen
      row(6, "took", 100), row(6, "handed in", 100 + 5 * 3600),                           -- old rows, far apart
    }
    local s = byKind(Q.Observe(h))
    T.eq(s[1].kind, "complete") T.eq(s[1].seconds, 600)
    T.eq(s[2].kind, "multi") T.eq(s[2].seconds, nil)
    T.eq(s[3].kind, "abandoned") T.eq(s[3].seconds, nil)
    T.eq(s[4].kind, "open")
    T.eq(s[5].kind, "censored")
    T.eq(s[6].kind, "multi", "no session ids and over MAX_GAP apart")
    for _, x in pairs(s) do if x.kind ~= "complete" then T.eq(x.seconds, nil, "no invented duration") end end
  end)

  T.it("grouped quests are told apart; strata by level band, solo or group, and build", function()
    local _, _, Q = session()
    local h = {}
    for i = 1, 5 do
      h[#h + 1] = row(i, "took", i * 1000, { ps = "ps:a" })
      h[#h + 1] = row(i, "handed in", i * 1000 + 300 + i * 10, { ps = "ps:a" })
    end
    h[#h + 1] = row(9, "took", 9000, { ps = "ps:a", grp = true })
    h[#h + 1] = row(9, "handed in", 9200, { ps = "ps:a" })
    local sum = Q.Summary(Q.Observe(h))
    T.eq(#sum.strata, 2)
    local solo, group
    for _, st in ipairs(sum.strata) do if st.key:find("solo") then solo = st else group = st end end
    T.eq(solo.n, 5) T.ok(solo.enough) T.eq(solo.median, 330)
    T.eq(group.n, 1) T.eq(group.enough, false)
    T.ok(solo.key:find("L11") and solo.key:find("70862"), solo.key)
  end)

  T.it("compared with Journey's 300 s estimate only where there are enough samples", function()
    local _, ns, Q = session()
    local h = {}
    for i = 1, 6 do
      h[#h + 1] = row(i, "took", i * 1000, { ps = "ps:a" })
      h[#h + 1] = row(i, "handed in", i * 1000 + 600, { ps = "ps:a" })
    end
    h[#h + 1] = row(50, "took", 1, { ps = "ps:a", grp = true })
    h[#h + 1] = row(50, "handed in", 61, { ps = "ps:a" })
    local cmp = Q.Compare(Q.Summary(Q.Observe(h)))
    local solo, group
    for _, c in ipairs(cmp) do if c.key:find("solo") then solo = c else group = c end end
    T.eq(solo.baseline, ns.Journey.QUEST_TIME)
    T.eq(solo.ratio, 2)
    T.ok(solo.note:find("travel"))
    T.eq(group.ratio, nil, "one sample is not enough")
  end)

  T.it("the live diary rows carry play session, group and game build; old rows still read", function()
    local game, ns, Q = session()
    game.inGroup = true
    game:fire("QUEST_ACCEPTED", 77)
    game:advance(120)
    game.inGroup = false
    game:fire("QUEST_TURNED_IN", 77)
    local h = ns.Modules:Get("QuestInfo"):History()
    local took = h[#h - 1]
    T.eq(took.ps, ns.PlaySession:Id())
    T.eq(took.grp, true)
    T.eq(took.gb, "70862")
    local mine = byKind(Q:Mine())
    T.eq(mine[77].kind, "complete") T.eq(mine[77].seconds, 120) T.eq(mine[77].grouped, true)
  end)
end)
