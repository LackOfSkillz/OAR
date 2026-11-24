-- Modules/FishingLog.lua
-- Fishing session detail, spots, records and a wanted list (requirement
-- 2026-11-23: after researching OneCast, the fishing module must match or
-- beat it). Outrider already had the one-key cast and hook, lure on the key,
-- the 4-line HUD, lifetime counts, the skill-up predictor, zones per skill,
-- trainers, gear swap and the Extravaganza countdown. This adds what OneCast
-- shows that we didn't:
--   * the session in full: fish, vendor gold and auction gold per hour, caught
--     of casts, getaways, skill gained and per hour, catches and time to the
--     next point and to the cap, worth at vendor and at the auction house,
--     every fish with its share and price, and fish per hour with and without
--     a lure
--   * spots: every sub-zone you fished, fish and gold per hour there, best
--     first, an arrow back to it; for any fish, the spots where it bites best
--   * records: best fish and gold per hour, biggest session, past sessions,
--     notable catches (green or better, and the first of each fish ever)
--   * a wanted list ("20 Stonescale Eel") counted from your bags, with an alert
--   * lures left in the bags, and a nudge to restock under 5
--   * the Speckled Tastyfish count while the Extravaganza is on
-- Read only: it listens to loot, casts and errors. Nothing here acts.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("FishingLog", {
  title = "Fishing session, spots and records",
  phase = "P5",
  order = 77,
  defaults = { wantedAlert = true },
})
ns.FishingLog = M

M.RESUME = 15 * 60     -- a break shorter than this keeps the session going
M.GAP = 300            -- seconds of idle counted at most between two events
M.KEEP_SESSIONS = 30
M.KEEP_NOTABLE = 25
M.RECORD_SECS = 15 * 60 -- a session counts for per-hour records after this long
M.SPOT_CASTS = 5        -- a spot needs this many casts before it's ranked
M.LOW_LURES = 5
M.TASTYFISH = "Speckled Tastyfish"

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end
local function now() return time() end

function M:OnInitialize()
  local g = ns.db.global
  g.fishLog = type(g.fishLog) == "table" and g.fishLog or {}
  local d = g.fishLog
  d.sessions = type(d.sessions) == "table" and d.sessions or {}
  d.best = type(d.best) == "table" and d.best or {}
  d.spots = type(d.spots) == "table" and d.spots or {}
  d.first = type(d.first) == "table" and d.first or {}
  d.notable = type(d.notable) == "table" and d.notable or {}
  d.wanted = type(d.wanted) == "table" and d.wanted or {}
  -- fish caught before this module existed aren't "new" (FishingGuide's lifetime list)
  if not d.seeded then
    for id in pairs(g.fishStats and g.fishStats.fish or {}) do d.first[id] = d.first[id] or { t = 0 } end
    for _, zone in pairs(g.fishing or {}) do
      for id in pairs(type(zone) == "table" and zone or {}) do d.first[id] = d.first[id] or { t = 0 } end
    end
    d.seeded = true
  end
  self.data = d
end

