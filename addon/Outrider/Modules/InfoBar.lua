-- Modules/InfoBar.lua
-- A thin info strip (gap analysis 2026-11-17, Titan Panel style): gold, free
-- bag slots, durability, ammo (hunters), XP with rested and quest XP, clock,
-- latency and frame rate. Display only: our own plain frame, never a Blizzard
-- one. Hover a segment for detail; a click opens the matching page (bags open
-- Blizzard's own bags). Drag with Shift held to move it; the spot is saved
-- per character. Refreshed once a second for the clock and latency.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("InfoBar", {
  title = "Info bar",
  phase = "P7",
  order = 48,
  defaults = { shown = true, point = nil, flight = true, gold = true, bags = true, dura = true, ammo = true, xp = true, layer = true, clock = true, net = true },
  yieldsTo = { "Titan", "ChocolateBar", "Bazooka" },
})
ns.InfoBar = M

M.ORDER = { "flight", "layer", "gold", "bags", "dura", "ammo", "xp", "clock", "net" }

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

-- ------------------------------------------------------------------ values
function M.GoldText(copper)
  copper = tonumber(copper) or 0
  if ns.Prices and ns.Prices.Coins then return ns.Prices.Coins(copper) end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return string.format("|cffffd100%dg|r %ds", g, s) end
  if s > 0 then return string.format("%ds %dc", s, c) end
  return c .. "c"
end

-- free and total general bag slots (profession bags left out)
function M.Bags()
  local free, total = 0, 0
  for bag = 0, 4 do
    local n = tonumber(C.NumSlots(bag)) or 0
    local f, kind = C.Call("C_Container.GetContainerNumFreeSlots", bag)
    if f == nil then f, kind = C.Call("GetContainerNumFreeSlots", bag) end
    if n > 0 and (kind == nil or kind == 0) then
      total = total + n
      free = free + (tonumber(f) or 0)
    end
  end
  return free, total
end

-- lowest durability percent over worn items, and the overall percent
M.DURA_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
function M.Durability()
  local cur, max, low, lowSlot = 0, 0, 100, nil
  for _, slot in ipairs(M.DURA_SLOTS) do
    local a, b = C.Call("GetInventoryItemDurability", slot)
    a, b = tonumber(readable(a)), tonumber(readable(b))
    if a and b and b > 0 then
      cur, max = cur + a, max + b
      local pct = a / b * 100
      if pct < low then low, lowSlot = pct, slot end
    end
  end
  if max == 0 then return nil end
  return cur / max * 100, low, lowSlot
end

function M.Ammo()
  local _, class = C.Call("UnitClass", "player")
  if class ~= "HUNTER" then return nil end
  return tonumber(readable(C.Call("GetInventoryItemCount", "player", 0)))
end

-- XP percent, rested percent, and the XP waiting in finished-or-not quests
function M.XP()
  local level = tonumber(C.Call("UnitLevel", "player")) or 1
  local maxLevel = tonumber(readable(C.Call("GetMaxPlayerLevel"))) or 60
  if level >= maxLevel then return nil end
  local xp, need = tonumber(readable(C.Call("UnitXP", "player"))), tonumber(readable(C.Call("UnitXPMax", "player")))
  if not (xp and need and need > 0) then return nil end
  local rested = tonumber(readable(C.Call("GetXPExhaustion"))) or 0
  local quest, ready = 0, 0
  if ns.QuestExtras and ns.QuestExtras.QuestXP then quest, ready = ns.QuestExtras:QuestXP() end
  return xp / need * 100, rested / need * 100, quest, xp, need, ready
end

function M.Net()
  local _, _, home, world = C.Call("GetNetStats")
  local fps = tonumber(C.Call("GetFramerate"))
  return tonumber(world) or tonumber(home), fps and math.floor(fps + 0.5)
end

-- text for each segment (nil hides it)
function M:Text(id)
  local s = self:Settings()
  if s[id] == false then return nil end
  if id == "flight" then
    local F = ns.FlightTimes
    if not (F and F.flight) then return nil end
    local left, to = F:Remaining()
    return left and string.format("|cff7fbfffLanding in %s|r", F.Clock(left)) or string.format("|cff7fbfffFlying to %s|r", tostring(to or "?"))
  end
  if id == "layer" then
    local layers = ns.Layers
    if not (layers and layers.enabled) or C.Call("IsInInstance") then return nil end
    local id, _, label = layers:Current()
    if not id then return "|cff8f96a6Layer —|r" end
    return label
  end
  if id == "gold" then return M.GoldText(C.Call("GetMoney")) end
  if id == "bags" then
    local free, total = M.Bags()
    if total == 0 then return nil end
    local col = free <= 2 and "|cffff5050" or free <= 6 and "|cffffd100" or "|cffffffff"
    return string.format("Bags %s%d|r/%d", col, free, total)
  end
  if id == "dura" then
    local all, low = M.Durability()
    if not all then return nil end
    local col = low < 20 and "|cffff5050" or low < 50 and "|cffffd100" or "|cffffffff"
    return string.format("Durability %s%d%%|r", col, math.floor(math.min(all, low + 30) + 0.5))
  end
  if id == "ammo" then
    local n = M.Ammo()
    if not n then return nil end
    local col = n < 50 and "|cffff5050" or n < 200 and "|cffffd100" or "|cffffffff"
    return string.format("Ammo %s%d|r", col, n)
  end
  if id == "xp" then
    local pct, rested, quest, _, need, ready = M.XP()
    if not pct then return nil end
    local t = string.format("XP %d%%", math.floor(pct))
    if rested > 0 then t = t .. string.format(" |cff7fbfff+%d%% rested|r", math.floor(rested + 0.5)) end
    if ready > 0 then t = t .. string.format(" |cff7fff7f+%d%% ready|r", math.floor(ready / need * 100 + 0.5))
    elseif quest > 0 then t = t .. string.format(" |cffaaaaaa+%d%% in log|r", math.floor(quest / need * 100 + 0.5)) end
    local pace = ns.QuestExtras and ns.QuestExtras:Pace()
    if pace and pace.perHour then t = t .. string.format("  %d XP/h", math.floor(pace.perHour + 0.5)) end
    return t
  end
  if id == "clock" then return date("%H:%M") end
  if id == "net" then
    local ms, fps = M.Net()
    if not ms then return nil end
    return string.format("%d ms  %s fps", ms, tostring(fps or "?"))
  end
end

-- the honest durability number shown: the worst item matters most, so the
-- strip shows the lower of overall and (worst + 30)

function M:Tip(id, tt)
  if id == "flight" then
    local F = ns.FlightTimes
    tt:AddLine("Flight", 1, 0.82, 0)
    if F and F.flight then
      tt:AddLine(string.format("%s to %s", F.flight.from, F.flight.to), 1, 1, 1, true)
      local left = F:Remaining()
      tt:AddLine(left and ("Landing in " .. F.Clock(left)) or "First time on this flight: Outrider times it now.", 0.6, 0.6, 0.6, true)
    end
  elseif id == "layer" then
    tt:AddLine("Current layer", 1, 0.82, 0)
    local layers = ns.Layers
    if layers and layers.enabled then
      local id, conf, label = layers:Current()
      if id then
        tt:AddLine(string.format("%s (zone UID %d, %.0f%% confidence)", label, id, conf * 100), 1, 1, 1)
      else
        tt:AddLine("Unknown: observing nearby creatures.", 0.7, 0.7, 0.7)
      end
      local mapID = C.PlayerPosition("player")
      local history = layers:History(mapID, 8)
      if #history > 0 then tt:AddLine("Recently observed on this map:", 1, 0.82, 0) end
      for _, h in ipairs(history) do
        local age = math.max(0, time() - (tonumber(h.at) or time()))
        tt:AddDoubleLine(layers.Label(h.id), ns.Ago(age), 1, 1, 1, 0.7, 0.7, 0.7)
      end
    end
  elseif id == "gold" then
    tt:AddLine("Gold", 1, 0.82, 0)
    local total, n = 0, 0
    for key, inv in pairs(ns.db.global.inventory or {}) do
      if type(inv) == "table" and tonumber(inv.money) then
        total, n = total + inv.money, n + 1
        tt:AddDoubleLine(key, M.GoldText(inv.money), 1, 1, 1, 1, 1, 1)
      end
    end
    if n > 1 then tt:AddDoubleLine("All characters", M.GoldText(total), 1, 0.82, 0, 1, 0.82, 0) end
    tt:AddLine("Click: the Money page.", 0.6, 0.6, 0.6)
  elseif id == "bags" then
    local free, total = M.Bags()
    tt:AddLine("Bags", 1, 0.82, 0)
    tt:AddLine(string.format("%d free of %d (profession bags not counted).", free, total), 1, 1, 1, true)
    tt:AddLine("Click: open your bags.", 0.6, 0.6, 0.6)
  elseif id == "dura" then
    local all, low, slot = M.Durability()
    tt:AddLine("Durability", 1, 0.82, 0)
    if all then
      tt:AddLine(string.format("Overall %d%%, worst item %d%%.", math.floor(all + 0.5), math.floor(low + 0.5)), 1, 1, 1, true)
      local link = slot and C.Call("GetInventoryItemLink", "player", slot)
      if link then tt:AddLine("Worst: " .. link, 1, 1, 1, true) end
    end
    tt:AddLine("Click: Errands (where to repair).", 0.6, 0.6, 0.6)
  elseif id == "ammo" then
    tt:AddLine("Ammo", 1, 0.82, 0)
    tt:AddLine(tostring(M.Ammo() or "?") .. " in your quiver and bags.", 1, 1, 1, true)
  elseif id == "xp" then
    local pct, rested, quest, xp, need, ready = M.XP()
    tt:AddLine("Experience", 1, 0.82, 0)
    if pct then
      tt:AddLine(string.format("%d / %d (%.1f%%)", xp, need, pct), 1, 1, 1)
      if rested > 0 then tt:AddLine(string.format("Rested: %d%% of a level (double XP from kills)", math.floor(rested + 0.5)), 0.5, 0.75, 1, true) end
      tt:AddLine(string.format("Quest XP: %d ready to turn in, %d in whole log", ready, quest), 0.5, 1, 0.5, true)
      if ready > 0 then
        tt:AddLine(xp + ready >= need and "Ready quests should get you at least to the next level." or
          string.format("Ready quests would put you at %.1f%% of this level.", (xp + ready) / need * 100), 0.5, 1, 0.5, true)
      end
      local pace = ns.QuestExtras and ns.QuestExtras:Pace()
      if pace then
        tt:AddLine(string.format("Session: +%d XP (since login/reload)", pace.gained or 0), 1, 1, 1)
        if pace.perHour then
          tt:AddLine(string.format("Active pace: %d XP/hour", math.floor(pace.perHour + 0.5)), 1, 1, 1)
          if pace.secondsToLevel then tt:AddLine(string.format("At this pace: ~%d minutes to level", math.ceil(pace.secondsToLevel / 60)), 1, 1, 1) end
        else
          tt:AddLine("XP/hour: collecting at least 60 seconds of active gains", 0.7, 0.7, 0.7)
        end
      end
      local items
      if ns.QuestExtras and ns.QuestExtras.QuestXP then
        local _, _, rows = ns.QuestExtras:QuestXP()
        items = rows
      end
      if items then
        local shown = 0
        for _, q in ipairs(items) do
          if q.ready and shown < 12 then
            tt:AddDoubleLine(q.title, tostring(q.xp) .. " XP", 0.7, 1, 0.7, 0.7, 1, 0.7)
            shown = shown + 1
          end
        end
      end
    end
    tt:AddLine("Click: What now?", 0.6, 0.6, 0.6)
  elseif id == "clock" then
    tt:AddLine("Time", 1, 0.82, 0)
    tt:AddLine("Your computer's time. Server time: " .. date("%H:%M", C.ServerTime and C.ServerTime() or time()), 1, 1, 1, true)
  elseif id == "net" then
    local ms, fps = M.Net()
    tt:AddLine("Connection", 1, 0.82, 0)
    tt:AddLine(string.format("Latency %s ms, %s frames a second.", tostring(ms or "?"), tostring(fps or "?")), 1, 1, 1, true)
  end
end

local function openPage(id)
  local hub = ns.Hub
  local f = hub:Build()
  f:Show()
  hub:ShowTab(id)
end

function M:Click(id)
  if id == "gold" then openPage("money")
  elseif id == "bags" then
    local toggle = C.Resolve("ToggleAllBags") or C.Resolve("OpenAllBags")
    if type(toggle) == "function" then pcall(toggle) end
  elseif id == "dura" then openPage("errands")
  elseif id == "xp" then openPage("whatnow")
  end
end

-- ------------------------------------------------------------------ frame
function M:Build()
  if self.frame then return self.frame end
  local UI, Theme = ns.UI, ns.Theme
  local f = CreateFrame("Frame", "Outrider_InfoBar", UIParent, Theme:BackdropTemplate())
  f:SetHeight(20)
  f:SetFrameStrata("LOW")
  Theme:ApplyPanel(f, "bg", "border")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if C.Call("IsShiftKeyDown") then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    M:Settings().point = { point, rel, x, y }
  end)
  f.segs = {}
  for i, id in ipairs(M.ORDER) do
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(20)
    b.text = UI.Text(b, "small", "text")
    b.text:SetPoint("CENTER")
    b.id = id
    b:SetScript("OnEnter", function(self)
      local tt = rawget(_G, "GameTooltip")
      if not tt then return end
      tt:SetOwner(self, "ANCHOR_BOTTOM")
      ns.Safe("infobar:tip", M.Tip, M, self.id, tt)
      tt:Show()
    end)
    b:SetScript("OnLeave", function() local tt = rawget(_G, "GameTooltip") if tt then tt:Hide() end end)
    b:SetScript("OnClick", function(self) ns.Safe("infobar:click", M.Click, M, self.id) end)
    f.segs[i] = b
  end
  f.elapsed = 0
  f:SetScript("OnUpdate", function(self, dt)
    self.elapsed = self.elapsed + (dt or 0)
    if self.elapsed < 1 then return end
    self.elapsed = 0
    ns.Safe("infobar:update", M.Update, M)
  end)
  self.frame = f
  self:Place()
  return f
