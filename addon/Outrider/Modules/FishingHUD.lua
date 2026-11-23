-- Modules/FishingHUD.lua
-- A 4-line box shown only while a fishing pole is equipped (Gary, 2026-11-14:
-- "especially the fishing hud ... clutter is too much clutter"):
--   Fishing 87/150 (+25)   Lure 6:12          skill and lure time left
--   Here: Smallfish 70% · Mud Snapper 25%      what you've caught in this zone
--   42 fish · 1g 20s (1g 05s/h)                this session, valued like MoneyGuide
--   Goal: Raw Brilliant Smallfish 2/6          a quest objective you fish for, or
--                                               a fish a recipe you know uses
-- Hover: each fish here with what to do with it (cook / sell at AH / vendor).
-- Also: "too hard here" when many fish get away, one chat line when the pole
-- comes off, a sound for rare catches, pins for fishing pools you mouse over.
-- Read only, except the Weapons button (Gary's click, secure, works in combat).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("FishingHUD", {
  title = "Fishing HUD",
  phase = "P5",
  order = 76,
  defaults = { show = true, rareSound = true, point = nil },
})
ns.FishingHUD = M

M.HARD_CASTS, M.HARD_SHARE = 8, 0.25
-- "Your fish got away" text when the client's global string is missing
M.ESCAPED = "got away"

function M:OnInitialize()
  self.session = nil
end

-- ------------------------------------------------------------ facts
function M:Skill()
  local get, info = rawget(_G, "GetProfessions"), rawget(_G, "GetProfessionInfo")
  if type(get) ~= "function" or type(info) ~= "function" then return nil end
  local ok, _, _, _, fishing = pcall(get)
  if not ok or not fishing then return nil end
  local ok2, _, _, skill, max, _, _, _, mod = pcall(info, fishing)
  if not ok2 then return nil end
  return C.Readable(skill), C.Readable(max), C.Readable(mod)
end

-- Seconds of lure left on the pole (temporary main-hand enchant), or nil.
function M:LureLeft()
  local has, ms = C.Call("GetWeaponEnchantInfo")
  if not C.Readable(has) then return nil end
  ms = C.Readable(ms)
  return type(ms) == "number" and math.floor(ms / 1000) or 0
end

local function itemName(id)
  local info = C.ItemInfo(id)
  return info and info.name or ("item " .. id)
end