-- ------------------------------------------------------------------ prices
-- vendor copper each, and auction copper each (after the 5% cut; vendor when
-- no auction price is known, like OneCast's "AH" column)
function M.Prices(id)
  local ah, src, vendor
  if ns.Prices and ns.Prices.Get then ah, src, vendor = ns.Prices:Get(id) end
  vendor = vendor or ((C.ItemInfo(id) or {}).sellPrice) or 0
  local auction = ah and math.floor(ah * 0.95) or vendor
  return vendor, auction
end

-- ------------------------------------------------------------------ session
function M:Skill()
  if ns.FishingHUD and ns.FishingHUD.Skill then return ns.FishingHUD:Skill() end
end

function M:LureOn()
  return ns.Fishing and ns.Fishing.LureActive and ns.Fishing:LureActive() or false
end

-- The current session, resumed if the last cast or catch was recent; an old
-- one goes into the history first.
function M:Session()
  local s = ns.db.char.fishLogSession
  if type(s) == "table" and s.last and now() - s.last < M.RESUME then return s end
  if type(s) == "table" then self:Archive(s) end
  local skill = self:Skill()
  s = { start = now(), last = now(), secs = 0, casts = 0, catches = 0, escapes = 0, skill0 = skill,
    fish = {}, lureSecs = 0, lureCatches = 0, bareSecs = 0, bareCatches = 0 }
  ns.db.char.fishLogSession = s
  return s
end

function M:Current()
  local s = ns.db.char.fishLogSession
  if type(s) == "table" and s.last and now() - s.last < M.RESUME then return s end
end

-- Count the time since the last event (at most GAP), split by lure on or off.
function M:Touch(s)
  local t = now()
  local dt = math.max(0, math.min(t - (s.last or t), M.GAP))
  s.secs = s.secs + dt
  if self:LureOn() then s.lureSecs = s.lureSecs + dt else s.bareSecs = s.bareSecs + dt end
  s.last = t
  local spot = self:Spot()
  if spot then spot.secs = (spot.secs or 0) + dt end
  return dt
end

-- Where you're fishing: { name, mapID, x, y, casts, catches, secs, fish = {[id] = {n, t}} }
function M:Spot()
  local mapID, x, y = C.PlayerPosition("player")
  if not mapID then return nil end
  local sub = readable(C.Call("GetSubZoneText"))
  if type(sub) ~= "string" or sub == "" then sub = readable(C.Call("GetZoneText")) end
  if type(sub) ~= "string" or sub == "" then sub = "Open water" end
  local zone = self.data.spots[mapID] or {}
  self.data.spots[mapID] = zone
  local spot = zone[sub]
  if not spot then
    spot = { name = sub, casts = 0, catches = 0, secs = 0, fish = {} }
    zone[sub] = spot
  end
  if x and not spot.x then spot.x, spot.y = x, y end
  spot.mapID = mapID
  return spot
end

function M:OnCast(_, unit, _, spellID)
  if unit ~= "player" then return end
  local info = C.Call("C_Spell.GetSpellInfo", spellID)
  if readable(type(info) == "table" and info.name or nil) ~= "Fishing" then return end
  local s = self:Session()
  self:Touch(s)
  s.casts = s.casts + 1
  local spot = self:Spot()
  if spot then spot.casts = spot.casts + 1 end
end

function M:OnError(_, _, message)
  if type(message) ~= "string" then return end
  local escaped = rawget(_G, "ERR_FISH_ESCAPED") or rawget(_G, "FISH_ESCAPED")
  if not ((escaped and message == escaped) or message:lower():find("got away", 1, true)) then return end
  local s = self:Current()
  if s then s.escapes = s.escapes + 1 s.last = now() end
end

function M:OnSkill(_, msg)
  msg = readable(msg)
  if type(msg) ~= "string" or not msg:find("Fishing", 1, true) then return end
  local s = self:Current()
  local skill = tonumber(msg:match("(%d+)"))
  if s and skill then
    s.skillNow = skill
    if not s.skill0 then s.skill0 = skill - 1 end
  end
end

function M:OnLoot(_, kind, items)
  if kind ~= "fish" or type(items) ~= "table" then return end
  local s = self:Session()
  self:Touch(s)
  local spot = self:Spot()
  local lure = self:LureOn()
  local newOnes = {}
  for _, it in ipairs(items) do
    local id, n = it.id, it.count or 1
    if id then
      s.catches = s.catches + n
      if lure then s.lureCatches = s.lureCatches + n else s.bareCatches = s.bareCatches + n end
      local f = s.fish[id] or { n = 0, name = it.name }
      f.n, f.name = f.n + n, f.name or it.name
      s.fish[id] = f
      s.latest = { id = id, t = now(), name = f.name }
      if spot then
        spot.catches = spot.catches + n
        local sf = spot.fish[id] or { n = 0 }
        sf.n, sf.t = sf.n + n, now()
        spot.fish[id] = sf
      end
      if not self.data.first[id] then
        self.data.first[id] = { t = now(), char = ns.db.key }
        newOnes[#newOnes + 1] = f.name or ("item " .. id)
        self:Notable(id, f.name, "new")
      else
        local info = C.ItemInfo(id)
        if info and type(info.quality) == "number" and info.quality >= 2 then self:Notable(id, f.name, "rare") end
      end
      self:CheckWanted(id, f.name)
    end
  end
  if #newOnes > 0 then
    self:Info("new for your collection: %s", table.concat(newOnes, ", "))
    -- one chat line per session (quiet by default); the rest are on the Fishing page
    if not self.saidNew then
      self.saidNew = true
      ns.Print("fishing: new for your collection: %s", table.concat(newOnes, ", "))
    end
  end
  self:Records(s)
end

function M:Notable(id, name, why)
  local list = self.data.notable
  table.insert(list, 1, { id = id, name = name, why = why, t = now(), char = ns.db.key })
  for i = M.KEEP_NOTABLE + 1, #list do list[i] = nil end
end

-- ------------------------------------------------------------------ numbers
-- Everything the session page shows, worked out from the raw counts.
function M.Stats(s)
  if type(s) ~= "table" then return nil end
  local out = { catches = s.catches, casts = s.casts, escapes = s.escapes, secs = s.secs, vendor = 0, auction = 0, fish = {} }
  for id, f in pairs(s.fish or {}) do
    local v, a = M.Prices(id)
    out.vendor, out.auction = out.vendor + v * f.n, out.auction + a * f.n
    out.fish[#out.fish + 1] = { id = id, name = f.name or ((C.ItemInfo(id) or {}).name) or ("item " .. id), n = f.n,
      share = s.catches > 0 and f.n / s.catches or 0, vendor = v, auction = a }
  end
  table.sort(out.fish, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
  local hours = s.secs / 3600
  if s.secs >= 60 then
    out.fishHr = s.catches / hours
    out.vendorHr = out.vendor / hours
    out.auctionHr = out.auction / hours
  end
  if s.lureSecs and s.lureSecs >= 120 then out.lureHr = s.lureCatches / (s.lureSecs / 3600) end
  if s.bareSecs and s.bareSecs >= 120 then out.bareHr = s.bareCatches / (s.bareSecs / 3600) end
  if s.skill0 and s.skillNow then
    out.gained = math.max(0, s.skillNow - s.skill0)
    if s.secs >= 60 then out.skillHr = out.gained / hours end
  end
  return out
end

-- Catches and seconds to the next point and to the cap, from your own
-- catches per point (FishingGuide) and this session's catch speed.
function M:Ahead(st)
  local G = ns.FishingGuide
  if not (G and G.NextPoint) then return nil end
  local left, avg = G:NextPoint()
  if not left then return nil end
  local skill, max = self:Skill()
  local out = { next = left }
  if type(skill) == "number" and type(max) == "number" and max > skill then
    out.toMax = math.ceil(left + avg * (max - skill - 1))
    out.max = max
  end
  local rate = st and st.fishHr
  if rate and rate > 0 then
    out.nextSecs = math.floor(out.next / rate * 3600)
    if out.toMax then out.maxSecs = math.floor(out.toMax / rate * 3600) end
  end
  return out
end

-- Keep the bests up to date (per-hour records only after RECORD_SECS).
function M:Records(s)
  local st = M.Stats(s)
  if not st then return end
  local b = self.data.best
  local function better(key, v)
    if v and (not b[key] or v > b[key].v) then b[key] = { v = v, t = now(), char = ns.db.key } end
  end
  better("catches", st.catches)
  if s.secs >= M.RECORD_SECS then
    better("fishHr", st.fishHr)
    better("goldHr", st.auctionHr)
  end
end

function M:Archive(s)
  local st = M.Stats(s)
  if not st or st.catches == 0 then return end
  table.insert(self.data.sessions, 1, { start = s.start, secs = s.secs, catches = s.catches, casts = s.casts,
    vendor = st.vendor, auction = st.auction, gained = st.gained, char = ns.db.key,
    top = st.fish[1] and st.fish[1].name or nil })
  for i = M.KEEP_SESSIONS + 1, #self.data.sessions do self.data.sessions[i] = nil end
end

function M:Reset()
  local s = ns.db.char.fishLogSession
  if type(s) == "table" then self:Archive(s) end
  ns.db.char.fishLogSession = nil
  self.saidNew = nil
end

-- ------------------------------------------------------------------ spots
-- This zone's spots, best fish per hour first (spots with few casts last).
function M:SpotsHere(mapID)
  mapID = mapID or C.PlayerPosition("player")
  local out = {}
  for _, spot in pairs(mapID and self.data.spots[mapID] or {}) do
    local hours = (spot.secs or 0) / 3600
    local value = 0
    for id, f in pairs(spot.fish) do local _, a = M.Prices(id) value = value + a * f.n end
    out[#out + 1] = { spot = spot, name = spot.name, casts = spot.casts, catches = spot.catches,
      fishHr = hours > 0 and spot.catches / hours or nil, goldHr = hours > 0 and value / hours or nil,
      ranked = spot.casts >= M.SPOT_CASTS }
  end
  table.sort(out, function(a, b)
    if a.ranked ~= b.ranked then return a.ranked end
    if (a.fishHr or 0) ~= (b.fishHr or 0) then return (a.fishHr or 0) > (b.fishHr or 0) end
    return a.name < b.name
  end)
  return out
end

-- Where one fish bites best: spots by its share of the catches there.
function M:WhereBites(id)
  local out = {}
  for mapID, zone in pairs(self.data.spots) do
    for _, spot in pairs(zone) do
      local f = spot.fish[id]
      if f and spot.catches > 0 then
        out[#out + 1] = { mapID = mapID, spot = spot, name = spot.name, n = f.n, share = f.n / spot.catches, t = f.t }
      end
    end
  end
  table.sort(out, function(a, b) if a.share ~= b.share then return a.share > b.share end return a.n > b.n end)
  return out
end

function M:GoSpot(spot)
  if not (spot and spot.mapID and spot.x and ns.Waypoints) then return false end
  ns.Waypoints:Set(spot.mapID, spot.x, spot.y, spot.name)
  return true
end

-- ------------------------------------------------------------------ wanted
local function bagCount(id)
  local n = C.Call("C_Item.GetItemCount", id)
  if n == nil then n = C.Call("GetItemCount", id) end
  return tonumber(readable(n)) or 0
end
M.BagCount = bagCount

-- An item id from a link, "#123", a number or a name you've caught.
function M:Resolve(text)
  if type(text) == "number" then return text end
  if type(text) ~= "string" then return nil end
  local id = tonumber(text:match("item:(%d+)") or text:match("^#?(%d+)$"))
  if id then return id end
  local want = text:lower()
  for fid, f in pairs(ns.db.global.fishStats and ns.db.global.fishStats.fish or {}) do
    if type(f) == "table" and f.name and f.name:lower() == want then return fid, f.name end
  end
  local s = self:Current()
  for fid, f in pairs(s and s.fish or {}) do if f.name and f.name:lower() == want then return fid, f.name end end
end

function M:Want(id, count, name)
  if not id then return false end
  count = math.max(1, math.floor(tonumber(count) or 20))
  for _, w in ipairs(self.data.wanted) do
    if w.id == id then w.want, w.done = count, nil return true end
  end
  name = name or ((C.ItemInfo(id) or {}).name)
  self.data.wanted[#self.data.wanted + 1] = { id = id, name = name, want = count }
  return true
end

function M:Unwant(id)
  for i, w in ipairs(self.data.wanted) do
    if w.id == id then table.remove(self.data.wanted, i) return true end
  end
  return false
end

function M:Wanted()
  local out = {}
  for _, w in ipairs(self.data.wanted) do
    local have = bagCount(w.id)
    out[#out + 1] = { id = w.id, name = w.name or ("item " .. w.id), want = w.want, have = have, done = have >= w.want }
  end
  return out
end

function M:CheckWanted(id, name)
  for _, w in ipairs(self.data.wanted) do
    if w.id == id then
      -- the catch isn't in the bags yet while the loot window is open
      local have = bagCount(id) + 1
      w.name = w.name or name
      local done = have >= w.want
      self:Info("wanted catch %s %d/%d", tostring(w.name), have, w.want)
      if self:Settings().wantedAlert and ns.Toast then
        ns.Toast:Show({ title = done and "Wanted list done!" or "Wanted catch", text = string.format("%s %d/%d", tostring(w.name), math.min(have, w.want), w.want),
          color = "good", duration = done and 8 or 4, sound = done and ns.Toast:SoundID("READY_CHECK") or nil })
      end
      return
    end
  end
end

-- ------------------------------------------------------------------ lures and the contest
-- { name, count } of the lure the fish key would use, and whether it's running low.
function M:Lures()
  local F = ns.Fishing
  local name = F and F.LureInBags and F:LureInBags()
  if not name then return nil end
  local n = 0
  for bag = 0, 4 do
    for slot = 1, (C.Call("C_Container.GetContainerNumSlots", bag) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local it = type(info) == "table" and info.itemID and C.ItemInfo(info.itemID)
      if it and it.name == name then n = n + (tonumber(readable(info.stackCount)) or 1) end
    end
  end
  return { name = name, count = n, low = n < M.LOW_LURES }
end

-- Speckled Tastyfish in the bags while the Extravaganza is on, else nil.
function M:Tastyfish()
  local G = ns.FishingGuide
  local _, on = G and G.Extravaganza and G:Extravaganza()
  if not on then return nil end
  local n = tonumber(readable(C.Call("GetItemCount", M.TASTYFISH))) or 0
  return n, 40
end

-- ------------------------------------------------------------------ text
function M.Clock(secs)
  secs = math.floor(secs or 0)
  if secs >= 3600 then return string.format("%dh %dm", math.floor(secs / 3600), math.floor(secs % 3600 / 60)) end
  if secs >= 60 then return string.format("%dm", math.floor(secs / 60)) end
  return secs .. "s"
end

function M.Money(c)
  return ns.Prices and ns.Prices.Money and ns.Prices.Money(math.floor(c or 0)) or tostring(math.floor(c or 0))
end

-- The session as plain lines (the page and /ride fishstats).
function M:Report()
  local s = self:Current()
  local st = M.Stats(s)
  if not st or (st.catches == 0 and st.casts == 0) then return { "No fishing session yet: equip a pole and cast." } end
  local out = {}
  out[#out + 1] = string.format("Session %s: %d caught of %d casts, %d got away", M.Clock(st.secs), st.catches, st.casts, st.escapes)
  if st.fishHr then
    out[#out + 1] = string.format("%d fish/hr · %s vendor/hr · %s auction/hr", math.floor(st.fishHr + 0.5), M.Money(st.vendorHr), M.Money(st.auctionHr))
  end
  out[#out + 1] = string.format("Worth: %s vendor · %s auction", M.Money(st.vendor), M.Money(st.auction))
  if st.gained then
    out[#out + 1] = string.format("Skill gained: +%d%s", st.gained, st.skillHr and string.format(" (%.0f/hr)", st.skillHr) or "")
  end
  local a = self:Ahead(st)
  if a then
    out[#out + 1] = string.format("Next point: about %d catches%s", a.next, a.nextSecs and (" (" .. M.Clock(a.nextSecs) .. ")") or "")
    if a.toMax then
      out[#out + 1] = string.format("To %d: about %d catches%s", a.max, a.toMax, a.maxSecs and (" (" .. M.Clock(a.maxSecs) .. ")") or "")
    end
  end
  if st.lureHr and st.bareHr then
    out[#out + 1] = string.format("With a lure %d fish/hr, without %d fish/hr", math.floor(st.lureHr + 0.5), math.floor(st.bareHr + 0.5))
  end
  return out
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("OTR_LOOT", self.OnLoot)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("UI_ERROR_MESSAGE", self.OnError)
  self:On("CHAT_MSG_SKILL", self.OnSkill)
end

function M:Activity()
  local st = M.Stats(self:Current())
  if not st or st.catches == 0 then return string.format("%d spots, %d past sessions", (function()
    local n = 0 for _, z in pairs(self.data.spots) do for _ in pairs(z) do n = n + 1 end end return n end)(), #self.data.sessions) end
  return string.format("this session: %d fish%s", st.catches, st.fishHr and string.format(", %d/hr", math.floor(st.fishHr + 0.5)) or "")
end

ns.AddCommand("fishstats", "[reset]  this fishing session in full (reset starts a new one)", function(arg)
  if arg and arg:lower() == "reset" then M:Reset() ns.Print("fishing: new session started") return end
  for _, line in ipairs(M:Report()) do ns.Print("%s", line) end
end)

ns.AddCommand("fishwant", "<fish> [count] | remove <fish> | clear  fish you want, counted from your bags", function(arg)
  if not arg or arg == "" then
    local list = M:Wanted()
    if #list == 0 then ns.Print("wanted list is empty: /ride fishwant Stonescale Eel 20") return end
    for _, w in ipairs(list) do ns.Print("%s %d/%d%s", w.name, math.min(w.have, w.want), w.want, w.done and " (done)" or "") end
    return
  end
  if arg:lower() == "clear" then M.data.wanted = {} ns.db.global.fishLog.wanted = M.data.wanted ns.Print("wanted list cleared") return end
  local rm = arg:match("^[Rr]emove%s+(.+)$")
  if rm then
    local id = M:Resolve(rm)
    ns.Print(id and M:Unwant(id) and "removed from the wanted list" or "not on the wanted list")
    return
  end
  local text, count = arg:match("^(.-)%s+(%d+)$")
  text = text or arg
  local id, name = M:Resolve(text)
  if not id then ns.Print("fishing: catch one %s first, or use its item link", text) return end
  M:Want(id, count, name)
  ns.Print("wanted: %s x%d", tostring(name or (C.ItemInfo(id) or {}).name or ("item " .. id)), tonumber(count) or 20)
end)
