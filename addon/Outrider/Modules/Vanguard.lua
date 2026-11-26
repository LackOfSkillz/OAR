-- Modules/Vanguard.lua
-- Vanguard VG01: Group check (preview). One Outrider install looks at the
-- group the game lets it see: roster facts for everyone, and gear and talents
-- for the members you scan (native inspect, through the shared InspectBroker).
-- Nobody else needs Outrider.
--
-- Rules (spec sections 4 and 6, D18, D27):
--   * Off by default (preview). Off means no events, no timers, no requests.
--   * A scan starts only when you press Scan (or rescan one member); nothing
--     repeats by itself, nothing is asked while drawing the page.
--   * Out of combat only. Combat, zoning, a changed group or turning it off
--     cancels the scan; a late answer can't fill in the wrong member.
--   * Unknown stays unknown: a slot or talent the game didn't show is never
--     counted as empty or zero.
--   * Memory only. Names, GUIDs, gear and talents of other players are never
--     written to saved data or the log (only counts are logged).

local _, ns = ...
local C = ns.Compat
local V = ns.Vanguard
local Obs, Roster, Profile, Cache = V.Obs, V.Roster, V.Profile, V.Cache
local M = ns:NewModule("Vanguard", {
  title = "Group check (preview)",
  phase = "VG01",
  order = 160,
  defaultEnabled = false,
  defaults = {},
})
ns.VanguardModule = M

M.DEADLINE = 180      -- seconds a whole scan may take (spec section 6)
M.ITEM_RETRY = 2      -- seconds between re-checks of gear the game hasn't sent yet
M.ITEM_TRIES = 5

local function now() return (GetTime and GetTime()) or 0 end

function M:OnInitialize()
  self.scanSeq, self.rev, self.manual = 0, 0, {}
end

function M:OnEnable()
  self:On("GROUP_ROSTER_UPDATE", function(mod) mod:OnRoster() end)
  self:On("PLAYER_REGEN_DISABLED", function(mod) mod:Cancel("combat started") end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Cancel("you changed zone") mod:OnRoster() end)
  self:On("PLAYER_LOGOUT", function(mod) Cache:Clear() end)
  self:ReadRoster()
end

function M:OnDisable()
  self:Cancel("turned off")
  Cache:Clear()
  self.snap, self.scan, self.manual, self.selected = nil, nil, {}, nil
  self.itemTimer, self.itemTries, self.itemEvent = nil, nil, nil
end

-- ------------------------------------------------------------------ roster
function M:ReadRoster()
  local prev = self.snap
  self.snap = Roster.Read(prev)
  if prev and prev.generation ~= self.snap.generation then
    local dropped = Cache:Keep(self.snap)
    for _, k in ipairs(Roster.Left(prev, self.snap)) do self.manual[k] = nil end
    if dropped > 0 then self:Debug("forgot %d member(s) who left the group", dropped) end
  end
  return self.snap
end

function M:OnRoster()
  local before = self.snap and self.snap.generation
  self:ReadRoster()
  if self.scan and self.scan.state == "running" and self.snap.generation ~= before then
    self:Cancel("the group changed")
  end
  self:Redraw()
end

-- ------------------------------------------------------------------ scan
-- Scan everyone (or one member by key). Returns the scan or nil, reason.
function M:Scan(onlyKey)
  if not self:IsEnabled() then return nil, "off" end
  if C.InCombat() then return nil, "combat" end
  if self.scan and self.scan.state == "running" then self:Cancel("started again") end
  local snap = self:ReadRoster()
  self.scanSeq = self.scanSeq + 1
  local scan = { id = self.scanSeq, gen = snap.generation, state = "running", total = 0, done = 0, failed = 0,
    startedAt = now(), members = {}, only = onlyKey }
  self.scan = scan
  local id = scan.id
  for _, m in ipairs(snap.members) do
    if not onlyKey or m.key == onlyKey then
      local key = m.key
      if m.self then
        self:Store(m, Profile.Collect("player", m, self:NextRev()))
        scan.members[key] = { state = "done" }
      elseif m.availability == "offline" then
        scan.members[key] = { state = "offline" }
      elseif not m.guid then
        scan.members[key] = { state = "no id" }
      else
        local token, why = ns.InspectBroker:Request({ owner = "Vanguard", unit = m.unit, guid = m.guid,
          onReady = function(unit, guid) M:OnReady(id, key, unit, guid) end,
          onFail = function(_, reason) M:OnFail(id, key, reason) end })
        if token then
          scan.members[key] = { state = "queued", token = token }
          scan.total = scan.total + 1
        else
          scan.members[key] = { state = why or "not asked" }
        end
      end
    end
  end
  self:Info("scan %d: %d member(s) asked of %d in the %s", id, scan.total, snap.size, snap.kind)
  if scan.total == 0 then self:Done(scan) else
    scan.timer = self:After(M.DEADLINE, function(mod) if mod.scan == scan and scan.state == "running" then mod:Cancel("took too long") end end, "Vanguard:deadline")
  end
  self:Redraw()
  return scan
