-- Cross-language contract (Outrider Intelligence, spec 12.4): the addon's
-- /ride ask snapshot -> the companion's answer (Python, committed fixture) ->
-- pasted back into the addon. Refresh with tools/contract_fixtures.ps1.
local T = ...
package.path = "./tests/lib/?.lua;" .. package.path
local session = require("contract_session")

local function read(name)
  local f = io.open("tests/fixtures/contract/" .. name, "rb")
  if not f then return nil end
  local t = f:read("*a")
  f:close()
  return t
end

T.describe("contract fixtures", function()
  T.it("the addon still makes the snapshot the fixture was built from", function()
    local _, ns = session()
    local want = read("snapshot_v2.txt")
    T.ok(want ~= nil, "run tools/contract_fixtures.ps1")
    T.eq(ns.Snapshot:Code(), (want:gsub("%s+$", "")))
  end)

  T.it("the companion's answer pastes into the addon with every card and the plan", function()
    local _, ns = session()
    local code = read("advice_v2.txt")
    T.ok(code ~= nil, "run tools/contract_fixtures.ps1")
    local n, why = ns.Advice:Paste(code)
    T.eq(why, "ok")
    T.eq(n, 3)
    local items, _, answer = ns.Advice:Load()
    T.eq(items[1].action, "waypoint")
    T.eq(items[2].args.x, 0.4012345678901234)   -- coordinates survive Lua -> Python -> Lua exactly
    T.eq(items[3].args.panel, "professions")
    T.eq(answer.budget, 30)
    T.eq(#answer.plan, 3)
    T.contains(ns.Advisor.PlanLine(answer), "of 30")
    T.eq(#ns.Errors.list, 0)
  end)
end)
