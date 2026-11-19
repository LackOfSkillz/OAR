-- Modules/Forecasts.lua  (P8-08 forecasts)
-- Respawn forecasts from every respawn gap Sightings has observed (Gary's own
-- and guildmates' shared sightings, P8-03): the usual range (middle 80% of
-- the gaps once there are 5+, else min to max), the median, and how many
-- observations it rests on. Under 3 observations it says so instead of
-- guessing (hard rule 7).
-- Gold forecast from the ledger (P5-08): gold per hour over saved sessions
-- of 10+ minutes, and whether the last 5 run above or below the earlier
-- ones. Always labelled an estimate.
-- Forecasts hub tab and /ride forecast.

local _, ns = ...
local UI = ns.UI
local M = ns:NewModule("Forecasts", {
  title = "Respawn and gold forecasts",
  phase = "P8",
  order = 94,
  defaults = {},
})
ns.Forecasts = M

M.MIN_OBS, M.MIN_SESSION = 3, 600

local function sorted(list)
  local t = {}
  for i, v in ipairs(list) do t[i] = v end
  table.sort(t)
  return t
end

local function pick(t, f) return t[math.max(1, math.min(#t, math.floor(f * (#t - 1) + 1.5)))] end

-- { lo, hi, median, n } or { n } when too few
function M.Respawn(gaps)
  local n = gaps and #gaps or 0
  if n < M.MIN_OBS then return { n = n } end
  local t = sorted(gaps)
  local lo, hi = t[1], t[#t]
  if n >= 5 then lo, hi = pick(t, 0.1), pick(t, 0.9) end
  return { lo = lo, hi = hi, median = pick(t, 0.5), n = n }
end

local function mins(sec) return math.floor(sec / 60 + 0.5) end

local function rareName(id)
  local pack = ns.Data and ns.Data:Get("rare", id)
  if pack and pack.name then return pack.name end
  local d = ns.db.global.discovered and ns.db.global.discovered.npcs and ns.db.global.discovered.npcs[id]
  return d and d.name or ("NPC " .. id)
end

-- { {npcID, name, text, n} } sorted by observations
function M:RespawnLines()
  local out = {}
  for id, gaps in pairs(ns.db.global.respawnObs or {}) do
    local r = M.Respawn(gaps)
    local text
    if r.lo then
      text = string.format("respawns in %d to %d min, usually %d (%d observations)", mins(r.lo), mins(r.hi), mins(r.median), r.n)
    else
      -- in words (tour 2026-11-19: "2 of 3 observations needed" read like a fault)
      local more = M.MIN_OBS - r.n
      text = string.format("%d respawn%s timed so far; %d more and Outrider can forecast it", r.n, r.n == 1 and "" or "s", more)
    end
    out[#out + 1] = { npcID = id, name = rareName(id), text = text, n = r.n, ready = r.lo ~= nil }
  end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
  return out
end

-- { perHour, sessions, trend = "up"|"down"|"steady"|nil } in copper, or nil
function M.Gold(sessions)
  local total, secs, rates = 0, 0, {}
  for _, s in ipairs(sessions or {}) do
    local d = (s.stop or 0) - (s.start or 0)
    if d >= M.MIN_SESSION and type(s.net) == "number" then
      total, secs = total + s.net, secs + d
      rates[#rates + 1] = s.net / d * 3600
    end
  end
  if #rates == 0 then return nil end
  local r = { perHour = total / secs * 3600, sessions = #rates }
  if #rates >= 8 then
    local early, late = 0, 0
    for i = 1, #rates - 5 do early = early + rates[i] end
    for i = #rates - 4, #rates do late = late + rates[i] end
    early, late = early / (#rates - 5), late / 5
    local base = math.max(math.abs(early), 1)
    if late > early + base * 0.15 then r.trend = "up"
    elseif late < early - base * 0.15 then r.trend = "down"
    else r.trend = "steady" end
  end
  return r
end

function M:GoldLine()
  local g = M.Gold(ns.db.char.ledger)
  if not g then return "Gold: no sessions of 10+ minutes saved yet (log out once to save one)" end
  local money = ns.Prices.Money(math.floor(math.abs(g.perHour)))
  return string.format("Gold: about %s%s per hour over %d sessions%s (estimate)", g.perHour < 0 and "-" or "", money,
    g.sessions, g.trend and (", trend " .. g.trend) or "")
end

function M:Activity()
  local n = 0
  for _, l in ipairs(self:RespawnLines()) do if l.n >= M.MIN_OBS then n = n + 1 end end
  return string.format("%d rares with a respawn forecast", n)
end

ns.Hub:AddTab("forecasts", "Forecasts", function(p)
  p.stats = UI:StatStrip(p)
  p.stats:SetPoint("TOPLEFT", 0, 0)
  p.stats:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.gold = UI.Text(p, "normal", "text")
  p.gold:SetPoint("TOPLEFT", 0, -80)
  p.gold:SetPoint("RIGHT", p, "RIGHT", -4, 0) p.gold:SetJustifyH("LEFT")
  p.list = UI:ScrollList(p, {
    rows = 12, rowHeight = 22,
    render = function(row, l) row.text:SetText(l.name .. "  |cffbbbbbb" .. l.text .. "|r") end,
  })
  p.list:SetPoint("TOPLEFT", p.gold, "BOTTOMLEFT", 0, -10)
  p.list:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  function p:Refresh()
    local g = M.Gold(ns.db.char.ledger)
    local lines = M:RespawnLines()
    local ready = 0
    for _, l in ipairs(lines) do if l.ready then ready = ready + 1 end end
    self.stats:SetItems({
      { cap = "Gold per hour", value = g and ns.Prices.Coins(math.floor(math.abs(g.perHour))) or "—", color = g and "gold" or nil,
        note = g and ("over " .. g.sessions .. " sessions") or "log out once to save a session" },
      { cap = "Trend", value = g and g.trend and ns.TitleCase(g.trend) or "—", color = g and g.trend == "up" and "good" or g and g.trend == "down" and "bad" or nil },
      { cap = "Rares with a forecast", value = tostring(ready), note = ready == 0 and (#lines > 0 and (#lines .. " still learning") or "needs sightings") or "respawn times below" },
    })
    self.gold:SetText(M:GoldLine())
    self.list:SetItems(lines)
  end
end, 49)

ns.AddCommand("forecast", "respawn and gold forecasts", function()
  ns.Print(M:GoldLine())
  local lines = M:RespawnLines()
  if #lines == 0 then ns.Print("no respawns observed yet") end
  for i = 1, math.min(8, #lines) do ns.Print("%s: %s", lines[i].name, lines[i].text) end
end)
