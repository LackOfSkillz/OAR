-- Modules/TalentLab.lua
-- The Talents page (requirement 2026-11-23: looks like Blizzard's talent
-- window, plus suggestions for the best builds; reads the current build and
-- lets the player tune and test builds;
-- research and plan in docs/TALENT_BUILDS_RESEARCH_2026-11-23.md).
--   * The three trees come live from the client (Talents:Read, C_Traits on
--     Forever): names, ranks, rows, links. Builds are stored by talent name,
--     so a hotfix that moves a talent doesn't break them.
--   * Build cards per goal (levelling, max damage, max healing, tank,
--     dungeons, PvP) from cited guides, verified = false until seen in game.
--   * A sandbox: start from your build or a card, add and remove points with
--     the game's rules (5 points a row, links, points for the level), slide
--     the level, see the split and what to change from your build.
--   * Share codes with a checksum of the class's talents: a code made before
--     a talent changed is refused instead of loading a wrong build.
-- Advice only: points are spent in the game's own talent window, by Gary.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("TalentLab", {
  title = "Talent builds",
  phase = "P6",
  order = 85,
  defaults = { goal = nil, level = nil, saved = {} },
})
ns.TalentLab = M

M.FIRST = 10       -- the first talent point
M.MAX_LEVEL = 60
M.PER_TIER = 5     -- points in a tree before its next row opens
M.CODE = "OTB1"

M.GOALS = {
  { id = "leveling", label = "Levelling" },
  { id = "dps", label = "Max damage" },
  { id = "hps", label = "Max healing", healer = true },
  { id = "tank", label = "Tank", tank = true },
  { id = "dungeon", label = "Dungeons" },
  { id = "pvp", label = "PvP" },
}
M.HEALERS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
M.TANKS = { WARRIOR = true, PALADIN = true, DRUID = true, SHAMAN = true }
-- the trees' names when the client gives none (the order Blizzard's window uses)
M.TREES = {
  DRUID = { "Balance", "Feral Combat", "Restoration" }, HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
  MAGE = { "Arcane", "Fire", "Frost" }, PALADIN = { "Holy", "Protection", "Retribution" },
  PRIEST = { "Discipline", "Holy", "Shadow" }, ROGUE = { "Assassination", "Combat", "Subtlety" },
  SHAMAN = { "Elemental", "Enhancement", "Restoration" }, WARLOCK = { "Affliction", "Demonology", "Destruction" },
  WARRIOR = { "Arms", "Fury", "Protection" },
}

