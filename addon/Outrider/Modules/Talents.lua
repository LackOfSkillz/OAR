-- Modules/Talents.lua
-- Talent advisor (Gary, 2026-11-16: "build a talent tree recommendation into
-- outrider ... make it the best available").
--   * Reads this character's talent trees from the client (names, ranks,
--     tiers, prerequisites) at login and whenever points change, and logs
--     the tree once so names can be checked against the build data.
--   * Follows a levelling build from Data/Talents.lua (one talent per point,
--     from a cited guide, verified = false until seen in game). The plan
--     picks up from whatever is spent: points already where the build puts
--     them count, points spent elsewhere are reported "off plan", and a step
--     whose row is still locked waits.
--   * Next points: on the Blizzard talent window each recommended talent
--     gets a gold ring and its order number (our own frames on top, nothing
--     of Blizzard's is changed); the talent tooltip says where it sits in the
--     plan; one chat line when a new point is ready; the class page lists the
--     plan with what's done.
-- Advice only: spending a point stays Gary's click in Blizzard's window.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Talents", {
  title = "Talent advisor",
  phase = "P6",
  order = 84,
  defaults = { build = nil, notify = true, highlight = true, toldLevel = 0 },
})
ns.Talents = M

M.FIRST_LEVEL = 10 -- the first talent point
M.PER_TIER = 5     -- points in a tree before its next row opens
M.SHOW = 3         -- how many next points to ring

-- ------------------------------------------------------------ reading the client
-- GetTalentTabInfo returns name first on Classic, id first on later clients.
local function tabInfo(t)
  local a, b, _, _, e = C.Call("GetTalentTabInfo", t)
  if type(a) == "number" and type(b) == "string" then return b, e end
  return a
end

