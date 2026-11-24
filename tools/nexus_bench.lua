-- tools/nexus_bench.lua [out.md] [runs]
-- OI02-15: Nexus vs WhatNow on curated scenarios. For each scenario it runs the
-- same candidates through WhatNow.Pick (today's suggester) and the Nexus
-- pipeline (adapters -> graph -> score -> planner), checks each against the
-- scenario's expected property, and times the Nexus pipeline (os.clock, mock
-- client; NOT in-game numbers). Writes a Markdown report.
-- Run: python tools/lua.py tools/nexus_bench.lua docs/quality/nexus_bench.md 200
package.path = "./tests/lib/?.lua;" .. package.path
local mock = require("wowmock")
mock.listLua = function() return {} end
local bench = require("nexus_scenarios")

local out, runs = arg[1], tonumber(arg[2]) or 100
local game = mock.new()
local ns = game:loadAddon()
game:login()

local lines = { "# Nexus planner benchmark (OI02-15)", "",
  "Mock client, Lua 5.1 through lupa on the development PC. These are **not** in-game measurements:",
  "live p95 frame cost and memory are pending Gary's session (tracker item).", "",
  string.format("Runs per scenario: %d. Times are the Nexus pipeline only (adapters, graph, score, planner).", runs), "",
  "| Scenario | Expected | WhatNow top | Nexus top | WhatNow ok | Nexus ok | mean ms | p95 ms | max ms | work | KB allocated per run |",
  "|---|---|---|---|---|---|---|---|---|---|---|" }
local allOk, diffs = true, {}
for _, sc in ipairs(bench.SCENARIOS) do
  local r = bench.Run(ns, game, sc)
  -- os.clock ticks in whole milliseconds on Windows, so a single run often
  -- reads 0 or 1: the mean comes from the whole batch, p95/max from single runs
  local times = {}
  collectgarbage("collect")
  collectgarbage("stop")
  local kb0 = collectgarbage("count")
  local batch0 = os.clock()
  for i = 1, runs do
    local t0 = os.clock()
    bench.Nexus(ns, game, sc)
    times[i] = (os.clock() - t0) * 1000
  end
  local mean = (os.clock() - batch0) * 1000 / runs
  local kb = collectgarbage("count") - kb0
  collectgarbage("restart")
  table.sort(times)
  local p = function(q) return times[math.max(1, math.ceil(#times * q))] end
  lines[#lines + 1] = string.format("| %s | %s | %s | %s | %s | %s | %.2f | %.2f | %.2f | %d | %.0f |",
    sc.name, sc.expect, tostring(r.whatnowTop), tostring(r.nexusTop), r.whatnowOk and "yes" or "**no**",
    r.nexusOk and "yes" or "**no**", mean, p(0.95), times[#times], r.work or 0, kb / runs)
  if not r.nexusOk then allOk = false end
  if r.whatnowTop ~= r.nexusTop then diffs[#diffs + 1] = string.format("- %s: WhatNow picks %s, Nexus %s. %s", sc.name, tostring(r.whatnowTop), tostring(r.nexusTop), sc.why or "") end
end
local real = bench.RealProducers(ns, game)
lines[#lines + 1] = ""
lines[#lines + 1] = "## The addon's own producers (mock client)"
lines[#lines + 1] = ""
lines[#lines + 1] = string.format("Planner on, real WhatNow producers, LevelRoutes, DealDesk and Handoffs on the mock client: %d opportunities, %d unavailable producers, %s.",
  real.opportunities or 0, real.unavailable or 0, real.ok and (real.steps > 0 and (real.steps .. " planned steps, each citing evidence that resolves, none twice") or ("no plan, reason " .. tostring(real.why))) or ("**failed: " .. tostring(real.why) .. "**"))
if not real.ok then allOk = false end
lines[#lines + 1] = ""
lines[#lines + 1] = "## Where the two differ"
lines[#lines + 1] = ""
for _, d in ipairs(diffs) do lines[#lines + 1] = d end
if #diffs == 0 then lines[#lines + 1] = "None." end
lines[#lines + 1] = ""
lines[#lines + 1] = allOk and "Nexus met every scenario's expected property." or "**Nexus missed at least one scenario (see table).**"
local fh = assert(io.open(out or "docs/quality/nexus_bench.md", "w"))
fh:write(table.concat(lines, "\n"), "\n")
fh:close()
io.write(table.concat(lines, "\n"), "\n")
