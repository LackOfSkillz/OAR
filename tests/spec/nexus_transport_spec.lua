-- OI02-14: cross-language contract tests. Lua writes tests/fixtures/contract/
-- nexus_v4_otr1.txt (tools/nexus_fixtures.lua); Python wrote nexus_v4_otr1_py.txt
-- with its own encoder. Both must decode to the same records, keep ids and
-- numeric units, and validate. Fuzzed records can never smuggle in an action.
local T, mock = ...

local function loadData(path, name)
  local fh = assert(io.open(path, "r"))
  local text = fh:read("*a")
  fh:close()
  local env = {}
  local chunk = assert(loadstring(text))
  setfenv(chunk, env)
  chunk()
  return env[name]
end
local function lines(path)
  local out = {}
  for line in io.lines(path) do
    local rec, code = line:match("^(%w+)\t(.+)$")
    if rec then out[#out + 1] = { rec, code } end
  end
  return out
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

T.describe("nexus cross-language contracts", function()
  T.it("the committed Lua codes are exactly what the addon exports today", function()
    local _, ns = session()
    local fx = loadData("docs/contracts/nexus_v4_fixtures.lua", "NexusFixtures")
    local valid = {}
    for _, c in ipairs(fx) do if c.ok then valid[#valid + 1] = c end end
    local got = lines("tests/fixtures/contract/nexus_v4_otr1.txt")
    T.eq(#got, #valid)
    for i, c in ipairs(valid) do
      T.eq(got[i][1], c.record)
      T.eq(got[i][2], ns.Serialize.Export(c.data), "regenerate with tools/nexus_fixtures.lua if the contract changed")
    end
  end)

  T.it("codes Python encoded decode in Lua to the same valid records (ids and units kept)", function()
    local _, ns = session()
    local fx = loadData("docs/contracts/nexus_v4_fixtures.lua", "NexusFixtures")
    local valid = {}
    for _, c in ipairs(fx) do if c.ok then valid[#valid + 1] = c end end
    local py = lines("tests/fixtures/contract/nexus_v4_otr1_py.txt")
    T.eq(#py, #valid)
    for i, c in ipairs(valid) do
      local data = ns.Serialize.Import(py[i][2])
      T.ok(data, "decoded " .. c.record)
      -- an empty list arrives as an empty table either way
      T.ok(same(data, c.data), c.record .. " identical after the trip")
      T.ok(ns.Nexus.Validate(c.record, data))
    end
  end)

  T.it("fuzzed records are either still valid or rejected; none carries an action", function()
    local _, ns = session()
    local fx = loadData("docs/contracts/nexus_v4_fixtures.lua", "NexusFixtures")
    local seed = 12345
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n + 1 end
    local junk = { "x|cffff0000", 1e300, -1, 0.5, true, "/cast Fireball", { 1, 2 }, string.rep("a", 400), "" }
    local extras = { "action", "macro", "run", "script", "cast" }
    local rejected, kept = 0, 0
    for _, c in ipairs(fx) do
      if c.ok then
        local fields = {}
        for k in pairs(c.data) do fields[#fields + 1] = k end
        table.sort(fields)
        for _ = 1, 150 do
          local d = ns.CopyTable(c.data)
          local how = rnd(3)
          if how == 1 then d[fields[rnd(#fields)]] = junk[rnd(#junk)]
          elseif how == 2 then d[extras[rnd(#extras)]] = junk[rnd(#junk)]
          else d[fields[rnd(#fields)]] = nil end
          local ok = ns.Nexus.Validate(c.record, d)
          if ok then
            kept = kept + 1
            for k in pairs(d) do T.ok(k ~= "action" and k ~= "macro" and k ~= "run" and k ~= "script" and k ~= "cast") end
            if d.intent then T.ok(d.intent == "waypoint" or d.intent == "panel" or d.intent == "none") end
          else rejected = rejected + 1 end
        end
      end
    end
    T.ok(rejected > 500, "most mutations rejected (" .. rejected .. ")")
    T.ok(kept > 0, "harmless mutations still pass (" .. kept .. ")")
  end)

  T.it("a record that arrives without its producer can't do anything (execution boundary)", function()
    local game, ns = session()
    local N = ns.NexusCore
    N:Settings().on = true
    local rec = ns.Serialize.Import(lines("tests/fixtures/contract/nexus_v4_otr1_py.txt")[4][2]) -- an Opportunity
    N.current = { result = { plan = { steps = { rec.opportunityId } } }, revision = ns.NexusState:Revision(), at = game.now,
      runtime = {}, graph = { nodes = {} } }
    local ok, why = N:Act(rec.opportunityId)
    T.eq(ok, false)
    T.eq(why, "that step isn't in the current plan")
  end)
end)
