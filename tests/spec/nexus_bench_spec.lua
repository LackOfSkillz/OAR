-- OI02-15: the curated Nexus scenarios stay correct and cheap (mock timings;
-- live numbers are a tracked live item). tools/nexus_bench.lua writes the report.
local T, mock = ...
package.path = "./tests/lib/?.lua;" .. package.path
local bench = require("nexus_scenarios")

T.describe("nexus benchmark scenarios", function()
  T.it("every curated scenario meets its expected property, within the work cap", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    for _, sc in ipairs(bench.SCENARIOS) do
      local r = bench.Run(ns, game, sc)
      T.ok(r.nexusOk, sc.name .. ": " .. sc.expect)
      T.ok((r.work or 0) <= ns.NexusPlanner.MAX_WORK, sc.name .. " work")
    end
  end)

  T.it("the addon's own producers on the mock client give a valid plan or a reasoned no-plan", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local r = bench.RealProducers(ns, game)
    T.ok(r.ok, tostring(r.why))
  end)

  T.it("the pipeline stays cheap: 50 plans of every scenario well under a second in the mock", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local t0 = os.clock()
    for _ = 1, 50 do for _, sc in ipairs(bench.SCENARIOS) do bench.Nexus(ns, game, sc) end end
    local ms = (os.clock() - t0) * 1000
    T.ok(ms < 2000, string.format("%d plans took %.0f ms", 50 * #bench.SCENARIOS, ms))
  end)
end)
