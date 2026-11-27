-- Talent advisor: the plan follows the build from what is spent, waits for
-- locked rows, reports points spent elsewhere, and rings the next points.
-- Trees and names here are test data (the real build is Data/Talents.lua).
local T, mock = ...

local function tree()
  return {
    { name = "Beast Mastery", talents = {
      { name = "Endurance Training", tier = 1, column = 2, rank = 0, max = 5 },
      { name = "Deadly Aspects", tier = 1, column = 3, rank = 0, max = 5 },
      { name = "Improved Aspect of the Monkey", tier = 2, column = 1, rank = 0, max = 3 },
      { name = "Improved Revive Pet", tier = 2, column = 3, rank = 0, max = 2 },
      { name = "Bestial Swiftness", tier = 3, column = 1, rank = 0, max = 1 },
      { name = "Pathfinding", tier = 3, column = 2, rank = 0, max = 2 },
      { name = "Unleashed Fury", tier = 3, column = 3, rank = 0, max = 5 },
      { name = "Summon Hawk", tier = 4, column = 1, rank = 0, max = 1, req = { 3, 1 } },
    } },
    { name = "Marksmanship", talents = { { name = "Lethal Shots", tier = 1, column = 2, rank = 0, max = 5 } } },
  }
end

local function session(level, ranks, unspent)
  local game = mock.new({ level = level })
  game.talents = tree()
  for name, r in pairs(ranks or {}) do
    for _, tab in ipairs(game.talents) do for _, e in ipairs(tab.talents) do if e.name == name then e.rank = r end end end
  end
  game.unspent = unspent
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

