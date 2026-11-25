-- tools/preservation_flatten.lua  (review OI-FR14)
-- Runs one data file in a sandbox and lists every value it defines as
-- "path<TAB>value" lines, so tools/preservation_check.py can compare a file's
-- full contents with an earlier commit, not just its record ids.
--   Flatten(text, name) -> lines (a table of strings), unverifiable (a table of
--   paths it could not read: functions, cycles), or nil, error
-- The sandbox gives the file `ns` (with a Data:Register that keeps the
-- entries) and a private global table; nothing outside it is touched.
-- Lists of records are keyed by the record's identity (id, key, npcID, ...)
-- rather than position, so inserting a record doesn't look like changing all
-- the ones after it; two records with one identity are #1 and #2, so losing a
-- duplicate is seen.

local IDENT = { "id", "key", "npcID", "npc", "questID", "itemID", "spellID", "mapID", "name", "title", "slug" }

local SAFE = { "string", "table", "math", "pairs", "ipairs", "type", "tostring", "tonumber", "select", "unpack", "next",
  "setmetatable", "getmetatable", "rawget", "rawset", "rawequal", "error", "assert", "pcall", "format" }

local function sandbox()
  local env = {}
  for _, k in ipairs(SAFE) do env[k] = _G[k] end
  env._G = env
  local packs = {}
  local ns = { Data = { packs = packs } }
  function ns.Data:Register(kind, name, entries)
    packs[kind] = packs[kind] or {}
    packs[kind][name] = entries
    return type(entries) == "table" and #entries or 0
  end
  function ns.Data.Validate() return true end
  return env, ns
end

local function scalar(v)
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t == "number" then return string.format("%.10g", v) end
  if t == "boolean" then return tostring(v) end
  return nil
end

local function isList(t)
  local n = #t
  if n == 0 then return false end
  local c = 0
  for _ in pairs(t) do c = c + 1 end
  return c == n
end

local function identity(e)
  if type(e) ~= "table" then return nil end
  for _, f in ipairs(IDENT) do
    local v = rawget(e, f)
    if type(v) == "string" or type(v) == "number" then return f .. "=" .. tostring(v) end
  end
  return nil
end

function Flatten(text, name)
  local chunk, err = loadstring(text, "=" .. tostring(name))
  if not chunk then return nil, err end
  local env, ns = sandbox()
  setfenv(chunk, env)
  local ok, e = pcall(chunk, "Outrider", ns)
  if not ok then return nil, tostring(e) end
  local lines, unverifiable, seen = {}, {}, {}
  local function walk(v, path, depth)
    local s = scalar(v)
    if s then lines[#lines + 1] = path .. "\t" .. s return end
    if type(v) == "function" then
      -- a loader builds data on first use (FightPlans.loaders.HUNTER): run
      -- it and compare what it builds; any other function is code, not data
      if path:find("%.loaders%.[%w_]+$") then
        local okL, built = pcall(v)
        if okL and type(built) == "table" then walk(built, path .. "()", depth + 1)
        else unverifiable[#unverifiable + 1] = path .. " (loader failed)" end
      end
      return
    end
    if type(v) ~= "table" then return end
    if seen[v] then unverifiable[#unverifiable + 1] = path .. " (repeated table)" return end
    if depth > 40 then unverifiable[#unverifiable + 1] = path .. " (too deep)" return end
    seen[v] = true
    if next(v) == nil then lines[#lines + 1] = path .. "\t{}" end
    if isList(v) then
      local count = {}
      for i, e in ipairs(v) do
        local id = identity(e)
        local k
        if id then
          count[id] = (count[id] or 0) + 1
          k = "[" .. id .. "#" .. count[id] .. "]"
        else
          k = "[" .. i .. "]"
        end
        walk(e, path .. k, depth + 1)
      end
    else
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      for _, k in ipairs(keys) do
        local part = type(k) == "string" and ("." .. k) or ("[" .. tostring(k) .. "]")
        walk(v[k], path .. part, depth + 1)
      end
    end
    seen[v] = nil
  end
  local nsKeys = {}
  for k in pairs(ns) do nsKeys[#nsKeys + 1] = k end
  table.sort(nsKeys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(nsKeys) do
    if k == "Data" then walk(ns.Data.packs, "ns.Data.packs", 0)
    else walk(ns[k], "ns." .. tostring(k), 0) end
  end
  local gKeys = {}
  for k, v in pairs(env) do if v ~= _G[k] and k ~= "_G" then gKeys[#gKeys + 1] = k end end
  table.sort(gKeys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(gKeys) do walk(env[k], "G." .. tostring(k), 0) end
  return lines, unverifiable
end
