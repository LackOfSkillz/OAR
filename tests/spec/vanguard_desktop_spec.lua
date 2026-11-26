-- VG07-02/04/07: the desktop companion and the addon agree on one contract.
--   * every field the addon writes into a run record is in the shared fixture
--     (companion/tests/fixtures/vanguard_contract.json), which the Python
--     export filter and strict import use;
--   * companion/outrider_companion/vanguard/addon_tables.json is exactly what
--     tools/vanguard_tables.lua builds from the addon now (no drift);
--   * the addon never refers to the desktop tools (it works without them).
local T, mock = ...

local J = dofile("tests/lib/json.lua")
local FIX = J.file("companion/tests/fixtures/vanguard_contract.json")

local function set(list) local s = {} for _, v in ipairs(list) do s[v] = true end return s end

local function readAll(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

T.describe("vanguard desktop contract", function()
  T.it("run records the addon writes stay inside the shared contract", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    local R = ns.Vanguard.Runs
    local store = R.Store()
    local snap = { members = { { class = "WARRIOR", level = 20 }, { class = "PRIEST", level = 21 } } }
    local feats = R.Features(snap, function(m) return { value = m.class == "WARRIOR" and "TANK" or "HEALER" } end)
    local t = game.env.time()
    R.Enter(store, "The Deadmines", { bosses = 2, size = 5, features = feats,
      assessment = { low = 40, high = 60, coverage = 0.5, gate = "not established", point = nil, catalog = 1 } }, t)
    R.EncounterStart(store, 1, "Rhahk'Zor", t + 10)
    R.EncounterEnd(store, 1, "Rhahk'Zor", 1, t + 70)
    R.EncounterStart(store, 2, "Sneed", t + 100)
    R.Left(store, t + 200)
    local run = R.Close(store, "left", t + 900)
    local fields = FIX.fields
    local allowed, fAllowed, aAllowed, atAllowed = set(fields.run), set(fields.features), set(fields.assessment), set(fields.attempt)
    for k in pairs(run) do T.ok(allowed[k], "run field in the contract: " .. tostring(k)) end
    for k in pairs(run.features) do T.ok(fAllowed[k], "features field: " .. tostring(k)) end
    for c in pairs(run.features.classes) do T.ok(set(FIX.classes)[c], "class " .. c) end
    for k in pairs(run.assessment) do T.ok(aAllowed[k], "assessment field: " .. tostring(k)) end
    for _, a in ipairs(run.attempts) do
      for k in pairs(a) do T.ok(atAllowed[k], "attempt field: " .. tostring(k)) end
      T.ok(set(FIX.results)[a.result], "result " .. tostring(a.result))
    end
    T.ok(set(FIX.outcomes)[run.outcome], "outcome " .. tostring(run.outcome))
    -- the assessment the module copies into a run uses only contract fields
    local src = readAll("addon/Outrider/Modules/Vanguard.lua")
    local body = src:match("info%.assessment = (%b{})")
    T.ok(body, "the module still copies the assessment")
    for key in body:gmatch("([%a_][%w_]*)%s*=") do T.ok(aAllowed[key], "module assessment field: " .. key) end
    -- a lost run is unknown with a reason (import accepts that shape)
    R.Enter(store, "Scholomance", { bosses = 3 }, t + 2000)
    local lost = R.Close(store, "lost", t + 2100)
    T.eq(lost.outcome, "unknown")
    T.ok(type(lost.censorReason) == "string" and #lost.censorReason <= 60)
  end)

  T.it("the companion's copy of the addon tables matches the addon", function()
    local game = mock.new()
    local ns = game:loadAddon()
    local VT = dofile("tools/vanguard_tables.lua")
    local want = VT.json(VT.build(ns))
    local have = readAll(VT.OUT):gsub("%s+$", "")
    T.eq(have, want, "addon_tables.json is stale: run  python tools/lua.py tools/vanguard_tables.lua write")
    local tables = J.decode(have)
    T.eq(tables.verified, false)
    for class in pairs(ns.Vanguard.Roles.BY_CLASS) do T.ok(set(FIX.classes)[class], "fixture knows " .. class) end
  end)

  T.it("the addon never refers to the desktop tools", function()
    local toc = readAll("addon/Outrider/Outrider.toc")
    local n = 0
    for line in toc:gmatch("[^\r\n]+") do
      if not line:match("^%s*#") and line:match("%.lua%s*$") then
        local path = "addon/Outrider/" .. line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")
        local s = readAll(path)
        n = n + 1
        T.ok(not s:find("outrider_companion", 1, true) and not s:find("vanguard.sqlite", 1, true)
          and not s:find("OTR-VG-EXPORT", 1, true), path .. " stays independent of the desktop")
      end
    end
    T.ok(n > 50, "read the TOC files")
  end)
end)
