-- Vanguard/Profile.lua
-- VG01-06/07: what one inspect (or your own character) shows: gear slot by
-- slot, talents and role evidence (spec section 7, MemberProfile).
--
-- Slot states (never mixed up):
--   known        item and its details read
--   pending      the item is there but the game hasn't sent its details yet
--   empty        nothing worn there
--   unreadable   the game answered with a secret value
--   unavailable  this client has no API to read it
-- Talents only through APIs seen working on Forever (probe 2026-11-26: spec ID
-- and the Traits tree for config INSPECT_TRAIT_CONFIG_ID); the Classic talent
-- tab API is missing there and is reported as unavailable, not as no talents.
-- Role: one you set here (manual) beats the group's assigned role, which beats
-- a tentative guess from the game's own spec-to-role answer. Nothing else is
-- guessed: an unknown role stays unknown.
-- Memory only (D27); see Vanguard/Cache.lua.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local Obs = ns.Vanguard.Obs
local P = {}
ns.Vanguard.Profile = P

P.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
P.NODES_MAX = 300

local function readable(v) return C.Readable(v) end

local function itemDetails(ref)
  local name, _, quality, level = C.Call("C_Item.GetItemInfo", ref)
  if name == nil then name, _, quality, level = C.Call("GetItemInfo", ref) end
  if C.IsSecret(name) then return nil end
  if name == nil then return nil end
  local detailed = C.Resolve("C_Item.GetDetailedItemLevelInfo") or C.Resolve("GetDetailedItemLevelInfo")
  if detailed and type(ref) == "string" then
    local ok, v = pcall(detailed, ref)
    v = ok and readable(v) or nil
    if type(v) == "number" then level = v end
  end
  quality, level = readable(quality), readable(level)
  return { quality = type(quality) == "number" and quality or nil, level = type(level) == "number" and level or nil }
end

function P.ParseLink(link)
  local body = type(link) == "string" and link:match("item:([%-%d:]+)")
  if not body then return nil end
  local id, ench = body:match("^(%d+):?(%-?%d*)")
  ench = tonumber(ench)
  return tonumber(id), (ench and ench > 0) and ench or nil
end

-- one slot of a unit
function P.Slot(unit, slot)
  local s = { slot = slot }
  if not C.Resolve("GetInventoryItemLink") then s.state = "unavailable" return s end
  local link = C.Call("GetInventoryItemLink", unit, slot)
  if C.IsSecret(link) then s.state = "unreadable" return s end
  local id
  if type(link) == "string" then
    id, s.enchant = P.ParseLink(link)
    s.link = link
  else
    local raw = C.Call("GetInventoryItemID", unit, slot)
    if C.IsSecret(raw) then s.state = "unreadable" return s end
    id = type(raw) == "number" and raw or nil
  end
  if not id then s.state = "empty" return s end
  s.itemId = id
  return P.Resolve(s)
end

-- fill in the item's details if the game has them now
function P.Resolve(s)
  if not s.itemId or s.state == "known" then return s end
  local d = itemDetails(s.link or s.itemId)
  if not d then s.state = "pending" return s end
  s.state = "known"
  s.quality = d.quality
  s.itemLevel = Obs.New("itemLevel", d.level, "native")
  return s
end

