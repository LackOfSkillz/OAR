-- Core/DB.lua
-- SavedVariables layout (account-wide file, one section per character):
--
-- OAR_DB = {
--   schema = 1,
--   global = { debug, minimap, loads, sessions, lastSave, probe, discovered ... },
--   chars  = { ["Torrant-Realm"] = { meta, modules = { [name] = { enabled, settings } }, hub ... } },
-- }
--
-- Why account-wide and not SavedVariablesPerCharacter: the hub can show and
-- copy settings across characters, and the Phase 9 companion app can read
-- every character from one file. "Character aware" = ns.db.char is the
-- section for whoever is logged in.

local _, ns = ...
local DB = {
  name = "db",
  globalDefaults = {
    debug = false,
    minimap = { hide = false, angle = 200 },
    loads = 0,
    sessions = {},
  },
  charDefaults = {
    modules = {},
    hub = { point = "CENTER", x = 0, y = 0, shown = false },
    meta = { logins = 0 },
  },
  moduleDefaults = {},
  migrations = {
    -- [1] = function(db) ... upgrade schema 1 -> 2 ... end,
  },
  MAX_SESSIONS = 15,
}
ns.DB = DB

function DB:RegisterModuleDefaults(name, defaults)
  self.moduleDefaults[name] = defaults or {}
  if ns.db then self:ModuleSettings(name) end
end

-- Upgrades a COPY of the saved data. Returns the upgraded copy, or nil and a
-- reason. The original table is never modified, so a failed or missing
-- migration cannot damage what is on disk.
function DB:Migrate(original)
  local from = type(original.schema) == "number" and original.schema or ns.SCHEMA
  if from > ns.SCHEMA then
    return nil, string.format("saved by a newer OAR (schema %d, this version understands %d)", from, ns.SCHEMA)
  end
  if from == ns.SCHEMA then original.schema = from return original end
  local db = ns.CopyTable(original)
  db.schema = from
  while db.schema < ns.SCHEMA do
    local step = self.migrations[db.schema]
    if not step then return nil, string.format("no migration from schema %d", db.schema) end
    local ok, err = pcall(step, db)
    if not ok then return nil, string.format("migration from schema %d failed: %s", db.schema, tostring(err)) end
    db.schema = db.schema + 1
    if ns.Log then ns.Log:Info("db", "migrated to schema %d", db.schema) end
  end
  return db
end

-- Safe mode: the saved file is left exactly as loaded (and written back
-- unchanged at logout); this session runs on temporary in-memory settings.
function DB:EnterSafeMode(reason)
  self.safeMode = reason
  if ns.Log then ns.Log:Error("db", "safe mode: %s. Saved settings untouched; using temporary settings.", reason) end
  ns.Print("|cffff6060safe mode|r: %s. Your saved settings are untouched; this session uses temporary settings.", reason)
  return { schema = ns.SCHEMA, global = {}, chars = {} }
end

function DB:Init()
  self.freshFile = type(OAR_DB) ~= "table"
  if self.freshFile then OAR_DB = {} end
  self.safeMode = nil
  local db, why = self:Migrate(OAR_DB)
  if db then OAR_DB = db else db = self:EnterSafeMode(why) end
  db.global = type(db.global) == "table" and db.global or {}
  db.chars = type(db.chars) == "table" and db.chars or {}
  ns.ApplyDefaults(db.global, self.globalDefaults)

  -- SavedVariables round trip (Phase 0, P0-07): if we can see what the last
  -- session wrote at logout, the client read the file back.
  self.previousSave = db.global.lastSave
  db.global.loads = (db.global.loads or 0) + 1

  local key = ns.CharKey()
  self.freshChar = db.chars[key] == nil
  db.chars[key] = type(db.chars[key]) == "table" and db.chars[key] or {}
  local char = db.chars[key]
  ns.ApplyDefaults(char, self.charDefaults)
  local meta = char.meta
  meta.class = ns.PlayerClass()
  if UnitRace then meta.race = select(2, UnitRace("player")) end
  if UnitLevel then meta.level = UnitLevel("player") end
  if UnitFactionGroup then meta.faction = UnitFactionGroup("player") end
  meta.logins = (meta.logins or 0) + 1
  meta.lastLogin = time()
  meta.created = meta.created or meta.lastLogin

  ns.db = { global = db.global, char = char, key = key, raw = db }

  for name in pairs(self.moduleDefaults) do self:ModuleSettings(name) end
  return ns.db
end

-- Status for "/oar status" and the P0-07 round-trip check.
function DB:SavedVariablesStatus()
  if self.safeMode then return "SAFE MODE (" .. self.safeMode .. ")", 0 end
  local loads = ns.db and ns.db.global.loads or 0
  if self.previousSave then
    return "yes", loads
  elseif loads <= 1 then
    return "unknown (first load: /reload and check again)", loads
  end
  return "NO (loads counter moved but lastSave missing)", loads
end

function DB:ModuleState(name)
  local m = ns.db.char.modules[name]
  if not m then m = {} ns.db.char.modules[name] = m end
  return m
end

function DB:ModuleSettings(name)
  local m = self:ModuleState(name)
  m.settings = type(m.settings) == "table" and m.settings or {}
  ns.ApplyDefaults(m.settings, self.moduleDefaults[name])
  return m.settings
end

function DB:StartSession(id)
  local g = ns.db.global
  table.insert(g.sessions, { id = id, t = time(), char = ns.db.key, build = ns.build, version = ns.version })
  while #g.sessions > self.MAX_SESSIONS do table.remove(g.sessions, 1) end
end

function DB:OnLogout()
  if not ns.db or self.reset or self.safeMode then return end
  ns.db.global.lastSave = { t = time(), session = ns.session, char = ns.db.key, build = ns.build }
end

-- Other characters (for "copy settings from" and the hub's character list)
function DB:Characters()
  local out = {}
  for key, c in pairs(ns.db.raw.chars) do
    out[#out + 1] = { key = key, class = c.meta and c.meta.class, level = c.meta and c.meta.level,
                      lastLogin = c.meta and c.meta.lastLogin or 0, current = key == ns.db.key }
  end
  table.sort(out, function(a, b) return a.lastLogin > b.lastLogin end)
  return out
end

-- Both resets also rebind the live tables so nothing keeps writing into the
-- discarded ones before the reload the slash command performs.
function DB:ResetChar()
  ns.db.raw.chars[ns.db.key] = nil
  local char = ns.ApplyDefaults({}, self.charDefaults)
  ns.db.raw.chars[ns.db.key] = char
  ns.db.char = char
  for name in pairs(self.moduleDefaults) do self:ModuleSettings(name) end
end

function DB:ResetAll()
  OAR_DB = nil
  self.reset = true
end
