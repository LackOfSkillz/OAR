-- tools/vanguard_tables.lua
-- VG07-04: the addon's own Vanguard tables (class roles, class capabilities,
-- researched boss needs, raid sizes) as canonical JSON for the desktop
-- companion, so both sides use one copy. Used two ways:
--   python tools/lua.py tools/vanguard_tables.lua write   (regenerates the file)
--   dofile("tools/vanguard_tables.lua")                   (returns the module; the
--     spec tests/spec/vanguard_desktop_spec.lua fails when the file drifts)
-- Output: companion/outrider_companion/vanguard/addon_tables.json
-- Nothing here is verified in game (the facts stay verified = false).

local M = { OUT = "companion/outrider_companion/vanguard/addon_tables.json" }

local function sortedKeys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function isArray(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  for i = 1, n do if t[i] == nil then return false end end
  return true
end

local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function enc(v, out)
  local ty = type(v)
  if ty == "table" then
    if next(v) ~= nil and isArray(v) then
      out[#out + 1] = "["
      for i, x in ipairs(v) do if i > 1 then out[#out + 1] = "," end enc(x, out) end
      out[#out + 1] = "]"
    else
      out[#out + 1] = "{"
      for i, k in ipairs(sortedKeys(v)) do
        if i > 1 then out[#out + 1] = "," end
        enc(tostring(k), out)
        out[#out + 1] = ":"
        enc(v[k], out)
      end
      out[#out + 1] = "}"
    end
  elseif ty == "string" then
    out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
  elseif ty == "number" then
    out[#out + 1] = (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%.0f", v) or string.format("%.17g", v)
  elseif ty == "boolean" then
    out[#out + 1] = tostring(v)
  else
    out[#out + 1] = "null"
  end
end

function M.json(v)
  local out = {}
  enc(v, out)
  return table.concat(out)
end

-- ns: a loaded Outrider namespace (wowmock)
function M.build(ns)
  local V = ns.Vanguard
  local roles = {}
  for class, t in pairs(V.Roles.BY_CLASS) do
    roles[class] = {}
    for role, kinds in pairs(t) do
      local k = {}
      for i, x in ipairs(kinds) do k[i] = x end
      roles[class][role] = k
    end
  end
  local caps = {}
  for cap, c in pairs(V.Utility.CAPS) do
    local classes = sortedKeys(c.spells or {})
    caps[cap] = { label = c.label, scope = c.scope, classes = classes }
  end
  local bosses = {}
  local facts = ns.VanguardFacts or {}
  for inst, b in pairs(facts.bosses or {}) do
    local list = {}
    for i, boss in ipairs(b.list or {}) do
      list[i] = { name = boss.name, optional = boss.optional and true or nil, tags = sortedKeys(boss.tags or {}) }
    end
    bosses[inst] = { kind = b.kind, source = b.source, list = list }
  end
  local raids = {}
  for name, r in pairs(facts.raids or {}) do raids[name] = { size = r.size, status = r.status } end
  local tagCap, tagNote = {}, {}
  for k, v in pairs(V.Facts.TAG_CAP) do tagCap[k] = v end
  for k, v in pairs(V.Facts.TAG_NOTE) do tagNote[k] = v end
  return { v = 1, verified = false, factsVersion = facts.version, roles = roles, caps = caps,
    tagCap = tagCap, tagNote = tagNote, bosses = bosses, raids = raids }
end

function M.load()
  package.path = "./tests/lib/?.lua;" .. package.path
  local mock = require("wowmock")
  local game = mock.new()
  local ns = game:loadAddon()
  return ns
end

if arg and arg[1] == "write" and tostring(arg[0]):find("vanguard_tables") then
  local text = M.json(M.build(M.load())) .. "\n"
  local f = assert(io.open(M.OUT, "wb"))
  f:write(text)
  f:close()
  print("wrote " .. M.OUT .. " (" .. #text .. " bytes)")
end

return M
