-- Intelligence/Scenario.lua  (OI05-01: scenario contract)
-- "What if...?" without touching the real thing. Base() takes a copy of your
-- character as Outrider sees it now (level, class, role, gold, the gear you
-- wear, talent points per tree, professions, zone). Branch(base, overrides)
-- makes a NEW frozen scenario from that copy with explicit hypothetical changes:
--   gear        { [slot 1..19] = itemID }        an item in a slot
--   talents     { [tree] = points }               points per tree (total within level - 9)
--   spend       copper                            gold spent (at most what you have)
--   role        a role your class can play (ClassProfiles.ROLES)
--   zone        mapID
--   professions { [name] = skill 0..450 }
--   level       1..60
-- Invalid overrides are refused with the reason, never adjusted. A scenario
-- carries its version, the base it came from (a hash), every override and the
-- assumptions the comparison relies on. Nothing here writes to saved data or
-- changes anything in the game: the live character's hash is the same before
-- and after (tested).

local _, ns = ...
local C = ns.Compat
local S = { VERSION = "scenario-1", MAX_LEVEL = 60, MAX_SKILL = 450 }
ns.Scenario = S

local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end

-- a deep, read-only view: writing to a scenario is an error
local function freeze(t)
  if type(t) ~= "table" then return t end
  local inner = {}
  for k, v in pairs(t) do inner[k] = freeze(v) end
  -- Lua 5.1 (WoW) has no __pairs/__len for tables: iterate S.Raw(scenario)
  return setmetatable({}, { __index = inner, __newindex = function() error("a scenario can't be changed: branch a new one") end,
    __frozen = inner })
end
function S.Raw(t)
  local mt = type(t) == "table" and getmetatable(t)
  if not (mt and mt.__frozen) then return t end
  local out = {}
  for k, v in pairs(mt.__frozen) do out[k] = S.Raw(v) end
  return out
end

function S.Hash(state)
  local ok, enc = pcall(ns.Serialize.Encode, S.Raw(state))
  return ok and tostring(ns.Serialize.Adler32(enc)) or nil
end

-- the live character, copied
function S.Base()
  local st = { level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1 }
  local P = ns.ClassProfiles
  local cur = P and P.Current and P.Current() or {}
  st.class, st.role = cur.class or "UNKNOWN", cur.role or "UNKNOWN"
  st.copper = tonumber(C.Readable(C.Call("GetMoney"))) or 0
  st.gear = {}
  for slot = 1, 19 do
    local id = tonumber(C.Readable(C.Call("GetInventoryItemID", "player", slot)))
    if id then st.gear[slot] = id end
  end
  st.talents = {}
  local T = ns.Modules:Get("Talents")
  local ok, tstate = pcall(function() return T and T.Read and T:Read() end)
  if ok and type(tstate) == "table" then for i, tab in ipairs(tstate.tabs or {}) do st.talents[i] = tab.spent or 0 end end
  st.professions = {}
  local O = ns.Outcomes
  if O and O.Professions then for name, rank in pairs(O:Professions()) do st.professions[name] = rank end end
  st.zone = tonumber(C.Readable(C.PlayerPosition("player")))
  return st
end

local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end

-- check one override set against a base; returns nil or why
function S.Check(base, o)
  if type(o) ~= "table" then return "overrides must be a table" end
  local level = o.level or base.level
  if o.level ~= nil and not int(o.level, 1, S.MAX_LEVEL) then return "level must be 1 to " .. S.MAX_LEVEL end
  for slot, id in pairs(o.gear or {}) do
    if not int(slot, 1, 19) then return "gear slot must be 1 to 19" end
    if not int(id, 1, 10000000) then return "gear item must be an item id" end
  end
  if o.talents then
    local sum = 0
    for tree, pts in pairs(o.talents) do
      if not int(tree, 1, 3) then return "talent tree must be 1 to 3" end
      if not int(pts, 0, 61) then return "talent points must be a whole number" end
      sum = sum + pts
    end
    if sum > math.max(0, level - 9) then return string.format("%d talent points is more than level %d has (%d)", sum, level, math.max(0, level - 9)) end
  end
  if o.spend ~= nil and not int(o.spend, 0, base.copper or 0) then return "spending must be 0 to the gold you have" end
  if o.role ~= nil then
    local allowed = false
    for _, r in ipairs(ns.ClassProfiles and ns.ClassProfiles.ROLES[base.class or "UNKNOWN"] or {}) do if r == o.role then allowed = true end end
    if not allowed then return "your class can't play " .. tostring(o.role) end
  end
  if o.zone ~= nil and not int(o.zone, 1, 100000) then return "zone must be a map id" end
  for name, skill in pairs(o.professions or {}) do
    if type(name) ~= "string" or not int(skill, 0, S.MAX_SKILL) then return "profession skill must be 0 to " .. S.MAX_SKILL end
  end
  return nil
end

-- a new frozen scenario, or nil and why
function S.Branch(base, overrides, assumptions)
  base = S.Raw(base)
  local why = S.Check(base, overrides or {})
  if why then return nil, why end
  local st = copy(base)
  local o = copy(overrides or {})
  if o.level then st.level = o.level end
  for slot, id in pairs(o.gear or {}) do st.gear[slot] = id end
  if o.talents then st.talents = copy(o.talents) end
  if o.spend then st.copper = st.copper - o.spend end
  if o.role then st.role = o.role end
  if o.zone then st.zone = o.zone end
  for name, skill in pairs(o.professions or {}) do st.professions[name] = skill end
  local list = { "scores use your stat weights for the role", "unknown values stay unknown" }
  for _, a in ipairs(assumptions or {}) do list[#list + 1] = tostring(a) end
  return freeze({ version = S.VERSION, baseHash = S.Hash(base), state = st, overrides = o, assumptions = list, createdAt = time() })
end
