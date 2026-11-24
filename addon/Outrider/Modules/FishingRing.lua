-- Modules/FishingRing.lua
-- A ring of fishing buttons and your real fishing skill added up (requirement
-- 2026-11-24: borrow FishFry's best ideas; the ideas only, nothing copied).
--
-- The ring shows while a fishing pole is equipped: Cast in the middle, around
-- it Lure (hover: a row of the lures in your bags; click one to put it on and
-- make it your usual), Find Fish, Basic Campfire, Cooking, Weapons back and
-- the Fishing page. Each button has a green edge when it's ready, amber when
-- it can be used but isn't on (lure not on), red when something is missing,
-- and a count (lures left, your effective skill on Cast). A circle or a bar,
-- drag to move, a size setting.
-- Every button is a secure button Gary clicks, like a macro on an action bar;
-- nothing fires by itself. Showing, hiding and re-pointing them waits for
-- combat to end (ns.Combat:Run), like every secure frame here.
--
-- Effective skill: base + pole + gear + lure. The game gives base and the
-- total bonus (GetProfessionInfo); the pole and gear bonuses are read from
-- their tooltips, the lure is what's left over (or the lure table when the
-- client gives no bonus). Compared with the skill range of the zone you're in
-- (Data/Fishing.lua tiers, the cited Forever guide, unverified).

local _, ns = ...
local C, UI, Theme = ns.Compat, ns.UI, ns.Theme
local M = ns:NewModule("FishingRing", {
  title = "Fishing button ring",
  phase = "P5",
  order = 77,
  defaults = { show = true, shape = "circle", scale = 1, point = nil, lure = nil },
  -- one fishing HUD on screen: step aside for the fishing addons (hard rule 8)
  yieldsTo = { "FishingBuddy", "ForeverFishing", "FishFry" },
})
ns.FishingRing = M

-- Lure bonuses, Classic values (wowhead classic item pages via Fishing.lua;
-- unverified on Forever). Only used when the client doesn't report the bonus.
M.LURE_BONUS = { ["Aquadynamic Fish Attractor"] = 100, ["Flesh Eating Worm"] = 75, ["Bright Baubles"] = 75,
  ["Aquadynamic Fish Lens"] = 50, ["Nightcrawlers"] = 50, ["Shiny Bauble"] = 25 }
M.GEAR_SLOTS = { 1, 5, 8, 9, 10 }
M.SIZE = 36
M.RADIUS = 50

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end
local function linkID(link) return link and tonumber(tostring(link):match("item:(%d+)")) end

-- ------------------------------------------------------------ skill
local function bonus(id)
  local G = ns.FishingGuide
  return (G and G.FishingBonus and id) and G.FishingBonus(id) or 0
end

-- { base, max, pole, gear, lure, total, lureName, zone = {name, lo, hi}, verdict }
function M:Breakdown()
  local HUD = ns.FishingHUD
  local base, max, mod
  if HUD and HUD.Skill then base, max, mod = HUD:Skill() end
  if not base then return nil end
  local poleID = linkID(C.Call("GetInventoryItemLink", "player", 16))
  local pole = ns.Fishing and ns.Fishing.PoleEquipped and ns.Fishing:PoleEquipped() and bonus(poleID) or 0
  local gear = 0
  for _, slot in ipairs(M.GEAR_SLOTS) do gear = gear + bonus(linkID(C.Call("GetInventoryItemLink", "player", slot))) end
  local lure = 0
  local lureName = self:LureName()
  if type(mod) == "number" and mod > 0 then
    lure = math.max(0, mod - pole - gear)
  elseif lureName then
    lure = M.LURE_BONUS[lureName] or 0
  elseif ns.Fishing and ns.Fishing:LureActive() then
    lure = nil -- on, but how much is unknown
  end
  local total = base + pole + gear + (lure or 0)
  local out = { base = base, max = max, pole = pole, gear = gear, lure = lure, lureName = lureName, total = total }
  -- the zone you're in against the guide's skill range
  local mapID = C.PlayerPosition("player")
  local info = mapID and C.Call("C_Map.GetMapInfo", mapID)
  local zname = type(info) == "table" and readable(info.name)
  local d = ns.FishingData
  if zname and d then
    for _, t in ipairs(d.tiers or {}) do
      for _, z in ipairs(t.zones) do
        if z == zname then out.zone = { name = zname, lo = t.lo, hi = t.hi } end
      end
    end
  end
  if out.zone then
    out.verdict = total >= out.zone.hi and "easy" or total >= out.zone.lo and "ok" or "hard"
  end
  return out
