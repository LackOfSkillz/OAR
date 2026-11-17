-- Modules/FlightTimes.lua
-- Flight times (gap analysis 2026-11-17, Leatrix Plus style), learned by
-- timing the flights you take: when you pick a destination at the flight
-- master (post-hook on TakeTaxiNode, which your click calls) the start and
-- destination are noted; landing (UnitOnTaxi turns false) stores the time,
-- account-wide, in ns.db.global.flightTimes["From|To"] = seconds.
-- Shown: on the flight map tooltip ("Flight: 1:42, timed"), and on the
-- info bar during a flight as a countdown to landing.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("FlightTimes", {
  title = "Flight times",
  phase = "P3",
  order = 59,
  defaults = {},
  yieldsTo = { "InFlight", "InFlight_Load" },
})
ns.FlightTimes = M

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.flightTimes = type(g.flightTimes) == "table" and g.flightTimes or {}
  self.times = g.flightTimes
end

function M.Key(from, to) return tostring(from) .. "|" .. tostring(to) end

function M:Get(from, to) return self.times[M.Key(from, to)] end

function M.Clock(sec)
  sec = math.max(0, math.floor(tonumber(sec) or 0))
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- the flight point you're standing at, from the open flight map
function M.Here()
  local n = tonumber(readable(C.Call("NumTaxiNodes"))) or 0
  for i = 1, n do
    if readable(C.Call("TaxiNodeGetType", i)) == "CURRENT" then return readable(C.Call("TaxiNodeName", i)) end
  end
  return nil
end

function M:OnTake(index)
  local to = readable(C.Call("TaxiNodeName", index))
  local from = M.Here()
  if not (to and from) then return end
  self.pending = { from = from, to = to, asked = time() }
  self:Debug("flight picked: %s -> %s", from, to)
end

function M:OnControl()
  local on = readable(C.Call("UnitOnTaxi", "player")) and true or false
  if on and self.pending and not self.flight then
    self.flight = self.pending
    self.flight.start = time()
    self.pending = nil
  elseif not on and self.flight then
    local f = self.flight
    self.flight = nil
    local secs = time() - f.start
    if secs >= 10 and secs < 3600 then
      local k = M.Key(f.from, f.to)
      local old = self.times[k]
      self.times[k] = old and math.floor((old + secs) / 2 + 0.5) or secs
      self:Info("flight %s -> %s took %s", f.from, f.to, M.Clock(secs))
    end
  end
end

-- seconds left on the current flight, if we know how long it takes
function M:Remaining()
  local f = self.flight
  if not f then return nil end
  local total = self:Get(f.from, f.to)
  if not total then return nil, f.to end
  return math.max(0, total - (time() - f.start)), f.to
end

function M:TipLine(tt, index)
  local to = readable(C.Call("TaxiNodeName", index))
  local from = M.Here()
  if not (tt and to and from) or to == from then return end
  local t = self:Get(from, to)
  if t then tt:AddLine("Flight: " .. M.Clock(t) .. " (timed by Outrider)", 0.5, 1, 0.5)
  else tt:AddLine("Flight time: not timed yet; it will be after you fly it.", 0.6, 0.6, 0.6, true) end
  tt:Show()
end

function M:OnEnable()
  if not self.hooked then
    if type(rawget(_G, "TakeTaxiNode")) == "function" then
      hooksecurefunc("TakeTaxiNode", function(i) if M.enabled then ns.Safe("flight:take", M.OnTake, M, i) end end)
    end
    if type(rawget(_G, "TaxiNodeOnButtonEnter")) == "function" then
      hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
        if M.enabled and button and button.GetID then ns.Safe("flight:tip", M.TipLine, M, rawget(_G, "GameTooltip"), button:GetID()) end
      end)
    end
    self.hooked = true
  end
  self:On("PLAYER_CONTROL_LOST", self.OnControl)
  self:On("PLAYER_CONTROL_GAINED", self.OnControl)
  self:On("PLAYER_ENTERING_WORLD", self.OnControl)
end

function M:Activity()
  local n = 0
  for _ in pairs(self.times) do n = n + 1 end
  return string.format("%d flights timed", n)
end
