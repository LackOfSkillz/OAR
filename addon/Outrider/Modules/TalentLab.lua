-- Modules/TalentLab.lua
-- The Talents page (Gary, 2026-11-23: "a page that looks like [Blizzard's
-- talent window] but you have suggestions for the best builds ... let them
-- tune their build ... read their current build ... let them test builds";
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
  for g, grp in ipairs(groups) do
    local tier, col = ranks(grp.talents, "y"), ranks(grp.talents, "x")
    local tree = { name = grp.name or names[g] or ("Tree " .. g), talents = {} }
    for _, e in ipairs(grp.talents) do
      local key = e.node or (g * 1000 + (e.index or 0))
      local t = { node = key, name = e.name, tree = g, max = e.max or 1, icon = e.icon, spell = e.spell,
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
    if not t then
      if not seen[name] then seen[name] = true missing[#missing + 1] = name end
    else
      M.Add(model, r, t.node, level) -- a point the rules refuse yet is skipped
    end
  end
  for name in pairs(card.points or {}) do
    if not model.byName[name] and not seen[name] then seen[name] = true missing[#missing + 1] = name end
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
  local s = self:Settings()
  return tonumber(s.level) or math.max(self:Level(), M.FIRST)
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

-- Build cards for the chosen goal, for the page.
function M:CardItems()
  local model = self.model or self:Load()
  local cls = ns.PlayerClass()
  local goal = self:Goal()
  local level = self:ViewLevel()
  local mine = model and M.Mine(model) or {}
  local out = {}
  for _, card in ipairs(M.Cards(cls)) do
    if card.goal == goal then
      local r, missing = {}, {}
      if model then r, missing = M.RanksFor(model, card, level) end
      local shared = M.Shared(mine, r)
      local tags = { { model and M.Split(model, r) or (card.split or ""), "gold" }, { M.Host(card.source), "plain" } }
      if card.verified ~= true then tags[#tags + 1] = { "not checked in game yet", "plain" } end
      if #missing > 0 then tags[#tags + 1] = { #missing .. " talents not found", "bad" } end
      out[#out + 1] = { pic = "Interface\\Icons\\" .. (M.GOAL_ICON[goal] or "Ability_Marksmanship"),
        title = card.name, tags = tags,
        line = (card.why or "") .. (M.Total(mine) > 0 and string.format("  You share %d of its points.", shared) or ""),
        actions = { { "Try it", function()
          M:Use(card)
          M.msg = "Loaded " .. card.name .. ". Change any point below."
          M:RefreshPage()
        end, "Puts this build in the trees below so you can see it and change it." } } }
    end
  end
  return out
end

function M:RefreshPage() if self.page and self.page.Refresh then self.page:Refresh() end end

-- One talent button.
local function talentButton(parent)
  local b = CreateFrame("Button", nil, parent, ns.Theme:BackdropTemplate())
  b:SetSize(M.ICON, M.ICON)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.rank = ns.UI.Text(b, "small", "text")
  b.rank:SetPoint("BOTTOMRIGHT", 4, -4)
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
    GameTooltip:AddLine(string.format("In this build: %d/%d   Yours now: %d/%d", r[t.node] or 0, t.max, t.rank or 0, t.max), 1, 0.82, 0.2)
    GameTooltip:AddLine("Click: add a point. Right-click: take one off.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- The three trees, side by side.
function M:TreeView(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetSize(600, M.TOP + 7 * (M.ICON + M.GAP_Y) + 6)
  f.buttons, f.titles = {}, {}
  function f:Refresh()
    for _, b in ipairs(self.buttons) do b:Hide() b.t = nil end
    for _, t in pairs(self.titles) do t:Hide() end
    local r, model = M:Sandbox()
    if not model then
      self.titles.none = self.titles.none or ns.UI.Text(self, "normal", "body")
      self.titles.none:SetPoint("TOPLEFT", 0, 0)
      self.titles.none:SetText("Your talent trees aren't readable yet: log in, or open the game's talent window once.")
      self.titles.none:Show()
      return
    end
    local n, mine, level = 0, M.Mine(model), M:ViewLevel()
    for g, tree in ipairs(model.trees) do
      local x0 = (g - 1) * M.TREE_W
      local title = self.titles[g] or ns.UI.Text(self, "normal", "accent")
      self.titles[g] = title
      title:ClearAllPoints()
      title:SetPoint("TOPLEFT", x0, 0)
      title:SetText(string.format("%s  %d", tree.name, M.TreeSpent(model, r, g)))
      title:Show()
      for _, t in ipairs(tree.talents) do
        n = n + 1
        local b = self.buttons[n] or talentButton(self)
        self.buttons[n] = b
        b.t = t
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x0 + (math.min(t.column, 4) - 1) * (M.ICON + M.GAP_X), -M.TOP - (math.min(t.tier, 7) - 1) * (M.ICON + M.GAP_Y))
        b.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local have, own = r[t.node] or 0, mine[t.node] or 0
        local canAdd = M.CanAdd(model, r, t.node, level)
        if b.icon.SetDesaturated then b.icon:SetDesaturated(have == 0 and not canAdd) end
        b.icon:SetAlpha((have > 0 or canAdd) and 1 or 0.45)
        -- green: as you have it; gold: more than you have (to learn); red: less (a respec)
        local color = have == own and "|cff7fff7f" or (have > own and "|cffffd100" or "|cffff6060")
        local txt = have .. "/" .. t.max
        if have > 0 or own > 0 then txt = color .. txt .. "|r" end
        b.rank:SetText(txt)
        ns.Theme:ApplyPanel(b, "bg", have >= t.max and "gold" or (have > 0 and "strong" or "border"))
        b:Show()
      end
    end
  end
  f:Refresh()
  return f
end

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

ns.Hub:AddTab("talentlab", "Talents", function(p)
  local UI = ns.UI
  M.page = p
  local goals = M.Goals(ns.PlayerClass())
  local goalButtons = {}
  for i, g in ipairs(goals) do
    goalButtons[i] = { g.label, function() M:Settings().goal = g.id p:Refresh() end, 100 }
  end
  UI:FormPage(p, {
    { "header", "Talent builds", icon = "Ability_Marksmanship" },
    { "note", "Pick what you want to be good at and see the best builds for it. Try one, change any point, slide the level to see it as you grow. You still spend your points yourself in the game's talent window." },
    { "buttons", goalButtons, active = function(i) return goals[i] ~= nil and goals[i].id == M:Goal() end },
    { "cards", function() return M:CardItems() end },
    { "note", function()
      return #M:CardItems() == 0 and "No build for this goal yet for your class. Try your own points below." or ""
    end },
    { "header", "Try a build", icon = "INV_Misc_Book_09" },
    { "stats", function()
      local r, model = M:Sandbox()
      if not model then return { { cap = "Talents", value = "not readable yet" } } end
      local level = M:ViewLevel()
      local mine = M.Mine(model)
      local off = M.Total(mine) - M.Shared(mine, r)
      return {
        { cap = "Points", value = string.format("%d / %d", M.Total(r), M.Points(level)), color = "gold", note = "at level " .. level },
        { cap = "Split", value = M.Split(model, r) },
        { cap = "From your build", value = off == 0 and "same" or (off .. " to change"), note = "yours: " .. M.Split(model, mine) },
      }
    end },
    { "slider", "Level", M.FIRST, M.MAX_LEVEL, 1, function() return M:ViewLevel() end,
      function(v) M:Settings().level = v if M.card then M:Use(M.card) end p:Refresh() end, "%d" },
    { "custom", function(host) return M:TreeView(host) end, M.TOP + 7 * (M.ICON + M.GAP_Y) + 10 },
    { "note", function() return (M.msg and ("|cffff7f7f" .. M.msg .. "|r\n") or "") .. M:DiffText() end, 40 },
    { "buttons", {
      { "Start from my build", function()
        local model = M:Load()
        if model then M.sandbox, M.sandboxFor, M.card, M.msg = M.Mine(model), model.checksum, nil, nil end
        p:Refresh()
      end, 150 },
      { "Clear points", function() M.sandbox, M.card, M.msg = {}, nil, nil p:Refresh() end, 110 },
      { "Copy code", function() ns.Slash:Run("talentcode") end, 100 },
      { "Load a code", function()
        UI:TextDialog("Paste a talent code", "", "paste", function(text) ns.Slash:Run("talentcode " .. tostring(text)) p:Refresh() end)
      end, 110 },
    }, plain = true },
  })
end)
