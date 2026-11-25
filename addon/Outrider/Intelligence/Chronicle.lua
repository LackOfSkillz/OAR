-- Intelligence/Chronicle.lua  (OI03-08)
-- A short story of your play: milestones and the choices you made, in order.
-- Driven by the outcome recorder (same opt-in switch, same store:
-- char.outcomes.chronicle). Built from recorded outcomes (OTR_OUTCOME), your
-- Go on a plan step (OTR_NEXUS_ACTED) and play session starts; never from
-- chat, never every event: only these milestones:
--   level        reached a new level
--   quest        turned in or abandoned a quest
--   zone         first visit to a zone (per character)
--   profession   a profession reached 75, 150, 225 or 300
--   gear         first time you put on an item
--   death        a death (where)
--   decision     you pressed Go on a plan step (with the plan and step ids)
--   session      a play session started
-- Each entry has a key (what it is about), so a replay, a reload or a
-- duplicate event never adds it twice; entries are kept in time order.
-- Privacy: kinds you hide are not recorded; Clear(filter) moves the matching
-- entries to the archive ("chronicleCleared") before removing them (owner
-- data preservation: never just deleted); Export(filter) gives plain text
-- to copy, nothing is sent anywhere.

local _, ns = ...
local C = ns.Compat
local H = { MAX = 300, KEY_DAYS = 30, PROF_STEPS = { 75, 150, 225, 300 } }
ns.Chronicle = H
H.KINDS = { "level", "quest", "zone", "profession", "gear", "death", "decision", "session" }

function H:Store(mod)
  local s = mod:Store()
  s.chronicle = ns.KeepTable(s.chronicle, "Chronicle:char.outcomes.chronicle") or {}
  s.chronicleKeys = ns.KeepTable(s.chronicleKeys, "Chronicle:char.outcomes.chronicleKeys") or {}
  s.chronicleSeq = tonumber(s.chronicleSeq) or 0
  return s
end

function H:Hidden(mod) return mod:Settings().chronicleHide or {} end

-- Add one entry; returns it, or nil and why.
function H:Add(mod, kind, key, text, at, ref)
  if self:Hidden(mod)[kind] then return nil, "hidden" end
  local s = self:Store(mod)
  key = kind .. ":" .. tostring(key)
  if s.chronicleKeys[key] then return nil, "duplicate" end
  s.chronicleSeq = s.chronicleSeq + 1
  local e = { key = key, kind = kind, text = tostring(text):gsub("|", ""):sub(1, 140), at = math.floor(tonumber(at) or time()),
    seq = s.chronicleSeq, ref = ref }
  s.chronicleKeys[key] = e.at
  -- the "seen" index is bounded: keys older than KEY_DAYS go (an index, not
  -- collected data; the entries themselves stay in the list or the archive)
  if s.chronicleSeq % 100 == 0 then
    local cutoff = time() - H.KEY_DAYS * 86400
    for k, t in pairs(s.chronicleKeys) do if type(t) ~= "number" or t < cutoff then s.chronicleKeys[k] = nil end end
  end
  local list = s.chronicle
  -- keep time order even when an event arrives late
  local i = #list
  while i > 0 and (list[i].at > e.at) do i = i - 1 end
  table.insert(list, i + 1, e)
  local cap = mod.Cap and mod:Cap("chronicle") or H.MAX
  while #list > cap and ns.Archive:Shift("chronicleEntries", list, { path = "char.outcomes.chronicle", scope = "char" }) do end
  return e
end

local function questName(id)
  local Q = ns.Modules:Get("QuestInfo")
  local ok, name = pcall(function() return Q and Q.Name and Q:Name(id) end)
  return ok and name or ("quest " .. tostring(id))
end
local function zoneName(id)
  local info = C.Call("C_Map.GetMapInfo", id)
  local name = type(info) == "table" and C.Readable(info.name)
  return type(name) == "string" and name or ("zone " .. tostring(id))
end
local function itemName(id)
  local name = C.Call("GetItemInfo", id)
  name = C.Readable(name)
  return type(name) == "string" and name or ("item " .. tostring(id))