-- ------------------------------------------------------------ the model
-- Distinct values of one field, sorted, as { [value] = position }.
local function ranks(list, field)
  local seen, vals = {}, {}
  for _, e in ipairs(list) do
    local v = e[field]
    if v ~= nil and not seen[v] then seen[v] = true vals[#vals + 1] = v end
  end
  table.sort(vals)
  local out = {}
  for i, v in ipairs(vals) do out[v] = i end
  return out
end

-- djb2 over a string, as a short base-36 text
function M.Hash(text)
  local h = 5381
  for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
  local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
  repeat
    local d = h % 36
    out = digits:sub(d + 1, d + 1) .. out
    h = math.floor(h / 36)
  until h == 0
  return out
end

-- The trees as Outrider draws them, from Talents:Read():
-- { class, trees = { { name, talents = { t } } }, byNode, byName, checksum }
-- t = { node, name, tree, tier, column, max, icon, spell, req = { node, ... }, rank }
function M.Model(state, class)
  if type(state) ~= "table" or type(state.tabs) ~= "table" then return nil end
  class = class or (ns.PlayerClass and ns.PlayerClass())
  -- one tree holding the class's three trees as sub-trees: split them
  local groups = {}
  local tabs = state.tabs
  if #tabs == 1 then
    local bySub, order = {}, {}
    for _, e in ipairs(tabs[1].talents) do
      local k = e.sub or 0
      if not bySub[k] then bySub[k] = {} order[#order + 1] = k end
      table.insert(bySub[k], e)
    end
    if #order > 1 then
      table.sort(order)
      for _, k in ipairs(order) do
        local nm = k ~= 0 and C.Call("C_Traits.GetSubTreeInfo", state.config, k)
        groups[#groups + 1] = { name = type(nm) == "table" and C.Readable(nm.name) or nil, talents = bySub[k] }
      end
    end
  end
  -- one tree with the class's three trees side by side (Forever, 2026-11-23:
  -- 52 druid talents in tree 1089, a grid of 600 units): split where the
  -- columns jump, left to right
  if #groups == 0 and #tabs == 1 and tabs[1].talents[1] and tabs[1].talents[1].x then
    local xs, seen = {}, {}
    for _, e in ipairs(tabs[1].talents) do if e.x and not seen[e.x] then seen[e.x] = true xs[#xs + 1] = e.x end end
    table.sort(xs)
    local step
    for i = 2, #xs do local d = xs[i] - xs[i - 1] if d > 0 and (not step or d < step) then step = d end end
    if step then
      local cut, clusters = {}, 1
      for i = 2, #xs do if xs[i] - xs[i - 1] > step * 1.5 then clusters = clusters + 1 end cut[xs[i]] = clusters end
      cut[xs[1]] = 1
      if clusters > 1 then
        for k = 1, clusters do groups[k] = { talents = {} } end
        for _, e in ipairs(tabs[1].talents) do table.insert(groups[cut[e.x] or 1].talents, e) end
      end
    end
  end
  if #groups == 0 then
    for _, tab in ipairs(tabs) do
      local name = tab.name
      if type(name) == "string" and name:find("^tree %d") then name = nil end
      groups[#groups + 1] = { name = name, talents = tab.talents }
    end
  end
  local model = { class = class, trees = {}, byNode = {}, byName = {} }
  local names = M.TREES[class or ""] or {}
  local keys = {}
  -- rows and columns from the grid: the smallest step between positions, and
  -- the top row across all trees (a row with no talent still counts)
  local function grid(list, field)
    local vals, seen = {}, {}
    for _, grp in ipairs(list) do
      for _, e in ipairs(grp.talents) do local v = e[field] if v and not seen[v] then seen[v] = true vals[#vals + 1] = v end end
    end
    table.sort(vals)
    local step
    for i = 2, #vals do local d = vals[i] - vals[i - 1] if d > 0 and (not step or d < step) then step = d end end
    return vals[1], step
  end
  local minY, stepY = grid(groups, "y")
  for g, grp in ipairs(groups) do
    local tier, col = ranks(grp.talents, "y"), ranks(grp.talents, "x")
    if stepY then
      local minX, stepX = grid({ grp }, "x")
      tier, col = {}, {}
      for _, e in ipairs(grp.talents) do
        if e.y then tier[e.y] = math.floor((e.y - minY) / stepY + 0.5) + 1 end
        if e.x and stepX then col[e.x] = math.floor((e.x - minX) / stepX + 0.5) + 1 elseif e.x then col[e.x] = 1 end
      end
    end
    local tree = { name = grp.name or names[g] or ("Tree " .. g), talents = {} }
    for _, e in ipairs(grp.talents) do
      local key = e.node or (g * 1000 + (e.index or 0))
      local t = { node = key, name = e.name, tree = g, max = e.max or 1, icon = e.icon, spell = e.spell, entry = e.entry,
        tier = e.tier or tier[e.y] or 1, column = e.column or col[e.x] or 1, rank = e.rank or 0, req = {},
        opens = e.opens, classicReq = e.req }
      tree.talents[#tree.talents + 1] = t
      model.byNode[key] = t
      model.byName[t.name] = model.byName[t.name] or t
      keys[#keys + 1] = tostring(key) .. "=" .. tostring(t.name) .. "/" .. tostring(t.max)
    end
    table.sort(tree.talents, function(a, b) if a.tier ~= b.tier then return a.tier < b.tier end return a.column < b.column end)
    model.trees[g] = tree
  end
  -- links: the talent an arrow points to needs the one it starts from, maxed
  for _, t in pairs(model.byNode) do
    for _, target in ipairs(t.opens or {}) do
      local to = model.byNode[target]
      if to then to.req[#to.req + 1] = t.node end
    end
    if t.classicReq then
      for _, o in ipairs(model.trees[t.tree].talents) do
        if o.tier == t.classicReq.tier and o.column == t.classicReq.column then t.req[#t.req + 1] = o.node end
      end
    end
  end
  table.sort(keys)
  model.checksum = M.Hash(table.concat(keys, ";"))
  return model
end

-- This character's own points: { [node] = rank }
function M.Mine(model)
  local out = {}
  for node, t in pairs(model and model.byNode or {}) do if (t.rank or 0) > 0 then out[node] = t.rank end end
  return out
end

-- ------------------------------------------------------------ the rules
function M.Points(level)
  return math.max(0, math.min(tonumber(level) or M.MAX_LEVEL, M.MAX_LEVEL) - M.FIRST + 1)
end

function M.Total(r)
  local n = 0
  for _, v in pairs(r or {}) do n = n + v end
  return n
end

function M.TreeSpent(model, r, tree, belowTier)
  local n = 0
  for _, t in ipairs(model.trees[tree] and model.trees[tree].talents or {}) do
    if not belowTier or t.tier < belowTier then n = n + (r[t.node] or 0) end
  end
  return n
end

-- ok, or false and why, for a whole set of points at a level
function M.Check(model, r, level)
  if M.Total(r) > M.Points(level) then
    return false, string.format("only %d points at level %d", M.Points(level), tonumber(level) or M.MAX_LEVEL)
  end
  for node, n in pairs(r) do
    local t = model.byNode[node]
    if not t then return false, "a talent this class doesn't have" end
    if n > t.max then return false, t.name .. " has only " .. t.max .. " ranks" end
    if n > 0 then
      local need = (t.tier - 1) * M.PER_TIER
      if M.TreeSpent(model, r, t.tree, t.tier) < need then
        return false, string.format("%s needs %d points in %s above it", t.name, need, model.trees[t.tree].name)
      end
      for _, q in ipairs(t.req) do
        local p = model.byNode[q]
        if p and (r[q] or 0) < p.max then return false, string.format("%s needs %s maxed first", t.name, p.name) end
      end
    end
  end
  return true
end

local function copy(r) local o = {} for k, v in pairs(r or {}) do o[k] = v end return o end

function M.CanAdd(model, r, node, level)
  local t = model.byNode[node]
  if not t then return false, "unknown talent" end
  if (r[node] or 0) >= t.max then return false, t.name .. " is maxed" end
  local o = copy(r)
  o[node] = (o[node] or 0) + 1
  return M.Check(model, o, level)
end

function M.CanRemove(model, r, node, level)
  if (r[node] or 0) <= 0 then return false, "no point there" end
  local o = copy(r)
  o[node] = o[node] - 1
  if o[node] == 0 then o[node] = nil end
  local ok, why = M.Check(model, o, level)
  if not ok then return false, "other points depend on it (" .. why .. ")" end
  return true
end

function M.Add(model, r, node, level)
  local ok, why = M.CanAdd(model, r, node, level)
  if ok then r[node] = (r[node] or 0) + 1 end
  return ok, why
end

function M.Remove(model, r, node, level)
  local ok, why = M.CanRemove(model, r, node, level)
  if ok then r[node] = r[node] - 1 if r[node] == 0 then r[node] = nil end end
  return ok, why
end

-- "31/20/0"
function M.Split(model, r)
  local parts = {}
  for g = 1, #model.trees do parts[g] = tostring(M.TreeSpent(model, r, g)) end
  return table.concat(parts, "/")
end

-- ------------------------------------------------------------ builds
-- Cards: Data "talentcard" entries (goal, points by name, optional order) and
-- the levelling builds the advisor follows (Data/Talents.lua, with order).
function M.Cards(class)
  local out = {}
  for _, b in ipairs(ns.Data:All("talentcard")) do if b.class == class then out[#out + 1] = b end end
  local function same(p, q)
    for k, v in pairs(p) do if q[k] ~= v then return false end end
    for k, v in pairs(q) do if p[k] ~= v then return false end end
    return true
  end
  for _, b in ipairs(ns.Data:All("talentbuild")) do
    if b.class == class then
      local points = {}
      for _, step in ipairs(b.order or {}) do points[step[1]] = (points[step[1]] or 0) + (tonumber(step[2]) or 1) end
      -- the same build already as a card (same guide): keep one
      local dup
      for _, c in ipairs(out) do if type(c.points) == "table" and same(c.points, points) then dup = c end end
      if dup then
        dup.advisor = true
      else
      out[#out + 1] = { id = b.id, class = b.class, goal = "leveling", name = b.name, points = points,
        order = ns.Talents and ns.Talents.Expand(b) or nil, why = b.note, source = b.source, verified = b.verified,
        fromLevel = b.fromLevel, toLevel = b.toLevel, advisor = true }
      end
    end
  end
  table.sort(out, function(a, b) if (a.goal or "") ~= (b.goal or "") then return (a.goal or "") < (b.goal or "") end return a.id < b.id end)
  return out
end

-- The goals that apply to this class.
function M.Goals(class)
  local out = {}
  for _, g in ipairs(M.GOALS) do
    if not (g.healer and not M.HEALERS[class]) and not (g.tank and not M.TANKS[class]) then out[#out + 1] = g end
  end
  return out
end

-- The order to spend a card's points: its own, or tree by tree (the tree with
-- the most points first), row by row.
function M.Order(model, card)
  if card.order then return card.order end
  local list = {}
  for name, n in pairs(card.points or {}) do
    local t = model.byName[name]
    if t then list[#list + 1] = { t = t, n = n } end
  end
  local treeTotal = {}
  for _, x in ipairs(list) do treeTotal[x.t.tree] = (treeTotal[x.t.tree] or 0) + x.n end
  table.sort(list, function(a, b)
    local ta, tb = treeTotal[a.t.tree], treeTotal[b.t.tree]
    if ta ~= tb then return ta > tb end
    if a.t.tree ~= b.t.tree then return a.t.tree < b.t.tree end
    if a.t.tier ~= b.t.tier then return a.t.tier < b.t.tier end
    return a.t.column < b.t.column
  end)
  local out = {}
  for _, x in ipairs(list) do for _ = 1, x.n do out[#out + 1] = x.t.name end end
  return out
end

-- A card's points at a level: ranks, and the names this client lacks.
function M.RanksFor(model, card, level)
  local r, missing, seen = {}, {}, {}
  local budget = M.Points(level)
  for _, name in ipairs(M.Order(model, card)) do
    if M.Total(r) >= budget then break end
    local t = model.byName[name]
    if not t and ns.Talents and ns.Talents.Renamed then t = model.byName[ns.Talents.Renamed(name) or ""] end -- Forever renamed it
    if not t then
      if not seen[name] then seen[name] = true missing[#missing + 1] = name end
    else
      M.Add(model, r, t.node, level) -- a point the rules refuse yet is skipped
    end
  end
  for name in pairs(card.points or {}) do
    local to = ns.Talents and ns.Talents.Renamed and ns.Talents.Renamed(name)
    if not model.byName[name] and not (to and model.byName[to]) and not seen[name] then seen[name] = true missing[#missing + 1] = name end
  end
  table.sort(missing)
  return r, missing
end

-- What to change from one set of points to another: adds and removes by name.
function M.Diff(model, from, to, order)
  local adds, removes = {}, {}
  local seen = {}
  local function add(node)
    local t = model.byNode[node]
    local d = (to[node] or 0) - (from[node] or 0)
    if t and d > 0 and not seen[node] then seen[node] = true adds[#adds + 1] = { name = t.name, n = d, node = node } end
  end
  for _, name in ipairs(order or {}) do local t = model.byName[name] if t then add(t.node) end end
  for node in pairs(to) do add(node) end
  for node, n in pairs(from) do
    local d = n - (to[node] or 0)
    local t = model.byNode[node]
    if t and d > 0 then removes[#removes + 1] = { name = t.name, n = d, node = node } end
  end
  table.sort(removes, function(a, b) return a.name < b.name end)
  return adds, removes
end

-- Points that differ between two sets (to learn plus to take off).
function M.Changes(a, b)
  local n = 0
  for node, v in pairs(a) do n = n + math.abs(v - (b[node] or 0)) end
  for node, v in pairs(b) do if a[node] == nil then n = n + v end end
  return n
end

-- Points two sets share.
function M.Shared(a, b)
  local n = 0
  for node, v in pairs(a) do n = n + math.min(v, b[node] or 0) end
  return n
end

-- The card nearest to a set of points: card, points off (to change).
function M.Closest(model, r, cards, level)
  local best, bestOff
  local have = M.Total(r)
  if have == 0 then return nil end
  for _, card in ipairs(cards) do
    local target = M.RanksFor(model, card, level)
    local off = have - M.Shared(r, target)
    if not bestOff or off < bestOff then best, bestOff = card, off end
  end
  return best, bestOff
end

-- ------------------------------------------------------------ share codes
function M.Export(model, r)
  local parts = {}
  for node, n in pairs(r) do if n > 0 then parts[#parts + 1] = tostring(node) .. "." .. tostring(n) end end
  table.sort(parts)
  return string.format("%s:%s:%s:%s", M.CODE, tostring(model.class), model.checksum, table.concat(parts, ","))
end

-- ranks, or nil and why
function M.Import(model, text)
  if type(text) ~= "string" then return nil, "no code" end
  local tag, class, sum, body = text:match("^%s*(%w+):(%u+):(%w+):([%d%.,]*)%s*$")
  if tag ~= M.CODE then return nil, "that isn't an Outrider talent code" end
  if class ~= model.class then return nil, "that code is for a " .. class:lower() end
  if sum ~= model.checksum then return nil, "the talents changed since that code was made, so it could load the wrong build" end
  local r = {}
  for node, n in body:gmatch("(%d+)%.(%d+)") do r[tonumber(node)] = tonumber(n) end
  local ok, why = M.Check(model, r, M.MAX_LEVEL)
  if not ok then return nil, "that build breaks the rules: " .. why end
  return r
end

-- ------------------------------------------------------------ state
function M:Level() return tonumber(C.Call("UnitLevel", "player")) or 1 end

function M:Load()
  local T = ns.Talents
  local state = T and T.Read and T:Read()
  self.model = M.Model(state)
  return self.model
end

-- The sandbox: starts from your own points.
function M:Sandbox()
  local model = self.model or self:Load()
  if not model then return nil end
  if not self.sandbox or self.sandboxFor ~= model.checksum then
    self.sandbox, self.sandboxFor = M.Mine(model), model.checksum
  end
  return self.sandbox, model
end

function M:ViewLevel()
  -- this session only: the page opens at your own level
  return tonumber(self.viewLevel) or math.max(self:Level(), M.FIRST)
end

function M:Use(card)
  local model = self.model or self:Load()
  if not (model and card) then return false end
  self.sandbox = M.RanksFor(model, card, self:ViewLevel())
  self.sandboxFor = model.checksum
  self.card = card
  return true
end

-- ------------------------------------------------------------ module
function M:OnEnable()
  self:On("PLAYER_TALENT_UPDATE", function(mod) mod.model = nil end)
  self:On("TRAIT_CONFIG_UPDATED", function(mod) mod.model = nil end)
  self:On("PLAYER_LEVEL_UP", function(mod) mod.model = nil end)
end

function M:Activity()
  local model = self.model or self:Load()
  if not model then return "talent trees not readable yet" end
  return string.format("%s: %s", ns.PlayerClass():lower(), M.Split(model, M.Mine(model)))
end

ns.AddCommand("talentcode", "[code]  copy your talent build as a code, or load a code into the Talents page", function(arg)
  local model = M:Load()
  if not model then ns.Print("talent trees aren't readable yet") return end
  if not arg or arg == "" then
    ns.UI:TextDialog("Your talent build", M.Export(model, M:Sandbox() or M.Mine(model)), "copy")
    return
  end
  local r, why = M.Import(model, arg)
  if not r then ns.Print("talent code: %s", why) return end
  M.sandbox, M.sandboxFor, M.card = r, model.checksum, nil
  ns.Print("talent code loaded: %s (open /ride, Talents)", M.Split(model, r))
end)

-- ------------------------------------------------------------ the page
M.ICON, M.GAP_X, M.GAP_Y, M.TOP = 34, 12, 10, 26
M.TREE_W = 200

function M:Goal()
  local cls = ns.PlayerClass()
  local want = self:Settings().goal
  for _, g in ipairs(M.Goals(cls)) do if g.id == want then return want end end
  return self:Level() < M.MAX_LEVEL and "leveling" or (M.HEALERS[cls] and "hps" or "dps")
end

-- "wowhandbook.com" from a source line
function M.Host(source)
  local s = tostring(source or "")
  local h = s:match("^%a+://([^/]+)") or s:match("^([%w%.%-]+%.%a+)")
  return h and (h:gsub("^www%.", "")) or "a guide"
end

M.GOAL_ICON = { pvp = "Ability_DualWield", hps = "Spell_Holy_FlashHeal", tank = "Ability_Defend",
  leveling = "Spell_Holy_SurgeOfLight", dungeon = "INV_Misc_Key_03", dps = "Ability_Marksmanship" }

function M:RefreshPage() if self.page and self.page.Refresh then self.page:Refresh() end end

-- "To get there, learn: Ferocity 3, Feral Instinct 2. Take off (...): Thorns."
function M:DiffText()
  local r, model = self:Sandbox()
  if not model then return "" end
  local adds, removes = M.Diff(model, M.Mine(model), r, self.card and M.Order(model, self.card) or nil)
  if #adds == 0 and #removes == 0 then return "This is exactly your build." end
  local function list(t)
    local out = {}
    for i, x in ipairs(t) do
      if i > 12 then out[#out + 1] = "..." break end
      out[#out + 1] = x.name .. (x.n > 1 and (" " .. x.n) or "")
    end
    return table.concat(out, ", ")
  end
  local text = ""
  if #adds > 0 then text = "To get there, learn: " .. list(adds) .. "." end
  if #removes > 0 then
    text = text .. (text ~= "" and "  " or "") .. "Take off (a respec at a class trainer in a city): " .. list(removes) .. "."
  end
  return text
end


-- ------------------------------------------------------------ the studio (page)
-- One screen, three columns (requirement 2026-11-23: columns to cut down
-- scrolling, a showpiece UI/UX):
--   top    goal chips, level slider, points / split / change from yours
--   left   the builds for the goal, best for you first (Try, Follow)
--   middle the three trees like the game's window, with their links
--   right  what to change, what it gives, your stats, how it does, codes
-- Narrower windows put the right column under the trees, then stack.
M.UIL = { LEFT = 286, RIGHT = 300, GAP = 18, ICON = 36, CELL = 46, PAD = 10, HEAD = 34, TOP = 64 }

-- The builds for the goal with what the page shows: best for you first.
function M:CardList()
  local model = self.model or self:Load()
  local cls = ns.PlayerClass()
  local goal = self:Goal()
  local level = self:ViewLevel()
  local mine = model and M.Mine(model) or {}
  local list = {}
  if ns.TalentSim and model then
    for _, x in ipairs(ns.TalentSim:Rank(goal, level)) do list[#list + 1] = { card = x.card, est = x.est } end
  else
    for _, card in ipairs(M.Cards(cls)) do if card.goal == goal then list[#list + 1] = { card = card } end end
  end
  for i, e in ipairs(list) do
    local r, missing = {}, {}
    if model then r, missing = M.RanksFor(model, e.card, level) end
    e.split = model and M.Split(model, r) or (e.card.split or "")
    e.shared = M.Shared(mine, r)
    e.missing = #missing
    e.words = e.est and ns.TalentSim.Words(e.est, goal) or nil
    e.pick = i == 1 and #list > 1 and e.words ~= nil
    e.following = ns.Talents and ns.Talents:Settings().card == e.card.id or false
    e.selected = self.card and self.card.id == e.card.id or false
  end
  return list
end

-- Cards for a plain list (kept for other pages and the tests).
function M:CardItems()
  local out = {}
  local goal = self:Goal()
  for _, e in ipairs(self:CardList()) do
    local card = e.card
    local tags = { { e.split, "gold" }, { M.Host(card.source), "plain" } }
    if e.words then table.insert(tags, 1, { e.words, e.pick and "good" or "plain" }) end
    if e.pick then table.insert(tags, 1, { "Outrider's pick for you", "good" }) end
    if card.verified ~= true then tags[#tags + 1] = { "not checked in game yet", "plain" } end
    if e.missing > 0 then tags[#tags + 1] = { e.missing .. " talents not found", "bad" } end
    out[#out + 1] = { pic = "Interface\\Icons\\" .. (M.GOAL_ICON[goal] or "Ability_Marksmanship"), title = card.name, tags = tags,
      line = (card.why or "") .. (e.shared > 0 and string.format("  You share %d of its points.", e.shared) or "") }
  end
  return out
end

function M:Try(card)
  self:Use(card)
  self.msg = nil
  self:RefreshPage()
end

function M:Follow(card)
  local T = ns.Talents
  if not T then return end
  T:Settings().card = T:Settings().card ~= card.id and card.id or nil
  if T.Check then ns.Safe("talents:follow", T.Check, T) end
  self.msg = T:Settings().card and ("Following " .. card.name .. ": the game's talent window rings your next points.") or nil
  self:RefreshPage()
end

-- this page's text is a size bigger than the rest (owner request 2026-11-23:
-- slightly larger font)
M.BUMP = 2
local function bigger(t, size)
  local F = ns.Theme.font
  if t and t.SetFont then t:SetFont(F.path, (F[size or "normal"] or F.normal) + M.BUMP, "") end
  return t
end

local function text(parent, size, color, w)
  local t = bigger(ns.UI.Text(parent, size or "normal", color or "text"), size)
  t:SetJustifyH("LEFT")
  if t.SetJustifyV then t:SetJustifyV("TOP") end
  if w then t:SetWidth(w) end
  if t.SetWordWrap then t:SetWordWrap(true) end
  return t
end

local function height(t) local h = t.GetStringHeight and t:GetStringHeight() return type(h) == "number" and h or 14 end

-- ---------------------------------------------------------------- talent button
local function talentButton(parent)
  local U = M.UIL
  local b = CreateFrame("Button", nil, parent, ns.Theme:BackdropTemplate())
  b:SetSize(U.ICON, U.ICON)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.badge = CreateFrame("Frame", nil, b, ns.Theme:BackdropTemplate())
  b.badge:SetSize(32, 16)
  b.badge:SetPoint("BOTTOMRIGHT", 6, -5)
  ns.Theme:ApplyPanel(b.badge, "bg", "border")
  b.rank = bigger(ns.UI.Text(b.badge, "small", "text"), "small")
  b.rank:SetPoint("CENTER", 0, 0)
  b:SetScript("OnClick", function(self, button)
    local r, model = M:Sandbox()
    if not (r and self.t) then return end
    local ok, why
    if button == "RightButton" then ok, why = M.Remove(model, r, self.t.node, M:ViewLevel())
    else ok, why = M.Add(model, r, self.t.node, M:ViewLevel()) end
    M.msg = not ok and why or nil
    M:RefreshPage()
  end)
  b:SetScript("OnEnter", function(self)
    local t = self.t
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if t.spell and GameTooltip.SetSpellByID then pcall(GameTooltip.SetSpellByID, GameTooltip, t.spell)
    else GameTooltip:AddLine(t.name) end
    local r = M:Sandbox() or {}
    GameTooltip:AddLine(string.format("In this build: %d/%d    Yours now: %d/%d", r[t.node] or 0, t.max, t.rank or 0, t.max), 1, 0.82, 0.2)
    local ok, why = M.CanAdd(M.model, r, t.node, M:ViewLevel())
    if not ok and (r[t.node] or 0) < t.max then GameTooltip:AddLine("Can't add: " .. tostring(why), 1, 0.5, 0.5, true) end
    GameTooltip:AddLine("Click: add a point.  Right-click: take one off.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- ---------------------------------------------------------------- build tile
local function cardTile(parent)
  local U = M.UIL
  local c = CreateFrame("Button", nil, parent, ns.Theme:BackdropTemplate())
  c:SetSize(U.LEFT, 96)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(30, 30)
  c.icon:SetPoint("TOPLEFT", 8, -8)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  c.title = text(c, "normal", "accent", U.LEFT - 54)
  c.title:SetPoint("TOPLEFT", 46, -8)
  c.meta = text(c, "small", "text", U.LEFT - 54)
  c.meta:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
  c.src = text(c, "small", "body", U.LEFT - 54)
  c.src:SetPoint("TOPLEFT", c.meta, "BOTTOMLEFT", 0, -2)
  c.try = ns.UI:Button(c, "Try it", 74, function() if c.e then M:Try(c.e.card) end end)
  c.try:SetHeight(20)
  c.try:SetPoint("BOTTOMLEFT", 46, 7)
  ns.UI.SetPrimary(c.try, true)
  c.follow = ns.UI:Button(c, "Follow", 84, function() if c.e then M:Follow(c.e.card) end end)
  c.follow:SetHeight(20)
  c.follow:SetPoint("LEFT", c.try, "RIGHT", 6, 0)
  c:SetScript("OnClick", function() if c.e then M:Try(c.e.card) end end)
  c:SetScript("OnEnter", function(self)
    if not self.e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.e.card.name, 1, 0.82, 0.2)
    if self.e.card.why then GameTooltip:AddLine(self.e.card.why, 1, 1, 1, true) end
    GameTooltip:AddLine("From " .. tostring(self.e.card.source), 0.6, 0.6, 0.6, true)
    if self.e.shared > 0 then GameTooltip:AddLine(string.format("You already have %d of its points.", self.e.shared), 0.5, 0.9, 0.5) end
    if self.e.missing > 0 then GameTooltip:AddLine(self.e.missing .. " of its talents weren't found in your trees.", 1, 0.5, 0.5) end
    GameTooltip:AddLine("Click to try it in the trees.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function c:Fill(e, goal)
    self.e = e
    self.icon:SetTexture("Interface\\Icons\\" .. (M.GOAL_ICON[goal] or "Ability_Marksmanship"))
    self.title:SetText(e.card.name)
    local parts = {}
    if e.pick then parts[#parts + 1] = "|cff7fff7fOutrider's pick|r" end
    if e.words then parts[#parts + 1] = e.words end
    parts[#parts + 1] = "|cffffd100" .. e.split .. "|r"
    self.meta:SetText(table.concat(parts, "  ·  "))
    self.src:SetText(M.Host(e.card.source) .. (e.card.verified ~= true and "  ·  not checked in game" or "")
      .. (e.missing > 0 and ("  ·  |cffff7f7f" .. e.missing .. " not found|r") or ""))
    self.follow.label:SetText(e.following and "Following" or "Follow")
    ns.UI.SetPrimary(self.follow, e.following)
    ns.Theme:ApplyPanel(self, e.selected and "goldSoft" or "raised", e.selected and "gold" or (e.pick and "accent" or "border"))
    local h = 8 + height(self.title) + 3 + height(self.meta) + 2 + height(self.src) + 6 + 20 + 7
    self:SetHeight(math.max(84, h))
  end
  return c
end

-- ---------------------------------------------------------------- info block
local function block(parent, title, w)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 40)
  f.head = text(f, "small", "accent", w)
  f.head:SetPoint("TOPLEFT", 0, 0)
  f.head:SetText(title:upper())
  f.rule = f:CreateTexture(nil, "ARTWORK")
  f.rule:SetHeight(1)
  f.rule:SetPoint("TOPLEFT", 0, -15)
  f.rule:SetPoint("TOPRIGHT", 0, -15)
  f.rule:SetColorTexture(ns.Theme:Color("gold"))
  if f.rule.SetAlpha then f.rule:SetAlpha(0.35) end
  f.body = text(f, "normal", "body", w)
  f.body:SetPoint("TOPLEFT", 0, -21)
  function f:Set(body, width)
    self:SetWidth(width)
    self.head:SetWidth(width)
    self.body:SetWidth(width)
    self.body:SetText(body or "")
    local h = (body and body ~= "") and (21 + height(self.body) + 12) or 0
    self:SetHeight(math.max(1, h))
    self:SetShown(h > 0)
    return h
  end
  return f
end

-- ---------------------------------------------------------------- the studio
function M:Studio(host)
  local U = M.UIL
  local f = CreateFrame("Frame", nil, host)
  f:SetSize(1000, 600)
  f.h = 600
  M.studio = f

  -- top bar: goals, level, numbers
  f.top = CreateFrame("Frame", nil, f)
  f.top:SetHeight(U.TOP)
  f.top:SetPoint("TOPLEFT", 0, 0)
  f.top:SetPoint("TOPRIGHT", 0, 0)
  f.chips = {}
  f.level = ns.UI:Slider(f.top, "Level", M.FIRST, M.MAX_LEVEL, 1, function() return M:ViewLevel() end,
    function(v) M.viewLevel = v if M.card then M:Use(M.card) end M:RefreshPage() end, "%d")
  f.level:SetWidth(220)
  f.nums = text(f.top, "normal", "text")
  f.purpose = text(f.top, "small", "body")

  f.left = CreateFrame("Frame", nil, f)
  f.leftHead = text(f.left, "small", "accent")
  f.tiles = {}
  f.leftEmpty = text(f.left, "normal", "body", U.LEFT)

  f.mid = CreateFrame("Frame", nil, f)
  f.trees = {}
  f.midMsg = text(f.mid, "normal", "body")
  f.legend = text(f.mid, "small", "body")

  f.right = CreateFrame("Frame", nil, f)
  f.blocks = {
    msg = block(f.right, "Note", U.RIGHT),
    diff = block(f.right, "To get there from your build", U.RIGHT),
    gives = block(f.right, "What this build gives", U.RIGHT),
    stats = block(f.right, "Your stats with it", U.RIGHT),
    does = block(f.right, "How it does", U.RIGHT),
  }
  f.btns = {
    ns.UI:Button(f.right, "Start from my build", 146, function()
      local model = M:Load()
      if model then M.sandbox, M.sandboxFor, M.card, M.msg = M.Mine(model), model.checksum, nil, nil end
      M:RefreshPage()
    end),
    ns.UI:Button(f.right, "Clear points", 146, function() M.sandbox, M.card, M.msg = {}, nil, nil M:RefreshPage() end),
    ns.UI:Button(f.right, "Copy code", 146, function() ns.Slash:Run("talentcode") end),
    ns.UI:Button(f.right, "Load a code", 146, function()
      ns.UI:TextDialog("Paste a talent code", "", "paste", function(t) ns.Slash:Run("talentcode " .. tostring(t)) M:RefreshPage() end)
    end),
  }

  function f:LayoutHeight() return self.h or 600 end

  -- one tree panel
  local function treePanel(i)
    local t = f.trees[i]
    if t then return t end
    t = CreateFrame("Frame", nil, f.mid, ns.Theme:BackdropTemplate())
    ns.Theme:ApplyPanel(t, "bg", "border")
    t.name = text(t, "normal", "accent")
    t.name:SetPoint("TOPLEFT", U.PAD, -9)
    t.count = text(t, "normal", "gold")
    t.count:SetPoint("TOPRIGHT", -U.PAD, -9)
    if t.count.SetJustifyH then t.count:SetJustifyH("RIGHT") end
    t.buttons, t.lines = {}, {}
    f.trees[i] = t
    return t
  end

  function f:Draw()
    local W = math.floor(self:GetWidth() or 1000)
    if W < 300 then W = 1000 end
    local model = M.model or M:Load()
    local r = (M:Sandbox()) or {}
    local level = M:ViewLevel()
    local goal = M:Goal()
    local cls = ns.PlayerClass()

    -- ---- top
    local goals = M.Goals(cls)
    local x = 0
    for i, g in ipairs(goals) do
      local b = self.chips[i]
      if not b then
        b = ns.UI:Button(self.top, g.label, 104, nil)
        b:SetHeight(26)
        self.chips[i] = b
      end
      b.label:SetText(g.label)
      b:SetScript("OnClick", function() M:Settings().goal = g.id M.card = nil M:RefreshPage() end)
      ns.UI.SetPrimary(b, g.id == goal)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", self.top, "TOPLEFT", x, 0)
      b:Show()
      x = x + 108
    end
    for i = #goals + 1, #self.chips do self.chips[i]:Hide() end
    self.level:ClearAllPoints()
    self.level:SetPoint("TOPLEFT", self.top, "TOPLEFT", x + 14, 0)
    local mine = model and M.Mine(model) or {}
    if model then
      local off = M.Changes(mine, r)
      self.nums:SetText(string.format("Points |cffffd100%d / %d|r    Split |cffffd100%s|r    From yours |cffffd100%s|r",
        M.Total(r), M.Points(level), M.Split(model, r), off == 0 and "same" or (off .. " to change")))
    else
      self.nums:SetText("")
    end
    self.nums:ClearAllPoints()
    self.nums:SetPoint("TOPLEFT", self.top, "TOPLEFT", x + 14 + 240, -4)
    self.purpose:ClearAllPoints()
    self.purpose:SetPoint("TOPLEFT", self.top, "TOPLEFT", 0, -36)
    self.purpose:SetWidth(W)
    self.purpose:SetText("Pick a goal, then a build on the left: Try puts it in the trees, Follow makes the game's talent window ring your next points. Click a talent to add a point, right-click to take one off. You spend points yourself in the game's window.")

    -- ---- the three trees (middle)
    local maxCol, maxTier = 4, 7
    if model then
      for _, tr in ipairs(model.trees) do
        for _, t in ipairs(tr.talents) do
          if t.column > maxCol then maxCol = t.column end
          if t.tier > maxTier then maxTier = t.tier end
        end
      end
    end
    local treeW = maxCol * U.CELL + 2 * U.PAD - (U.CELL - U.ICON)
    local nTrees = model and #model.trees or 3
    local midW = nTrees * treeW + (nTrees - 1) * 10
    local treeH = U.HEAD + maxTier * U.CELL + U.PAD - (U.CELL - U.ICON) + 6
    for i, tp in ipairs(self.trees) do if not (model and model.trees[i]) then tp:Hide() end end
    if model then
      self.midMsg:Hide()
      for g, tree in ipairs(model.trees) do
        local tp = treePanel(g)
        tp:SetSize(treeW, treeH)
        tp:ClearAllPoints()
        tp:SetPoint("TOPLEFT", self.mid, "TOPLEFT", (g - 1) * (treeW + 10), 0)
        tp.name:SetText(tree.name)
        tp.count:SetText(tostring(M.TreeSpent(model, r, g)))
        tp:Show()
        local pos = {}
        for i, t in ipairs(tree.talents) do
          local b = tp.buttons[i] or talentButton(tp)
          tp.buttons[i] = b
          b.t = t
          local bx, by = U.PAD + (t.column - 1) * U.CELL, -(U.HEAD + (t.tier - 1) * U.CELL)
          pos[t.node] = { bx + U.ICON / 2, by - U.ICON / 2 }
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", tp, "TOPLEFT", bx, by)
          b.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
          local have, own = r[t.node] or 0, mine[t.node] or 0
          local canAdd = M.CanAdd(model, r, t.node, level)
          if b.icon.SetDesaturated then b.icon:SetDesaturated(have == 0 and not canAdd) end
          b.icon:SetAlpha((have > 0 or canAdd) and 1 or 0.4)
          -- green: as you have it; gold: to learn; red: a respec takes it off
          local color = (have == own) and (have > 0 and "|cff7fff7f" or "|cffa0a0a0") or (have > own and "|cffffd100" or "|cffff6060")
          b.rank:SetText(color .. have .. "/" .. t.max .. "|r")
          ns.Theme:ApplyPanel(b, "bg", have >= t.max and "gold" or (have > 0 and "accent" or (canAdd and "strong" or "border")))
          b:Show()
        end
        for i = #tree.talents + 1, #tp.buttons do tp.buttons[i]:Hide() end
        -- links between talents (the arrows in the game's window)
        local n = 0
        if tp.CreateLine then
          for _, t in ipairs(tree.talents) do
            for _, q in ipairs(t.req) do
              local a, b = pos[q], pos[t.node]
              local ln = a and b and (tp.lines[n + 1] or tp:CreateLine(nil, "BACKGROUND"))
              if ln and ln.SetStartPoint then
                n = n + 1
                tp.lines[n] = ln
                ln:SetThickness(3)
                ln:SetStartPoint("TOPLEFT", tp, a[1], a[2])
                ln:SetEndPoint("TOPLEFT", tp, b[1], b[2])
                local src = model.byNode[q]
                local lit = src and (r[q] or 0) >= src.max
                ln:SetColorTexture(lit and 1 or 0.45, lit and 0.82 or 0.45, lit and 0.2 or 0.45, lit and 0.9 or 0.6)
                ln:Show()
              end
            end
          end
        end
        for i = n + 1, #tp.lines do tp.lines[i]:Hide() end
      end
      self.legend:SetText("|cff7fff7f3/5|r as you have it   |cffffd1003/5|r to learn   |cffff60603/5|r a respec takes it off")
      self.legend:ClearAllPoints()
      self.legend:SetPoint("TOPLEFT", self.mid, "TOPLEFT", 0, -(treeH + 6))
      self.legend:Show()
    else
      self.legend:Hide()
      self.midMsg:SetWidth(midW)
      self.midMsg:SetText("Your talent trees aren't readable yet: log in, or open the game's talent window once.")
      self.midMsg:ClearAllPoints()
      self.midMsg:SetPoint("TOPLEFT", self.mid, "TOPLEFT", 0, 0)
      self.midMsg:Show()
    end
    local midH = treeH + 26

    -- ---- builds (left)
    local list = M:CardList()
    local goalLabel = goal
    for _, g in ipairs(goals) do if g.id == goal then goalLabel = g.label end end
    self.leftHead:SetText(("Builds: " .. goalLabel):upper())
    self.leftHead:ClearAllPoints()
    self.leftHead:SetPoint("TOPLEFT", self.left, "TOPLEFT", 0, 0)
    local ly = 20
    for i, e in ipairs(list) do
      local c = self.tiles[i] or cardTile(self.left)
      self.tiles[i] = c
      c:Fill(e, goal)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", self.left, "TOPLEFT", 0, -ly)
      c:Show()
      ly = ly + c:GetHeight() + 8
    end
    for i = #list + 1, #self.tiles do self.tiles[i]:Hide() end
    if #list == 0 then
      self.leftEmpty:SetText("No build for this goal yet for your class. Try your own points in the trees.")
      self.leftEmpty:ClearAllPoints()
      self.leftEmpty:SetPoint("TOPLEFT", self.left, "TOPLEFT", 0, -ly)
      self.leftEmpty:Show()
      ly = ly + height(self.leftEmpty) + 8
    else
      self.leftEmpty:Hide()
    end
    local leftH = ly

    -- ---- info (right)
    local S, Sim = ns.TalentStats, ns.TalentSim
    local stats = ""
    if S and model then
      local lines = {}
      for _, s in ipairs(S.Now(model, r)) do
        local d = s.with - s.now
        lines[#lines + 1] = string.format("%s  %s%s", s.label, tostring(s.with),
          d ~= 0 and string.format("  |cff%s(%s%s)|r", d > 0 and "7fff7f" or "ff7f7f", d > 0 and "+" or "", tostring(d)) or "")
      end
      stats = table.concat(lines, "\n")
    end
    local function place(w)
      local ry = 0
      local function put(key, body)
        local b = self.blocks[key]
        local h = b:Set(body, w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.right, "TOPLEFT", 0, -ry)
        ry = ry + h
      end
      put("msg", M.msg and ("|cffff9f7f" .. M.msg .. "|r") or nil)
      put("diff", model and M:DiffText() or nil)
      put("gives", S and S:Report() or nil)
      put("stats", stats)
      put("does", Sim and Sim:Report() or nil)
      local bw = math.floor((w - 8) / 2)
      for i, b in ipairs(self.btns) do
        b:SetWidth(bw)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.right, "TOPLEFT", ((i - 1) % 2) * (bw + 8), -(ry + math.floor((i - 1) / 2) * 30))
      end
      return ry + 60
    end

    -- ---- arrange the columns for the width there is
    local top = U.TOP
    local rightW = U.RIGHT
    self.left:ClearAllPoints()
    self.mid:ClearAllPoints()
    self.right:ClearAllPoints()
    local total
    if W >= U.LEFT + U.GAP + midW + U.GAP + U.RIGHT then
      -- three columns; the right one takes what's left
      rightW = W - U.LEFT - midW - 2 * U.GAP
      self.left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
      self.mid:SetPoint("TOPLEFT", self, "TOPLEFT", U.LEFT + U.GAP, -top)
      self.right:SetPoint("TOPLEFT", self, "TOPLEFT", U.LEFT + U.GAP + midW + U.GAP, -top)
      local rightH = place(rightW)
      total = top + math.max(leftH, midH, rightH)
    elseif W >= U.LEFT + U.GAP + midW then
      -- builds beside the trees, the rest under the trees
      self.left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
      self.mid:SetPoint("TOPLEFT", self, "TOPLEFT", U.LEFT + U.GAP, -top)
      rightW = W - U.LEFT - U.GAP
      self.right:SetPoint("TOPLEFT", self, "TOPLEFT", U.LEFT + U.GAP, -(top + midH + 8))
      local rightH = place(rightW)
      total = top + math.max(leftH, midH + 8 + rightH)
    else
      -- stacked: builds, trees, the rest
      self.left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
      self.mid:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(top + leftH + 8))
      rightW = math.max(U.RIGHT, math.min(W, midW))
      self.right:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(top + leftH + 8 + midH + 8))
      local rightH = place(rightW)
      total = top + leftH + 8 + midH + 8 + rightH
    end
    self.left:SetSize(U.LEFT, leftH)
    self.mid:SetSize(midW, midH)
    self.right:SetSize(rightW, 10)
    self.h = math.ceil(total + 10)
    self:SetHeight(self.h)
  end

  function f:Refresh() self:Draw() end
  f:SetScript("OnSizeChanged", function(self, w)
    if math.abs((self.lastW or 0) - (w or 0)) >= 2 then
      self.lastW = w
      ns.Safe("talentlab:draw", self.Draw, self)
      if M.page and M.page.form and M.page.form.Layout then M.page.form:Layout() end
    end
  end)
  f:Draw()
  return f
end

ns.Hub:AddTab("talentlab", "Talents", function(p)
  M.page = p
  ns.UI:FormPage(p, {
    { "custom", function(host) return M:Studio(host) end, 600, stretch = true },
  })
end)
