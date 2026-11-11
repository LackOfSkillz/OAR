-- tests/lib/wowmock.lua
-- A small fake of the WoW client, enough to load Outrider the way the game does:
-- files in TOC order, each called with (addonName, ns), inside a sandbox
-- that has WoW's globals and NOT Lua's io/os (WoW has neither).
--
-- Usage:
--   local mock = require("wowmock")
--   local game = mock.new({ name = "Torrant", class = "HUNTER" })
--   game:loadAddon()            -- runs every TOC file
--   game:login()                -- ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD
--   local text = game:logout()  -- PLAYER_LOGOUT, returns SavedVariables file text
--   local game2 = mock.new({ savedVariables = text })   -- "next session"

local M = {}

M.ADDON = "Outrider"
M.ROOT = "addon/Outrider/"

local function noop() end

-- ------------------------------------------------------------------ helpers
local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end
M.readFile = readFile

function M.tocFiles(tocPath)
  local text = assert(readFile(tocPath or (M.ROOT .. M.ADDON .. ".toc")), "cannot read TOC")
  local files, meta = {}, {}
  for line in text:gmatch("[^\r\n]+") do
    local k, v = line:match("^##%s*([%w%-_]+)%s*:%s*(.-)%s*$")
    if k then meta[k] = v
    elseif not line:match("^%s*#") and line:match("%S") then
      files[#files + 1] = (line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/"))
    end
  end
  return files, meta
end

-- Lua-source writer in the same spirit as WoW's SavedVariables writer.
local function serialize(v, indent, seen)
  indent = indent or ""
  local t = type(v)
  if t == "string" then return string.format("%q", v)
  elseif t == "number" then
    if v == math.floor(v) then return string.format("%.0f", v) end
    return string.format("%.17g", v)
  elseif t == "boolean" or t == "nil" then return tostring(v)
  elseif t == "table" then
    seen = seen or {}
    assert(not seen[v], "cycle in saved variables")
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
      return type(a) < type(b)
    end)
    local inner = indent .. "\t"
    local parts = {}
    for _, k in ipairs(keys) do
      local kv = v[k]
      local kt = type(kv)
      if kt ~= "function" and kt ~= "userdata" and kt ~= "thread" then
        local key = type(k) == "string" and string.format("[%q]", k) or ("[" .. serialize(k) .. "]")
        parts[#parts + 1] = inner .. key .. " = " .. serialize(kv, inner, seen) .. ","
      end
    end
    seen[v] = nil
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
  end
  return "nil"
end
M.serialize = serialize

-- ------------------------------------------------------------------ frames
local Game = {}
Game.__index = Game

local function newRegion(game, kind, name, parent)
  local r = {
    __kind = kind, __name = name, __parent = parent, __shown = (kind ~= "Frame" and true) or true,
    __scripts = {}, __events = {}, __points = {}, __w = 0, __h = 0, __text = nil,
  }
  local methods = game.methods
  -- Unknown Methods (Capitalized, like the real API) are no-ops; unknown
  -- lowercase fields are nil, as on a real frame table.
  setmetatable(r, { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return noop end
  end })
  game.frames[#game.frames + 1] = r
  if name then rawset(game.env, name, r) end
  return r
end
M.newRegion = newRegion

local function buildMethods(game)
  local m = {}
  m.RegisterEvent = function(self, event)
    if game.blockedEvents[event] then
      game.forbiddenAttempts = (game.forbiddenAttempts or 0) + 1
      error("Frame:RegisterEvent(): " .. event .. " is not allowed", 2)
    end
    self.__events[event] = true
  end
  m.UnregisterEvent = function(self, event) self.__events[event] = nil end
  m.UnregisterAllEvents = function(self) self.__events = {} end
  m.IsEventRegistered = function(self, event) return self.__events[event] == true end
  m.RegisterUnitEvent = m.RegisterEvent
  m.SetScript = function(self, what, fn) self.__scripts[what] = fn end
  m.GetScript = function(self, what) return self.__scripts[what] end
  m.HookScript = function(self, what, fn)
    local old = self.__scripts[what]
    self.__scripts[what] = function(...) if old then old(...) end fn(...) end
  end
  local function guard(self, what)
    if self.__protected and game.combat then
      game.blocked[#game.blocked + 1] = what .. "(" .. tostring(self.__name) .. ")"
    end
  end
  m.SetAttribute = function(self, k, v)
    guard(self, "SetAttribute")
    if not rawget(self, "__attrs") then rawset(self, "__attrs", {}) end
    self.__attrs[k] = v
  end
  m.GetAttribute = function(self, k) local a = rawget(self, "__attrs") return a and a[k] end
  m.RegisterForClicks = function(self, ...) self.__clicks = { ... } end
  m.SetAllPoints = noop
  m.IsMouseOver = function(self) return rawget(self, "__mouseOver") == true end
  m.SetColorTexture = noop
  m.Click = function(self, button)
    if self.__scripts.OnClick then self.__scripts.OnClick(self, button or "LeftButton", false) end
    local a = rawget(self, "__attrs")
    if self.__protected and a and a.type == "macro" then
      game.macrosRun[#game.macrosRun + 1] = a.macrotext
    end
  end
  m.Show = function(self)
    guard(self, "Show")
    local was = self.__shown
    self.__shown = true
    if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
  end
  m.Hide = function(self)
    guard(self, "Hide")
    local was = self.__shown
    self.__shown = false
    if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
  end
  m.SetShown = function(self, on) if on then m.Show(self) else m.Hide(self) end end
  m.IsShown = function(self) return self.__shown end
  m.IsVisible = function(self) return self.__shown end
  m.GetName = function(self) return self.__name end
  m.GetParent = function(self) return self.__parent end
  m.SetSize = function(self, w, h) self.__w, self.__h = w, h end
  m.SetWidth = function(self, w) self.__w = w end
  m.SetHeight = function(self, h) self.__h = h end
  m.GetWidth = function(self) return self.__w > 0 and self.__w or 140 end
  m.GetHeight = function(self) return self.__h > 0 and self.__h or 140 end
  m.GetCenter = function() return 0, 0 end
  m.GetEffectiveScale = function() return 1 end
  m.GetScale = function() return 1 end
  m.SetPoint = function(self, point, a, b, c, d)
    local rel, relPoint, x, y = nil, nil, 0, 0
    if type(a) == "number" then x, y = a, b
    elseif type(a) == "table" then rel, relPoint, x, y = a, b, c, d end
    if type(relPoint) == "number" then x, y, relPoint = relPoint, x, nil end
    self.__points[#self.__points + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
    -- A secure frame anchored to one of our insecure frames makes that frame
    -- protected in game (moving it gets the addon blocked). Record it.
    if self.__protected and type(rel) == "table" and not rel.__protected and rel ~= game.env.UIParent then
      game.secureAnchoredToInsecure = (game.secureAnchoredToInsecure or 0) + 1
    end
  end
  m.ClearAllPoints = function(self) guard(self, "ClearAllPoints") self.__points = {} end
  m.GetPoint = function(self, i)
    local p = self.__points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
  end
  m.GetNumPoints = function(self) return #self.__points end
  m.SetText = function(self, t)
    self.__text = t
    if self.__kind == "EditBox" and self.__scripts.OnTextChanged then self.__scripts.OnTextChanged(self, false) end
  end
  m.SetMinMaxValues = function(self, a, b) self.__min, self.__max = a, b end
  m.GetMinMaxValues = function(self) return self.__min, self.__max end
  m.SetValue = function(self, v)
    if self.__min then v = math.max(self.__min, math.min(self.__max, v)) end
    local changed = self.__value ~= v
    self.__value = v
    if changed and self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, v, false) end
  end
  m.GetValue = function(self) return self.__value end
  m.GetText = function(self) return self.__text end
  m.SetFormattedText = function(self, fmt, ...) self.__text = string.format(fmt, ...) end
  m.CreateFontString = function(self, name) return newRegion(game, "FontString", name, self) end
  m.CreateTexture = function(self, name) return newRegion(game, "Texture", name, self) end
  m.GetObjectType = function(self) return self.__kind end
  m.IsForbidden = function() return false end
  m.GetFrameLevel = function() return 1 end
  m.GetChildren = function() return end
  m.EnableMouse = noop
  -- tooltip-ish
  m.AddLine = function(self, text) self.__lines = self.__lines or {} table.insert(self.__lines, text) end
  m.NumLines = function(self) return self.__lines and #self.__lines or 0 end
  m.SetOwner = function(self) self.__lines = {} end
  -- chat frame
  m.AddMessage = function(_, text) game.chat[#game.chat + 1] = text end
  return m
end

-- ------------------------------------------------------------------ game
function M.new(opts)
  opts = opts or {}
  local game = setmetatable({
    opts = opts,
    frames = {},
    chat = {},
    timers = {},
    now = opts.now or 1731300000,
    clock = 1000,
    combat = false,
    reloads = 0,
    blockedEvents = {},
    blocked = {},
    macrosRun = {},
    sounds = {},      -- macrotext of secure buttons Gary "clicked"        -- protected calls an addon made in combat (taint in game)
    globalsWritten = {},
    loadedAddons = {},
  }, Game)
  for _, e in ipairs(opts.blockedEvents or {}) do game.blockedEvents[e] = true end
  for _, a in ipairs(opts.addons or {}) do game.loadedAddons[a] = true end
  game.loadedAddons[M.ADDON] = true
  game.methods = buildMethods(game)

  local player = {
    name = opts.name or "Torrant", realm = opts.realm or "Forever", class = opts.class or "HUNTER",
    race = opts.race or "Tauren", level = opts.level or 24, faction = opts.faction or "Horde",
    money = opts.money or 123456,
  }
  game.player = player

  local env = {}
  game.env = env
  local base = {}

  -- Lua builtins WoW exposes (no io, os, require, loadfile, dofile)
  for _, k in ipairs({ "assert", "error", "ipairs", "next", "pairs", "pcall", "print", "rawequal", "rawget",
    "rawset", "select", "setmetatable", "getmetatable", "tonumber", "tostring", "type", "unpack", "xpcall",
    "loadstring", "setfenv", "getfenv", "collectgarbage" }) do base[k] = _G[k] end
  base.string, base.table, base.math, base.coroutine = string, table, math, coroutine
  base.bit = { band = function() return 0 end }
  -- WoW aliases
  base.format, base.strlen, base.strsub, base.strlower, base.strupper = string.format, string.len, string.sub, string.lower, string.upper
  base.strfind, base.strmatch, base.gsub, base.strrep, base.strbyte, base.strchar = string.find, string.match, string.gsub, string.rep, string.byte, string.char
  base.gmatch = string.gmatch
  base.tinsert, base.tremove, base.sort = table.insert, table.remove, table.sort
  base.floor, base.ceil, base.abs, base.min, base.max = math.floor, math.ceil, math.abs, math.min, math.max
  base.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    game.chat[#game.chat + 1] = table.concat(parts, " ")
  end
  base.strsplit = function(sep, s, limit)
    local out, start = {}, 1
    while true do
      if limit and #out == limit - 1 then out[#out + 1] = s:sub(start) break end
      local i, j = s:find(sep, start, true)
      if not i then out[#out + 1] = s:sub(start) break end
      out[#out + 1] = s:sub(start, i - 1)
      start = j + 1
    end
    return unpack(out)
  end
  base.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  base.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
  base.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  base.date = function(fmt, t) return os.date(fmt, t or game.now) end
  base.time = function() return game.now end
  base.GetTime = function() return game.clock end
  base.GetServerTime = function() return game.now end
  base.debugstack = function() return "[mock stack]" end
  base.debugprofilestop = function() return game.clock * 1000 end
  base.geterrorhandler = function() return function(e) error(e) end end
  base.hooksecurefunc = function(a, b, c)
    if type(a) == "table" then
      local old = a[b]
      a[b] = function(...) local r = { old(...) } c(...) return unpack(r) end
    else
      local old = env[a]
      env[a] = function(...) local r = { old(...) } b(...) return unpack(r) end
    end
  end
  base.issecurevariable = function() return true end

  -- frames and UI globals
  base.CreateFrame = function(kind, name, parent, template)
    local r = newRegion(game, kind or "Frame", name, parent)
    r.__template = template
    r.__protected = type(template) == "string" and template:find("Secure") ~= nil
    if r.__protected and game.combat then game.blocked[#game.blocked + 1] = "CreateFrame(" .. tostring(name) .. ")" end
    return r
  end
  base.UIParent = newRegion(game, "Frame", nil, nil)
  base.Minimap = newRegion(game, "Frame", nil, nil)
  base.GameTooltip = newRegion(game, "GameTooltip", nil, nil)
  base.DEFAULT_CHAT_FRAME = newRegion(game, "ScrollingMessageFrame", nil, nil)
  base.UISpecialFrames = {}
  base.SlashCmdList = {}
  base.BackdropTemplateMixin = {}
  base.GetCursorPosition = function() return 100, 100 end
  base.HideUIPanel = noop
  base.PlaySound = function(id, channel) game.sounds[#game.sounds + 1] = id end
  base.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
  base.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
      game.settingsCategory = { name = name, frame = frame, ID = 42, GetID = function() return 42 end }
      return game.settingsCategory
    end,
    RegisterAddOnCategory = function(cat) game.settingsRegistered = cat end,
    OpenToCategory = function(id) game.settingsOpened = id end,
  }
  base.ReloadUI = function() game.reloads = game.reloads + 1 end

  -- player and units
  base.UnitName = function(unit) if unit == "player" then return player.name end return game.units and game.units[unit] and game.units[unit].name end
  base.UnitFullName = function(unit) if unit == "player" then return player.name, player.realm end end
  base.GetRealmName = function() return player.realm end
  base.UnitClass = function(unit) if unit == "player" then return player.class:sub(1, 1) .. player.class:sub(2):lower(), player.class end end
  base.UnitRace = function(unit) if unit == "player" then return player.race, player.race end end
  base.UnitLevel = function(unit)
    if unit == "player" then return player.level end
    return game.units and game.units[unit] and game.units[unit].level
  end
  base.UnitIsPlayer = function(unit) return unit == "player" or (game.units and game.units[unit] and game.units[unit].player) or false end
  base.UnitCreatureType = function(unit) return game.units and game.units[unit] and game.units[unit].creatureType end
  base.UnitIsDead = function(unit) return game.units and game.units[unit] and game.units[unit].dead or false end
  base.IsInInstance = function() return opts.inInstance and true or false, opts.inInstance and "party" or "none" end
  base.UnitFactionGroup = function(unit) if unit == "player" then return player.faction end end
  base.UnitExists = function(unit) return unit == "player" or (game.units and game.units[unit] ~= nil) end
  base.UnitGUID = function(unit)
    if unit == "player" then return "Player-1-00000001" end
    return game.units and game.units[unit] and game.units[unit].guid
  end
  base.UnitClassification = function(unit) return game.units and game.units[unit] and game.units[unit].classification or "normal" end
  base.UnitCreatureFamily = function(unit) return game.units and game.units[unit] and game.units[unit].family end
  base.GetMoney = function() return player.money end
  base.GetInventoryItemLink = function(_, slot) if slot == 18 then return "|cffffffff|Hitem:2504::::::::24:::::|h[Worn Shortbow]|h|r" end end
  base.InCombatLockdown = function() return game.combat end
  base.GetBuildInfo = function() return "1.60.1", "70862", "Nov 1 2026", 16001 end
  base.WOW_PROJECT_ID = 99
  -- macros: game.macros = { { name, icon, body, perChar } }, index = position
  game.macros = opts.macros or {}
  base.MAX_CHARACTER_MACROS = 18
  base.GetMacroIndexByName = function(name)
    for i, m in ipairs(game.macros) do if m.name == name then return i end end
    return 0
  end
  base.GetNumMacros = function()
    local acct, char = 0, 0
    for _, m in ipairs(game.macros) do if m.perChar then char = char + 1 else acct = acct + 1 end end
    return acct, char
  end
  base.EditMacro = function(i, name, icon, body)
    if game.combat then error("EditMacro in combat") end
    local m = game.macros[i]
    if name then m.name = name end
    if icon then m.icon = icon end
    if body then m.body = body end
    return i
  end
  base.CreateMacro = function(name, icon, body, perChar)
    if game.combat then error("CreateMacro in combat") end
    game.macros[#game.macros + 1] = { name = name, icon = icon, body = body, perChar = perChar }
    return #game.macros
  end
  base.C_CVar = { GetCVar = function(name) return (opts.cvars or {})[name] end }

  -- C_ namespaces
  local files, meta = M.tocFiles()
  game.tocFiles, game.tocMeta = files, meta
  base.C_AddOns = {
    GetAddOnMetadata = function(addon, field) if addon == M.ADDON then return meta[field] end end,
    IsAddOnLoaded = function(addon) return game.loadedAddons[addon] == true end,
    LoadAddOn = function(addon) return game.loadedAddons[addon] == true end,
    UpdateAddOnMemoryUsage = function() game.memoryUpdated = true end,
    GetAddOnMemoryUsage = function(addon) if addon == M.ADDON then return opts.memoryKB or 420 end return 0 end,
  }
  if not opts.noCTimer then
    base.C_Timer = {
      After = function(delay, fn) game.timers[#game.timers + 1] = { at = game.clock + delay, fn = fn } end,
      NewTicker = function(delay, fn, iterations)
        local h = { cancelled = false }
        function h:Cancel() self.cancelled = true end
        function h:IsCancelled() return self.cancelled end
        game.timers[#game.timers + 1] = { at = game.clock + delay, fn = function() fn(h) end, every = delay,
          handle = h, left = iterations }
        return h
      end,
    }
  end
  base.C_Map = {
    GetBestMapForUnit = function() return opts.mapID or 1412 end,
    GetPlayerMapPosition = function()
      local x, y = opts.x or 0.46, opts.y or 0.37
      return { GetXY = function() return x, y end }
    end,
    GetMapInfo = function(id) return { mapID = id, name = "Mulgore" } end,
  }
  base.issecretvalue = function(v) return type(v) == "table" and v.__secret == true end

  base._G = env
  -- Real WoW globals live directly in _G (so rawget(_G, "Settings") works).
  -- New globals are caught by __newindex; overwritten Blizzard globals are
  -- caught by Game:overwrittenGlobals() comparing against this copy.
  for k, v in pairs(base) do rawset(env, k, v) end
  setmetatable(env, {
    __newindex = function(t, k, v) game.globalsWritten[k] = true rawset(t, k, v) end,
  })
  game.base = base

  -- previous session's SavedVariables, exactly as the client would read them
  if opts.savedVariables then
    local chunk = assert(loadstring(opts.savedVariables, "=SavedVariables"))
    setfenv(chunk, env)
    chunk()
    game.globalsWritten = {}
  end
  return game
end

-- ------------------------------------------------------------------ actions
function Game:loadAddon()
  self.ns = {}
  for _, rel in ipairs(self.tocFiles) do
    local path = M.ROOT .. rel
    local chunk, err = loadfile(path)
    if not chunk then error("syntax error: " .. tostring(err), 0) end
    setfenv(chunk, self.env)
    chunk(M.ADDON, self.ns)
  end
  return self.ns
end

function Game:fire(event, ...)
  for _, f in ipairs(self.frames) do
    if f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
  end
end

function Game:login()
  self:fire("ADDON_LOADED", M.ADDON)
  self:fire("PLAYER_LOGIN")
  self:fire("PLAYER_ENTERING_WORLD", true, false)
  return self.ns
end

function Game:setCombat(on)
  self.combat = on
  self:fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

-- Runs due timers in time order (a timer scheduled by a callback runs in the
-- same advance if it falls inside the window), then one OnUpdate per shown
-- frame. Use small steps to exercise OnUpdate-driven code.
function Game:advance(seconds)
  local target = self.clock + seconds
  self.now = self.now + math.floor(seconds)
  while true do
    local best, bi
    for i, t in ipairs(self.timers) do
      if t.at <= target and (not best or t.at < best.at) then best, bi = t, i end
    end
    if not best then break end
    table.remove(self.timers, bi)
    if best.at > self.clock then self.clock = best.at end
    if not (best.handle and best.handle.cancelled) then
      best.fn()
      if best.every and not best.handle.cancelled then
        if best.left then best.left = best.left - 1 end
        if not best.left or best.left > 0 then
          best.at = best.at + best.every
          self.timers[#self.timers + 1] = best
        end
      end
    end
  end
  self.clock = target
  for _, f in ipairs(self.frames) do
    if f.__shown and f.__scripts.OnUpdate then f.__scripts.OnUpdate(f, seconds) end
  end
end

function Game:slash(line)
  return self.env.SlashCmdList.OUTRIDER(line)
end

-- Fires PLAYER_LOGOUT and returns the SavedVariables file text.
function Game:logout()
  self:fire("PLAYER_LOGOUT")
  local names = {}
  for name in (self.tocMeta.SavedVariables or ""):gmatch("[%w_]+") do names[#names + 1] = name end
  local out = {}
  for _, name in ipairs(names) do
    local v = rawget(self.env, name)
    if v ~= nil then out[#out + 1] = name .. " = " .. serialize(v) end
  end
  return table.concat(out, "\n") .. "\n"
end

-- Blizzard globals the addon replaced (assigning to one taints it in game).
function Game:overwrittenGlobals()
  local out = {}
  for k, v in pairs(self.base) do
    if rawget(self.env, k) ~= v then out[#out + 1] = k end
  end
  table.sort(out)
  return out
end

function Game:chatText()
  return table.concat(self.chat, "\n")
end

M.Game = Game
return M
