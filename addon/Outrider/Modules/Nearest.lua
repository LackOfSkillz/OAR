-- Modules/Nearest.lua  (P3-07)
-- /ride near <kind>: nearest known place of that kind on this continent
-- (world yards), same faction or neutral, sets a waypoint and says how far.
-- On death (PLAYER_DEAD) it sets the waypoint to the nearest spirit healer by
-- itself (setting; a waypoint is not a protected action, it only shows the way).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Nearest", {
  title = "Nearest place (/ride near)",
  phase = "P3",
  order = 52,
  defaults = { spiritOnDeath = true },
})
ns.Nearest = M

M.ALIASES = {
  spirit = "spirit_healer", healer = "spirit_healer", flight = "flight_master", fly = "flight_master",
  vendor = "vendor", repair = "repair", trainer = "trainer", mail = "mailbox", mailbox = "mailbox",
  bank = "bank", ah = "auction", auction = "auction", stable = "stable_master",
  inn = "innkeeper", innkeeper = "innkeeper", guild = "guild_master", tabard = "tabard",
}

function M:OnEnable()
  self:On("PLAYER_DEAD", self.OnDead)
end

-- Returns poi, yards (or nil, reason).
function M:Find(kind)
  local W = ns.Waypoints
  local mapID = C.PlayerPosition("player")
  local _, px, py = W.PlayerWorldPos()
  if not (mapID and px) then return nil, "your position is unknown here" end
  local here = W.WorldPos(mapID, 0.5, 0.5)
  local faction = C.Call("UnitFactionGroup", "player")
  local best, bestD
  for _, p in pairs(ns.db.global.pois or {}) do
    if p.kind == kind and (p.faction == nil or p.faction == faction) then
      local cont, wx, wy = W.WorldPos(p.mapID, p.x, p.y)
      if wx and cont == here then
        local d = math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
        if not bestD or d < bestD then best, bestD = p, d end
      end
    end
  end
  if not best then return nil, "no " .. kind:gsub("_", " ") .. " known on this continent yet" end
  return best, bestD
end

function M:Go(kind)
  local p, d = self:Find(kind)
  if not p then return false, d end
  ns.Waypoints:Set(p.mapID, p.x, p.y, p.name or kind)
  self:Info("nearest %s: %s %.0f yards", kind, tostring(p.name), d)
  return true, string.format("%s, %d yards. Waypoint set.", p.name or kind, math.floor(d + 0.5))
end

function M:OnDead()
  if not self:Settings().spiritOnDeath then return end
  local ok, msg = self:Go("spirit_healer")
  if ok then ns.Print("nearest spirit healer: %s", msg) end
end

function M:Activity()
  return "/ride near spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild"
end

ns.AddCommand("near", "<spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild>  waypoint to the nearest one", function(arg)
  local kind = M.ALIASES[(arg or ""):lower()]
  if not kind then ns.Print("usage: /ride near spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild") return end
  local _, msg = M:Go(kind)
  ns.Print(msg)
end)