end

function M:NextRev() self.rev = self.rev + 1 return self.rev end

function M:Store(member, profile)
  profile.role = Profile.Role(member, profile.talents, self.manual[member.key])
  Cache:Put(member.key, profile)
  if profile.count.pending > 0 then self:WatchItems() end
end

-- a reply from the broker; only kept if it is still the same scan, the same
-- group and the same player
function M:OnReady(scanId, key, unit, guid)
  local scan = self.scan
  if not (scan and scan.id == scanId and scan.state == "running") then self.ignored = (self.ignored or 0) + 1 return end
  local m = self.snap and self.snap.byKey[key]
  if not m or m.guid ~= guid or self.snap.generation ~= scan.gen then self.ignored = (self.ignored or 0) + 1 return end
  self:Store(m, Profile.Collect(unit, m, self:NextRev()))
  scan.members[key] = { state = "done" }
  scan.done = scan.done + 1
  self:Check(scan)
end

function M:OnFail(scanId, key, reason)
  local scan = self.scan
  if not (scan and scan.id == scanId and scan.state == "running") then return end
  scan.members[key] = { state = tostring(reason or "failed") }
  scan.failed = scan.failed + 1
  self:Check(scan)
end

function M:Check(scan)
  if scan.done + scan.failed >= scan.total then self:Done(scan) end
  self:Redraw()
end

function M:Done(scan)
  scan.state, scan.endedAt = "done", now()
  if scan.timer then scan.timer:Cancel() scan.timer = nil end
  self:Info("scan %d done: %d read, %d not read, %.0f s", scan.id, scan.done, scan.failed, scan.endedAt - scan.startedAt)
end

function M:Cancel(reason)
  local scan = self.scan
  if not (scan and scan.state == "running") then return false end
  scan.state, scan.reason, scan.endedAt = "canceled", reason, now()
  if scan.timer then scan.timer:Cancel() scan.timer = nil end
  ns.InspectBroker:CancelOwner("Vanguard", reason)
  for _, s in pairs(scan.members) do
    if s.state == "queued" then s.state = "canceled" end
  end
  self:Info("scan %d canceled: %s", scan.id, tostring(reason))
  self:Redraw()
  return true
end

-- gear the game hasn't sent yet: re-checked when the game says item data
-- arrived (GET_ITEM_INFO_RECEIVED, listened to only while something is
-- loading) and a few times on a timer. Results only go to profiles still in
-- the cache (a newer scan replaces the profile, so an old re-check can't
-- write into it).
function M:ResolveAll()
  local left = 0
  for _, p in pairs(Cache.entries) do
    if p.count.pending > 0 then left = left + Profile.ResolvePending(p) end
  end
  if left == 0 and self.itemEvent then self:Off("GET_ITEM_INFO_RECEIVED") self.itemEvent = nil end
  self:Redraw()
  return left
end

function M:WatchItems()
  if not self.itemEvent then
    self.itemEvent = true
    self:On("GET_ITEM_INFO_RECEIVED", function(mod)
      ns.Throttle("vanguard:items", 0.5, function() if mod:IsEnabled() then mod:ResolveAll() end end)
    end)
  end
  if self.itemTimer then return end
  self.itemTries = 0
  local function step(mod)
    mod.itemTimer = nil
    mod.itemTries = (mod.itemTries or 0) + 1
    if mod:ResolveAll() > 0 and mod.itemTries < M.ITEM_TRIES then
      mod.itemTimer = mod:After(M.ITEM_RETRY, step, "Vanguard:items")
    end
  end
  self.itemTimer = self:After(M.ITEM_RETRY, step, "Vanguard:items")
end