-- Every return value (C.Call keeps five; GetTalentInfo's max rank is the sixth).
local function callAll(path, ...)
  local fn = C.Resolve(path)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if r[1] then return unpack(r, 2, table.maxn(r)) end
end

-- state = { api, tabs = { { name, spent, talents = { { name, tab, index, tier, column, rank, max, req, node } } } },
--   byName = { [name] = talent }, spent, unspent, level }
function M:Read()
  local state = self:ReadTraits() or self:ReadClassic()
  if not state then return nil end
  local level = tonumber(C.Call("UnitLevel", "player")) or 1
  if not state.unspent then
    local free = tonumber(C.Readable(C.Call("UnitCharacterPoints", "player")))
    if not free then free = tonumber(C.Readable(C.Call("GetUnspentTalentPoints"))) end
    if not free then free = math.max(0, level - M.FIRST_LEVEL + 1 - state.spent) end
    state.unspent = free
  end
  state.level = level
  return state
end

-- Modern clients: the active talent config's nodes. Each node's talent name
-- is its spell's name; nodes are grouped by tree (one tab per tree ID). Rows
-- and prerequisites are not known here, so whether a point can go in comes
-- from the client (canPurchaseRank / isAvailable) for the node itself.
function M:ReadTraits()
  local config = C.Call("C_ClassTalents.GetActiveConfigID")
  if type(config) ~= "number" then return nil end
  local cinfo = C.Call("C_Traits.GetConfigInfo", config)
  local trees = type(cinfo) == "table" and cinfo.treeIDs
  if type(trees) ~= "table" or #trees == 0 then return nil end
  local state = { api = "traits", config = config, tabs = {}, byName = {}, spent = 0 }
  local unspent
  for t, treeID in ipairs(trees) do
    local tab = { name = "tree " .. tostring(treeID), treeID = treeID, spent = 0, talents = {} }
    local cur = C.Call("C_Traits.GetTreeCurrencyInfo", config, treeID, false)
    if type(cur) == "table" and type(cur[1]) == "table" then
      local q = tonumber(C.Readable(cur[1].quantity))
      if q then unspent = (unspent or 0) + q end
    end
    for i, nodeID in ipairs(C.Call("C_Traits.GetTreeNodes", treeID) or {}) do
      local node = C.Call("C_Traits.GetNodeInfo", config, nodeID)
      if type(node) == "table" and (node.isVisible ~= false) then
        local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
        local entry = entryID and C.Call("C_Traits.GetEntryInfo", config, entryID)
        local def = type(entry) == "table" and entry.definitionID and C.Call("C_Traits.GetDefinitionInfo", entry.definitionID)
        local spell = type(def) == "table" and (def.overriddenSpellID or def.spellID)
        local name = type(def) == "table" and C.Readable(def.overrideName)
        if (type(name) ~= "string" or name == "") and spell then name = C.SpellName(spell) end
        if type(name) == "string" and name ~= "" then
          local e = { name = name, tab = t, index = i, node = nodeID, tier = nil, column = nil,
            rank = tonumber(C.Readable(node.currentRank)) or 0, max = tonumber(node.maxRanks) or 1,
            open = node.canPurchaseRank == true or (node.isAvailable == true and node.meetsEdgeRequirements ~= false),
            x = node.posX, y = node.posY }
          tab.talents[#tab.talents + 1] = e
          tab.spent = tab.spent + e.rank
          state.byName[name] = e
        end
      end
    end
    state.spent = state.spent + tab.spent
    state.tabs[t] = tab
  end
  if next(state.byName) == nil then return nil end
  state.unspent = unspent
  return state
end

function M:ReadClassic()
  local n = tonumber(C.Call("GetNumTalentTabs")) or 0
  if n == 0 then return nil end
  local state = { api = "classic", tabs = {}, byName = {}, spent = 0 }
  for t = 1, n do
    local tab = { name = tabInfo(t), spent = 0, talents = {} }
    for i = 1, tonumber(C.Call("GetNumTalents", t)) or 0 do
      local name, _, tier, column, rank, max = callAll("GetTalentInfo", t, i)
      name = C.Readable(name)
      if type(name) == "string" then
        local rt, rc = C.Call("GetTalentPrereqs", t, i)
        local e = { name = name, tab = t, index = i, tier = tonumber(tier) or 1, column = tonumber(column) or 1,
          rank = tonumber(C.Readable(rank)) or 0, max = tonumber(max) or 1,
          req = (type(rt) == "number" and type(rc) == "number") and { tier = rt, column = rc } or nil }
        tab.talents[#tab.talents + 1] = e
        tab.spent = tab.spent + e.rank
        state.byName[name] = e
      end
    end
    state.spent = state.spent + tab.spent
    state.tabs[t] = tab
  end
  return state
end

-- ------------------------------------------------------------ builds
-- Data/Talents.lua: { id, class, name, source, verified, order = { { "Talent", points }, ... } }
function M.Builds(class)
  local out = {}
  for _, b in ipairs(ns.Data:All("talentbuild")) do if b.class == class then out[#out + 1] = b end end
  table.sort(out, function(a, b) return (a.rank or 9) < (b.rank or 9) or ((a.rank or 9) == (b.rank or 9) and a.id < b.id) end)
  return out
end

local function fits(b, level) return (b.fromLevel or 0) <= level and level <= (b.toLevel or 999) end

-- The chosen build, else the first one for this level (the mage's Arcane
-- build ends at 39 and its Frost build starts at 40).
function M:Build()
  local cls = ns.PlayerClass and ns.PlayerClass()
  local builds = M.Builds(cls)
  local level = tonumber(C.Call("UnitLevel", "player")) or 1
  local want = self:Settings().build
  for _, b in ipairs(builds) do if b.id == want and fits(b, level) then return b end end
  for _, b in ipairs(builds) do if fits(b, level) then return b end end
  return builds[1]
end

-- The build that comes after this one, when it ends at a respec.
function M.After(build)
  if not (build and build.toLevel) then return nil end
  for _, b in ipairs(M.Builds(build.class)) do if b.fromLevel == build.toLevel + 1 then return b end end
end

-- One talent name per point, in order.
function M.Expand(build)
  local out = {}
  for _, step in ipairs(build and build.order or {}) do
    for _ = 1, tonumber(step[2]) or 1 do out[#out + 1] = step[1] end
  end
  return out
end

-- ------------------------------------------------------------ the plan
local function reqMet(state, e, ranks)
  if not e.req then return true end
  for _, o in ipairs(state.tabs[e.tab].talents) do
    if o.tier == e.req.tier and o.column == e.req.column then return (ranks[o.name] or 0) >= o.max end
  end
  return true
end

-- Walks the build against what is spent. Returns
--   { steps = { { point, level, name, rank, max, done, next, locked, missing, tab, index } },
--     next = { step, ... } (learnable now, up to the unspent points), offPlan = { {name, extra} },
--     missing = { name, ... } (build names the client doesn't have) }
function M:Plan(state, build)
  local plan = { steps = {}, next = {}, offPlan = {}, missing = {} }
  if not (state and build) then return plan end
  local ranks, tabSpent = {}, {}
  for name, e in pairs(state.byName) do ranks[name] = e.rank end
  for t, tab in ipairs(state.tabs) do tabSpent[t] = tab.spent end
  local planned, budget, blocked, seenMissing = {}, state.unspent or 0, false, {}
  for p, name in ipairs(M.Expand(build)) do
    planned[name] = (planned[name] or 0) + 1
    local e = state.byName[name]
    local step = { point = p, level = M.FIRST_LEVEL + p - 1, name = name, rank = planned[name] }
    if not e then
      step.missing = true
      if not seenMissing[name] then seenMissing[name] = true plan.missing[#plan.missing + 1] = name end
    else
      step.max, step.tab, step.index = e.max, e.tab, e.index
      if (e.rank or 0) >= planned[name] then
        step.done = true
      elseif not blocked and budget > 0 then
        local tierOK
        if e.tier then tierOK = (tabSpent[e.tab] or 0) >= (e.tier - 1) * M.PER_TIER
        else tierOK = e.open or (e.rank or 0) > 0 or #plan.next > 0 end
        if tierOK and reqMet(state, e, ranks) and (ranks[name] or 0) < e.max then
          step.next = #plan.next + 1
          plan.next[#plan.next + 1] = step
          ranks[name] = (ranks[name] or 0) + 1
          tabSpent[e.tab] = (tabSpent[e.tab] or 0) + 1
          budget = budget - 1
        else
          step.locked = true
          blocked = true -- the order matters: later steps wait for this one
        end
      end
    end
    plan.steps[#plan.steps + 1] = step
  end
  for name, e in pairs(state.byName) do
    local extra = (e.rank or 0) - (planned[name] or 0)
    if extra > 0 then plan.offPlan[#plan.offPlan + 1] = { name = name, extra = extra } end
  end
  table.sort(plan.offPlan, function(a, b) return a.name < b.name end)
  return plan
end

function M:Current()
  local state = self:Read()
  local build = self:Build()
  return self:Plan(state, build), state, build
end

-- "Endurance Training (3/5)"
function M.StepText(s)
  return string.format("%s (%d/%s)", s.name, s.rank, s.max and tostring(s.max) or "?")
end

-- One line for chat, the hub and the snapshot.
function M:Summary()
  local plan, state, build = self:Current()
  if not state then return "talents not readable on this client" end
  if not build then return "no talent build for your class yet" end
  local parts = {}
  for _, s in ipairs(plan.next) do parts[#parts + 1] = M.StepText(s) end
  local out
  if #parts > 0 then
    out = string.format("%d talent point%s: %s", state.unspent, state.unspent == 1 and "" or "s", table.concat(parts, ", "))
  elseif (state.unspent or 0) > 0 then
    local locked
    for _, s in ipairs(plan.steps) do if s.locked then locked = s break end end
    out = string.format("%d talent point%s; the plan's next is %s", state.unspent, state.unspent == 1 and "" or "s",
      locked and (M.StepText(locked) .. ", not open yet") or "done")
  else
    out = "no talent points to spend"
  end
  if build.respec and (state.level or 0) >= (build.toLevel or 999) then out = out .. ". " .. build.respec end
  if build.fromLevel and #plan.offPlan > 0 then
    for _, prev in ipairs(M.Builds(build.class)) do
      if prev.toLevel == build.fromLevel - 1 and prev.respec then return prev.respec .. " (" .. out .. ")" end
    end
  end
  if #plan.offPlan > 0 then
    local o = {}
    for _, x in ipairs(plan.offPlan) do o[#o + 1] = x.name .. " +" .. x.extra end
    out = out .. ". Off plan: " .. table.concat(o, ", ")
  end
  return out
end

-- ------------------------------------------------------------ the talent window
-- Blizzard's buttons are PlayerTalentFrameTalent<n>, GetID() = talent index on
-- the shown tab. We put our own ring on top; if the names differ on Forever
-- the log says so and only the hub list and tooltip show the plan.
M.BUTTON = "PlayerTalentFrameTalent"
M.MAX_BUTTONS = 40

function M.ShownTab()
  local f = rawget(_G, "PlayerTalentFrame")
  local get = rawget(_G, "PanelTemplates_GetSelectedTab")
  local t = (f and type(get) == "function" and select(2, pcall(get, f))) or (f and (f.selectedTab or f.currentSelectedTab))
  return tonumber(t) or 1
end

function M:Rings()
  self.rings = self.rings or {}
  for _, r in ipairs(self.rings) do r:Hide() end
  if not self:Settings().highlight then return 0 end
  local plan = self:Current()
  local tab = M.ShownTab()
  local want = {}
  for i, s in ipairs(plan.next) do
    if i <= M.SHOW and s.tab == tab then want[s.index] = want[s.index] or i end
  end
  local used = 0
  for n = 1, M.MAX_BUTTONS do
    local b = rawget(_G, M.BUTTON .. n)
    if not b then break end
    local id = b.GetID and b:GetID() or n
    local order = want[id]
    if order and (not b.IsShown or b:IsShown()) then
      used = used + 1
      local r = self.rings[used]
      if not r then
        r = CreateFrame("Frame", nil, b:GetParent() or UIParent)
        r.glow = r:CreateTexture(nil, "OVERLAY")
        r.glow:SetAllPoints()
        r.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        r.glow:SetBlendMode("ADD")
        r.glow:SetVertexColor(1, 0.82, 0.2)
        r.num = r:CreateFontString(nil, "OVERLAY")
        if r.num.SetFontObject then r.num:SetFontObject("GameFontNormalLarge") end
        r.num:SetPoint("TOPLEFT", -2, 2)
        self.rings[used] = r
      end
      r:ClearAllPoints()
      r:SetPoint("CENTER", b, "CENTER", 0, 0)
      local w, h = b:GetSize()
      r:SetSize((w or 37) * 1.8, (h or 37) * 1.8)
      r:SetFrameLevel((b.GetFrameLevel and b:GetFrameLevel() or 1) + 5)
      r.num:SetText(tostring(order))
      r:Show()
    end
  end
  return used
end

-- The Classic window (PlayerTalentFrame) or a modern one (PlayerSpellsFrame,
-- ClassTalentFrame): whichever this client has gets an OnShow hook.
M.WINDOWS = { "PlayerTalentFrame", "PlayerSpellsFrame", "ClassTalentFrame" }
M.UI_ADDONS = { Blizzard_TalentUI = true, Blizzard_PlayerSpells = true, Blizzard_ClassTalentUI = true }
function M:HookWindow()
  self.hookedFrames = self.hookedFrames or {}
  for _, name in ipairs(M.WINDOWS) do
    local f = rawget(_G, name)
    if f and f.HookScript and not self.hookedFrames[name] then
      self.hookedFrames[name] = true
      f:HookScript("OnShow", function() ns.Safe("talents:window", M.OnWindow, M, name) end)
    end
  end
  if not self.updateHooked and type(rawget(_G, "PlayerTalentFrame_Update")) == "function" then
    self.updateHooked = true
    hooksecurefunc("PlayerTalentFrame_Update", function() ns.Safe("talents:rings", M.Rings, M) end)
  end
end

function M:OnWindow(which)
  self.window = which
  local used = self:Rings()
  if not self.windowLogged then
    self.windowLogged = true
    local found = 0
    for n = 1, M.MAX_BUTTONS do if rawget(_G, M.BUTTON .. n) then found = n end end
    self:Info("talent window %s: tab %d, %d buttons named %s<n>, %d rings drawn; frames: PlayerTalentFrame=%s PlayerSpellsFrame=%s ClassTalentFrame=%s",
      tostring(which), M.ShownTab(), found, M.BUTTON, used, tostring(rawget(_G, "PlayerTalentFrame") ~= nil),
      tostring(rawget(_G, "PlayerSpellsFrame") ~= nil), tostring(rawget(_G, "ClassTalentFrame") ~= nil))
  end
end

-- Talent tooltip: "Outrider plan: point 6 of 3 at level 15" / "not in your plan".
function M:TooltipLine(tab, index)
  local plan, state = self:Current()
  if not state then return nil end
  local e
  for _, t in ipairs(state.tabs[tab] and state.tabs[tab].talents or {}) do if t.index == index then e = t end end
  if not e then return nil end
  local points = {}
  for _, s in ipairs(plan.steps) do if s.name == e.name then points[#points + 1] = s end end
  if #points == 0 then return "Outrider plan: not in your build" end
  for _, s in ipairs(points) do
    if s.next then return string.format("Outrider plan: spend here next (#%d)", s.next) end
  end
  local todo
  for _, s in ipairs(points) do if not s.done then todo = s break end end
  if not todo then return string.format("Outrider plan: done (%d/%d)", #points, e.max) end
  return string.format("Outrider plan: rank %d at level %d", todo.rank, todo.level)
end

-- ------------------------------------------------------------ events
function M:Check()
  local plan, state = self:Current()
  if not state then return end
  local s = self:Settings()
  local key = string.format("%d:%d", state.level or 0, state.spent or 0)
  if key ~= self.lastKey then
    self.lastKey = key
    self:Info("talents: level %d, %d spent, %d free; %s", state.level or 0, state.spent or 0, state.unspent or 0, self:Summary())
  end
  if #plan.missing > 0 and not self.missingLogged then
    self.missingLogged = true
    self:Warn("talent build names this client doesn't have: %s", table.concat(plan.missing, ", "))
  end
  -- one chat line per level with points waiting
  if s.notify and (state.unspent or 0) > 0 and #plan.next > 0 and (s.toldLevel or 0) < (state.level or 0) then
    s.toldLevel = state.level
    ns.Print("%s. Open your talents (N): the gold rings are the plan.", self:Summary())
  end
  if rawget(_G, "PlayerTalentFrame") and PlayerTalentFrame.IsShown and PlayerTalentFrame:IsShown() then self:Rings() end
end

-- The whole tree, once per session, so build names can be checked against it.
-- What the client's talent functions hand back, step by step, once per
-- session (2026-11-23: no talent tree was ever logged on Forever, though the
-- probe found C_ClassTalents and C_Traits). Read only.
function M:Diagnose()
  if self.diagnosed then return end
  self.diagnosed = true
  local function show(v)
    if type(v) ~= "table" then return tostring(C.Readable(v)) end
    local parts, n = {}, 0
    for k, x in pairs(v) do
      n = n + 1
      if n > 14 then parts[#parts + 1] = "..." break end
      parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and ("{" .. (#x > 0 and (#x .. " items") or "table") .. "}") or tostring(C.Readable(x)))
    end
    table.sort(parts)
    return "{" .. table.concat(parts, " ") .. "}"
  end
  local config = C.Call("C_ClassTalents.GetActiveConfigID")
  self:Info("talent probe: active config %s", show(config))
  local cinfo = type(config) == "number" and C.Call("C_Traits.GetConfigInfo", config)
  self:Info("talent probe: config info %s", show(cinfo))
  local trees = type(cinfo) == "table" and cinfo.treeIDs or {}
  for t, treeID in ipairs(trees) do
    local nodes = C.Call("C_Traits.GetTreeNodes", treeID) or {}
    self:Info("talent probe: tree %s has %d nodes; currency %s", tostring(treeID), #nodes, show(C.Call("C_Traits.GetTreeCurrencyInfo", config, treeID, false)))
    for i = 1, math.min(3, #nodes) do
      local node = C.Call("C_Traits.GetNodeInfo", config, nodes[i])
      self:Info("talent probe: node %s %s", tostring(nodes[i]), show(node))
      local entryID = type(node) == "table" and ((node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1]))
      local entry = entryID and C.Call("C_Traits.GetEntryInfo", config, entryID)
      self:Info("talent probe: entry %s %s", tostring(entryID), show(entry))
      local def = type(entry) == "table" and entry.definitionID and C.Call("C_Traits.GetDefinitionInfo", entry.definitionID)
      self:Info("talent probe: definition %s", show(def))
    end
    if t >= 4 then break end
  end
  self:Info("talent probe: classic tabs %s, specs %s", show(C.Call("GetNumTalentTabs")), show(C.Call("GetNumSpecializations")))
end

function M:LogTree()
  if not self.treeLogged then ns.Safe("talents:diagnose", M.Diagnose, M) end
  local state = self:Read()
  if not state or self.treeLogged then return end
  self.treeLogged = true
  for t, tab in ipairs(state.tabs) do
    local names = {}
    for _, e in ipairs(tab.talents) do
      if e.tier then
        names[#names + 1] = string.format("%s r%d c%d %d/%d%s", e.name, e.tier, e.column, e.rank, e.max,
          e.req and string.format(" needs r%dc%d", e.req.tier, e.req.column) or "")
      else
        names[#names + 1] = string.format("%s node %s at %s,%s %d/%d%s", e.name, tostring(e.node), tostring(e.x), tostring(e.y),
          e.rank, e.max, e.open and " open" or "")
      end
    end
    self:Info("talent tree %d %s via %s (%d spent): %s", t, tostring(tab.name), tostring(state.api), tab.spent, table.concat(names, "; "))
  end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    mod:LogTree() mod:Check() mod:HookWindow()
  end)
  self:On("CHARACTER_POINTS_CHANGED", function(mod) mod:Check() end)
  self:On("PLAYER_TALENT_UPDATE", function(mod) mod:Check() end)
  self:On("PLAYER_LEVEL_UP", function(mod) ns.Timer.After(1, function() ns.Safe("talents:level", M.Check, M) end, "talents:level") end)
  self:On("ADDON_LOADED", function(mod, _, name) if M.UI_ADDONS[name or ""] then mod:HookWindow() end end)
  if not self.tipHooked and rawget(_G, "GameTooltip") and GameTooltip.SetTalent then
    self.tipHooked = true
    hooksecurefunc(GameTooltip, "SetTalent", function(tip, tab, index)
      if not M.enabled then return end
      local _, line = ns.Safe("talents:tip", M.TooltipLine, M, tab, index)
      if type(line) == "string" then tip:AddLine(line, 1, 0.82, 0.2, true) tip:Show() end
    end)
  end
end

function M:Snapshot()
  local plan, state, build = self:Current()
  if not state then return nil end
  local trees = {}
  for _, tab in ipairs(state.tabs) do trees[#trees + 1] = { name = tab.name, spent = tab.spent } end
  local nxt = {}
  for _, s in ipairs(plan.next) do nxt[#nxt + 1] = M.StepText(s) end
  return { build = build and build.id, unspent = state.unspent, trees = trees, next = nxt, summary = self:Summary() }
end

function M:Activity() return self:Summary() end

ns.AddCommand("talents", "[build <id>|on|off]  your next talent points from the levelling build", function(arg)
  arg = arg or ""
  local id = arg:match("^build%s+(%S+)")
  if id then
    for _, b in ipairs(M.Builds(ns.PlayerClass())) do
      if b.id == id then M:Settings().build = id ns.Print("talent build: %s", b.name) M:Check() return end
    end
    ns.Print("no build %s for your class", id)
    return
  end
  if arg == "on" or arg == "off" then
    M:Settings().highlight = arg == "on"
    M:Rings()
    ns.Print("talent rings %s", arg)
    return
  end
  ns.Print("%s", M:Summary())
end)
