-- Pages an 8th grader gets at a glance (Gary, 2026-11-20): steps under the
-- title, plain words, pictures, and something useful to do on each.
local T, mock = ...

local function rogue(level, spells)
  local game = mock.new({ class = "ROGUE", level = level or 12 })
  game.spells = {}
  for i, n in ipairs(spells or { "Sinister Strike", "Stealth", "Eviscerate" }) do game.spells[i] = { name = n, id = 600 + i } end
  local ns = game:loadAddon()
  game:login()
  ns.Hub:Build()
  return game, ns
end

local function open(ns, id)
  ns.Hub.frame.tabBar:Select(id)
  return ns.Hub.byId[id].panel
end

T.describe("pages at a glance", function()
  T.it("the six pages say what they're for and show numbered steps under the title", function()
    local _, ns = rogue()
    for _, id in ipairs({ "class", "waypoints", "rares", "journal", "professions", "crafting" }) do
      local p = open(ns, id)
      T.ok(p:IsShown(), id)
      T.ok(p.hubSteps and #p.hubSteps >= 2, id .. " has steps")
      T.eq(p.hubSteps[1].num:GetText(), "1")
    end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("class page: spells your trainer has for you now and next", function()
    local _, ns = rogue(12)
    local now, soon, nextLevel = ns.ClassPage.TrainerSpells("ROGUE")
    local names = {}
    for _, sp in ipairs(now) do names[sp.name] = true end
    T.ok(names.Kick and names.Gouge, "Kick (12) and Gouge (6) not known yet: learn them now")
    T.ok(not names.Stealth, "known spells are left out")
    T.ok(nextLevel and nextLevel > 12)
    for _, sp in ipairs(soon) do T.ok(sp.level > 12) end
    for _, sp in ipairs(now) do T.ok(sp.level <= 12) end
    open(ns, "class")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("rares: the chosen rare is explained on the right with Waypoint and Watch", function()
    local _, ns = rogue()
    ns.RaresTab.scope = "all"
    local p = open(ns, "rares")
    p:Refresh()
    if #p.list.items > 0 then
      T.ok(p.detail:IsShown())
      T.ok(p.detail.name:GetText() ~= "")
      T.contains(p.detail.text:GetText(), "Layers")
    end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("crafting: recipes, queue and what you need, with plain notes", function()
    local _, ns = rogue()
    ns.db.char.professions = { Cooking = { skill = 50, max = 150, recipes = {
      [1] = { name = "Charred Wolf Meat", diff = 1, product = 2679, reagents = { [2672] = 1 } } } } }
    local p = open(ns, "crafting")
    p:Refresh()
    T.eq(#p.list.items, 1)
    p.list.rowFrames[1].__scripts.OnClick(p.list.rowFrames[1])
    T.eq(#p.qlist.items, 1)
    T.eq(#p.slist.items, 1)
    T.contains(p.total:GetText(), "to buy")
    T.eq(#ns.Errors.list, 0)
  end)
end)