end

-- an outcome -> a milestone, if it is one
function H:FromOutcome(mod, e)
  if type(e) ~= "table" then return end
  local ref = { eventId = e.eventId, planId = e.planId, stepId = e.stepId }
  local id = e.subject and tostring(e.subject):match(":(.+)$")
  if e.kind == "level_up" and id then
    return self:Add(mod, "level", id, "Reached level " .. id, e.at, ref)
  elseif e.kind == "quest_completed" and id then
    return self:Add(mod, "quest", id .. ":done:" .. e.at, "Turned in " .. questName(tonumber(id)), e.at, ref)
  elseif e.kind == "quest_abandoned" and id then
    return self:Add(mod, "quest", id .. ":abandoned:" .. e.at, "Abandoned " .. questName(tonumber(id)), e.at, ref)
  elseif e.kind == "zone_entered" and id then
    return self:Add(mod, "zone", id, "First visit to " .. zoneName(tonumber(id)), e.at, ref)
  elseif e.kind == "gear_equipped" and id then
    return self:Add(mod, "gear", id, "Put on " .. itemName(tonumber(id)), e.at, ref)
  elseif e.kind == "death" then
    local here = tonumber(C.Readable(C.PlayerPosition("player")))
    return self:Add(mod, "death", e.eventId, here and ("Died in " .. zoneName(here)) or "Died", e.at, ref)
  elseif e.kind == "profession_skill" and id then
    self.ranks = self.ranks or {}
    local P = mod.Professions and mod:Professions() or {}
    for name, rank in pairs(P) do
      if name:gsub("[^%w]", "") == id then
        for _, step in ipairs(H.PROF_STEPS) do
          if rank >= step then self:Add(mod, "profession", id .. ":" .. step, string.format("%s reached %d", name, step), e.at, ref) end
        end
      end
    end
  end
end

function H:Wire(mod)
  mod:On("OTR_OUTCOME", function(m, _, e) H:FromOutcome(m, e) end)
  mod:On("OTR_NEXUS_ACTED", function(m, _, info)
    if type(info) ~= "table" then return end
    H:Add(m, "decision", tostring(info.planId) .. ":" .. tostring(info.stepId),
      "Chose a plan step: " .. tostring(info.title or info.stepId), info.at, { planId = info.planId, stepId = info.stepId })
  end)
  mod:On("OTR_PLAYSESSION", function(m, _, kind)
    local P = ns.PlaySession
    if kind == "new" and P and P:Id() then H:Add(m, "session", P:Id(), "Started playing", P:Current().startedAt) end
  end)
end

-- entries matching a filter: { kinds = { [kind] = true }, from = t, to = t }
local function match(e, f)
  if f.kinds and not f.kinds[e.kind] then return false end
  if f.from and e.at < f.from then return false end
  if f.to and e.at > f.to then return false end
  return true
end

function H:Entries(mod, filter)
  local out = {}
  for _, e in ipairs(self:Store(mod).chronicle) do if match(e, filter or {}) then out[#out + 1] = e end end
  return out
end

-- archive first, then remove; nothing is cleared if archiving fails
function H:Clear(mod, filter)
  local s = self:Store(mod)
  local gone, keep = {}, {}
  for _, e in ipairs(s.chronicle) do if match(e, filter or {}) then gone[#gone + 1] = e else keep[#keep + 1] = e end end
  if #gone == 0 then return 0 end
  if not ns.Archive:Put("chronicleCleared", gone, { path = "char.outcomes.chronicle", scope = "char" }) then return nil, "couldn't archive" end
  for i = #s.chronicle, 1, -1 do s.chronicle[i] = nil end
  for i, e in ipairs(keep) do s.chronicle[i] = e end
  -- the keys stay: a cleared milestone is not re-added by a replay
  return #gone
end

function H:Export(mod, filter)
  local lines = {}
  for _, e in ipairs(self:Entries(mod, filter)) do
    lines[#lines + 1] = string.format("%s  %s", date("%Y-%m-%d %H:%M", e.at), e.text)
  end
  return table.concat(lines, "\n")
end
