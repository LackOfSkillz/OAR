-- Advisor/AdviceLoader.lua
-- Phase 9 groundwork. Reads Outrider_Advice (written by the companion app into
-- Advisor/Advice.lua) and keeps only well-formed items whose action is on the
-- whitelist. Advice never acts by itself: each item becomes a row the player
-- may click, and clicks only do the whitelisted, non-protected things below.
--
-- Every item carries a confidence ("verified" in game, "community" reported,
-- "inferred", or "unknown"); the panel shows it next to the advice.
-- Expected shape:
-- Outrider_Advice = {
--   schema = 1,
--   forCharacter = "Torrant-Realm",
--   answersSnapshot = 1731300000,      -- must equal Outrider_Snapshots[char].askedAt (or takenAt)
--   items = {
--     { title = "Tame The Rake", why = "...", action = "waypoint", confidence = "verified",
--       args = { mapID = 1412, x = 0.46, y = 0.37 } },
--   },
-- }

local _, ns = ...
local Advice = { name = "advice", SCHEMA = 1, MAX_ITEMS = 12 }
ns.Advice = Advice

-- Arg kinds: "id" = positive integer below 2^31, "frac" = finite 0..1,
-- "panel" = one of PANELS. Anything else in args is dropped.
Advice.ALLOWED = {
  waypoint    = { mapID = "id", x = "frac", y = "frac" },
  track_quest = { questID = "id" },
  open_panel  = { panel = "panel" },
  show_item   = { itemID = "id" },
}
Advice.PANELS = { hub = true, rares = true, pet = true, macros = true, gear = true, professions = true, map = true }
Advice.CONFIDENCE = { verified = true, community = true, inferred = true, unknown = true }

local function isId(v) return type(v) == "number" and v == v and v >= 1 and v < 2147483648 and v == math.floor(v) end
local function isFrac(v) return type(v) == "number" and v == v and v >= 0 and v <= 1 end

-- Strip WoW UI escape sequences (|c colors, |H links, |T textures, |r ...) and
-- control characters, so advice text is shown as plain text only.
local function plain(s, max)
  if type(s) ~= "string" then return nil end
  s = s:gsub("|", ""):gsub("[%z\1-\31]", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if #s == 0 then return nil end
  return s:sub(1, max)
end

local CHECK = {
  id = isId,
  frac = isFrac,
  panel = function(v) return type(v) == "string" and Advice.PANELS[v] == true end,
}

local function clean(item)
  if type(item) ~= "table" then return nil end
  local spec = Advice.ALLOWED[item.action]
  if not spec then return nil end
  local title = plain(item.title, 120)
  if not title then return nil end
  local args = {}
  local src = type(item.args) == "table" and item.args or {}
  for k, kind in pairs(spec) do
    if not CHECK[kind](src[k]) then return nil end
    args[k] = src[k]
  end
  -- A waypoint must name a map this client knows (skipped if the API is missing).
  if item.action == "waypoint" and ns.Compat.Has("C_Map.GetMapInfo") and not ns.Compat.Call("C_Map.GetMapInfo", args.mapID) then
    return nil
  end
  local confidence = Advice.CONFIDENCE[item.confidence] and item.confidence or "unknown"
  return { title = title, why = plain(item.why, 400) or "", action = item.action, args = args, confidence = confidence }
end

-- Returns list of clean items (possibly empty) and a reason string.
function Advice:Load()
  local a = rawget(_G, "Outrider_Advice")
  if type(a) ~= "table" then return {}, "no advice file" end
  if a.schema ~= self.SCHEMA then return {}, "wrong schema" end
  if a.forCharacter ~= ns.db.key then return {}, "advice is for another character" end
  local snaps = rawget(_G, "Outrider_Snapshots")
  local snap = type(snaps) == "table" and snaps[ns.db.key]
  if not snap then return {}, "advice is stale" end
  if snap.askedAt then
    if a.answersSnapshot ~= snap.askedAt then return {}, "advice is stale" end
  else
    -- snapshots from before askedAt existed: accept advice for this one or a
    -- logout refresh of it from the last 6 hours
    local age = (snap.takenAt or 0) - (tonumber(a.answersSnapshot) or 0)
    if age < 0 or age > 6 * 3600 then return {}, "advice is stale" end
  end
  local out = {}
  if type(a.items) == "table" then
    for _, item in ipairs(a.items) do
      local c = clean(item)
      if c then out[#out + 1] = c end
      if #out >= self.MAX_ITEMS then break end
    end
  end
  return out, "ok"
end

Advice._clean = clean
