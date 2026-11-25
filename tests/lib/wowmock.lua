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
  m.SetFrameStrata = function(self, s) guard(self, "SetFrameStrata") rawset(self, "__strata", s) end
  m.GetFrameStrata = function(self) return rawget(self, "__strata") or "MEDIUM" end
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
  m.GetLeft = function() return 100 end
  m.GetTop = function() return 700 end
  m.GetEffectiveScale = function() return 1 end
  m.GetScale = function(self) return self.__scale or 1 end
  m.SetScale = function(self, v) self.__scale = v end
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
  m.CreateLine = function(self, name) return newRegion(game, "Line", name, self) end
  m.GetObjectType = function(self) return self.__kind end
  m.IsForbidden = function() return false end
  m.SetAlpha = function(self, a) self.__alpha = a end
  m.GetAlpha = function(self) return self.__alpha or 1 end
  m.GetFrameLevel = function(self) return self.__level or 1 end
  m.SetFrameLevel = function(self, l) self.__level = l end
  m.GetChildren = function() return end
  m.EnableMouse = noop
  -- tooltip-ish
  m.AddLine = function(self, text) self.__lines = self.__lines or {} table.insert(self.__lines, text) end
  -- two columns, recorded as "left<TAB>right"
  m.AddDoubleLine = function(self, l, r) self.__lines = self.__lines or {} table.insert(self.__lines, tostring(l) .. "	" .. tostring(r)) end
  m.ClearLines = function(self) self.__lines = {} end
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
  base.time = function(t) if type(t) == "table" then return os.time(t) end return game.now end
  base.GetTime = function() return game.clock end
  base.GetServerTime = function() return game.now end
  base.debugstack = function() return "[mock stack]" end
  base.debugprofilestop = function() return game.clock * 1000 end
  game.errorhandler = function(e) error(e) end
  base.geterrorhandler = function() return game.errorhandler end
  base.seterrorhandler = function(f) game.errorhandler = f end
  base.hooksecurefunc = function(a, b, c)
    if type(a) == "table" then
      local old = a[b]
      a[b] = function(...) local r = { old(...) } c(...) return unpack(r) end
    else
      local old = env[a]
      env[a] = function(...) local r = { old(...) } b(...) return unpack(r) end
      game.secureHooked = game.secureHooked or {}
      game.secureHooked[a] = env[a] -- hooksecurefunc is the sanctioned way; not an overwrite
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
  -- world map: a frame with a canvas; game.mapShownID is the map on screen
  base.WorldMapFrame = newRegion(game, "Frame", "WorldMapFrame", nil)
  base.WorldMapFrame.__shown = false
  local canvas = newRegion(game, "Frame", nil, nil)
  canvas.__w, canvas.__h = 1000, 700
  base.WorldMapFrame.GetCanvas = function() return canvas end
  base.WorldMapFrame.GetMapID = function() return game.mapShownID end
  base.WorldMapFrame.OnMapChanged = function() end
  base.GameTooltip = newRegion(game, "GameTooltip", nil, nil)
  base.DEFAULT_CHAT_FRAME = newRegion(game, "ScrollingMessageFrame", nil, nil)
  base.UISpecialFrames = {}
  base.SlashCmdList = {}
  base.BackdropTemplateMixin = {}
  base.GetCursorPosition = function() return game.cursorX or 200, game.cursorY or 650 end
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
  base.UnitName = function(unit) if unit == "player" then return player.name end local u = game.units and game.units[unit] if u then return u.name, u.realm end end
  base.UnitFullName = function(unit) if unit == "player" then return player.name, player.realm end end
  base.GetRealmName = function() return player.realm end
  local CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
  base.UnitClass = function(unit)
    if unit == "player" then return player.class:sub(1, 1) .. player.class:sub(2):lower(), player.class, CLASS_ID[player.class] end
    local u = game.units and game.units[unit]
    if u and u.class then return u.class:sub(1, 1) .. u.class:sub(2):lower(), u.class, CLASS_ID[u.class] end
  end
  -- quests: game.questsDone[id] = true, game.questsActive[id] = true
  base.C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return game.questsDone and game.questsDone[id] or false end,
    IsOnQuest = function(id) return game.questsActive and game.questsActive[id] or false end,
    -- quest log: game.questLog = { {title, questID, level, isHeader, complete} }
    GetNumQuestLogEntries = function() return #(game.questLog or {}) end,
    GetInfo = function(i) return game.questLog and game.questLog[i] end,
    -- objectives: game.questObjectives[questID] = { {text, type, numFulfilled, numRequired, finished} }
    GetQuestObjectives = function(id) return game.questObjectives and game.questObjectives[id] or {} end,
    IsComplete = function(id)
      for _, q in ipairs(game.questLog or {}) do if q.questID == id then return q.complete or false end end
      return false
    end,
  }
  base.C_DeathInfo = {
    GetCorpseMapPosition = function(mapID)
      local p = game.corpse
      if p and p.mapID == mapID then return { x = p.x, y = p.y, GetXY = function(self) return self.x, self.y end } end
    end,
  }
  -- temporary weapon enchant (a fishing lure): game.lureMs = milliseconds left, nil = none
  base.GetWeaponEnchantInfo = function() if game.lureMs then return true, game.lureMs, 0, 0 end return game.mhEnchant or false end
  -- druid forms: game.forms = { spellID, ... } in stance-bar order
  base.GetNumShapeshiftForms = function() return #(game.forms or {}) end
  base.GetShapeshiftFormInfo = function(i) local id = (game.forms or {})[i] if id then return 0, false, true, id end end
  base.UnitRace = function(unit)
    if unit == "player" then return player.race, player.race, opts.raceID end
    local u = game.units and game.units[unit]
    if u and u.race then return u.race, u.race:gsub(" ", "") end
  end
  -- other players' guild: game.units[unit].guild
  base.GetGuildInfo = function(unit)
    if unit == "player" then return player.guild end
    local u = game.units and game.units[unit]
    return u and u.guild
  end
  -- /who: game.whoResults = { {fullName, fullGuildName, level, raceStr, classStr, area, filename} },
  -- game.whoTotal (defaults to #whoResults); game.whoSent lists the filters asked for
  base.C_FriendList = base.C_FriendList or {}
  base.C_FriendList.SendWho = function(filter, origin) game.whoSent = game.whoSent or {} game.whoSent[#game.whoSent + 1] = filter end
  base.C_FriendList.GetNumWhoResults = function() local r = game.whoResults or {} return #r, game.whoTotal or #r end
  base.C_FriendList.GetWhoInfo = function(i) return (game.whoResults or {})[i] end
  -- guild roster: game.guildRoster = { {name, rank, rankIndex, level, classDisplayName, zone, note, officernote, online, status, class} }
  base.GetNumGuildMembers = function() local n = #(game.guildRoster or {}) return n, n, n end
  base.GetGuildRosterInfo = function(i) local g = (game.guildRoster or {})[i] if g then return unpack(g, 1, 11) end end
  base.GetClassInfo = function(id)
    for file, cid in pairs(CLASS_ID) do if cid == id then return file:sub(1, 1) .. file:sub(2):lower(), file, cid end end
  end
  base.UnitLevel = function(unit)
    if unit == "player" then return player.level end
    return game.units and game.units[unit] and game.units[unit].level
  end
  base.UnitIsPlayer = function(unit) return unit == "player" or (game.units and game.units[unit] and game.units[unit].player) or false end
  base.UnitCreatureType = function(unit) return game.units and game.units[unit] and game.units[unit].creatureType end
  base.UnitIsDead = function(unit) return game.units and game.units[unit] and game.units[unit].dead or false end
  -- game.instance = { name, map, kind } puts you inside one (else opts.inInstance)
  base.IsInInstance = function()
    if game.instance then return true, game.instance.kind or "party" end
    return opts.inInstance and true or false, opts.inInstance and "party" or "none"
  end
  base.GetInstanceInfo = function()
    local i = game.instance
    if i then return i.name, i.kind or "party", 1, "Normal", 5, 0, false, i.map end
    return "World", "none", 0, "", 0, 0, false, 0
  end
  base.UnitFactionGroup = function(unit)
    if unit == "player" then return player.faction end
    local u = game.units and game.units[unit]
    return u and u.faction
  end
  base.UnitExists = function(unit) return unit == "player" or (game.units and game.units[unit] ~= nil) end
  base.UnitGUID = function(unit)
    if unit == "player" then return "Player-1-00000001" end
    return game.units and game.units[unit] and game.units[unit].guid
  end
  base.UnitClassification = function(unit) return game.units and game.units[unit] and game.units[unit].classification or "normal" end
  base.UnitCreatureFamily = function(unit) return game.units and game.units[unit] and game.units[unit].family end
  -- known spells by id (weapon skills): game.knownSpells = { [264] = true }; nil = client can't say
  base.IsPlayerSpell = function(id) if game.knownSpells then return game.knownSpells[id] == true end end
  base.GetMoney = function() if game.loggingOut then return 0 end return game.money or player.money end
  base.C_AuctionHouse = {
    GetBrowseResults = function() return game.browse or {} end,
    -- game.ahListings = { [itemID] = { name, minPrice, qty, recipe = subclass } }; a query fills game.browse
    SendBrowseQuery = function(q)
      game.queries = game.queries or {}
      game.queries[#game.queries + 1] = q
      local out = {}
      for id, l in pairs(game.ahListings or {}) do
        -- the real search matches part of a name ("Fishing Pole" finds "Strong Fishing Pole")
        local hit = (q.searchString ~= "" and l.name:find(q.searchString, 1, true) ~= nil)
          or (q.itemClassFilters and l.recipe and q.itemClassFilters[1].subClassID == l.recipe)
          or (q.itemClassFilters and l.class and q.itemClassFilters[1].classID == l.class
            and (not q.itemClassFilters[1].inventoryType or q.itemClassFilters[1].inventoryType == l.invType))
        if hit then out[#out + 1] = { itemKey = { itemID = id }, minPrice = l.minPrice, totalQuantity = l.qty or 1 } end
      end
      game.browse = out
    end,
    IsThrottledMessageSystemReady = function() return true end,
    -- full scan: game.replicate = { {itemID, count, buyout}, ... } (0-based reads)
    ReplicateItems = function() game.replicated = (game.replicated or 0) + 1 end,
    GetNumReplicateItems = function() return #(game.replicate or {}) end,
    GetReplicateItemInfo = function(i)
      local r = (game.replicate or {})[i + 1]
      if not r then return nil end
      return "x", nil, r[2], 1, true, 1, 0, 0, 0, r[3], 0, false, nil, "seller", nil, 0, r[1], true
    end,
    -- gear: a browse with itemClassFilters returns game.ahGear rows whose class (and inventoryType, if given) match
    -- item listings: game.ahAuctions[itemID] = { {auctionID, buyout}, ... }; PlaceBid records game.bought
    SendSearchQuery = function(key) game.itemSearch = key and key.itemID end,
    -- {auctionID, buyout (whole listing), quantity (default 1), mine}; game.partial[itemID] = n shows only
    -- the first n until RequestMoreItemSearchResults
    GetNumItemSearchResults = function(key)
      local all = #((game.ahAuctions or {})[key.itemID] or {})
      local part = game.partial and game.partial[key.itemID]
      return part and math.min(part, all) or all
    end,
    HasFullItemSearchResults = function(key) return not (game.partial and game.partial[key.itemID]) end,
    RequestMoreItemSearchResults = function(key) if game.partial then game.partial[key.itemID] = nil end game.moreAsked = (game.moreAsked or 0) + 1 end,
    GetItemSearchResultInfo = function(key, i)
      local a = ((game.ahAuctions or {})[key.itemID] or {})[i]
      return a and { auctionID = a[1], buyoutAmount = a[2], quantity = a[3] or 1, containsOwnerItem = a[4] and true or false }
    end,
    StartCommoditiesPurchase = function(id, qty) game.commodityStart = { id = id, qty = qty } end,
    ConfirmCommoditiesPurchase = function(id, qty) game.bought = game.bought or {} game.bought[#game.bought + 1] = { commodity = id, qty = qty } end,
    CancelCommoditiesPurchase = function() game.commodityStart = nil end,
    PlaceBid = function(id, price) game.bought = game.bought or {} game.bought[#game.bought + 1] = { id = id, price = price } end,
    -- game.commodityList[itemID] = { {unitPrice, quantity, numOwnerItems, owners}, ... } (else game.commodity[itemID] = one price)
    GetCommoditySearchResultInfo = function(id, i)
      local list = game.commodityList and game.commodityList[id]
      if list then local r = list[i] return r and { unitPrice = r[1], quantity = r[2] or 1, numOwnerItems = r[3] or 0, owners = r[4] } end
      local p = game.commodity and game.commodity[id] return p and { unitPrice = p } end,
    GetCommoditySearchResultsQuantity = function(id)
      local list = game.commodityList and game.commodityList[id]
      if not list then return game.commodity and game.commodity[id] and 1 or 0 end
      local n = 0 for _, r in ipairs(list) do n = n + (r[2] or 1) end return n
    end,
    GetNumCommoditySearchResults = function(id)
      local list = game.commodityList and game.commodityList[id]
      if list then return #list end
      return game.commodity and game.commodity[id] and 1 or 0
    end,
    -- selling: game.posted = { {commodity|item, itemID, bag, slot, duration, qty, price} }
    PostCommodity = function(loc, dur, qty, unit)
      if game.combat then error("post in combat") end
      game.posted = game.posted or {}
      game.posted[#game.posted + 1] = { kind = "commodity", bag = loc.bag, slot = loc.slot, duration = dur, qty = qty, price = unit }
    end,
    PostItem = function(loc, dur, qty, bid, buyout)
      game.posted = game.posted or {}
      game.posted[#game.posted + 1] = { kind = "item", bag = loc.bag, slot = loc.slot, duration = dur, qty = qty, price = buyout, bid = bid }
    end,
    QueryOwnedAuctions = function() game.ownedQueries = (game.ownedQueries or 0) + 1 end,
    CancelAuction = function(id) game.cancelled = game.cancelled or {} game.cancelled[#game.cancelled + 1] = id end,
    GetItemKeyFromItem = function(loc)
      local id = game.bags and game.bags[loc.bag] and game.bags[loc.bag][loc.slot]
      return id and { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
    end,
    -- game.commodities[itemID] = true marks stackable goods
    GetItemKeyInfo = function(key) return key and { itemID = key.itemID, isCommodity = game.commodities and game.commodities[key.itemID] or false } end,
    GetItemCommodityStatus = function(loc)
      local id = type(loc) == "table" and game.bags and game.bags[loc.bag] and game.bags[loc.bag][loc.slot] or loc
      if type(id) ~= "number" or not game.commodities then return nil end -- nil: callers fall back to the stack size
      return game.commodities[id] and 2 or 1
    end,
    GetOwnedAuctions = function() return game.owned or {} end,
    CalculateCommodityDeposit = function(id, dur, qty) return (game.deposit or 0) * (qty or 1) end,
  }
  base.GetInventoryItemLink = function(_, slot)
    if game.loggingOut then return nil end
    if game.worn and game.worn[slot] then return "|cffffffff|Hitem:" .. game.worn[slot] .. "::::::::24:::::|h[w]|h|r" end
    if slot == 18 and not game.noRanged then return "|cffffffff|Hitem:2504::::::::24:::::|h[Worn Shortbow]|h|r" end
    if slot == 16 and game.pole then return "|cffffffff|Hitem:6256::::::::24:::::|h[Fishing Pole]|h|r" end
    if slot == 0 and (game.ammo or opts.ammo) then return "|cffffffff|Hitem:2512::::::::24:::::|h[Rough Arrow]|h|r" end
  end
  base.GetInventoryItemCount = function(_, slot) if slot == 0 then return game.ammo or opts.ammo or 0 end return 1 end
  base.InCombatLockdown = function() return game.combat end
  base.IsPlayerMoving = function() return game.moving == true end
  base.GetBuildInfo = function() return "1.60.1", "70862", "Nov 1 2026", 16001 end
  base.WOW_PROJECT_ID = 99
  -- professions: game.prof = { name, skill, max, recipes = { [id] = { name, reagents = {[itemID]=n} } } }
  -- several at once: game.profs = { [slot] = { name, skill, max, line } } in the
  -- real five-slot shape (prof 1, prof 2, archaeology, fishing, cooking; nil = empty)
  base.GetProfessions = function()
    if game.profs then
      local s = game.profs
      return s[1] and 1 or nil, s[2] and 2 or nil, s[3] and 3 or nil, s[4] and 4 or nil, s[5] and 5 or nil
    end
    if game.prof then return 1 end
  end
  base.GetProfessionInfo = function(idx)
    local p = game.prof
    if game.profs then p = game.profs[idx] end
    if p then return p.name, nil, p.skill, p.max, 0, 0, p.line end
  end
  base.UnitCastingInfo = function(unit) if unit == "player" then return game.casting end end
  base.C_TradeSkillUI = {
    GetAllRecipeIDs = function()
      local ids = {}
      for id in pairs(game.prof and game.prof.recipes or {}) do ids[#ids + 1] = id end
      table.sort(ids)
      return ids
    end,
    GetBaseProfessionInfo = function()
      local p = game.prof
      return p and { professionName = p.name, skillLevel = p.skill, maxSkillLevel = p.max }
    end,
    GetRecipeInfo = function(id) local r = game.prof.recipes[id] return r and { name = r.name, learned = true, relativeDifficulty = r.diff, craftable = not r.gather, isGatheringRecipe = r.gather or false } end,
    GetCraftableCount = function(id) local r = game.prof.recipes[id] return r and r.have or 0 end,
    IsTradeSkillReady = function() return game.tradeOpen == true end,
    OpenTradeSkill = function(line) if game.prof and game.prof.line == line and not game.noAutoOpen then game.tradeOpen = true end end,
    CraftRecipe = function(id, n) game.crafted = game.crafted or {} game.crafted[#game.crafted + 1] = { id = id, n = n } end,
    GetRecipeSchematic = function(id)
      local r = game.prof.recipes[id]
      local slots = {}
      for item, n in pairs(r.reagents) do slots[#slots + 1] = { reagents = { { itemID = item } }, quantityRequired = n } end
      return { reagentSlotSchematics = slots, outputItemID = r.product, quantityMin = r.makes or 1 }
    end,
  }
  base.GetRepairAllCost = function() return game.repairCost or 0, (game.repairCost or 0) > 0 end
  base.RepairAllItems = function(guild) game.repaired = { guild = guild } game.repairCost = 0 end
  base.CanGuildBankRepair = function() return false end
  -- override bindings: game.overrides[key] = action or "CLICK name"
  base.SetOverrideBinding = function(owner, prio, key, action)
    if game.combat then game.blocked[#game.blocked + 1] = "SetOverrideBinding" end
    game.overrides = game.overrides or {}
    game.overrides[key] = action
  end
  base.SetOverrideBindingClick = function(owner, prio, key, name)
    if game.combat then game.blocked[#game.blocked + 1] = "SetOverrideBindingClick" end
    game.overrides = game.overrides or {}
    game.overrides[key] = "CLICK " .. name
  end
  base.ClearOverrideBindings = function() game.overrides = {} end
  base.SetCVar = function(k, v) opts.cvars = opts.cvars or {} opts.cvars[k] = v end
  -- loot window: game.loot = { {id, name, count} }, game.fishingLoot = bool
  base.GetNumLootItems = function() return game.loot and #game.loot or 0 end
  base.GetLootSlotLink = function(i) local l = game.loot[i] return l and ("|Hitem:" .. l.id .. "::|h[" .. l.name .. "]|h") end
  base.GetLootSlotInfo = function(i) local l = game.loot[i] return nil, l.name, l.count or 1 end
  base.IsFishingLoot = function() return game.fishingLoot or false end
  base.GetSubZoneText = function() return game.subzone or "" end
  base.GetZoneText = function() return game.zoneText or "" end
  -- inbox: game.inbox = { {money, cod, items = {itemID,...}} }
  base.GetInboxNumItems = function() return game.inbox and #game.inbox or 0 end
  base.GetInboxHeaderInfo = function(i)
    local m = game.inbox[i]
    local n = 0 for _ in pairs(m.items or {}) do n = n + 1 end
    return nil, nil, m.sender or "Sender", m.subject or "Subject", m.money or 0, m.cod or 0, m.days or 30, n
  end
  base.GetInboxItemLink = function(i, a) local id = game.inbox[i].items and game.inbox[i].items[a] return id and ("|Hitem:" .. id .. "::|h[x]|h") end
  base.TakeInboxMoney = function(i) game.money = (game.money or player.money) + game.inbox[i].money game.inbox[i].money = 0 end
  base.TakeInboxItem = function(i, a) game.inbox[i].items[a] = nil end
  -- quest rewards: game.choices = { itemID, ... }
  base.GetNumQuestChoices = function() return game.choices and #game.choices or 0 end
  base.GetQuestItemLink = function(kind, i) local id = game.choices and game.choices[i] return id and ("|cffffffff|Hitem:" .. id .. "::::::::24:::::|h[x]|h|r") end
  base.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) game.prefixes = game.prefixes or {} game.prefixes[p] = true return true end,
    SendAddonMessage = function(prefix, msg, channel, target)
      game.sent = game.sent or {}
      game.sent[#game.sent + 1] = { prefix = prefix, msg = msg, channel = channel, target = target }
    end,
  }
  -- group loot rolls: game.lootRolls[rollID] = { link, name, quality, bop, canNeed, canGreed }
  base.GetLootRollItemLink = function(id) local r = game.lootRolls and game.lootRolls[id] return r and r.link end
  base.GetLootRollItemInfo = function(id)
    local r = game.lootRolls and game.lootRolls[id]
    if not r then return nil end
    return "Interface\\Icons\\INV_Misc_QuestionMark", r.name, 1, r.quality or 2, r.bop, r.canNeed ~= false, r.canGreed ~= false
  end
  base.IsInGuild = function() return opts.inGuild or false end
  -- whispers and invites are recorded: game.tells, game.invites, game.guildInvites
  -- XP and connection: game.xp, game.xpMax, game.rested, game.latency, game.fps
  -- quest log XP: game.questXP[questID] = xp
  base.GetQuestLogRewardXP = function(id) return game.questXP and game.questXP[id] or 0 end
  base.UnitXP = function(unit) if unit == "player" then return game.xp or 0 end end
  base.UnitXPMax = function(unit) if unit == "player" then return game.xpMax or 1000 end end
  base.GetXPExhaustion = function() return game.rested end
  base.UnitIsGhost = function(unit) return unit == "player" and game.isGhost or false end
  base.GetNetStats = function() return 0, 0, game.latency or 40, game.latency or 40 end
  base.GetFramerate = function() return game.fps or 60 end
  base.ToggleAllBags = function() game.bagsToggled = (game.bagsToggled or 0) + 1 end
  base.CanGuildInvite = function() return opts.canGuildInvite or false end
  base.ChatFrame_SendTell = function(name) game.tells = game.tells or {} game.tells[#game.tells + 1] = name end
  base.C_PartyInfo = base.C_PartyInfo or {}
  base.C_PartyInfo.InviteUnit = function(name) game.invites = game.invites or {} game.invites[#game.invites + 1] = name end
  base.C_GuildInfo = base.C_GuildInfo or {}
  base.C_GuildInfo.Invite = function(name) game.guildInvites = game.guildInvites or {} game.guildInvites[#game.guildInvites + 1] = name end
  game.chatFilters = {}
  base.ChatFrame_AddMessageEventFilter = function(ev, fn) game.chatFilters[ev] = game.chatFilters[ev] or {} table.insert(game.chatFilters[ev], fn) end
  base.SetItemRef = function() end
  -- chat windows: game.chatWindows[i] = name; FCF_OpenNewWindow adds one
  game.chatWindows = { "General", "Combat Log" }
  base.GetChatWindowInfo = function(i) return game.chatWindows[i] end
  base.FCF_OpenNewWindow = function(name)
    if game.combat then error("FCF_OpenNewWindow in combat") end
    game.chatWindows[#game.chatWindows + 1] = name
    return base.CreateFrame("ScrollingMessageFrame", "ChatFrame" .. #game.chatWindows, base.UIParent)
  end
  base.ChatFrame_AddChannel = function(frame, name) game.addedChannels = game.addedChannels or {} game.addedChannels[name] = frame end
  -- nameplates: one fake plate frame per nameplate unit
  base.C_NamePlate = { GetNamePlateForUnit = function(unit)
    if type(unit) ~= "string" or not unit:match("^nameplate") then return nil end
    game.plates = game.plates or {}
    game.plates[unit] = game.plates[unit] or base.CreateFrame("Frame", nil, base.UIParent)
    return game.plates[unit]
  end }
  base.IsResting = function() return game.resting or false end
  base.GetInventoryItemDurability = function(slot) local d = game.durability and game.durability[slot] if d then return d[1], d[2] end end
  base.IsInGroup = function() if game.inGroup ~= nil then return game.inGroup end return opts.inGroup or false end
  base.IsInRaid = function() if game.inRaid ~= nil then return game.inRaid end return opts.inRaid or false end
  base.GetNumGroupMembers = function()
    local n = 0
    for k in pairs(game.units or {}) do if tostring(k):match("^party%d") or tostring(k):match("^raid%d") then n = n + 1 end end
    return n > 0 and n + 1 or 0
  end
  base.UnitInRange = function(unit) local d = game.units and game.units[unit] if d then return d.inRange ~= false, true end end
  base.UnitIsDeadOrGhost = function(unit) return game.units and game.units[unit] and game.units[unit].dead or false end
  -- class trainer window: game.trainer = { { name, rank, status, level, cost, icon }, ... }.
  -- Forever's GetTrainerServiceInfo returns name, status (rank lives elsewhere);
  -- game.trainerClassic = true gives the Classic order name, rank, status.
  base.GetNumTrainerServices = function() return game.trainer and #game.trainer or 0 end
  base.GetTrainerServiceInfo = function(i)
    local t = game.trainer and game.trainer[i]
    if not t then return nil end
    if game.trainerClassic then return t[1], t[2], t[3] end
    return t[1], t[3], t[2]
  end
  base.GetTrainerServiceLevelReq = function(i) local t = game.trainer and game.trainer[i] return t and t[4] end
  base.GetTrainerServiceCost = function(i) local t = game.trainer and game.trainer[i] return t and t[5] end
  base.GetTrainerServiceIcon = function(i) local t = game.trainer and game.trainer[i] return t and t[6] end
  base.IsTradeskillTrainer = function() return game.tradeTrainer or false end
  -- index 3 is about 10 yards; game.units[unit].near = true when the player stands next to it
  base.CheckInteractDistance = function(unit, index)
    local d = game.units and game.units[unit]
    return d and d.near and (index == 3 or index == 2) or false
  end
  base.CanMerchantRepair = function() return game.canRepair or false end
  base.C_TooltipInfo = { GetUnit = function(unit)
    local d = game.units and game.units[unit]
    if not d then return nil end
    local lines = { { leftText = d.name } }
    if d.title then lines[2] = { leftText = d.title } else lines[2] = { leftText = "Level 20" } end
    -- quest objective lines: game.units[unit].objectives = { " - Wolves slain: 3/8" }
    for _, o in ipairs(d.objectives or {}) do lines[#lines + 1] = { leftText = o, type = 8 } end
    return { lines = lines }
  end,
  -- item tooltips: game.itemTips[itemID] = { "line", ... }
  GetItemByID = function(id)
    local t = game.itemTips and game.itemTips[id]
    if not t then return nil end
    local lines = {}
    for i, l in ipairs(t) do lines[i] = { leftText = l } end
    return { lines = lines }
  end }
  -- merchant: game.merchant = { itemID, ... }; game.itemClass[itemID] = classID
  base.GetMerchantNumItems = function() return game.merchant and #game.merchant or 0 end
  base.GetMerchantItemID = function(i) return game.merchant and game.merchant[i] end
  base.GetMerchantItemInfo = function(i)
    local id = game.merchant and game.merchant[i]
    local item = id and game.items and game.items[id]
    if not item then return nil end
    local price = item.buy or 100
    local bundle = item.bundle or 1
    local available = item.available == nil and -1 or item.available
    return item.name, "", price, bundle, available, item.usable ~= false, item.extended or false
  end
  base.BuyMerchantItem = function(i, units)
    if game.combat then error("purchase in combat") end
    local id = game.merchant and game.merchant[i]
    if not id then error("no merchant item") end
    local item = game.items[id] or {}
    local bundle = item.bundle or 1
    local count = math.ceil(units / bundle) * bundle
    local cost = math.ceil(count / bundle) * (item.buy or 100)
    game.money = (game.money or game.player.money) - cost
    game.bought = game.bought or {}
    game.bought[#game.bought + 1] = { id = id, count = count, cost = cost }
    game.bags = game.bags or {}
    game.bags[0] = game.bags[0] or {}
    for j = 1, 16 do
      if not game.bags[0][j] then
        game.bags[0][j] = id
        game.counts = game.counts or {}
        game.counts[0] = game.counts[0] or {}
        game.counts[0][j] = count
        break
      end
    end
  end
  base.C_Item = base.C_Item or {}
  base.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
  -- bags: game.bags[bag][slot] = itemID; game.items[itemID] = { name, reqLevel, spell }
  base.C_Container = {
    GetContainerItemLink = function(bag, slot)
      local id = game.bags and game.bags[bag] and game.bags[bag][slot]
      return id and ("|cffffffff|Hitem:" .. id .. "::::::::24:::::|h[x]|h|r")
    end,
    -- game.bagSize[bag] / game.bagFamily[bag] (1 arrows, 2 bullets) override the default 16-slot bag
    GetContainerNumSlots = function(bag)
      if game.bagSize and game.bagSize[bag] then return game.bagSize[bag] end
      return game.bags and game.bags[bag] and 16 or 0
    end,
    GetContainerNumFreeSlots = function(bag)
      local b = game.bags and game.bags[bag]
      if game.bagSize and game.bagSize[bag] then return game.bagSize[bag], game.bagFamily and game.bagFamily[bag] or 0 end
      if not b then return 0, 0 end
      local used = 0
      for _ in pairs(b) do used = used + 1 end
      return 16 - used, 0
    end,
    -- game.counts[bag][slot] overrides the default stack of 5
    UseContainerItem = function(bag, slot)
      if game.combat then error("UseContainerItem in combat") end
      local id = game.bags[bag][slot]
      game.sold = game.sold or {}
      game.sold[#game.sold + 1] = id
      game.bags[bag][slot] = nil
    end,
    GetContainerItemInfo = function(bag, slot)
      local id = game.bags and game.bags[bag] and game.bags[bag][slot]
      if id then return { itemID = id, stackCount = (game.counts and game.counts[bag] and game.counts[bag][slot]) or 5,
        isLocked = game.lockedItems and game.lockedItems[id] or false } end
    end,
    GetContainerItemQuestInfo = function(bag, slot)
      local id = game.bags and game.bags[bag] and game.bags[bag][slot]
      if id then return { isQuestItem = game.questItems and game.questItems[id] or false,
        questID = game.questStartItems and game.questStartItems[id] or nil } end
    end,
  }
  -- cursor and bag slots (BagSwap): game.cursorItem = { id, bag, slot }; the bag in slot n is
  -- game.bagItem[n] (its size game.bagSize[n]); a bag item's size is game.items[id].slots
  base.C_Container.ContainerIDToInventoryID = function(bag) return 30 + bag end
  base.C_Container.PickupContainerItem = function(bag, slot)
    if game.combat then error("item moved in combat") end
    game.bags = game.bags or {}
    game.bags[bag] = game.bags[bag] or {}
    local here = game.bags[bag][slot]
    local cur = game.cursorItem
    if not cur then
      if here then game.cursorItem = { id = here, bag = bag, slot = slot } game.bags[bag][slot] = nil end
      return
    end
    if slot > base.C_Container.GetContainerNumSlots(bag) then error("no such slot") end
    game.bags[bag][slot] = cur.id
    game.cursorItem = nil
    if here then game.bags[cur.bag][cur.slot] = here end -- swap
    game.moves = (game.moves or 0) + 1
  end
  base.CursorHasItem = function() return game.cursorItem ~= nil end
  base.PutItemInBag = function(inv)
    local bag = inv - 30
    local cur = game.cursorItem
    if not cur then return end
    for _ in pairs(game.bags[bag] or {}) do
      game.bags[cur.bag][cur.slot] = cur.id game.cursorItem = nil
      game.uiError = "That bag must be empty" return
    end
    local it = game.items[cur.id]
    local old = game.bagItem and game.bagItem[bag]
    game.cursorItem = nil
    game.bagItem = game.bagItem or {}
    game.bagSize = game.bagSize or {}
    game.bagItem[bag], game.bagSize[bag] = cur.id, it.slots
    game.bags[bag] = {}
    if old then game.bags[cur.bag][cur.slot] = old end -- the old bag lands where the new one was
  end
  -- gear: game.itemStats[id] = { ITEM_MOD_AGILITY_SHORT = 5, ... }; items[id].equipLoc / class / subclass
  base.C_Item.EquipItemByName = function(link, slot)
    if game.combat then error("EquipItemByName in combat") end
    game.worn = game.worn or {}
    game.worn[slot] = tonumber(tostring(link):match("item:(%d+)"))
  end
  base.C_Item.GetItemStats = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    return game.itemStats and game.itemStats[id] or {}
  end
  base.C_Item.GetItemCount = function(id) return game.counts and game.counts[id] or 0 end
  base.C_Item.GetItemSpell = function(id) local it = game.items and game.items[id] return it and it.spell end
  local function idOf(v) return tonumber(tostring(v):match("item:(%d+)")) or v end
  base.C_Item.GetItemInfo = function(id)
    id = idOf(id)
    local it = game.items and game.items[id]
    if it then return it.name, nil, it.quality or 1, it.ilvl or 1, it.reqLevel or 0, it.itemType, it.itemSubType, 20, it.equipLoc, nil, it.sell or 0, nil, nil, it.bind end
  end
  base.C_Item.GetItemInfoInstant = function(id)
    id = idOf(id)
    if id == 6256 then return id, nil, nil, nil, nil, 2, 20 end
    local it = game.items and game.items[id]
    if it and it.class then return id, nil, nil, it.equipLoc, nil, it.class, it.subclass end
    return id, nil, nil, nil, nil, game.itemClass and game.itemClass[id]
  end
  base.Enum = { TooltipDataType = { Unit = 2, Item = 0, Object = 33 }, SpellBookSpellBank = { Player = 0 } }
  -- spellbook: game.spells = { { name, id, rank, passive } } in one skill line
  game.spells = opts.spells or {
    { name = "Auto Shot", id = 75 }, { name = "Arcane Shot", id = 14282, rank = 3 },
    { name = "Arcane Shot", id = 14281, rank = 2 }, { name = "Tame Beast", id = 1515 },
    { name = "Hunter's Mark", id = 1130, rank = 1 }, { name = "Wing Clip", id = 2974, rank = 1 },
  }
  base.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #game.spells } end,
    GetSpellBookItemInfo = function(i)
      local s = game.spells[i]
      if s then return { name = s.name, spellID = s.id, subName = s.rank and ("Rank " .. s.rank) or "", isPassive = s.passive } end
    end,
  }
  base.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
    game.tooltipHooks = game.tooltipHooks or {}
    game.tooltipHooks[#game.tooltipHooks + 1] = { kind = kind, fn = fn }
  end }
  base.IsShiftKeyDown = function() return game.shift or false end
  -- talents (Classic API): game.talents = { { name = "Beast Mastery", talents = { { name, tier, column, rank, max, req = { tier, column } } } } }
  -- game.unspent = free points (nil: the client can't say)
  base.GetNumTalentTabs = function() return game.talents and #game.talents or 0 end
  base.GetTalentTabInfo = function(t) local tab = game.talents and game.talents[t] if tab then return tab.name, nil, 0, "bg" end end
  base.GetNumTalents = function(t) local tab = game.talents and game.talents[t] return tab and #tab.talents or 0 end
  base.GetTalentInfo = function(t, i)
    local e = game.talents and game.talents[t] and game.talents[t].talents[i]
    if e then return e.name, nil, e.tier, e.column, e.rank or 0, e.max end
  end
  base.GetTalentPrereqs = function(t, i)
    local e = game.talents and game.talents[t] and game.talents[t].talents[i]
    if e and e.req then return e.req[1], e.req[2], true end
  end
  base.UnitCharacterPoints = function() return game.unspent end
  base.GetSpellBaseCooldown = function(id) for _, s in ipairs(game.spells or {}) do if s.id == id then return s.cd or 0 end end return 0 end
  -- modern talents: game.traits = { { treeID, unspent, nodes = { { id, name, rank, max, open } } } }
  local function trNode(id)
    for _, tr in ipairs(game.traits or {}) do for _, n in ipairs(tr.nodes) do if n.id == id then return n end end end
  end
  base.C_ClassTalents = { GetActiveConfigID = function() if game.traits then return 7 end end }
  base.C_Traits = {
    GetConfigInfo = function() local ids = {} for i, tr in ipairs(game.traits or {}) do ids[i] = tr.treeID end return { treeIDs = ids } end,
    GetTreeCurrencyInfo = function(_, treeID)
      for _, tr in ipairs(game.traits or {}) do if tr.treeID == treeID then return { { quantity = tr.unspent or 0 } } end end
      return {}
    end,
    GetTreeNodes = function(treeID)
      local out = {}
      for _, tr in ipairs(game.traits or {}) do if tr.treeID == treeID then for i, n in ipairs(tr.nodes) do out[i] = n.id end end end
      return out
    end,
    GetNodeInfo = function(_, id)
      local n = trNode(id)
      if n then
        local edges = {}
        for _, t in ipairs(n.opens or {}) do edges[#edges + 1] = { targetNode = t } end
        return { ID = id, currentRank = n.rank or 0, maxRanks = n.max, entryIDs = { id * 10 }, isVisible = true,
          canPurchaseRank = n.open, isAvailable = n.open, posX = n.x or 0, posY = n.y or 0, visibleEdges = edges,
          subTreeID = n.sub }
      end
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID * 10 } end,
    GetDefinitionInfo = function(defID) local n = trNode(defID / 100) return n and { overrideName = n.name, spellID = n.spell, overrideIcon = n.icon } end,
    -- game.traitDesc[entryID] = "text at rank 1" (rank N: the numbers times N)
    GetTraitDescription = function(entryID, rank)
      local d = game.traitDesc and game.traitDesc[entryID]
      if not d then return nil end
      return (d:gsub("(%d+)", function(n) return tostring(tonumber(n) * math.max(1, rank or 1)) end))
    end,
    GetSubTreeInfo = function(_, sub) for _, tr in ipairs(game.traits or {}) do if tr.subNames and tr.subNames[sub] then return { name = tr.subNames[sub] } end end end,
  }
  -- pet: game.units.pet = { name, guid, level, family, hp, hpMax, focus, focusMax, auras = { {name, spellId} } }
  local function u(unit) return game.units and game.units[unit] end
  base.UnitHealth = function(unit) return u(unit) and u(unit).hp end
  base.UnitHealthMax = function(unit) return u(unit) and u(unit).hpMax end
  base.UnitAttackSpeed = function(unit) return u(unit) and u(unit).attackSpeed end
  base.UnitPower = function(unit) return u(unit) and u(unit).focus end
  base.UnitPowerMax = function(unit) return u(unit) and u(unit).focusMax end
  base.GetPetExperience = function() local p = u("pet") if p then return p.xp or 0, p.xpMax or 0 end return 0, 0 end
  base.HasPetUI = function() return u("pet") ~= nil end
  base.GetPetActionInfo = function(i)
    local a = game.petActions and game.petActions[i]
    if a then return a.name, nil, a.token or false, nil, a.allowed ~= false, a.auto or false end
  end
  base.C_UnitAuras = { GetAuraDataByIndex = function(unit, i)
    local a = u(unit) and u(unit).auras and u(unit).auras[i]
    if a then return { name = a.name, spellId = a.spellId } end
  end }
  if opts.petHappiness then base.GetPetHappiness = function() return game.petHappiness or opts.petHappiness end end
  -- macros: game.macros = { { name, icon, body, perChar } }, index = position
  game.macros = opts.macros or {}
  base.MAX_CHARACTER_MACROS = 18
  base.GetMacroIndexByName = function(name)
    for i, m in ipairs(game.macros) do if m.name == name then return i end end
    return 0
  end
  -- like the client: name lookup ignores case
  base.GetMacroIndexByName = function(name)
    for i, m in ipairs(game.macros) do if m.name:lower() == tostring(name):lower() then return i end end
    return 0
  end
  base.GetMacroInfo = function(i) local m = game.macros[i] if m then return m.name, m.icon, m.body end end
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
  base.DeleteMacro = function(i) if game.combat then error("DeleteMacro in combat") end table.remove(game.macros, i) end
  base.PickupMacro = function(i) game.cursorMacro = i end
  base.CreateMacro = function(name, icon, body, perChar)
    if game.combat then error("CreateMacro in combat") end
    game.macros[#game.macros + 1] = { name = name, icon = icon, body = body, perChar = perChar }
    return #game.macros
  end
  base.C_CVar = { GetCVar = function(name) return (opts.cvars or {})[name] end,
    SetCVar = function(k, v) opts.cvars = opts.cvars or {} opts.cvars[k] = v end }

  -- C_ namespaces
  local files, meta = M.tocFiles()
  game.tocFiles, game.tocMeta = files, meta
  base.C_AddOns = {
    GetAddOnMetadata = function(addon, field) if addon == M.ADDON then return meta[field] end end,
    IsAddOnLoaded = function(addon) return game.loadedAddons[addon] == true end,
    -- game.disabledAddons[name] = true: LoadAddOn says DISABLED until EnableAddOn
    LoadAddOn = function(addon)
      if game.disabledAddons and game.disabledAddons[addon] then return false, "DISABLED" end
      if game.loadable and game.loadable[addon] then game.loadedAddons[addon] = true end
      return game.loadedAddons[addon] == true
    end,
    EnableAddOn = function(addon) if game.disabledAddons then game.disabledAddons[addon] = nil end game.enabledAddons = (game.enabledAddons or 0) + 1 end,
    UpdateAddOnMemoryUsage = function() game.memoryUpdated = true end,
    GetAddOnMemoryUsage = function(addon)
      if addon == M.ADDON then return opts.memoryKB or 420 end
      return (game.addonMemory or {})[addon] or 0
    end,
    -- the add-on list, in load order: Outrider, then game.addonList (names)
    GetNumAddOns = function() return 1 + #(game.addonList or {}) end,
    GetAddOnInfo = function(i)
      local name = i == 1 and M.ADDON or (game.addonList or {})[i - 1]
      if name then return name, name, "", true, "INSECURE", false end
    end,
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
    GetBestMapForUnit = function() if game.loggingOut then return nil end return opts.mapID or 1412 end,
    GetPlayerMapPosition = function()
      local x, y = opts.x or 0.46, opts.y or 0.37
      return { GetXY = function() return x, y end }
    end,
    GetMapInfo = function(id)
      local m = game.maps and game.maps[id]
      if m then return { mapID = id, name = m.name, parentMapID = m.parent or 0, mapType = m.mapType } end
      return { mapID = id, name = "Mulgore" }
    end,
    -- game.maps[id] = { name, parent }: every map below id (all descendants)
    GetMapChildrenInfo = function(id)
      local out = {}
      local function under(m, top) for _ = 1, 10 do if not m or not game.maps[m] then return false end
        if game.maps[m].parent == top then return true end m = game.maps[m].parent end return false end
      for mid, m in pairs(game.maps or {}) do if under(mid, id) then out[#out + 1] = { mapID = mid, name = m.name, mapType = m.mapType } end end
      return out
    end,
  }
  -- game.maps[id].rect = { minX, maxX, minY, maxY } on its parent map
  base.C_Map.GetMapRectOnMap = function(id, top)
    local m = game.maps and game.maps[id]
    if m and m.rect and m.parent == top then return m.rect[1], m.rect[2], m.rect[3], m.rect[4] end
  end
  -- map art: game.mapArt[id] = { lw, lh } (default 1002 x 668 in 256 tiles); false = none
  base.C_Map.GetMapArtLayers = function(id)
    local a = game.mapArt and game.mapArt[id]
    if a == false then return nil end
    a = a or { 1002, 668 }
    return { { layerWidth = a[1], layerHeight = a[2], tileWidth = 256, tileHeight = 256 } }
  end
  base.C_Map.GetMapArtLayerTextures = function(id)
    local a = game.mapArt and game.mapArt[id]
    if a == false then return nil end
    a = a or { 1002, 668 }
    local out = {}
    for i = 1, math.ceil(a[1] / 256) * math.ceil(a[2] / 256) do out[i] = 100000 + i end
    return out
  end
  -- game.maps[id].rect on its parent: the child map under (x, y)
  base.C_Map.GetMapInfoAtPosition = function(id, x, y)
    for mid, m in pairs(game.maps or {}) do
      local r = m.rect
      if m.parent == id and r and x >= r[1] and x <= r[2] and y >= r[3] and y <= r[4] then
        return { mapID = mid, name = m.name, parentMapID = id, mapType = m.mapType }
      end
    end
    return { mapID = id }
  end
  base.C_Map.GetMapGroupID = function(id) local m = game.maps and game.maps[id] return m and m.group end
  base.C_Map.GetMapGroupMembersInfo = function(group)
    local out = {}
    for mid, m in pairs(game.maps or {}) do if m.group == group then out[#out + 1] = { mapID = mid, name = m.name, relativeHeightIndex = m.floor or 0 } end end
    return out
  end
  base.C_Map.SetUserWaypoint = function(p) game.userWaypoint = p end
  base.C_Map.ClearUserWaypoint = function() game.userWaypoint = nil end
  -- world yards: 1 map unit = 1000 yards on every test map
  -- game.mapWorld[mapID] = { continent, offsetX, offsetY } puts maps side by side or on other continents
  -- the inverse, onto a given map: (continent, world vector, uiMapID) -> uiMapID, map position
  base.C_Map.GetMapPosFromWorldPos = function(cont, v, mapID)
    local w = game.mapWorld and game.mapWorld[mapID]
    if not w or w[1] ~= cont then return nil end
    local x, y = (v.x - w[2]) / 1000, (v.y - w[3]) / 1000
    return mapID, { GetXY = function() return x, y end }
  end
  base.C_Map.GetWorldPosFromMapPos = function(mapID, v)
    local w = game.mapWorld and game.mapWorld[mapID]
    return w and w[1] or 1, { GetXY = function() return v.x * 1000 + (w and w[2] or 0), v.y * 1000 + (w and w[3] or 0) end }
  end
  base.CreateVector2D = function(x, y) return { x = x, y = y } end
  -- action bars: game.actions[slot] = spellID; spell info from game.spells
  local function spellByID(id) for _, s in ipairs(game.spells) do if s.id == id then return s end end end
  base.GetActionInfo = function(slot) local id = game.actions and game.actions[slot] if id then return "spell", id end end
  base.C_Spell = { GetSpellInfo = function(id) local s = spellByID(id) return s and { name = s.name, castTime = s.cast } end,
    GetSpellDescription = function(id) local s = spellByID(id) return s and s.desc end,
    GetSpellSubtext = function(id) local s = spellByID(id) return s and s.rank and ("Rank " .. s.rank) or "" end,
    PickupSpell = function(id) game.cursorSpell = id end }
  base.PlaceAction = function(slot)
    if game.combat then error("PlaceAction in combat") end
    game.actions = game.actions or {}
    game.actions[slot] = game.cursorSpell
  end
  base.ClearCursor = function()
    game.cursorSpell = nil
    local cur = game.cursorItem
    if cur then game.bags[cur.bag][cur.slot] = cur.id game.cursorItem = nil end
  end
  base.C_TaxiMap = { GetTaxiNodesForMap = function(mapID)
    return game.taxi and game.taxi[mapID] or {}
  end }
  base.C_Minimap = { GetViewRadius = function() return opts.minimapRadius or 200 end,
    GetNumTrackingTypes = function() return game.tracking and #game.tracking or 0 end,
    GetTrackingInfo = function(i) return game.tracking and game.tracking[i] end,
    -- like the client: switches tracking type i on or off (game.trackingLocked refuses)
    SetTracking = function(i, on)
      if game.trackingLocked then error("blocked") end
      local t = game.tracking and game.tracking[i]
      if t then t.active = on and true or false end
    end }
  base.GetPlayerFacing = function() return game.facing or 0 end
  base.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, x = x, y = y } end }
  base.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) game.superTracked = on end }
  if not opts.noQuestTrack then
    base.C_SuperTrack.SetSuperTrackedQuestID = function(id) game.trackedQuest = id end
    base.C_SuperTrack.GetSuperTrackedQuestID = function() return game.trackedQuest or 0 end
  end
  base.UnitPosition = function(unit)
    if unit ~= "player" then return nil end
    local w = game.mapWorld and game.mapWorld[opts.mapID or 1412]
    return (opts.y or 0.37) * 1000 + (w and w[3] or 0), (opts.x or 0.46) * 1000 + (w and w[2] or 0), 0, w and w[1] or 1
  end
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
  -- The rare seed pack (Data/Rares.lua) holds real Mulgore rares; specs use
  -- their own made-up rares on the same maps, so it is left out unless a
  -- spec asks for it with mock.new({ seedRares = true }).
  if not self.opts.seedRares and self.ns.Data and self.ns.Data.packs.rare then
    self.ns.Data.packs.rare.seed = nil
    for _, e in pairs(self.ns.Data.index.rare or {}) do
      if tostring(e.source or ""):find("2026-11-15", 1, true) then self.ns.Data.index.rare[e.npcID] = nil end
    end
  end
  -- The leveling knowledge base (Data/Leveling*.lua, Wowhead's Forever guides)
  -- holds real trainers, flight masters and tips on the maps specs use with
  -- made-up NPCs; left out unless a spec asks with mock.new({ guides = true }).
  if not self.opts.guides and self.ns.Data and self.ns.Data.index then
    self.ns.Data.index.place = {}
    if self.ns.Leveling then self.ns.Leveling.FACTS = {} end
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

-- Like the real client: PLAYER_REGEN_DISABLED fires while InCombatLockdown()
-- is still false; lockdown starts right after the handlers run.
function Game:setCombat(on)
  if on then
    self:fire("PLAYER_REGEN_DISABLED")
    self.combat = true
  else
    self.combat = false
    self:fire("PLAYER_REGEN_ENABLED")
  end
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
    local now = rawget(self.env, k)
    if now ~= v and not (self.secureHooked and self.secureHooked[k] == now) then out[#out + 1] = k end
  end
  table.sort(out)
  return out
end

function Game:chatText()
  return table.concat(self.chat, "\n")
end

M.Game = Game

-- Run a chat line through the registered message filters, like ChatFrame does.
-- Returns hidden, text.
function Game:chatLine(event, msg, author, frame, base, lineID)
  local text = msg
  for _, fn in ipairs(self.chatFilters[event] or {}) do
    local r = { fn(frame, event, text, author, nil, nil, nil, nil, nil, nil, base, nil, lineID) }
    if r[1] then return true end
    if r[2] then text = r[2] end
  end
  return false, text
end

-- Like ChatFrame's MessageEventHandler: a filter that returns new values
-- replaces ALL 17 message arguments with them (missing ones become nil).
-- Returns hidden, args (a table indexed 1..17).
function Game:chatArgs(event, args, frame)
  local a = {}
  for i = 1, 17 do a[i] = args[i] end
  for _, fn in ipairs(self.chatFilters[event] or {}) do
    local r = { fn(frame, event, unpack(a, 1, 17)) }
    if r[1] then return true end
    if r[2] ~= nil then
      local n = {}
      for i = 1, 17 do n[i] = r[i + 1] end
      a = n
    end
  end
  return false, a
end

return M
