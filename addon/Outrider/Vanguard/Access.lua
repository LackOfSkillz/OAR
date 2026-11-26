-- Vanguard/Access.lua
-- VG03-02: can you get in? A small graph of prerequisites with AND and OR:
--   { kind = "all", children = {...} }   every child met
--   { kind = "any", children = {...} }   one child met
--   { kind = "level", value = 55 }        your level (read now)
--   { kind = "quest", value = questID }   finished, per the game's quest flag
--   { kind = "item", value = itemID }     a key or item you carry or bank
--   { kind = "manual", value = "Scholomance" }  your own answer
--   { kind = "ref", value = "node id" }   another node (for shared parts)
-- Results: met, unmet, unknown. Unknown is never "denied": a quest flag or
-- item count we can't read, a missing answer, or a loop in the graph all end
-- as unknown. Evaluation is memoized and guarded against cycles.
-- The installed data has no attunement chains, so each place gets: level
-- range (reference data) AND your own access answer when the place needs one.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local Acc = { VERSION = 1, MAX_DEPTH = 32 }
ns.Vanguard.Access = Acc

local function leaf(node, env)
  local k, v = node.kind, node.value
  if k == "level" then
    local lvl = env.level
    if type(lvl) ~= "number" then return "unknown", "level not readable" end
    return lvl >= v and "met" or "unmet", "level " .. v
  elseif k == "quest" then
    local done = env.quest and env.quest(v)
    if done == true then return "met", "quest done" end
    if done == false then return "unmet", "quest not done" end
    return "unknown", "quest state not readable"
  elseif k == "item" then
    local n = env.item and env.item(v)
    if type(n) ~= "number" then return "unknown", "item count not readable" end
    return n > 0 and "met" or "unmet", n > 0 and "you have it" or "not carried or banked"
  elseif k == "holder" then
    -- one member's key opens it for the group: you not carrying it isn't a no
    local n = env.item and env.item(v)
    if type(n) ~= "number" then return "unknown", "item count not readable" end
    if n > 0 then return "met", "you carry the key" end
    return "unknown", "you don't carry the key; someone else in the group may"
  elseif k == "manual" then
    local a = env.manual and env.manual(v)
    if a == true then return "met", "you said you have it" end
    if a == false then return "unmet", "you said you don't have it" end
    return "unknown", "not answered"
  end
  return "unknown", "unknown kind " .. tostring(k)
end

-- graph: { [id] = node }, root id; env: { level, quest(id), item(id), manual(name) }
function Acc.Eval(graph, rootId, env)
  local memo, onStack = {}, {}
  local function eval(id, depth)
    if memo[id] then return memo[id][1], memo[id][2] end
    if onStack[id] then return "unknown", "loop in the prerequisites" end
    if depth > Acc.MAX_DEPTH then return "unknown", "too deep" end
    local node = graph[id]
    if not node then return "unknown", "missing node " .. tostring(id) end
    onStack[id] = true
    local state, why
    if node.kind == "all" or node.kind == "any" then
      local met, unmet, unknown, reasons = 0, 0, 0, {}
      for _, child in ipairs(node.children or {}) do
        local s, r = eval(child, depth + 1)
        if s == "met" then met = met + 1 elseif s == "unmet" then unmet = unmet + 1 reasons[#reasons + 1] = r
        else unknown = unknown + 1 reasons[#reasons + 1] = r end
      end
      if node.kind == "all" then
        if unmet > 0 then state = "unmet" elseif unknown > 0 then state = "unknown" else state = "met" end
      else
        if met > 0 then state = "met" elseif unknown > 0 then state = "unknown" else state = "unmet" end
      end
      if #(node.children or {}) == 0 then state = node.kind == "all" and "met" or "unknown" end
      why = table.concat(reasons, "; ")
    elseif node.kind == "ref" then
      state, why = eval(node.value, depth + 1)
    else
      state, why = leaf(node, env)
    end
    onStack[id] = nil
    memo[id] = { state, why }
    return state, why
  end
  return eval(rootId, 0)
end

-- the graph for one catalog entry and your answers
function Acc.ForInstance(e, st)
  local g = { root = { kind = "all", children = {} } }
  if e and e.min then
    g.level = { kind = "level", value = e.min }
    g.root.children[#g.root.children + 1] = "level"
  end
  local a = st and st.access and e and st.access[e.instanceId]
  if a ~= nil then
    -- your own answer wins over the researched facts
    g.access = { kind = "manual", value = e.instanceId }
    g.root.children[#g.root.children + 1] = "access"
    return g
  end
  local f = e and e.access
  if type(f) == "table" and f.disputed then
    g.access = { kind = "manual", value = e.instanceId }
    g.root.children[#g.root.children + 1] = "access"
    return g
  end
  if type(f) == "table" and f.needs and f.needs ~= "none" then
    local item = tonumber(f.item) or (type(f.itemName) == "string" and f.itemName) or nil
    if item then
      -- an item by id, or by name (the game's item count takes either)
      g.access = { kind = f.who == "each" and "item" or "holder", value = item }
      g.root.children[#g.root.children + 1] = "access"
    elseif tonumber(f.quest) then
      g.access = { kind = "quest", value = tonumber(f.quest) }
      g.root.children[#g.root.children + 1] = "access"
    else
      g.access = { kind = "manual", value = e.instanceId }
      g.root.children[#g.root.children + 1] = "access"
    end
  end
  return g
end

function Acc.Env(st)
  local get = C.Resolve("C_Item.GetItemCount") or C.Resolve("GetItemCount")
  return {
    level = C.Readable(C.Call("UnitLevel", "player")),
    quest = function(id)
      local v = C.Readable(C.Call("C_QuestLog.IsQuestFlaggedCompleted", id))
      if type(v) == "boolean" then return v end
    end,
    item = function(id)
      if not get then return nil end
      local ok, n = pcall(get, id, true)
      n = ok and C.Readable(n) or nil
      return type(n) == "number" and n or nil
    end,
    manual = function(name) return st and st.access and st.access[name] end,
  }
end

function Acc.Check(e, st)
  local g = Acc.ForInstance(e, st)
  if #g.root.children == 0 then return "unknown", "no prerequisites known" end
  return Acc.Eval(g, "root", Acc.Env(st))
end
