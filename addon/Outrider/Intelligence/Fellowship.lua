-- Intelligence/Fellowship.lua  (OI06-09 consent and protocol, OI06-10 group planner, OI06-11 group page)
-- OI06-09: an opt-in "FGOAL" addon message (Comm: PARTY, RAID, GUILD or a
--   WHISPER to a group member only) with the least a group plan needs:
--   { v, goals (up to 5 short ids), eligible (up to 10 opportunity ids from
--   your plan), ready (your own press), level, role }. Nothing is sent unless
--   you switched sharing on (off by default); at most one message per RATE
--   seconds. Received messages are checked: version (a newer one is ignored
--   and noted), size, field types and lengths, the sender in your group (a
--   party or raid message, or a whisper) and a per-sender rate. Turning
--   sharing off sends one "revoke" so others forget you; a member who revokes
--   is forgotten here. Peers live in memory only.
-- OI06-10: GroupPlan(members): the opportunities consenting members share,
--   ranked by how many need each, then by how often its members were already
--   served (so one member isn't always favoured), then id. A member who hasn't shared is
--   "not shared: can't tell if ready", never counted as ready. Nothing about a
--   member's bags is inferred; nobody is invited.
-- OI06-11: a Group page: what helps the most members, each member's gaps,
--   your ready / not ready and Stop sharing. Leaving the group or a roster
--   change drops members who left. Each member keeps their own plan.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Fellowship", {
  title = "Group planning",
  phase = "OI06",
  order = 212,
  defaults = { share = false, ready = false },
})
ns.Fellowship = M
M.VERSION, M.TYPE, M.RATE, M.MAX_GOALS, M.MAX_ELIGIBLE, M.MAX_ID = 1, "FGOAL", 10, 5, 10, 40
M.peers, M.served, M.lastIn, M.notes = {}, {}, {}, {}

local function short(name) return type(name) == "string" and (name:match("^([^%-]+)") or name) or nil end

function M.InGroup(sender)
  local want = short(sender)
  if not want then return false end
  for i = 1, 4 do if short(C.Readable(C.Call("UnitName", "party" .. i))) == want then return true end end
  for i = 1, 40 do if short(C.Readable(C.Call("UnitName", "raid" .. i))) == want then return true end end
  return false
end

local function ids(list, max)
  if type(list) ~= "table" then return nil end
  if #list > max then return nil end
  local out = {}
  for i, v in ipairs(list) do
    if type(v) ~= "string" or #v == 0 or #v > M.MAX_ID or v:find("[%c|]") then return nil end
    out[i] = v
  end
  return out
end

