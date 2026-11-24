-- Intelligence/State.lua  (OI02-04)
-- A read-only view of this character and the account for the Nexus planner.
-- Each field is read lazily through public functions or the client, cached
-- with the time it was read and a revision, and invalidated only by the events
-- that can change that field (a bag update never drops the gear or location
-- reading). Other characters come from their last saved snapshot and are
-- always marked live = false with their age: an alt's gold or level is never
-- presented as current. Nothing here writes saved data or acts in the game.
--   ns.NexusState:Get(field)  -> { value, at, revision, live = true } or nil, why
--   ns.NexusState:Alts(now)   -> { { key, level, class, copper, zone, at, ageSeconds, live = false } }
--   ns.NexusState:Revision()  -> bumps on any field change (plans key on it)

local _, ns = ...
local C = ns.Compat
local S = { cache = {}, revision = 0, name = "NexusState" }
ns.NexusState = S

-- field -> reader (public functions and the client only)
S.READERS = {
  gold = function() return tonumber(C.Readable(C.Call("GetMoney"))) end,
  level = function() return tonumber(C.Readable(C.Call("UnitLevel", "player"))) end,
  location = function()
    local mapID, x, y = C.PlayerPosition("player")
    if not mapID then return nil end
    return { mapID = mapID, x = x, y = y }
  end,
  gear = function()
    local out = {}
    for slot = 1, 19 do
      local link = C.Readable(C.Call("GetInventoryItemLink", "player", slot))
      local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
      if id then out[slot] = id end
    end
    return out
  end,
  spellbook = function()
    local B = ns.Spellbook
    if not (B and B.Known) then return nil end
    local n = 0
    for _ in pairs(B.spells or {}) do n = n + 1 end
    return { count = n }
  end,
  inventory = function()
    local I = ns.Inventory
    if not (I and I.enabled and I.Mine) then return nil end
    local mine = I:Mine()
    local bags, kinds = 0, 0
    for _, n in pairs(mine.bags or {}) do bags = bags + (tonumber(n) or 0) kinds = kinds + 1 end
    return { items = bags, kinds = kinds }
  end,
  professions = function()
    local P = ns.Modules:Get("Professions")
    return P and P.Snapshot and P:Snapshot() or nil
  end,
}

-- event -> fields it can change
S.EVENTS = {
  PLAYER_MONEY = { "gold" },
  PLAYER_LEVEL_UP = { "level" },
  ZONE_CHANGED_NEW_AREA = { "location" },
  ZONE_CHANGED = { "location" },
  PLAYER_ENTERING_WORLD = { "location", "gear", "level", "gold" },
  PLAYER_EQUIPMENT_CHANGED = { "gear" },
  SPELLS_CHANGED = { "spellbook" },
  BAG_UPDATE_DELAYED = { "inventory" },
  SKILL_LINES_CHANGED = { "professions" },
  TRADE_SKILL_LIST_UPDATE = { "professions" },
  -- OI02-R17: what justified a step can change with these too. Quests:
  -- accepting, turning in or abandoning one changes what is available and
  -- which prerequisites are done. Talents and specialization. The auction
  -- house: opening, closing and new search results change which listings
  -- (Deal Desk lots) exist. An event this client lacks is skipped safely
  -- (Core/Events.lua registers through pcall).
  QUEST_ACCEPTED = { "quests" },
  QUEST_TURNED_IN = { "quests" },
  QUEST_REMOVED = { "quests" },
  PLAYER_TALENT_UPDATE = { "talents" },
  CHARACTER_POINTS_CHANGED = { "talents" },
  ACTIVE_TALENT_GROUP_CHANGED = { "talents" },
  PLAYER_SPECIALIZATION_CHANGED = { "talents" },
  TRAIT_CONFIG_UPDATED = { "talents" },
  AUCTION_HOUSE_SHOW = { "auction" },
  AUCTION_HOUSE_CLOSED = { "auction" },
  ITEM_SEARCH_RESULTS_UPDATED = { "auction" },
}

-- any event that can change a field moves the revision on, read or not
-- (a plan built before the change is stale even if it never read that field)
function S:Invalidate(field)
  self.cache[field] = nil
  self.revision = self.revision + 1
end

function S:Revision() return self.revision end

function S:Get(field)
  local reader = self.READERS[field]
  if not reader then return nil, "unknown field" end
  local c = self.cache[field]
  if c then return c end
  local ok, value = pcall(reader)
  if not ok then return nil, "read failed" end
  if value == nil then return nil, "unknown" end
  c = { value = value, at = time(), revision = self.revision, live = true }
  self.cache[field] = c
  return c
end

-- other characters: last saved snapshot, never current
function S:Alts(now)
  now = now or time()
  local A = ns.Alts
  if not (A and A.List) then return {} end
  local out = {}
  for _, e in ipairs(A:List()) do
    if not e.current then
      local a = e.a or {}
      local at = tonumber(a.t)
      out[#out + 1] = { key = e.key, level = a.level, class = a.class, copper = tonumber(a.money), zone = a.zone,
        at = at, ageSeconds = at and math.max(0, now - at) or nil, live = false }
    end
  end
  return out
end

-- a short line for an alt: "level 24, 12g (seen 3 days ago)"
function S.AltAge(seconds)
  if not seconds then return "age unknown" end
  if seconds < 3600 then return string.format("seen %d min ago", math.floor(seconds / 60)) end
  if seconds < 86400 then return string.format("seen %d h ago", math.floor(seconds / 3600)) end
  return string.format("seen %d days ago", math.floor(seconds / 86400))
end

-- listen on the shared event bus with S as the owner (it isn't a module)
for event, fields in pairs(S.EVENTS) do
  ns.Events:On(event, S, function()
    for _, f in ipairs(fields) do S:Invalidate(f) end
  end)
end