end

function M:Place()
  local f, p = self.frame, self:Settings().point
  if not f then return end
  f:ClearAllPoints()
  if type(p) == "table" and p[1] then f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else f:SetPoint("TOP", UIParent, "TOP", 0, -2) end
end

function M:Update()
  local f = self.frame
  if not f then return end
  local x = 8
  for _, b in ipairs(f.segs) do
    local ok, text = pcall(self.Text, self, b.id)
    if ok and text then
      b.text:SetText(text)
      local w = (b.text.GetStringWidth and b.text:GetStringWidth()) or 60
      w = (type(w) == "number" and w > 0 and w or 60) + 16
      b:SetWidth(w)
      b:ClearAllPoints()
      b:SetPoint("LEFT", f, "LEFT", x, 0)
      x = x + w
      b:Show()
    else
      b:Hide()
    end
  end
  f:SetWidth(x + 8)
end

function M:Apply()
  local s = self:Settings()
  if s.shown then
    self:Build():Show()
    self:Update()
  elseif self.frame then
    self.frame:Hide()
  end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Apply() end)
  for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "QUEST_LOG_UPDATE" }) do
    self:On(e, function(mod) if mod.frame and mod.frame:IsShown() then mod:Update() end end)
  end
  if C.Call("IsLoggedIn") then self:Apply() end
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  return self:Settings().shown and "info bar shown" or "info bar hidden"
end

ns.AddCommand("bar", "the info bar: /ride bar on|off|reset (Shift-drag it to move)", function(arg)
  arg = tostring(arg or ""):lower()
  local s = M:Settings()
  if arg == "on" or arg == "off" then s.shown = arg == "on"
  elseif arg == "reset" then s.point = nil M:Place()
  else s.shown = not s.shown end
  M:Apply()
  ns.Print("info bar %s", s.shown and "on" or "off")
end)
