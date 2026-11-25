-- Memory by part (Modules/PerfMemory.lua; Gary, 2026-11-25: "we need to know
-- which modules are using what memory"). Sizes are estimates; numbers here are test data.
local T, mock = ...

local function session()
  local game = mock.new({ class = "SHAMAN", level = 4, memoryKB = 35000 })
  game.addonList = { "Questie", "Details" }
  game.addonMemory = { Questie = 90000, Details = 12000 }
  game.loadedAddons.Questie, game.loadedAddons.Details = true, true
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(1)
  return game, ns, ns.PerfMemory
end

local function finish(game, P)
  for _ = 1, 200 do
    if not P:Running() then return end
    game:advance(0.02)
  end
end

T.describe("memory by part", function()
  T.it("measures by itself after login and attributes saved data and features", function()
    local game, ns, P = session()
    ns.db.global.prices = { big = {} }
    for i = 1, 2000 do ns.db.global.prices.big[i] = { item = "item " .. i, low = i } end
    game:advance(P.SETTLE_S + 1)
    finish(game, P)
    local r = P:Latest()
    T.ok(r, "an estimate was saved")
    T.eq(r.why, "auto")
    local byName = {}
    for _, p in ipairs(r.parts) do byName[p.name] = p end
    T.ok(byName["saved: prices"] and byName["saved: prices"].kb > 50, "the prices table is sized")
    T.eq(byName["saved: prices"].kind, "saved")
    T.ok(r.savedKB >= byName["saved: prices"].kb)
    T.eq(r.totalKB, 35000, "the game's own figure is kept beside the estimate")
    T.eq(r.addons[1].name, "Questie", "every add-on, biggest first")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a table two parts share is counted once", function()
    local game, ns, P = session()
    local shared = {}
    for i = 1, 500 do shared[i] = { n = i } end
    ns.db.global.sharedA = { ref = shared }
    ns.db.global.sharedB = { ref = shared }
    P:Start("test")
    finish(game, P)
    local a, b
    for _, p in ipairs(P:Latest().parts) do
      if p.name == "saved: sharedA" then a = p.kb end
      if p.name == "saved: sharedB" then b = p.kb end
    end
    T.ok(a > 10 and (b or 0) < 1, "the first part to reach it owns it")
  end)

  T.it("waits out combat instead of adding work to a fight", function()
    local game, _, P = session()
    game.combat = true
    P:Start("test")
    game:advance(3)
    T.ok(P:Running(), "paused in combat")
    game.combat = false
    finish(game, P)
    T.ok(not P:Running() and P:Latest(), "finished after combat")
  end)

  T.it("estimates are kept; past the cap the oldest go to the archive", function()
    local game, ns, P = session()
    for _ = 1, P.KEEP + 2 do P:Start("test") finish(game, P) end
    T.eq(#ns.db.global.perfMemory, P.KEEP)
    T.eq(#ns.Archive:Rows("perfMemory"), 2)
  end)

  T.it("the Performance page shows memory by part and every add-on", function()
    local game, ns, P = session()
    P:Start("test")
    finish(game, P)
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("performance")
    game:advance(1.1)
    T.ok(#ns.PerfPage.MemoryParts() >= 5)
    local addons = ns.PerfPage.AddOnBars()
    T.eq(addons[1].label, "Questie")
    T.eq(#ns.Errors.list, 0)
  end)
end)