end

-- the lure on the pole, by the name the last lure button put on (the client
-- names no enchant); nil when none is on
function M:LureName()
  if not (ns.Fishing and ns.Fishing:LureActive()) then return nil end
  return ns.db.char.fishLureOn
end

function M:BreakdownLine(b)
  b = b or self:Breakdown()
  if not b then return "Fishing not learned yet." end
  local parts = { string.format("%d base", b.base) }
  if b.pole > 0 then parts[#parts + 1] = string.format("+%d pole", b.pole) end
  if b.gear > 0 then parts[#parts + 1] = string.format("+%d gear", b.gear) end
  if b.lure and b.lure > 0 then parts[#parts + 1] = string.format("+%d lure", b.lure)
  elseif b.lure == nil then parts[#parts + 1] = "+? lure" end
  local line = string.format("Fishing %d = %s", b.total, table.concat(parts, " "))
  if b.zone then
    local word = b.verdict == "easy" and "|cff66d980easy here|r" or b.verdict == "ok" and "|cffffd100fine here|r" or "|cffe06666hard here: put a lure on|r"
    line = line .. string.format("  -  %s is a %d-%d zone: %s", b.zone.name, b.zone.lo, b.zone.hi, word)
  end
  return line
end

-- ------------------------------------------------------------ lures
-- Lures in the bags, best first: { {name, count, bonus, id} }
function M:Lures()
  local have, ids = {}, {}
  for bag = 0, 4 do
    for slot = 1, (C.Call("C_Container.GetContainerNumSlots", bag) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local id = type(info) == "table" and readable(info.itemID)
      local it = id and C.ItemInfo(id)
      if it and it.name and M.LURE_BONUS[it.name] then
        have[it.name] = (have[it.name] or 0) + (readable(info.stackCount) or 1)
        ids[it.name] = id
      end
    end
  end
  local out = {}
  for _, name in ipairs((ns.Fishing and ns.Fishing.LURES) or {}) do
    if have[name] then out[#out + 1] = { name = name, count = have[name], bonus = M.LURE_BONUS[name], id = ids[name] } end
  end
  return out
end

-- The lure the Lure button uses: your usual one if it's in the bags, else the best.
function M:ChosenLure()
  local list = self:Lures()
  local want = self:Settings().lure
  for _, l in ipairs(list) do if l.name == want then return l, list end end
  local bad = ns.Fishing and ns.Fishing.badLure or {}
  for _, l in ipairs(list) do if not bad[l.name] then return l, list end end
  return list[1], list
end

function M:SetUsualLure(name)
  self:Settings().lure = name
  self:Info("usual lure: %s", tostring(name))
  self:Rebuild()
end

-- ------------------------------------------------------------ buttons
-- What each ring button is right now: { key, icon, macro|click, state, count, tip }
-- state: "ready" green, "off" amber, "missing" red. Pure apart from game reads.
function M:Specs()
  local known = function(s) return ns.Spellbook and ns.Spellbook:Known(s) ~= nil end
  local b = self:Breakdown()
  local out = {}
  out[#out + 1] = { key = "cast", icon = "Interface\\Icons\\Trade_Fishing", macro = "/cast Fishing",
    state = b and "ready" or "missing", count = b and tostring(b.total) or nil,
    tip = { "Cast", b and self:BreakdownLine(b) or "Fishing not learned yet." } }
  local lure, list = self:ChosenLure()
  local on = ns.Fishing and ns.Fishing:LureActive()
  local left = ns.FishingHUD and ns.FishingHUD:LureLeft()
  out[#out + 1] = { key = "lure", icon = lure and (C.ItemInfo(lure.id) or {}).icon or "Interface\\Icons\\INV_Misc_Orb_03",
    macro = lure and ("/use " .. lure.name .. "\n/use 16") or nil, lure = lure and lure.name,
    state = on and "ready" or lure and "off" or "missing",
    count = lure and tostring(lure.count) or "0",
    timer = on and left or nil,
    tip = { "Lure", on and string.format("On: %s, %d:%02d left.", tostring(self:LureName() or "a lure"), math.floor((left or 0) / 60), (left or 0) % 60)
        or lure and ("Click: put " .. lure.name .. " on your pole.") or "No lures in your bags: fishing supply vendors sell them.",
      #list > 1 and "Hover: pick another lure." or nil } }
  if known("Find Fish") then
    out[#out + 1] = { key = "find", icon = "Interface\\Icons\\INV_Misc_Fish_02", macro = "/cast Find Fish", state = "ready",
      tip = { "Find Fish", "Shows fishing pools on the minimap." } }
  end
  if known("Basic Campfire") then
    out[#out + 1] = { key = "fire", icon = "Interface\\Icons\\Spell_Fire_Fire", macro = "/cast Basic Campfire", state = "ready",
      tip = { "Basic Campfire", "A fire to cook your catch at." } }
  end
  if known("Cooking") then
    local cook = ns.FishCook and ns.FishCook:Rows() or {}
    local n = 0
    for _, r in ipairs(cook) do if r.n > 0 then n = n + 1 end end
    out[#out + 1] = { key = "cook", icon = "Interface\\Icons\\INV_Misc_Food_15", macro = "/cast Cooking",
      state = n > 0 and "ready" or "off", count = n > 0 and tostring(n) or nil,
      tip = { "Cooking", n > 0 and string.format("%d fish recipes you can cook now from your bags.", n) or "Opens Cooking.",
        "Outrider > Professions > Fishing lists what each fish cooks into." } }
  end
  local w = ns.db.char.fishingWeapons
  out[#out + 1] = { key = "weapons", icon = "Interface\\Icons\\INV_Sword_04",
    macro = w and w.mh and ("/equipslot 16 " .. w.mh .. (w.oh and ("\n/equipslot 17 " .. w.oh) or "")) or nil,
    state = w and w.mh and "ready" or "missing",
    tip = { "Weapons back", w and w.mh and ("Puts " .. w.mh .. (w.oh and (" and " .. w.oh) or "") .. " back in your hands. Works in combat.")
      or "Outrider remembers your weapons once you swap to a pole." } }
  out[#out + 1] = { key = "page", icon = "Interface\\Icons\\INV_Misc_Book_09", click = function()
      if ns.Hub then ns.Hub:Build():Show() ns.Hub:ShowTab("fishing") end end, state = "ready",
    tip = { "Fishing page", "Sessions, spots, your fish collection and milestones." } }
  return out
end

-- positions around the middle: circle or bar, for n outer buttons
function M.Layout(n, shape, size, radius)
  local pts = {}
  if shape == "bar" then
    for i = 1, n do pts[i] = { (i) * (size + 4), 0 } end
  else
    for i = 1, n do
      local a = math.pi / 2 - (i - 1) * 2 * math.pi / n
      pts[i] = { math.floor(math.cos(a) * radius + 0.5), math.floor(math.sin(a) * radius + 0.5) }
    end
  end
  return pts
end

local EDGE = { ready = { 0.35, 0.85, 0.45 }, off = { 1, 0.75, 0.2 }, missing = { 0.9, 0.3, 0.3 } }

local function makeButton(parent, name, size)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  local keyDown = C.Call("C_CVar.GetCVar", "ActionButtonUseKeyDown")
  b:RegisterForClicks(tostring(keyDown) == "1" and "AnyDown" or "AnyUp")
  b.edge = b:CreateTexture(nil, "BACKGROUND")
  b.edge:SetPoint("TOPLEFT", -2, 2) b.edge:SetPoint("BOTTOMRIGHT", 2, -2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(1, 1, 1, 0.2)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  b.timer = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.timer:SetPoint("TOP", b, "BOTTOM", 0, -1)
  b:SetScript("OnEnter", function(self)
    if self.spec and self.spec.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      for i, l in ipairs(self.spec.tip) do
        if i == 1 then GameTooltip:AddLine(l) else GameTooltip:AddLine(l, 1, 1, 1, true) end
      end
      GameTooltip:Show()
    end
    if self.spec and self.spec.key == "lure" then M:ShowFlyout(true) end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function M:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "Outrider_FishingRing", UIParent)
  f:SetSize(M.SIZE, M.SIZE)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(false)
  f.buttons = {}
  f.cast = makeButton(f, "Outrider_FishingRingCast", M.SIZE + 8)
  f.cast:SetPoint("CENTER")
  -- drag the middle with the right mouse button (out of combat)
  f.cast:RegisterForDrag("RightButton")
  f.cast:SetScript("OnDragStart", function() if not C.InCombat() then f:StartMoving() end end)
  f.cast:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, _, _, x, y = f:GetPoint()
    M:Settings().point = { p, x, y }
  end)
  for i = 1, 7 do f.buttons[i] = makeButton(f, "Outrider_FishingRing" .. i, M.SIZE) end
  f.flyout = {}
  for i = 1, 6 do
    local b = makeButton(f, "Outrider_FishingLure" .. i, M.SIZE - 6)
    b:HookScript("OnClick", function(self) if self.lureName then ns.db.char.fishLureOn = self.lureName M:SetUsualLure(self.lureName) end end)
    b:Hide()
    f.flyout[i] = b
  end
  f:Hide()
  self.frame = f
  return f
end

local function paint(b, spec)
  b.spec = spec
  b.icon:SetTexture(spec.icon)
  local e = EDGE[spec.state] or EDGE.ready
  b.edge:SetColorTexture(e[1], e[2], e[3], 0.9)
  b.count:SetText(spec.count or "")
  b.timer:SetText(spec.timer and string.format("%d:%02d", math.floor(spec.timer / 60), spec.timer % 60) or "")
end

-- Everything that touches the secure buttons (attributes, show, hide, points)
-- in one function, run now or after combat.
function M:Rebuild()
  if not self.frame then return end
  ns.Combat:Run("fishingring:rebuild", function() M:Apply() end, "fishingring:rebuild")
end

function M:Apply()
  local f = self.frame
  local s = self:Settings()
  local show = self.enabled and s.show and self.pole
  f:ClearAllPoints()
  local pt = s.point
  if type(pt) == "table" then f:SetPoint(pt[1], UIParent, pt[1], pt[2], pt[3]) else f:SetPoint("CENTER", UIParent, "CENTER", 260, -160) end
  f:SetScale(math.max(0.5, math.min(2, tonumber(s.scale) or 1)))
  if not show then f:Hide() return end
  local specs = self:Specs()
  self.specs = specs
  local cast = specs[1]
  paint(f.cast, cast)
  f.cast:SetAttribute("type", "macro")
  f.cast:SetAttribute("macrotext", cast.macro)
  local outer = {}
  for i = 2, #specs do outer[#outer + 1] = specs[i] end
  local pts = M.Layout(#outer, s.shape, M.SIZE, M.RADIUS)
  for i, b in ipairs(f.buttons) do
    local spec = outer[i]
    if spec then
      paint(b, spec)
      b:ClearAllPoints()
      b:SetPoint("CENTER", f, "CENTER", pts[i][1], pts[i][2])
      if spec.macro then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", spec.macro)
      elseif spec.click then
        b:SetAttribute("type", nil)
      else
        b:SetAttribute("type", nil)
      end
      b.clickFn = spec.click
      if not b.hooked then
        b.hooked = true
        b:HookScript("OnClick", function(self)
          if self.clickFn then ns.Safe("fishingring:click", self.clickFn) end
          if self.spec and self.spec.key == "lure" and self.spec.lure then ns.db.char.fishLureOn = self.spec.lure end
        end)
      end
      b:Show()
    else
      b:Hide()
    end
  end
  -- the lure flyout: one button per lure in the bags, above the Lure button
  local _, lures = self:ChosenLure()
  local lureBtn
  for i, spec in ipairs(outer) do if spec.key == "lure" then lureBtn = f.buttons[i] end end
  for i, b in ipairs(f.flyout) do
    local l = lures[i]
    if l and lureBtn then
      paint(b, { key = "flyout", icon = (C.ItemInfo(l.id) or {}).icon or "Interface\\Icons\\INV_Misc_Orb_03",
        state = l.name == (s.lure or "") and "ready" or "off", count = tostring(l.count),
        tip = { l.name, string.format("+%d Fishing (Classic value). Click: put it on and make it your usual lure.", l.bonus or 0) } })
      b.lureName = l.name
      b:SetAttribute("type", "macro")
      b:SetAttribute("macrotext", "/use " .. l.name .. "\n/use 16")
      b:ClearAllPoints()
      b:SetPoint("BOTTOM", lureBtn, "TOP", 0, 6 + (i - 1) * (M.SIZE - 2))
    else
      b.lureName = nil
      b:Hide()
    end
  end
  f:Show()
  if not self.logged then
    self.logged = true
    self:Info("fishing ring shown: %d buttons (%s)", #specs, s.shape)
  end
end

-- The flyout shows while the mouse is on the Lure button or the flyout
-- (out of combat only: showing secure buttons is protected in combat).
function M:ShowFlyout(on)
  local f = self.frame
  if not f or C.InCombat() then return end
  local any = false
  for _, b in ipairs(f.flyout) do
    if b.lureName then if on then b:Show() any = true else b:Hide() end end
  end
  if on and any and not self.flyTicker then
    self.flyTicker = ns.Timer.Ticker(0.3, function()
      local over = false
      for _, b in ipairs(f.flyout) do if b:IsShown() and b.IsMouseOver and b:IsMouseOver() then over = true end end
      for _, b in ipairs(f.buttons) do if b.spec and b.spec.key == "lure" and b.IsMouseOver and b:IsMouseOver() then over = true end end
      if not over then
        if M.flyTicker then M.flyTicker:Cancel() M.flyTicker = nil end
        M:ShowFlyout(false)
      end
    end, "fishingring:flyout")
  end
end

-- Counts, timers and colours change often; they're not protected, so they
-- refresh every second without touching the secure attributes.
function M:Paint()
  local f = self.frame
  if not (f and f:IsShown()) then return end
  local specs = self:Specs()
  paint(f.cast, specs[1])
  local i = 0
  for k = 2, #specs do
    i = i + 1
    local b = f.buttons[i]
    if b and b.spec and b.spec.key == specs[k].key then paint(b, specs[k]) end
  end
end

function M:Update()
  local pole = ns.Fishing and ns.Fishing.PoleEquipped and ns.Fishing:PoleEquipped() or false
  self.pole = pole
  self:Build()
  self:Rebuild()
  if pole and not self.ticker then
    self.ticker = ns.Timer.Ticker(1, function() ns.Safe("fishingring:paint", M.Paint, M) end, "fishingring")
  elseif not pole and self.ticker then
    self.ticker:Cancel() self.ticker = nil
  end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", self.Update)
  self:On("PLAYER_EQUIPMENT_CHANGED", self.Update)
  self:On("BAG_UPDATE_DELAYED", function(mod) if mod.pole then mod:Rebuild() end end)
  self:On("SPELLS_CHANGED", function(mod) if mod.pole then mod:Rebuild() end end)
end

function M:OnDisable()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  if self.flyTicker then self.flyTicker:Cancel() self.flyTicker = nil end
  if self.frame then self:Rebuild() end
end

function M:Activity()
  if not self:Settings().show then return "off" end
  return self.pole and "shown with your pole" or "shows while a fishing pole is equipped"
end
