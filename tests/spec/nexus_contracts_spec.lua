-- OI02-01: Nexus v4 contracts. One spec (docs/contracts/nexus_v4.lua) read by
-- Lua and Python; both validators must agree with the recorded verdicts in
-- docs/contracts/nexus_v4_fixtures.lua (companion/tests/test_nexus_v4.py runs
-- the same fixtures). v1-v3 contracts are unchanged (contract_spec and the
-- companion golden tests still pass).
local T, mock = ...

local function loadData(path, name)
  local fh = assert(io.open(path, "r"))
  local text = fh:read("*a")
  fh:close()
  local env = {}
  local chunk = assert(loadstring(text, "=" .. path))
  setfenv(chunk, env)
  chunk()
  return env[name]
end

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("nexus v4 contracts", function()
  T.it("the addon's spec is an exact copy of docs/contracts/nexus_v4.lua", function()
    local _, ns = session()
    T.ok(same(ns.Nexus.SPEC, loadData("docs/contracts/nexus_v4.lua", "NexusSpec")))
  end)

  T.it("every shared fixture gets its recorded verdict (same file the Python test reads)", function()
    local _, ns = session()
    local fx = loadData("docs/contracts/nexus_v4_fixtures.lua", "NexusFixtures")
    T.ok(#fx >= 18)
    for i, case in ipairs(fx) do
      local ok, field = ns.Nexus.Validate(case.record, case.data)
      T.eq(ok, case.ok, "fixture " .. i .. " " .. case.record)
      if not case.ok then T.eq(field, case.error, "fixture " .. i .. " field") end
    end
  end)

  T.it("a v3 opportunity card maps to a valid v4 Opportunity without changing the card", function()
    local _, ns = session()
    local card = { schema = 3, candidateId = "quest:123", kind = "quest", title = "Wanted: Gnoll", why = "near you",
      score = 0.62, evidenceId = "whatnow:quest:123", label = "community", expiresAt = 1794700180 }
    local rec = ns.Nexus.FromV3Opportunity(card, 4)
    T.ok(rec, "mapped")
    T.eq(rec.opportunityId, "opp:quest:123")
    T.eq(rec.legacyCandidateId, "quest:123")
    T.eq(rec.confidence, "community")
    T.eq(rec.intent, "none", "no action implied by the mapping")
    T.ok(ns.Nexus.Validate("Opportunity", rec))
    T.eq(card.schema, 3, "v3 card untouched")
    local bad = ns.Nexus.FromV3Opportunity({ candidateId = "x", kind = "quest", title = "t", label = "guaranteed",
      evidenceId = "e", expiresAt = 1 })
    T.eq(bad, nil, "an invalid confidence label is not mapped")
  end)

  T.it("records can't carry functions, secrets or nested commands", function()
    local _, ns = session()
    local ok, field = ns.Nexus.Validate("Plan", { planId = "p", snapshotRevision = 1, steps = { function() end },
      reasonCodes = {}, createdAt = 1, version = 1, truncated = false })
    T.eq(ok, false)
    T.eq(field, "steps")
    ok, field = ns.Nexus.Validate("Opportunity", { opportunityId = "o", kind = "quest", title = "t|cffff0000x",
      benefit = 0.5, confidence = "inferred", evidenceIds = { "e" }, expiresAt = 1, intent = "none", revision = 1 })
    T.eq(field, "title", "UI escape codes rejected")
  end)
end)
