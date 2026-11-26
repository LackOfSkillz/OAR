-- Vanguard/Roster.lua
-- VG01-02: the current group as one list, the same shape for solo, party and
-- raid (spec section 7, RosterSnapshot). Reads native APIs only; every read
-- goes through Compat and the secret check.
--
--   local snap = Roster.Read(previous)
--   snap.generation   goes up whenever who is in the group changes
--   snap.members[i] = { key, unit, self, guid, name, realm, class, level,
--     role, subgroup, connected, dead, availability, ambiguous }
--
-- Identity: the GUID when it can be read; otherwise name-realm (realm filled
-- in for your own realm, so two players with one name on two realms stay
-- two people); otherwise the unit token, marked ambiguous. Two members that
-- would get the same key are never merged: the second gets "#2".
-- GUIDs and names live in memory only, for the current view (D27).

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local Obs = ns.Vanguard.Obs
local R = {}
ns.Vanguard.Roster = R

R.MAX = 40
R.ROLES = { TANK = true, HEALER = true, DAMAGER = true }

local function readable(v) return C.Readable(v) end
local function str(v) v = readable(v) if type(v) == "string" and v ~= "" then return v end end

function R.HomeRealm()
  local r = str(C.Call("GetNormalizedRealmName")) or str(C.Call("GetRealmName"))
  return r and (r:gsub("[%s%-]", "")) or nil
end

-- unit tokens of the group, player first
function R.Units()
  local out = { "player" }
  local raid = readable(C.Call("IsInRaid")) == true
  if raid then
    local n = tonumber(readable(C.Call("GetNumGroupMembers"))) or 0
    n = math.min(n, R.MAX)
    for i = 1, n do
      local u = "raid" .. i
      if readable(C.Call("UnitIsUnit", u, "player")) ~= true then out[#out + 1] = u end
    end
    return out, "raid"
  end
  if readable(C.Call("IsInGroup")) == true then
    for i = 1, 4 do
      local u = "party" .. i
      if readable(C.Call("UnitExists", u)) then out[#out + 1] = u end
    end
    return out, "party"
  end
  return out, "solo"
end

local function role(unit)
  local r = str(C.Call("UnitGroupRolesAssigned", unit))
  if r and R.ROLES[r] then return Obs.New("role", r, "native"), "assigned" end
  if r == "NONE" then return Obs.Unknown("role", "no role assigned"), "none" end
  return Obs.Unknown("role", r and "unexpected value" or "not readable"), "none"
end

-- one member from a unit token (and the raid row, when in a raid)
function R.Member(unit, home, raidIndex)
  local m = { unit = unit, self = unit == "player" }
  m.guid = str(C.Call("UnitGUID", unit))
  local name, realm = C.Call("UnitName", unit)
  m.name, m.realm = str(name), str(realm)
  if m.name and not m.realm then m.realm = home end
  local _, class = C.Call("UnitClass", unit)
  m.class = Obs.New("class", str(class), "native")
  local lvl = readable(C.Call("UnitLevel", unit))
  m.level = (type(lvl) == "number" and lvl > 0) and Obs.New("level", lvl, "native") or Obs.Unknown("level", lvl == -1 and "too far above you" or "not readable")
  m.role, m.roleSource = role(unit)
  local online = readable(C.Call("UnitIsConnected", unit))
  if type(online) ~= "boolean" then online = nil end
  m.connected = Obs.New("connected", online, "native")
  m.dead = readable(C.Call("UnitIsDeadOrGhost", unit)) == true
  if raidIndex then
    local _, _, subgroup = C.Call("GetRaidRosterInfo", raidIndex)
    subgroup = readable(subgroup)
    m.subgroup = Obs.New("subgroup", type(subgroup) == "number" and subgroup or nil, "native")
  end
  if m.connected.value == false then m.availability = "offline"
  elseif m.dead then m.availability = "dead"
  elseif m.connected.status ~= "known" then m.availability = "unknown"
  else m.availability = "here" end
  return m
end

local function keyOf(m)
  if m.guid then return m.guid end
  if m.name and m.realm then m.ambiguous = false return m.name .. "-" .. m.realm end
  m.ambiguous = true
  return "unit:" .. m.unit
end

function R.Read(prev)
  local units, kind = R.Units()
  local home = R.HomeRealm()
  local snap = { kind = kind, members = {}, byKey = {}, at = (GetTime and GetTime()) or 0 }
  local _, build = C.Call("GetBuildInfo")
  snap.build = str(build)
  for i, unit in ipairs(units) do
    local idx = kind == "raid" and tonumber(unit:match("^raid(%d+)$")) or nil
    local m = R.Member(unit, home, idx)
    local key = keyOf(m)
    if snap.byKey[key] then
      -- never merge two people who only look the same
      local n = 2
      while snap.byKey[key .. "#" .. n] do n = n + 1 end
      key, m.ambiguous = key .. "#" .. n, true
    end
    m.key = key
    snap.byKey[key] = m
    snap.members[#snap.members + 1] = m
  end
  snap.size = #snap.members
  local keys = {}
  for k in pairs(snap.byKey) do keys[#keys + 1] = k end
  table.sort(keys)
  snap.who = table.concat(keys, "\31")
  if prev and prev.who == snap.who then snap.generation = prev.generation
  else snap.generation = (prev and prev.generation or 0) + 1 end
  return snap
end

-- keys in a but not in b
function R.Left(a, b)
  local out = {}
  if not a then return out end
  for k in pairs(a.byKey) do if not (b and b.byKey[k]) then out[#out + 1] = k end end
  table.sort(out)
  return out
end