-- { {id, name, n, share} } caught on this map, most first.
function M:Here(mapID)
  local zone = mapID and ns.db.global.fishing and ns.db.global.fishing[mapID]
  if not zone then return {} end
  local total, out = 0, {}
  for id, n in pairs(zone) do total = total + n out[#out + 1] = { id = id, n = n } end
  for _, e in ipairs(out) do e.share = e.n / total e.name = itemName(e.id) end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
  return out, total
end

-- Every fish ever caught: { [lowercase name] = itemID }
function M:Caught()
  local out = {}
  for _, zone in pairs(ns.db.global.fishing or {}) do
    for id in pairs(zone) do
      local info = C.ItemInfo(id)
      if info and info.name then out[info.name:lower()] = id end
    end
  end
  return out
end

-- Known recipes (any profession) that use this item and still give skill.
function M:RecipesUsing(itemID)
  local out = {}
  for prof, p in pairs(ns.db.char.professions or {}) do
    for _, r in pairs(type(p) == "table" and p.recipes or {}) do
      if type(r) == "table" and r.reagents and r.reagents[itemID] and (r.diff == nil or r.diff < 3) then
        out[#out + 1] = { prof = prof, name = r.name, need = r.reagents[itemID] }
      end
    end
  end
  return out
end

-- The goal line: a quest objective for something Gary fishes, else a recipe.
function M:Goal()
  local caught = self:Caught()
  local n = C.Call("C_QuestLog.GetNumQuestLogEntries") or 0
  for i = 1, n do
    local info = C.Call("C_QuestLog.GetInfo", i)
    if type(info) == "table" and not info.isHeader and info.questID then
      for _, o in ipairs(C.Call("C_QuestLog.GetQuestObjectives", info.questID) or {}) do
        local text = C.Readable(o.text)
        if type(text) == "string" and o.type == "item" and not o.finished then
          for name in pairs(caught) do
            if text:lower():find(name, 1, true) then
              return string.format("Goal: %s %d/%d (%s)", ns.TitleCase and ns.TitleCase(name) or name,
                o.numFulfilled or 0, o.numRequired or 0, C.Readable(info.title) or "quest")
            end
          end
        end
      end
    end
  end
  local mapID = C.PlayerPosition("player")
  for _, e in ipairs((self:Here(mapID))) do
    local r = self:RecipesUsing(e.id)[1]
    if r then return string.format("Goal: %s for %s (%s skill-up)", e.name, tostring(r.name), r.prof) end
  end
  return nil
end

-- What to do with one fish: "cook: Brilliant Smallfish (Cooking skill-up)", "sell at AH ~12s", "vendor 1s".
function M:Advice(id)
  local r = self:RecipesUsing(id)[1]
  if r then return string.format("cook: %s (%s skill-up)", tostring(r.name), r.prof) end
  local ah, _, vendor = ns.Prices and ns.Prices:Get(id)
  if ah and (not vendor or ah * 0.95 > vendor) then return "sell at the auction house, about " .. ns.Prices.Money(math.floor(ah * 0.95)) end
  if vendor and vendor > 0 then return "vendor, " .. ns.Prices.Money(vendor) end
  return "keep or vendor (no price known yet)"
end

-- ------------------------------------------------------------ session
-- A session survives a /reload or taking the pole off for a moment (Gary,
-- 2026-11-14: the 12 Pound Mud Snapper dropped out of the HUD after a reload).
-- It's kept per character and picked up again if the last catch or cast was
-- less than RESUME seconds ago.
M.RESUME = 15 * 60
function M:Start()
  local saved = ns.db.char.fishSession
  if type(saved) == "table" and saved.last and time() - saved.last < M.RESUME then
    saved.casts, saved.escapes, saved.warned = saved.casts or {}, saved.escapes or {}, saved.warned or {}
    self.session = saved
    return
  end
  local skill = self:Skill()
  self.session = { start = time(), last = time(), secs = 0, catches = 0, value = 0, skill0 = skill, lures = 0,
    casts = {}, escapes = {}, warned = {} }
  ns.db.char.fishSession = self.session
end

function M:Touch(s)
  local now = time()
  s.secs = s.secs + math.min(now - s.last, 300)
  s.last = now
end

function M:OnLoot(_, kind, items)
  if kind ~= "fish" or type(items) ~= "table" then return end
  local s = self.session
  if not s then self:Start() s = self.session end
  self:Touch(s)
  for _, it in ipairs(items) do
    s.catches = s.catches + (it.count or 1)
    if ns.MoneyGuide then
      ns.MoneyGuide.WhenWorth(it.id, function(each) s.value = s.value + each * (it.count or 1) M:Refresh() end)
    end
    local info = C.ItemInfo(it.id)
    if self:Settings().rareSound and info and type(info.quality) == "number" and info.quality >= 2 then
      ns.Toast:Show({ title = "Rare catch!", text = tostring(info.name or it.name), color = "good", duration = 8,
        sound = ns.Toast:SoundID("READY_CHECK") })
      self:Info("rare catch %s", tostring(info.name or it.name))
    end
  end
  self:Refresh()
end

function M:OnCast(unit, spellID)
  if unit ~= "player" or not self.shown then return end
  local info = C.Call("C_Spell.GetSpellInfo", spellID)
  if C.Readable(type(info) == "table" and info.name or nil) ~= "Fishing" then return end
  local s = self.session or (self:Start() or self.session)
  local mapID = C.PlayerPosition("player") or 0
  s.casts[mapID] = (s.casts[mapID] or 0) + 1
  self:Touch(s)
end

function M:OnError(_, _, message)
  local s = self.session
  if not (s and self.shown) or type(message) ~= "string" then return end
  local escaped = rawget(_G, "ERR_FISH_ESCAPED") or rawget(_G, "FISH_ESCAPED")
  if not ((escaped and message == escaped) or message:lower():find(M.ESCAPED, 1, true)) then return end
  local mapID = C.PlayerPosition("player") or 0
  s.escapes[mapID] = (s.escapes[mapID] or 0) + 1
  local hard = self:TooHard(mapID)
  if hard and not s.warned[mapID] then
    s.warned[mapID] = true
    ns.Print("fishing: %s", hard)
    self:Info("too hard here: %s", hard)
  end
  self:Refresh()
end

-- "3 of 10 got away: your skill is too low for this water" or nil
function M:TooHard(mapID)
  local s = self.session
  if not s then return nil end
  local casts, esc = s.casts[mapID] or 0, s.escapes[mapID] or 0
  if casts < M.HARD_CASTS or esc / casts < M.HARD_SHARE then return nil end
  local text = string.format("%d of %d got away: your skill is too low for this water", esc, casts)
  -- name the lure that would help, when one is in the bags and none is on
  local F = ns.Fishing
  local lure = F and F.LureInBags and not F:LureActive() and F:LureInBags()
  if lure then text = text .. " (put on your " .. lure .. ")" end
  return text
end

function M:Summary()
  local s = self.session
  if not s or s.catches == 0 then return nil end
  local skill = self:Skill()
  local gained = (type(skill) == "number" and type(s.skill0) == "number") and (skill - s.skill0) or 0
  return string.format("Fishing: %d catches, %s, %d skill point%s, %d lure%s", s.catches, ns.Prices.Money(s.value),
    gained, gained == 1 and "" or "s", s.lures, s.lures == 1 and "" or "s")
end

-- ------------------------------------------------------------ the box
function M:Lines()
  local s = self.session
  local skill, max, mod = self:Skill()
  local lure = self:LureLeft()
  local l1 = string.format("Fishing %s/%s%s   %s", tostring(skill or "?"), tostring(max or "?"),
    (type(mod) == "number" and mod > 0) and string.format(" (+%d)", mod) or "",
    lure and string.format("%sLure %d:%02d|r", lure < 60 and "|cffff8040" or "|cffffffff", math.floor(lure / 60), lure % 60) or "|cffff5050No lure|r")
  -- lures left in the bags, red under 5 (OneCast's tackle-box nudge)
  local stock = ns.FishingLog and ns.FishingLog.Lures and ns.FishingLog:Lures()
  if stock then l1 = l1 .. string.format(stock.low and " |cffff5050(%d left)|r" or " (%d left)", stock.count) end
  local mapID = C.PlayerPosition("player")
  local here = self:Here(mapID)
  local parts = {}
  -- short names on the box ("Raw " dropped); the hover tooltip has the full ones
  for i = 1, math.min(3, #here) do
    parts[#parts + 1] = string.format("%s %d%%", (here[i].name:gsub("^Raw ", "")), math.floor(here[i].share * 100 + 0.5))
  end
  local hard = mapID and self:TooHard(mapID)
  local l2 = hard and ("|cffff8040" .. hard .. "|r") or (#parts > 0 and ("Here: " .. table.concat(parts, " · ")) or "Here: nothing caught yet")
  local l3
  if s and s.catches > 0 then
    local rate = s.secs >= 300 and math.floor(s.value / s.secs * 3600) or nil
    local fishHr = s.secs >= 300 and math.floor(s.catches / s.secs * 3600 + 0.5) or nil
    l3 = string.format("%d fish%s · %s%s", s.catches, fishHr and string.format(" (%d/h)", fishHr) or "",
      ns.Prices.Money(s.value), rate and (" (" .. ns.Prices.Money(rate) .. "/h)") or "")
  else
    l3 = "No catches yet this session"
  end
  local tasty, need = ns.FishingLog and ns.FishingLog.Tastyfish and ns.FishingLog:Tastyfish()
  local goal = tasty and string.format("Goal: Speckled Tastyfish %d/%d (Riggle Bassbait, Booty Bay)", tasty, need) or self:Goal()
  return { l1, l2, l3, goal }
end

function M:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "Outrider_FishingHUD", UIParent, "BackdropTemplate")
  f:SetSize(300, 70)
  f:SetFrameStrata("MEDIUM")
  local pt = self:Settings().point
  if type(pt) == "table" then f:SetPoint(pt[1], UIParent, pt[1], pt[2], pt[3]) else f:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.6)
  end
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
  f:SetScript("OnDragStop", function(fr)
    fr:StopMovingOrSizing()
    local p, _, _, x, y = fr:GetPoint()
    M:Settings().point = { p, x, y }
    if M.wbtn then M:WeaponsButton() end -- the button follows the HUD
  end)
  f.lines = {}
  for i = 1, 4 do
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- one line each, never wrapped (Gary's screenshot, 2026-11-14: a long
    -- "Here" line wrapped onto the next); the box grows to fit instead
    t:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 15)
    t:SetJustifyH("LEFT")
    if t.SetWordWrap then t:SetWordWrap(false) end
    if t.SetMaxLines then t:SetMaxLines(1) end
    f.lines[i] = t
  end
  f:SetScript("OnEnter", function(fr)
    GameTooltip:SetOwner(fr, "ANCHOR_TOP")
    GameTooltip:AddLine("Fish here and what to do with them")
    local here = M:Here(C.PlayerPosition("player"))
    if #here == 0 then GameTooltip:AddLine("Nothing caught in this zone yet.", 0.7, 0.7, 0.7) end
    for i = 1, math.min(10, #here) do
      local e = here[i]
      GameTooltip:AddDoubleLine(string.format("%s (%d%%)", e.name, math.floor(e.share * 100 + 0.5)), M:Advice(e.id), 1, 1, 1, 0.6, 0.9, 0.6)
    end
    GameTooltip:AddLine("Drag to move.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:Hide()
  self.frame = f
  return f
end

function M:Refresh()
  if not (self.frame and self.shown) then return end
  local lines = self:Lines()
  local w = 220
  for i = 1, 4 do
    local t = self.frame.lines[i]
    t:SetText(lines[i] or "")
    local sw = t.GetStringWidth and t:GetStringWidth()
    if type(sw) == "number" and sw + 16 > w then w = sw + 16 end
  end
  local nw, nh = math.min(w, 460), lines[4] and 70 or 55
  if self.frame:GetWidth() ~= nw or self.frame:GetHeight() ~= nh then
    self.frame:SetWidth(nw)
    self.frame:SetHeight(nh)
    if self.wbtn then self:WeaponsButton() end
  end
end

-- Shown with the pole (the Fishing module's own test), hidden without it.
function M:Update()
  local on = self:Settings().show and ns.Fishing and ns.Fishing.PoleEquipped and ns.Fishing:PoleEquipped() or false
  if on == (self.shown or false) then return end
  self.shown = on
  self:Build()
  if on then
    if not self.session then self:Start() end
    self.frame:Show()
    self:Refresh()
    if not self.ticker then self.ticker = ns.Timer.Ticker(1, function() M:Refresh() end, "fishinghud") end
    self:WeaponsButton()
  else
    self.frame:Hide()
    if self.ticker then self.ticker:Cancel() self.ticker = nil end
    local line = self:Summary()
    if line then ns.Print("%s", line) self:Info("%s", line) end
    self.session = nil
    self:WeaponsButton()
  end
end

-- Lure applied while fishing (the enchant appeared): counted for the summary.
function M:OnInventory(_, unit)
  if unit ~= "player" or not self.session then return end
  local has = self:LureLeft() ~= nil
  if has and not self.hadLure then self.session.lures = self.session.lures + 1 end
  self.hadLure = has
end

-- ------------------------------------------------------------ weapons button
-- Remembers what was in the hands before the pole went on; a small secure
-- button on the HUD puts it back (works in combat: it's Gary's click).
function M:RememberWeapons()
  if ns.Fishing and ns.Fishing.PoleEquipped and ns.Fishing:PoleEquipped() then return end
  local function name(slot)
    local link = C.Call("GetInventoryItemLink", "player", slot)
    return link and link:match("%[(.-)%]") or nil
  end
  local mh, oh = name(16), name(17)
  if mh then ns.db.char.fishingWeapons = { mh = mh, oh = oh } end
end

function M:WeaponsButton()
  local w = ns.db.char.fishingWeapons
  if self.shown and w and w.mh then
    if not self.wbtn then self.wbtn = ns.SecureButtons:Acquire("FishingHUD") end
    local b = self.wbtn
    if not b then return end
    local body = "/equipslot 16 " .. w.mh .. (w.oh and ("\n/equipslot 17 " .. w.oh) or "")
    ns.SecureButtons:SetMacro(b, body)
    ns.SecureButtons:SetLabel(b, "Weapons")
    -- Placed against UIParent at the HUD's corner, never anchored to the HUD:
    -- a secure button anchored to a frame makes that frame protected, and then
    -- resizing or hiding the HUD in combat was blocked (B4, 35 ADDON_ACTION_BLOCKED).
    local f = self.frame
    local right, top = f and f:GetRight(), f and f:GetTop()
    if right and top then
      ns.SecureButtons:Place(b, "TOPRIGHT", UIParent, "BOTTOMLEFT", right - 4, top - 4)
    else
      ns.SecureButtons:Place(b, "TOPRIGHT", UIParent, "CENTER", 0, 0)
    end
    ns.SecureButtons:Raise(b, "HIGH")
    ns.SecureButtons:SetShown(b, true)
  elseif self.wbtn then
    ns.SecureButtons:Release(self.wbtn)
    self.wbtn = nil
  end
end

-- ------------------------------------------------------------ pools
-- A fishing pool's tooltip (School / Swarm / Wreckage / Pool): pin where Gary is.
M.POOL_WORDS = { "school", "swarm", "wreckage", "pool", "shoal" }
function M:OnPoolTooltip(title)
  if type(title) ~= "string" or not ns.LootLog then return end
  local low = title:lower()
  local pool = false
  for _, w in ipairs(M.POOL_WORDS) do if low:find(w, 1, true) then pool = true end end
  if not pool then return end
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return end
  local node, new = ns.LootLog:AddNode("pool", mapID, x, y, title)
  if node and new then node.seenOnly = true end
end

function M:OnEnable()
  self:On("OTR_LOOT", self.OnLoot)
  self:On("UNIT_SPELLCAST_CHANNEL_START", function(mod, _, unit, _, spellID) mod:OnCast(unit, spellID) end)
  self:On("UI_ERROR_MESSAGE", self.OnError)
  self:On("UNIT_INVENTORY_CHANGED", self.OnInventory)
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod) mod:RememberWeapons() mod:Update() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:RememberWeapons() mod:Update() end)
end

function M:OnDisable()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  if self.frame then self.frame:Hide() end
  self.shown = false
end

function M:Activity()
  if not self.shown then return "shows while a fishing pole is equipped" end
  return self:Summary() or "fishing, no catches yet"
end