local function names(list)
  local out = {}
  for _, s in ipairs(list) do out[#out + 1] = s.name .. " " .. s.rank end
  return table.concat(out, ", ")
end

T.describe("talent advisor", function()
  T.it("level 17 with Endurance Training 5/5: the next three are Improved Aspect of the Monkey 1-3", function()
    local _, ns = session(17, { ["Endurance Training"] = 5 }, 3)
    local plan, state, build = ns.Talents:Current()
    T.eq(build.id, "hunter-bm")
    T.eq(state.unspent, 3)
    T.eq(names(plan.next), "Improved Aspect of the Monkey 1, Improved Aspect of the Monkey 2, Improved Aspect of the Monkey 3")
    T.eq(plan.next[1].level, 15)
    T.eq(#plan.offPlan, 0)
    T.contains(ns.Talents:Summary(), "3 talent points: Improved Aspect of the Monkey (1/3)")
  end)

  T.it("points spent elsewhere are off plan; the plan carries on from what is spent", function()
    local _, ns = session(17, { ["Endurance Training"] = 3, ["Deadly Aspects"] = 2 }, 3)
    local plan = ns.Talents:Current()
    T.eq(names(plan.next), "Endurance Training 4, Endurance Training 5, Improved Aspect of the Monkey 1")
    T.eq(plan.offPlan[1].name, "Deadly Aspects")
    T.eq(plan.offPlan[1].extra, 2)
    T.contains(ns.Talents:Summary(), "Off plan: Deadly Aspects +2")
  end)

  T.it("a row that isn't open yet waits, and later steps wait behind it", function()
    -- 9 points in the tree: row 3 (Bestial Swiftness) needs 10
    local _, ns = session(20, { ["Endurance Training"] = 5, ["Improved Aspect of the Monkey"] = 3, ["Improved Revive Pet"] = 1 }, 2)
    local plan = ns.Talents:Current()
    T.eq(names(plan.next), "Improved Revive Pet 2, Bestial Swiftness 1", "the 10th point opens row 3 for the 11th")
    -- if Bestial Swiftness sat on row 4 (needs 15), it waits and Pathfinding waits behind it
    local game2, ns2 = session(20, { ["Endurance Training"] = 5, ["Improved Aspect of the Monkey"] = 3, ["Improved Revive Pet"] = 1 }, 3)
    game2.talents[1].talents[5].tier = 4
    local plan2 = ns2.Talents:Current()
    T.eq(names(plan2.next), "Improved Revive Pet 2")
    local locked
    for _, s in ipairs(plan2.steps) do if s.locked then locked = s end end
    T.eq(locked.name, "Bestial Swiftness")
  end)

  T.it("a prerequisite must be full first; free points come from the level when the client can't say", function()
    local _, ns = session(25, { ["Endurance Training"] = 5, ["Improved Aspect of the Monkey"] = 3, ["Improved Revive Pet"] = 2,
      ["Pathfinding"] = 2, ["Unleashed Fury"] = 2 }, nil)
    local plan, state = ns.Talents:Current()
    T.eq(state.unspent, 2, "16 points by 25, 14 spent")
    T.eq(names(plan.next), "Bestial Swiftness 1, Summon Hawk 1")
  end)

  T.it("build names the client doesn't have are reported, never a crash", function()
    local game, ns = session(17, { ["Endurance Training"] = 5 }, 1)
    game.talents[1].talents[1].name = "Endurance Drills"
    local plan = ns.Talents:Current()
    T.eq(plan.missing[1], "Endurance Training")
    T.eq(names(plan.next), "Improved Aspect of the Monkey 1")
    ns.Talents:Check()
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a talent Forever renamed follows its new name; a missing one goes to the log, not chat", function()
    local game, ns = session(17, { ["Endurance Training"] = 5 }, 1)
    -- pretend Forever renamed Improved Aspect of the Monkey
    ns.MacroTree.RENAMED["Improved Aspect of the Monkey"] = { to = "Monkey Training", note = "test" }
    game.talents[1].talents[3].name = "Monkey Training"
    game.talents[1].talents[2].name = "Deadly Drills" -- not in the build anyway
    local plan = ns.Talents:Current()
    for _, n in ipairs(plan.missing) do T.ok(n ~= "Improved Aspect of the Monkey", "the renamed talent is found") end
    T.eq(names(plan.next), "Monkey Training 1")
    T.eq(plan.next[1].renamedFrom, "Improved Aspect of the Monkey")
    ns.MacroTree.RENAMED["Improved Aspect of the Monkey"] = nil
    -- a name with no rename: logged once, never printed
    game.talents[1].talents[1].name = "Endurance Drills"
    ns.Talents.missingLogged = nil
    local before = #game.chat
    ns.Talents:Check()
    local printed = false
    for i = before + 1, #game.chat do if tostring(game.chat[i]):find("doesn't have") then printed = true end end
    T.ok(not printed, "no chat warning")
    T.ok(ns.Talents.missingLogged, "logged")
  end)

  T.it("tooltip line, one chat line per level, and the command", function()
    local game, ns = session(17, { ["Endurance Training"] = 5 }, 3)
    T.eq(ns.Talents:TooltipLine(1, 3), "Outrider plan: spend here next (#1)")
    T.eq(ns.Talents:TooltipLine(1, 1), "Outrider plan: done (5/5)")
    T.eq(ns.Talents:TooltipLine(2, 1), "Outrider plan: not in your build")
    T.eq(ns.Talents:TooltipLine(1, 8), "Outrider plan: rank 1 at level 25")
    ns.Talents:Check()
    ns.Talents:Check()
    local n = 0
    for _ in game:chatText():gmatch("gold rings") do n = n + 1 end
    T.eq(n, 1, "told once for this level")
    game:slash("talents")
    T.contains(game:chatText(), "Improved Aspect of the Monkey (1/3)")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("no talent API: says so quietly", function()
    local game = mock.new({ level = 17 })
    local ns = game:loadAddon()
    game:login()
    T.eq(ns.Talents:Read(), nil)
    T.contains(ns.Talents:Summary(), "not readable")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("talent advisor on the modern talent system", function()
  T.it("reads nodes by name from the active config; the client says which node can take a point", function()
    local game = mock.new({ level = 17 })
    game.traits = { { treeID = 100, unspent = 3, nodes = {
      { id = 1, name = "Endurance Training", rank = 5, max = 5 },
      { id = 2, name = "Improved Aspect of the Monkey", rank = 0, max = 3, open = true },
      { id = 3, name = "Improved Revive Pet", rank = 0, max = 2, open = true },
    } } }
    local ns = game:loadAddon()
    game:login()
    local plan, state = ns.Talents:Current()
    T.eq(state.api, "traits")
    T.eq(state.unspent, 3)
    T.eq(names(plan.next), "Improved Aspect of the Monkey 1, Improved Aspect of the Monkey 2, Improved Aspect of the Monkey 3")
    -- a node the client says is closed waits
    game.traits[1].nodes[2].open = false
    T.eq(#ns.Talents:Current().next, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("mage builds and the level 40 reset", function()
  local function mage(level, ranks, unspent)
    local game = mock.new({ level = level, class = "MAGE" })
    local nodes = {}
    for i, n in ipairs({ "Wand Specialization", "Improved Channeling", "Missile Barrage", "Arcane Subtlety", "Improved Frostbolt" }) do
      nodes[i] = { id = i, name = n, rank = ranks[n] or 0, max = 5, open = true }
    end
    game.traits = { { treeID = 1, unspent = unspent, nodes = nodes } }
    local ns = game:loadAddon()
    game:login()
    return game, ns
  end

  T.it("Arcane to 39, then Frost; at 40 with Arcane points it says to reset first", function()
    local _, ns = mage(20, { ["Wand Specialization"] = 2 }, 1)
    T.eq(ns.Talents:Build().id, "mage-arcane")
    T.eq(names(ns.Talents:Current().next), "Improved Channeling 1")
    local _, ns40 = mage(40, { ["Wand Specialization"] = 2, ["Improved Channeling"] = 5 }, 1)
    T.eq(ns40.Talents:Build().id, "mage-frost")
    T.contains(ns40.Talents:Summary(), "reset your talents at the mage trainer")
    local _, ns39 = mage(39, { ["Wand Specialization"] = 2 }, 1)
    T.contains(ns39.Talents:Summary(), "Level 40: reset")
  end)
end)
