-- Core/Profiles.lua
-- Every character has its own settings automatically. Profiles add:
--   * export string  (share a setup, back it up, paste it on another account)
--   * import string  (validated: wrong kind / wrong version / edited text is refused)
--   * copy from one of your other characters
-- Character metadata (class, level, logins) is never copied.

local _, ns = ...
local Profiles = { name = "profiles", KIND = "oar-profile", VERSION = 1 }
ns.Profiles = Profiles

local COPYABLE = { "modules", "hub" }

local function pick(char)
  local out = {}
  for _, field in ipairs(COPYABLE) do out[field] = ns.CopyTable(char[field]) end
  return out
end

function Profiles:Build(charKey)
  local char = charKey and ns.db.raw.chars[charKey] or ns.db.char
  if not char then return nil, "no such character" end
  return {
    kind = self.KIND, v = self.VERSION,
    from = charKey or ns.db.key,
    class = char.meta and char.meta.class,
    at = time(),
    addon = ns.version,
    data = pick(char),
  }
end

function Profiles:Export(charKey)
  local p, err = self:Build(charKey)
  if not p then return nil, err end
  return ns.Serialize.Export(p)
end

function Profiles:Validate(p)
  if type(p) ~= "table" then return false, "not a profile" end
  if p.kind ~= self.KIND then return false, "this string is not an OAR profile" end
  if type(p.v) ~= "number" or p.v > self.VERSION then return false, "profile is from a newer OAR version" end
  if type(p.data) ~= "table" then return false, "profile has no data" end
  for field, value in pairs(p.data) do
    local allowed = false
    for _, f in ipairs(COPYABLE) do if f == field then allowed = true end end
    if not allowed then return false, "unexpected field " .. tostring(field) end
    if type(value) ~= "table" then return false, "bad field " .. tostring(field) end
  end
  return true
end

-- Applies a validated profile to the current character. Settings only take
-- full effect after /reload (modules re-read settings on enable).
function Profiles:Apply(p)
  local ok, err = self:Validate(p)
  if not ok then return false, err end
  for field, value in pairs(p.data) do
    ns.db.char[field] = ns.CopyTable(value)
  end
  ns.ApplyDefaults(ns.db.char, ns.DB.charDefaults)
  for name in pairs(ns.DB.moduleDefaults) do ns.DB:ModuleSettings(name) end
  if ns.Log then ns.Log:Info("profiles", "applied profile from %s", tostring(p.from)) end
  ns.Events:Fire("OAR_PROFILE_CHANGED", p.from)
  return true
end

function Profiles:Import(text)
  local p, err = ns.Serialize.Import(text)
  if not p then return false, err end
  return self:Apply(p)
end

function Profiles:CopyFrom(charKey)
  if charKey == ns.db.key then return false, "that is the current character" end
  local p, err = self:Build(charKey)
  if not p then return false, err end
  return self:Apply(p)
end
