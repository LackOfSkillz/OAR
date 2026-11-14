-- tools/export_shared.lua
-- Writes Gary's account-wide knowledge from his SavedVariables into a data
-- addon (Outrider_Data_Shared) so family installs start with it (Gary,
-- 2026-11-14: "all the db info needs to transfer"). Only world knowledge is
-- copied: NPCs met, places, gathering nodes, rare sightings, spawn logs, rare
-- fight profiles, auction prices, pet diets, travel links, fishing catches.
-- Never copied: characters, bags, gold, sessions, logs, settings.
--   python tools/lua.py tools/export_shared.lua <Outrider.lua> <outDir> <stamp>

local svPath, outDir, stamp = arg[1], arg[2], arg[3] or "unknown"
assert(svPath and outDir, "usage: export_shared.lua <Outrider.lua> <outDir> [stamp]")

local env = {}
local chunk = assert(loadfile(svPath))
setfenv(chunk, env)
chunk()
local g = assert(env.Outrider_DB and env.Outrider_DB.global, "no Outrider_DB.global in " .. svPath)

local KEYS = { "discovered", "pois", "nodes", "sightings", "rareProfiles", "spawnLogs", "prices", "petDiet",
  "travelLinks", "taxiNodes", "fishing" }

local function isIdent(k) return type(k) == "string" and k:match("^[%a_][%w_]*$") end

local out = {}
local function w(s) out[#out + 1] = s end

local function ser(v, ind)
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then w("0") else w(string.format("%.14g", v)) end
  elseif t == "string" then w(string.format("%q", v))
  elseif t == "boolean" then w(tostring(v))
  elseif t == "table" then
    local keys = {}
    for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b)
      if type(a) == type(b) then return a < b end
      return type(a) == "number"
    end)
    w("{\n")
    for _, k in ipairs(keys) do
      local val = v[k]
      local vt = type(val)
      if vt == "number" or vt == "string" or vt == "boolean" or vt == "table" then
        w(ind .. "  ")
        if isIdent(k) then w(k) elseif type(k) == "number" then w("[" .. string.format("%.14g", k) .. "]") else w("[" .. string.format("%q", k) .. "]") end
        w(" = ")
        ser(val, ind .. "  ")
        w(",\n")
      end
    end
    w(ind .. "}")
  else
    w("nil")
  end
end

w("-- Outrider_Data_Shared: world knowledge exported from Gary's account (tools/export_shared.lua).\n")
w("-- Merged into each new account's Outrider data at first login; never overwrites what it already has.\n")
w("Outrider_DataShared = {\n  version = " .. string.format("%q", stamp) .. ",\n  data = {\n")
local counts = {}
for _, k in ipairs(KEYS) do
  local v = g[k]
  if type(v) == "table" then
    w("    " .. k .. " = ")
    ser(v, "    ")
    w(",\n")
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    counts[#counts + 1] = k .. " " .. n
  end
end
w("  },\n}\n")

local f = assert(io.open(outDir .. "/Data.lua", "wb"))
f:write(table.concat(out))
f:close()
local toc = assert(io.open(outDir .. "/Outrider_Data_Shared.toc", "wb"))
toc:write("## Interface: 16001\n## Title: Outrider Data: shared knowledge\n" ..
  "## Notes: NPCs, places, nodes, rare sightings and prices collected by Outrider, for family installs.\n" ..
  "## LoadOnDemand: 1\n## X-Exported: " .. stamp .. "\n\nData.lua\n")
toc:close()
print("exported " .. table.concat(counts, ", "))