-- a received payload, checked; nil and why
function M.Check(data)
  if type(data) ~= "table" then return nil, "not a table" end
  if data.v ~= M.VERSION then return nil, (type(data.v) == "number" and data.v > M.VERSION) and "newer version" or "bad version" end
  if data.revoke == true then return { revoke = true } end
  local goals, elig = ids(data.goals or {}, M.MAX_GOALS), ids(data.eligible or {}, M.MAX_ELIGIBLE)
  if not (goals and elig) then return nil, "bad goal or opportunity list" end
  local level = tonumber(data.level)
  if level and (level < 1 or level > 60 or level ~= math.floor(level)) then return nil, "bad level" end
  local role = data.role
  if role ~= nil and (type(role) ~= "string" or #role > 16) then return nil, "bad role" end
  return { goals = goals, eligible = elig, ready = data.ready == true, level = level, role = role }
end

function M:Receive(data, sender, channel, now)
  now = now or time()
  if not (channel == "PARTY" or channel == "RAID" or channel == "WHISPER") then return false, "group channels only" end
  if not M.InGroup(sender) then return false, "not in your group" end
  if M.lastIn[sender] and now - M.lastIn[sender] < M.RATE then return false, "too often" end
  M.lastIn[sender] = now
  local d, why = M.Check(data)
  if not d then
    if why == "newer version" and not M.notes[sender] then M.notes[sender] = "uses a newer Outrider: ignored" end
    return false, why
  end
  if d.revoke then M.peers[sender] = nil return true end
  d.at = now
  M.peers[sender] = d
  return true
end

function M:OnComm(_, kind, data, sender, channel)
  if kind == M.TYPE then self:Receive(data, sender, channel) end
end

-- what we'd send (nil when sharing is off)
function M:Payload()
  local st = self:Settings()
  if not st.share then return nil end
  local goals, elig = {}, {}
  for _, g in ipairs(ns.NexusGoals and ns.NexusGoals:Active() or {}) do
    if #goals < M.MAX_GOALS and type(g.id) == "string" then goals[#goals + 1] = g.id:sub(1, M.MAX_ID) end
  end
  local cur = ns.NexusCore and ns.NexusCore.current
  for _, step in ipairs(cur and cur.plan or {}) do
    local id = step.opportunityId or step.id
    if #elig < M.MAX_ELIGIBLE and type(id) == "string" then elig[#elig + 1] = id:sub(1, M.MAX_ID) end
  end
  local P = ns.ClassProfiles and ns.ClassProfiles.Current and ns.ClassProfiles.Current() or {}
  return { v = M.VERSION, goals = goals, eligible = elig, ready = st.ready == true,
    level = tonumber(C.Readable(C.Call("UnitLevel", "player"))), role = P.role }
end

function M:Channel()
  if C.Call("IsInRaid") then return "RAID" end
  if C.Call("IsInGroup") then return "PARTY" end
end

function M:Share(now)
  now = now or time()
  local p = self:Payload()
  if not p then return false, "sharing is off" end
  local ch = self:Channel()
  if not ch then return false, "not in a group" end
  if self.lastOut and now - self.lastOut < M.RATE then return false, "too soon" end
  self.lastOut = now
  return ns.Comm:Send(M.TYPE, p, ch)
end

function M:SetShare(on)
  local st = self:Settings()
  if st.share and not on then
    local ch = self:Channel()
    if ch then ns.Comm:Send(M.TYPE, { v = M.VERSION, revoke = true }, ch) end
  end
  st.share = on and true or false
  if on then self.lastOut = nil self:Share() end
end

function M:SetReady(on)
  self:Settings().ready = on and true or false
  self.lastOut = nil
  if self:Settings().share then self:Share() end
end

function M:OnRoster()
  for name in pairs(M.peers) do if not M.InGroup(name) then M.peers[name] = nil end end
  if not self:Channel() then M.peers = {} end
end

-- OI06-10: members = { { name, shared = bool, eligible = {...}, ready, level } }
function M.GroupPlan(members, served)
  served = served or {}
  local need, notShared = {}, {}
  for _, m in ipairs(members or {}) do
    if m.shared then
      for _, id in ipairs(m.eligible or {}) do
        need[id] = need[id] or {}
        need[id][#need[id] + 1] = m.name
      end
    else
      notShared[#notShared + 1] = m.name
    end
  end
  local items = {}
  for id, names in pairs(need) do
    table.sort(names)
    local total = 0
    for _, n in ipairs(names) do total = total + (served[n] or 0) end
    items[#items + 1] = { id = id, members = names, benefit = #names, served = total }
  end
  table.sort(items, function(a, b)
    if a.benefit ~= b.benefit then return a.benefit > b.benefit end
    if a.served ~= b.served then return a.served < b.served end
    return a.id < b.id
  end)
  local gaps = {}
  for _, m in ipairs(members or {}) do
    if not m.shared then gaps[m.name] = "not shared: can't tell if ready"
    elseif not m.ready then gaps[m.name] = "not ready yet" end
  end
  return { items = items, gaps = gaps, notShared = notShared }
end

-- the player picked an item: its members were served
function M:Pick(item)
  for _, n in ipairs(item and item.members or {}) do M.served[n] = (M.served[n] or 0) + 1 end
end

function M:Members()
  local list = {}
  local me = self:Payload() or {}
  list[#list + 1] = { name = "you", shared = true, eligible = me.eligible or {}, ready = self:Settings().ready, level = me.level }
  local seen = {}
  for name, d in pairs(M.peers) do
    seen[short(name)] = true
    list[#list + 1] = { name = short(name), shared = true, eligible = d.eligible, ready = d.ready, level = d.level }
  end
  for i = 1, 4 do
    local n = short(C.Readable(C.Call("UnitName", "party" .. i)))
    if n and not seen[n] then list[#list + 1] = { name = n, shared = false } end
  end
  return list
end

function M:Cards(refresh)
  local function again() if refresh then refresh() end end
  local st = self:Settings()
  local out = {}
  out[#out + 1] = { title = st.share and "Sharing with your group" or "Not sharing",
    line = st.share and "Your goals, plan picks and ready flag go to your party (nothing else)." or
      "Turn sharing on to plan with Outrider users in your party. Nothing is sent while it's off.",
    actions = {
      { st.share and "Stop sharing" or "Share with group", function() self:SetShare(not st.share) again() end,
        st.share and "Stop sending, and ask the others to forget what you sent." or "Send your goals and plan picks to your party." },
      { st.ready and "I'm not ready" or "I'm ready", function() self:SetReady(not st.ready) again() end, "Tell your group whether you're ready." },
    } }
  local plan = M.GroupPlan(self:Members(), M.served)
  for i = 1, math.min(3, #plan.items) do
    local it = plan.items[i]
    out[#out + 1] = { title = it.id, line = string.format("Helps %d: %s.", it.benefit, table.concat(it.members, ", ")),
      actions = { { "We'll do this", function() self:Pick(it) again() end, "Note that the group chose this (so others come first next time)." } } }
  end
  local gaps = {}
  for name, why in pairs(plan.gaps) do gaps[#gaps + 1] = name .. ": " .. why end
  table.sort(gaps)
  if #gaps > 0 then out[#out + 1] = { title = "Members", line = table.concat(gaps, "; ") .. "." } end
  return out
end

function M:OnEnable()
  if ns.Comm then ns.Comm.KNOWN_TYPES[M.TYPE] = true end
  self:On("OTR_COMM", self.OnComm)
  self:On("GROUP_ROSTER_UPDATE", function(mod) mod:OnRoster() end)
end

ns.Hub:AddTab("fellowship", "Group", function(p)
  ns.UI:FormPage(p, {
    { "header", "Plan with your group", icon = "INV_Misc_GroupNeedMore" },
    { "note", "Opt in: only goals, plan picks and ready go to your party. Each of you keeps your own plan; nobody is invited." },
    { "cards", function() return M:Cards(function() p:Refresh() end) end },
  })
end, 120)