-- ------------------------------------------------------------------ roles
function M:SetRole(key, role)
  if not (self.snap and self.snap.byKey[key]) then return false end
  if role ~= nil and not Roster.ROLES[role] then return false end
  self.manual[key] = role
  local p = Cache:Get(key)
  if p then p.role = Profile.Role(self.snap.byKey[key], p.talents, role) end
  self:Redraw()
  return true
end

function M:RoleOf(member)
  local p = Cache:Get(member.key)
  return Profile.Role(member, p and p.talents, self.manual[member.key])
end

-- ------------------------------------------------------------------ view (no requests)
local ROLE_WORD = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
local STATE_WORD = { queued = "in line", canceled = "canceled", offline = "offline", ["no id"] = "can't tell who it is",
  ["out of range"] = "too far away", moved = "left the spot", ["no answer"] = "no answer", overtaken = "another inspect got in first",
  combat = "combat", unavailable = "inspect not available", ["queue full"] = "too many queued" }

local function mins(s) s = math.max(0, s) if s < 60 then return "just now" end return string.format("%d min ago", math.floor(s / 60)) end

function M:Rows()
  local out = {}
  local snap = self.snap
  if not snap then return out end
  local t = now()
  for i, m in ipairs(snap.members) do
    local p, fresh = Cache:Get(m.key, t)
    local scanState = self.scan and self.scan.members[m.key]
    local r = { key = m.key, order = i, selected = self.selected == m.key }
    r.name = m.self and "You" or (m.name or "Unknown")
    if m.ambiguous then r.name = r.name .. " (?)" end
    r.class = Obs.Value(m.class) or "?"
    r.level = Obs.Num(m.level)
    local role = self:RoleOf(m)
    r.role = role.value and (ROLE_WORD[role.value] .. (role.source == "tentative" and " (guess)" or role.source == "manual" and " (you set)" or "")) or "unknown"
    if m.subgroup and Obs.Num(m.subgroup) then r.group = Obs.Num(m.subgroup) end
    if p then
      r.status = fresh == "stale" and ("old: seen " .. mins(t - p.cachedAt) .. ", scan again") or ("seen " .. mins(t - p.cachedAt))
      local c = p.count
      local read = c.known + c.pending
      local lvl = Obs.Num(p.itemLevel)
      r.gear = string.format("%d worn, %d empty%s", read, c.empty, (c.unreadable + c.unavailable) > 0 and (", " .. (c.unreadable + c.unavailable) .. " unreadable") or "")
      if lvl then r.gear = r.gear .. string.format(" · item level %.0f (%d items)", lvl, p.itemLevelSlots) end
      if c.pending > 0 then r.gear = r.gear .. " · " .. c.pending .. " loading" end
      local pts = Obs.Num(p.talents and p.talents.points)
      r.talents = pts and (pts .. " points") or (p.talents and p.talents.points and p.talents.points.reason) or "unknown"
      r.sortGear = lvl or -1
    else
      r.status = scanState and (STATE_WORD[scanState.state] or scanState.state) or (m.availability == "offline" and "offline" or "not checked yet")
      if scanState and scanState.state == "queued" and self.scan.state ~= "running" then r.status = "canceled" end
      r.gear, r.talents, r.sortGear = "unknown", "unknown", -1
    end
    out[#out + 1] = r
  end
  return out
end

function M:Summary()
  local snap = self.snap
  local s = { members = snap and snap.size or 0, kind = snap and snap.kind or "solo", checked = 0, stale = 0 }
  for _, m in ipairs(snap and snap.members or {}) do
    local p, fresh = Cache:Get(m.key)
    if p then s.checked = s.checked + 1 if fresh == "stale" then s.stale = s.stale + 1 end end
  end
  local scan = self.scan
  if scan and scan.state == "running" then s.scan = string.format("%d of %d", scan.done + scan.failed, scan.total)
  elseif scan and scan.state == "canceled" then s.scan = "stopped: " .. tostring(scan.reason)
  elseif scan then s.scan = "done" else s.scan = "not yet" end
  return s
end

function M:Redraw()
  local hub = ns.Hub
  if self.redrawing or not (hub and hub.current == "vanguard" and hub.frame and hub.frame:IsShown()) then return end
  self.redrawing = true
  ns.Timer.After(0.3, function() M.redrawing = nil ns.Hub:Refresh() end, "vanguard:redraw")
end

function M:Snapshot()
  -- counts only (D27): no names or gear of other players
  local s = self:Summary()
  return { enabled = self:IsEnabled(), members = s.members, checked = s.checked }
end

function M:Activity()
  local s = self:Summary()
  return string.format("%d in the group, %d checked", s.members, s.checked)
end

-- ------------------------------------------------------------------ page
ns.Hub:AddTab("vanguard", "Group check", function(p)
  local UI = ns.UI
  local refresh = function() if p.Refresh then p:Refresh() end end
  local function on() return M:IsEnabled() end
  local function sel() return M.selected end
  UI:FormPage(p, {
    { "header", "Group check (preview)" },
    { "note", "See your group's gear and talents before a dungeon, from what the game lets one addon read. Nobody else needs Outrider. 1. Join a group. 2. Stand near them, out of combat, and press Scan group. 3. Read each row: what is known, and what is still unknown. Nothing is saved: it's forgotten when they leave, when you log out, or turns old after 5 minutes." },
    { "note", function()
      if not on() then return "|cffffd100Group check is off.|r It's a preview: press Turn on group check to try it." end
      return ""
    end },
    { "buttons", {
      { "Turn on group check", function() ns.Modules:SetEnabled("Vanguard", true) refresh() end, 160, "Turns on Group check (preview) for this character." },
      { "Turn off group check", function() ns.Modules:SetEnabled("Vanguard", false) refresh() end, 160, "Turns it off: no scans, and everything it saw is forgotten." },
    }, active = function(i) return (i == 1) == on() end },
    { "stats", function()
      local s = M:Summary()
      return {
        { cap = "In the group", value = tostring(s.members), note = s.kind },
        { cap = "Checked", value = tostring(s.checked), note = s.stale > 0 and (s.stale .. " old") or nil },
        { cap = "Scan", value = s.scan },
      }
    end },
    { "buttons", {
      { "Scan group", function()
        local ok, why = M:Scan()
        if not ok then ns.Print("group check: %s", why == "off" and "turn it on first" or why == "combat" and "not in combat" or tostring(why)) end
        refresh()
      end, 120, "Looks at each member's gear and talents, one at a time (about 2 seconds each). Out of combat; stand near them." },
      { "Stop scan", function() M:Cancel("you pressed Stop") refresh() end, 100, "Stops the scan. What was already read stays." },
      { "Scan selected", function() if sel() then M:Scan(sel()) end refresh() end, 120, "Looks at the member you clicked in the list again." },
      { "Re-read group", function() if on() then M:ReadRoster() end refresh() end, 120, "Reads who is in the group again (no inspect)." },
    } },
    { "buttons", {
      { "Selected is tank", function() if sel() then M:SetRole(sel(), "TANK") end refresh() end, 130, "Sets the clicked member's role yourself. Yours wins over the group's role." },
      { "Healer", function() if sel() then M:SetRole(sel(), "HEALER") end refresh() end, 80 },
      { "Damage", function() if sel() then M:SetRole(sel(), "DAMAGER") end refresh() end, 80 },
      { "Clear role", function() if sel() then M:SetRole(sel(), nil) end refresh() end, 100, "Goes back to the group's role, or unknown." },
    }, plain = true },
    { "table", 10, {
      { key = "name", label = "Member", width = 0, sort = function(x) return x.order end,
        text = function(x) return (x.selected and "|cffffd100> |r" or "") .. tostring(x.name) end },
      { key = "class", label = "Class", width = 80, sort = function(x) return x.class end, text = function(x) return tostring(x.class):sub(1, 1) .. tostring(x.class):sub(2):lower() end },
      { key = "level", label = "Lvl", width = 36, align = "RIGHT", sort = function(x) return x.level or 0 end, text = function(x) return x.level or "?" end },
      { key = "role", label = "Role", width = 90, sort = function(x) return x.role end, text = function(x) return x.role end },
      { key = "gear", label = "Gear", width = 240, sort = function(x) return x.sortGear end, text = function(x) return x.gear end },
      { key = "talents", label = "Talents", width = 110, sort = function(x) return x.talents end, text = function(x) return x.talents end },
      { key = "status", label = "Status", width = 150, sort = function(x) return x.status end, text = function(x) return x.status end },
    }, function() if not on() then return {} end return M:Rows() end,
      function(x) if x and x.key then M.selected = x.key refresh() end end, sortKey = "name" },
    { "note", "Unknown means the game didn't show it, not that it's missing. \"Empty\" is a slot the game says is empty. A role marked (guess) comes from the game's answer for their talents; set it yourself if it's wrong. Rows are in group order, not a ranking." },
  })
end)
