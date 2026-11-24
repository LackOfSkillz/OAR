-- OI03-09: estimator and calibration.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Estimator
end
local NOW = 1800000000
local function s(value, daysAgo, build, key) return { value = value, at = NOW - (daysAgo or 1) * 86400, build = build or "B2", key = key } end

T.describe("estimator and calibration (OI03-09)", function()
  T.it("enough samples: a median-based estimate shrunk toward the prior, with an observed interval", function()
    local _, _, E = session()
    local list = {}
    for i = 1, 10 do list[i] = s(500 + i * 10) end
    local m = E.FitOne(list, { now = NOW, build = "B2", prior = 300 })
    T.eq(m.basis, "observed") T.eq(m.n, 10)
    T.ok(m.value < m.median and m.value > 300, "shrunk toward the prior, not past it")
    T.ok(m.lo <= m.value and m.hi >= m.value)
  end)

  T.it("sparse: too few samples falls back to the prior with a wide band, and says why", function()
    local _, _, E = session()
    local m = E.FitOne({ s(900), s(950) }, { now = NOW, build = "B2", prior = 300 })
    T.eq(m.basis, "prior") T.eq(m.value, 300) T.ok(m.why:find("only 2"))
    T.ok(m.hi - m.lo >= 300 * 0.9, "wide band")
    local none = E.FitOne({}, { now = NOW })
    T.eq(none.basis, "none") T.eq(none.value, nil)
  end)

  T.it("a patch change: old-build samples alone widen the interval; current-build samples replace them", function()
    local _, _, E = session()
    local old = {}
    for i = 1, 8 do old[i] = s(400 + i, 2, "B1") end
    local m = E.FitOne(old, { now = NOW, build = "B2" })
    T.eq(m.basis, "older build")
    local same = E.FitOne(old, { now = NOW, build = "B1" })
    T.ok((m.hi - m.lo) > (same.hi - same.lo), "wider when the samples are from an older build")
    local mixed = {}
    for i = 1, 8 do mixed[#mixed + 1] = s(400 + i, 2, "B1") end
    for i = 1, 5 do mixed[#mixed + 1] = s(700 + i, 1, "B2") end
    T.ok(E.FitOne(mixed, { now = NOW, build = "B2" }).median > 650, "only the current build counts once it has enough")
  end)

  T.it("outliers are set aside and widen the interval", function()
    local _, _, E = session()
    local clean, dirty = {}, {}
    for i = 1, 10 do clean[i] = s(300 + i) dirty[i] = s(300 + i) end
    dirty[#dirty + 1] = s(50000) dirty[#dirty + 1] = s(60000)
    local a, b = E.FitOne(clean, { now = NOW }), E.FitOne(dirty, { now = NOW })
    T.eq(b.outliers, 2)
    T.ok(math.abs(a.median - b.median) < 1, "the median isn't dragged by the outliers")
    T.ok((b.hi - b.lo) > (a.hi - a.lo), "the interval is wider")
  end)

  T.it("recent samples are preferred when there are enough", function()
    local _, _, E = session()
    local list = {}
    for i = 1, 6 do list[#list + 1] = s(1000, 200) end -- old habits
    for i = 1, 6 do list[#list + 1] = s(400, 2) end    -- recent
    T.eq(E.FitOne(list, { now = NOW }).median, 400)
  end)

  T.it("held-out calibration: later samples only, no leakage, with real error and coverage", function()
    local _, _, E = session()
    local list = {}
    for i = 1, 30 do list[i] = { value = 400 + (i % 5) * 20, at = NOW - (31 - i) * 3600, build = "B2" } end
    local r = E.Evaluate(list, { build = "B2", now = NOW })
    T.eq(r.trainN, 21) T.eq(r.n, 9)
    T.ok(r.enough)
    T.ok(r.medianAbsError and r.medianAbsError >= 0)
    T.ok(r.coverage and r.coverage >= 0 and r.coverage <= 1)
    -- no leakage: every test sample is later than everything trained on
    T.ok(r.trainedUntil < list[22].at)
    -- a test set that differs from training shows a real error, not zero
    for i = 22, 30 do list[i].value = 2000 end
    local bad = E.Evaluate(list, { build = "B2", now = NOW })
    T.ok(bad.medianAbsError > 1000, "the error is reported, not hidden")
    T.ok(bad.coverage < 0.5)
  end)

  T.it("too few later samples: calibration says so instead of reporting a number", function()
    local _, _, E = session()
    local list = {}
    for i = 1, 8 do list[i] = { value = 100, at = NOW - i } end
    local r = E.Evaluate(list, {})
    T.eq(r.enough, false) T.ok(r.why)
  end)

  T.it("adapters: quest samples from complete quests only; travel ratio from walking samples only", function()
    local _, _, E = session()
    local q = E.QuestSamples({ { kind = "complete", seconds = 600, level = 12, endedAt = NOW, build = "B2" },
      { kind = "multi", startedAt = 1 }, { kind = "abandoned", startedAt = 1 } })
    T.eq(#q, 1) T.eq(q[1].key, "L11|solo")
    local t = E.TravelSamples({ { walking = true, seconds = 120, estimate = 100, endedAt = NOW },
      { mode = "flight", seconds = 60, estimate = 100 } })
    T.eq(#t, 1) T.eq(t[1].value, 1.2)
  end)
end)