function P.Talents(unit, isSelf)
  local t = {}
  if isSelf then
    t.spec = Obs.Unsupported("spec", "your own talents are on the Talents page")
    t.points = Obs.Unsupported("talentPoints", "your own talents are on the Talents page")
    return t
  end
  if C.Resolve("GetInspectSpecialization") then
    local spec = readable(C.Call("GetInspectSpecialization", unit))
    if type(spec) == "number" and spec > 0 then t.spec = Obs.New("spec", spec, "native")
    else t.spec = Obs.Unknown("spec", spec == 0 and "no specialization reported" or "not readable") end
  else
    t.spec = Obs.Unsupported("spec", "no inspect specialization API")
  end
  -- Traits tree of the inspected player
  local consts = rawget(_G, "Constants")
  local id = consts and consts.TraitConsts and consts.TraitConsts.INSPECT_TRAIT_CONFIG_ID
  id = readable(id)
  local getInfo, getNodes, nodeInfo = C.Resolve("C_Traits.GetConfigInfo"), C.Resolve("C_Traits.GetTreeNodes"), C.Resolve("C_Traits.GetNodeInfo")
  if type(id) ~= "number" or not (getInfo and getNodes and nodeInfo) then
    t.points = Obs.Unsupported("talentPoints", "no inspect talent API")
    return t
  end
  local ok, info = pcall(getInfo, id)
  local trees = ok and type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs or nil
  if not trees or #trees == 0 then t.points = Obs.Unknown("talentPoints", "no talent tree answered") return t end
  local spent, seen, unread = 0, 0, 0
  for _, tree in ipairs(trees) do
    local okN, nodes = pcall(getNodes, tree)
    if okN and type(nodes) == "table" then
      for _, node in ipairs(nodes) do
        if seen >= P.NODES_MAX then break end
        seen = seen + 1
        local okI, n = pcall(nodeInfo, id, node)
        local rank = okI and type(n) == "table" and readable(n.ranksPurchased or n.currentRank) or nil
        if type(rank) == "number" and Obs.Finite(rank) and rank >= 0 then spent = spent + rank else unread = unread + 1 end
      end
    end
  end
  t.nodes = seen
  if seen == 0 then t.points = Obs.Unknown("talentPoints", "talent tree has no nodes")
  elseif unread > 0 then t.points = Obs.Unknown("talentPoints", unread .. " of " .. seen .. " talents unreadable")
  else t.points = Obs.New("talentPoints", spent, "native") end
  return t
end

-- role evidence in order of strength; never overwrites an explicit one
function P.Role(member, talents, manual)
  if manual and ns.Vanguard.Roster.ROLES[manual] then
    return { value = manual, source = "manual", note = "you set it" }
  end
  if member and Obs.Known(member.role) then
    return { value = member.role.value, source = "assigned", note = "the group's role" }
  end
  local spec = talents and Obs.Num(talents.spec)
  if spec then
    local r = readable(C.Call("GetSpecializationRoleByID", spec))
    if type(r) == "string" and ns.Vanguard.Roster.ROLES[r] then
      return { value = r, source = "tentative", note = "from their talents (the game's answer); not assigned" }
    end
  end
  return { value = nil, source = "unknown", note = "no role assigned" }
end

function P.Collect(unit, member, rev)
  local p = { key = member and member.key, rev = rev, at = (GetTime and GetTime()) or 0, slots = {},
    count = { known = 0, pending = 0, empty = 0, unreadable = 0, unavailable = 0 } }
  for _, slot in ipairs(P.SLOTS) do
    local s = P.Slot(unit, slot)
    p.slots[#p.slots + 1] = s
  end
  p.talents = P.Talents(unit, member and member.self)
  P.Count(p)
  return p
end

function P.Count(p)
  local c = { known = 0, pending = 0, empty = 0, unreadable = 0, unavailable = 0 }
  local sum, n = 0, 0
  for _, s in ipairs(p.slots) do
    c[s.state] = (c[s.state] or 0) + 1
    local lvl = Obs.Num(s.itemLevel)
    if lvl and s.slot ~= 18 then sum, n = sum + lvl, n + 1 end
  end
  p.count = c
  -- average of the slots we know, labelled with how many that is
  p.itemLevel = n > 0 and Obs.New("itemLevel", sum / n, "native") or Obs.Unknown("itemLevel", "no item levels read")
  p.itemLevelSlots = n
  return p
end

-- re-check pending slots; returns how many are still pending
function P.ResolvePending(p)
  local left = 0
  for _, s in ipairs(p.slots) do
    if s.state == "pending" then P.Resolve(s) end
    if s.state == "pending" then left = left + 1 end
  end
  P.Count(p)
  return left
end
