-- Data/Registry.lua
-- Data packs are plain Lua tables (no logic) keyed by game IDs, never names.
-- Packs register here; the registry validates required fields so a typo in a
-- pack is caught by the unit tests, not in game. Full field reference:
-- docs/DATA_SCHEMAS.md. Big packs can later move into load-on-demand addons
-- (Outrider_Data_Gear etc.) that call Outrider.Data:Register(...) the same way.
--
-- Rule: never invent IDs or coordinates. Fill them from in-game capture
-- (discovery mode) or a cited source, and set verified = true only after
-- Gary has seen it in game on WoW Forever.

local _, ns = ...
local Data = { name = "data", packs = {}, index = {} }
ns.Data = Data

-- required fields per kind: field = lua type
Data.SCHEMAS = {
  rare   = { npcID = "number", name = "string", mapID = "number", verified = "boolean" },
  poi    = { id = "string", kind = "string", mapID = "number", x = "number", y = "number", verified = "boolean" },
  macro  = { id = "string", name = "string", class = "string", body = "string", verified = "boolean" },
  beast  = { family = "string" },
  gear   = { itemID = "number", source = "string" },
  recipe = { spellID = "number", profession = "string" },
  fish   = { itemID = "number", mapID = "number" },
  herb   = { name = "string", source = "string", verified = "boolean" },
  link   = { id = "string", kind = "string", source = "string", verified = "boolean", from = "table", to = "table" },
}

Data.CONFIDENCE = { verified = true, community = true, inferred = true, unknown = true }

Data.KEY = { rare = "npcID", poi = "id", macro = "id", beast = "family", gear = "itemID", recipe = "spellID", herb = "name", link = "id" }

function Data:Validate(kind, entry)
  local schema = self.SCHEMAS[kind]
  if not schema then return false, "unknown kind " .. tostring(kind) end
  if type(entry) ~= "table" then return false, "entry is not a table" end
  for field, t in pairs(schema) do
    if type(entry[field]) ~= t then
      return false, string.format("%s.%s should be %s, got %s", kind, field, t, type(entry[field]))
    end
  end
  if (kind == "poi" or kind == "rare") and entry.x ~= nil then
    if type(entry.x) ~= "number" or entry.x < 0 or entry.x > 1 or type(entry.y) ~= "number" or entry.y < 0 or entry.y > 1 then
      return false, kind .. " x/y must be 0..1 map fractions"
    end
  end
  if kind == "macro" and #entry.body > 255 then return false, "macro " .. entry.id .. " is over 255 characters" end
  -- Provenance (optional): confidence = verified | community | inferred | unknown,
  -- verifiedOn = { build = "70862", date = "2026-11-14" } when Gary confirmed it.
  if entry.confidence ~= nil and not Data.CONFIDENCE[entry.confidence] then
    return false, "confidence must be verified, community, inferred or unknown"
  end
  if entry.verified == true and entry.confidence ~= nil and entry.confidence ~= "verified" then
    return false, "verified = true but confidence is " .. tostring(entry.confidence)
  end
  return true
end

-- Returns number accepted, list of errors
function Data:Register(kind, packName, entries)
  local errors, accepted = {}, 0
  self.packs[kind] = self.packs[kind] or {}
  self.packs[kind][packName] = entries
  self.index[kind] = self.index[kind] or {}
  local keyField = self.KEY[kind]
  for i, entry in ipairs(entries or {}) do
    local ok, err = self:Validate(kind, entry)
    if ok then
      accepted = accepted + 1
      if keyField then self.index[kind][entry[keyField]] = entry end
    else
      errors[#errors + 1] = string.format("%s[%d]: %s", packName, i, err)
    end
  end
  for _, e in ipairs(errors) do if ns.Log then ns.Log:Warn("data", "%s", e) end end
  if ns.Events and ns.Events.Fire then ns.Events:Fire("OTR_DATA_CHANGED", kind) end
  return accepted, errors
end

function Data:Get(kind, key)
  return self.index[kind] and self.index[kind][key]
end

function Data:All(kind)
  local out = {}
  for _, entry in pairs(self.index[kind] or {}) do out[#out + 1] = entry end
  return out
end
