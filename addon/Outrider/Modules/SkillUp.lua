-- Modules/SkillUp.lua  (P5-04 skill-up planner)
-- For each profession, ranks learned recipes by cost per expected skill
-- point, using the recipe color the client reports (Professions stores it as
-- diff: 0 orange, 1 yellow, 2 green, 3 grey). Expected points per craft are
-- ESTIMATES (Classic conventions, not measured): orange 1.0, yellow 0.6,
-- green 0.25, grey 0. Materials Gary already has in bags or bank cost
-- nothing; the rest are priced from Prices (AH; a vendor sell price is not
-- a buy price, so unpriced materials make the recipe "price unknown").
-- "Cheapest route to N": greedy, one craft at a time, using owned materials
-- first. Colors shift as the skill rises, so the route is only refreshed at
-- the next trade skill window scan; it says so.
-- /ride skillup [profession] [target]

local _, ns = ...
local M = ns:NewModule("SkillUp", {
  title = "Skill-up planner",
  phase = "P5",
  order = 75,
  defaults = {},
})
ns.SkillUp = M

M.EXPECTED = { [0] = 1.0, [1] = 0.6, [2] = 0.25, [3] = 0 }
M.COLOR = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }
M.MAX_CRAFTS = 400

local function owned()
  local me = (ns.db.global.inventory or {})[ns.db.key] or {}
  local have = {}
  for _, place in ipairs({ "bags", "bank" }) do
    for id, n in pairs(me[place] or {}) do have[id] = (have[id] or 0) + n end
  end
  return have
end

-- cost of one craft given what is left in `have` (not changed); nil if unpriced
local function craftCost(r, have)
  local total = 0
  for id, n in pairs(r.reagents or {}) do
    local buy = math.max(0, n - (have[id] or 0))
    if buy > 0 then
      local ah = ns.Prices:Get(id)
      if not ah then return nil end
      total = total + ah * buy
    end
  end
  return total
end

-- { {id, name, color, exp, cost, perPoint} } best first; unpriced last
function M:Rank(prof, have)
  have = have or owned()
  local p = (ns.db.char.professions or {})[prof]
  local out = {}
  for id, r in pairs(p and p.recipes or {}) do
    local exp = M.EXPECTED[r.diff or -1]
    if exp and exp > 0 and r.reagents and next(r.reagents) then
      local cost = craftCost(r, have)
      out[#out + 1] = { id = id, name = r.name or tostring(id), color = M.COLOR[r.diff], exp = exp, cost = cost,
        perPoint = cost and cost / exp or nil, recipe = r }
    end
  end
  table.sort(out, function(a, b)
    if (a.perPoint ~= nil) ~= (b.perPoint ~= nil) then return a.perPoint ~= nil end
    if a.perPoint and a.perPoint ~= b.perPoint then return a.perPoint < b.perPoint end
    return a.name < b.name
  end)
  return out
end

-- { steps = { {name, crafts, cost} }, points, cost, short } to gain `points`
function M:Route(prof, points)
  local have = owned()
  local steps, byName, gained, total = {}, {}, 0, 0
  local crafts = 0
  while gained < points - 1e-9 and crafts < M.MAX_CRAFTS do
    local best = self:Rank(prof, have)[1]
    if not best or not best.perPoint then break end
    for id, n in pairs(best.recipe.reagents) do have[id] = math.max(0, (have[id] or 0) - n) end
    gained, total, crafts = gained + best.exp, total + best.cost, crafts + 1
    local s = byName[best.name]
    if not s then s = { name = best.name, color = best.color, crafts = 0, cost = 0 } byName[best.name] = s steps[#steps + 1] = s end
    s.crafts, s.cost = s.crafts + 1, s.cost + best.cost
  end
  return { steps = steps, points = gained, cost = total, short = gained < points - 1e-9 }
end

function M:Lines(prof, target)
  local p = (ns.db.char.professions or {})[prof]
  if not p then return { "no " .. tostring(prof) .. " data yet: open its window once" } end
  local lines = {}
  local skill = p.skill or 0
  target = target or math.min((p.max or skill + 10), skill + 10)
  lines[1] = string.format("%s %d/%s, cheapest per point (estimates):", prof, skill, tostring(p.max or "?"))
  local ranked = self:Rank(prof)
  for i = 1, math.min(5, #ranked) do
    local r = ranked[i]
    -- 0 means "nothing to buy": materials owned or not priced yet, never "0c"
    local cost = r.perPoint and r.perPoint >= 1 and (ns.Prices.Money(math.floor(r.perPoint + 0.5)) .. " per point")
      or r.perPoint and "nothing to buy (in your bags, or not priced yet)" or "price unknown"
    lines[#lines + 1] = string.format("  %s (%s): %s", r.name, r.color, cost)
  end
  if #ranked == 0 then lines[#lines + 1] = "  no recipe gives skill right now (or colors not scanned yet)" end
  if target > skill then
    local route = self:Route(prof, target - skill)
    local total = route.cost >= 1 and ("about " .. ns.Prices.Money(math.floor(route.cost + 0.5))) or "nothing to buy that's priced"
    lines[#lines + 1] = string.format("Route to %d (%s, colors change as you go):", target, total)
    for _, s in ipairs(route.steps) do
      lines[#lines + 1] = string.format("  %d x %s%s", s.crafts, s.name, s.cost >= 1 and (" (" .. ns.Prices.Money(math.floor(s.cost + 0.5)) .. ")") or "")
    end
    if route.short then lines[#lines + 1] = "  not enough priced recipes to get all the way: browse the AH for their materials" end
  end
  return lines
end

function M:Activity()
  local n = 0
  for prof in pairs(ns.db.char.professions or {}) do n = n + #self:Rank(prof) end
  return string.format("%d recipes that still give skill", n)
end

ns.AddCommand("skillup", "[profession] [target]  cheapest recipes per skill point", function(arg)
  local profs = {}
  for prof in pairs(ns.db.char.professions or {}) do profs[#profs + 1] = prof end
  table.sort(profs)
  local want, target = (arg or ""):match("^(%a*)%s*(%d*)$")
  target = tonumber(target)
  local any = false
  for _, prof in ipairs(profs) do
    if not want or want == "" or prof:lower():find(want:lower(), 1, true) then
      any = true
      for _, l in ipairs(M:Lines(prof, target)) do ns.Print(l) end
    end
  end
  if not any then ns.Print("no profession data yet: open a profession window once") end
end)
