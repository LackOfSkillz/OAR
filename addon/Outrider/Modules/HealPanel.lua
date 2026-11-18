-- Modules/HealPanel.lua  (click-to-heal party bars; Gary, 2026-11-16)
-- A small panel of health bars for the group, like HealBot: a click on a
-- bar casts a heal on that player. Each bar is a SecureUnitButtonTemplate
-- button with "unit" and "type1"/"spell1" attributes, so the click itself
-- casts: Outrider never casts anything (hard rule 1).
--
-- Assigned players (Gary: "in larger raids you get assigned 2 or 3 people
-- ... select the members you're focused on and ignore everybody else"):
-- names picked out of combat on the Class page or with /ride heal assign.
-- With any assigned player in the group, the panel shows only them (and
-- you, unless switched off).
--
-- Limits on this client:
--   * secure buttons can't be created, retargeted, shown or hidden in combat,
--     so every layout change goes through self:Secure and waits for combat
--     to end (a player who joins mid-fight gets a bar after it);
--   * health may be a secret value in combat: it goes straight into the
--     bar (display only, hard rule 4); the low-health edge and the range
--     fade are drawn only when the numbers are readable.
-- Hunters get one bar, the pet's, with Mend Pet on a click.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("HealPanel", {
  title = "Click-to-heal bars",
  phase = "P4",
  order = 66,
  classes = { PRIEST = true, HUNTER = true, DRUID = true, PALADIN = true, SHAMAN = true },
  yieldsTo = { "HealBot", "VuhDo", "Grid2", "Clique", "NeoHeal", "Healium", "Cell" },
  defaults = { show = "group", assigned = {}, withSelf = true, pos = {}, bindings = {} },
})
ns.HealPanel = M

M.MAX = 40          -- 5 columns by 8 rows, created only outside combat
M.W, M.H, M.GAP, M.COLS = 150, 22, 2, 5
M.LOW = 0.5         -- red edge below half health (when readable)

-- Clicks per class: { attribute suffix, label, spells (first known wins) }.
-- Spell names without a rank cast the highest rank known.
M.CLICKS = {
  PRIEST = {
    { "1", "Left-click", { "Heal", "Lesser Heal" } },
    { "2", "Right-click", { "Renew" } },
    { "shift-", "Shift-click", { "Power Word: Shield" }, "1" },
    { "shift-", "Shift-right-click", { "Flash Heal" }, "2" },
  },
  DRUID = {
    { "1", "Left-click", { "Healing Touch" } },
    { "2", "Right-click", { "Rejuvenation" } },
    { "shift-", "Shift-click", { "Regrowth" }, "1" },
  },
  PALADIN = {
    { "1", "Left-click", { "Holy Light" } },
    { "2", "Right-click", { "Flash of Light" } },
  },
  SHAMAN = {
    { "1", "Left-click", { "Healing Wave" } },
    { "2", "Right-click", { "Lesser Healing Wave" } },
  },
  HUNTER = {
    { "1", "Left-click", { "Mend Pet" } },
  },
}

local function known(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end

-- { { mod, button, label, spell } } for this character, known spells only.
function M:Clicks()
  local out, overrides = {}, self:Settings().bindings or {}
  for _, c in ipairs(M.CLICKS[ns.PlayerClass()] or {}) do
    local mod, button = "", c[1]
    if c[4] then mod, button = c[1], c[4] end
    for _, sp in ipairs(c[3]) do
      if known(sp) then
        if not overrides[mod .. button] then
          out[#out + 1] = { mod = mod, button = button, label = c[2], spell = sp }
        end
        break
      end
    end
  end
  for key, spell in pairs(overrides) do
    local mod, button = self:ParseBinding(key)
    if mod and known(spell) then
      out[#out + 1] = { mod = mod, button = button, label = key, spell = spell }
    end
  end
  return out
end

function M:ParseBinding(key)
  if type(key) ~= "string" then return nil end
  if key == "1" or key == "2" then return "", key end
  local mod, button = key:match("^(shift%-)([12])$")
  if not mod then mod, button = key:match("^(ctrl%-)([12])$") end
  if not mod then mod, button = key:match("^(alt%-)([12])$") end
  return mod, button
end

function M:SetBinding(key, spell)
  local mod = self:ParseBinding(key)
  if not mod then return false, "expected 1, 2, shift-1, ctrl-2 or alt-1" end
  if spell ~= nil and (type(spell) ~= "string" or not known(spell)) then
    return false, "spell not known by this character"
  end
  self:Settings().bindings[key] = spell
  self:Layout("binding changed")
  return true
end

local function nameOf(unit)
  local n = C.Readable(C.Call("UnitName", unit))
  return type(n) == "string" and n or nil
end

function M:Assigned()
  local s = self:Settings()
  s.assigned = type(s.assigned) == "table" and s.assigned or {}
  return s.assigned
end

function M:IsAssigned(name) return name ~= nil and self:Assigned()[name] == true end

-- Units in the group, in order: you, then party1-4 (or raid1-40).
function M:GroupUnits()
  local out = {}
  if ns.PlayerClass() == "HUNTER" then
    if C.Call("UnitExists", "pet") then out[1] = "pet" end
    return out
  end
  if C.Call("IsInRaid") then
    for i = 1, 40 do if C.Call("UnitExists", "raid" .. i) then out[#out + 1] = "raid" .. i end end
    return out
  end
  out[1] = "player"
  for i = 1, 4 do if C.Call("UnitExists", "party" .. i) then out[#out + 1] = "party" .. i end end
  return out
end

-- The units that get a bar: assigned players only when any are in the group.
function M:Units()
  local all = self:GroupUnits()
  if ns.PlayerClass() == "HUNTER" then return all, false end
  local me = nameOf("player")
  local mine = {}
  for _, u in ipairs(all) do
    local n = nameOf(u)
    if n and n ~= me and self:IsAssigned(n) then mine[#mine + 1] = u end
  end
  local out = {}
  if #mine > 0 then
    if self:Settings().withSelf then
      for _, u in ipairs(all) do if u == "player" or nameOf(u) == me then out[1] = u break end end
    end
    for _, u in ipairs(mine) do out[#out + 1] = u end
    return out, true
  end
  for i = 1, math.min(#all, M.MAX) do out[i] = all[i] end
  return out, false
end

function M:ShouldShow()
  local mode = self:Settings().show
  if mode == "off" then return false end
  if ns.PlayerClass() == "HUNTER" then
    return C.Call("UnitExists", "pet") and (mode == "always" or C.Call("IsInGroup")) and true or false
  end
  return mode == "always" or (C.Call("IsInGroup") and true or false)
end

-- ------------------------------------------------------------------ frames
local function keyDownClicks()
  local v = C.Call("C_CVar.GetCVar", "ActionButtonUseKeyDown")
  if v == nil then v = C.Call("GetCVar", "ActionButtonUseKeyDown") end
  return tostring(v) == "1" and "AnyDown" or "AnyUp"
end

function M:Panel()
  if self.panel then return self.panel end
  local s = self:Settings()
  local f = CreateFrame("Frame", "Outrider_HealPanel", UIParent)
  f:SetSize(M.W * M.COLS + (M.COLS - 1) * M.GAP, M.H)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetFrameStrata("MEDIUM")
  local head = f:CreateFontString(nil, "OVERLAY")
  ns.Theme:StyleText(head, "small", "muted")
  head:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 2)
  f.head = head
  -- Drag by the header strip, out of combat only (the bars are secure).
  f:SetScript("OnDragStart", function(self) if not C.InCombat() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint(1)
    s.pos.point, s.pos.x, s.pos.y = point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5)
  end)
  f:ClearAllPoints()
  if s.pos and s.pos.point then f:SetPoint(s.pos.point, UIParent, s.pos.point, s.pos.x or 0, s.pos.y or 0)
  else f:SetPoint("LEFT", UIParent, "LEFT", 40, 80) end
  f:Hide()
  self.panel, self.bars = f, {}
  return f
end

function M:Bar(i)
  if self.bars[i] then return self.bars[i] end
  local f = self:Panel()
  local b = CreateFrame("Button", "Outrider_HealBar" .. i, f, "SecureUnitButtonTemplate")
  b:SetSize(M.W, M.H)
  b:RegisterForClicks(keyDownClicks())
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(ns.Theme:Color("raised"))
  local edge = b:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  edge:SetColorTexture(ns.Theme:Color("bad"))
  edge:Hide()
  b.edge = edge
  local bar = CreateFrame("StatusBar", nil, b)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  if bar.SetStatusBarTexture then bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") end
  if bar.SetStatusBarColor then bar:SetStatusBarColor(0.2, 0.75, 0.3) end
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  b.bar = bar
  b.label = bar:CreateFontString(nil, "OVERLAY")
  ns.Theme:StyleText(b.label, "small", "text")
  b.label:SetPoint("LEFT", 4, 0)
  b.mark = bar:CreateFontString(nil, "OVERLAY")
  ns.Theme:StyleText(b.mark, "small", "accent")
  b.mark:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnEnter", function(self) M:Tooltip(self) end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  self.bars[i] = b
  return b
end

function M:Tooltip(b)
  if not (GameTooltip and b.unit) then return end
  GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
  GameTooltip:AddLine(nameOf(b.unit) or b.unit)
  for _, c in ipairs(self:Clicks()) do GameTooltip:AddLine(c.label .. ": " .. c.spell, 0.8, 0.8, 0.8) end
  if self:IsAssigned(nameOf(b.unit)) then GameTooltip:AddLine("Assigned to you", 1, 0.82, 0) end
  GameTooltip:Show()
end

-- Layout: which unit each bar heals and which spell each click casts.
-- Secure: runs now out of combat, or right after the fight.
function M:Layout(why)
  return self:Secure("layout", function()
    local f = self:Panel()
    local show = self:ShouldShow()
    local units, focused = self:Units()
    local clicks = self:Clicks()
    if not show or #clicks == 0 then units = {} end
    for i = 1, math.max(#units, #self.bars) do
      local b = units[i] and self:Bar(i) or self.bars[i]
      if b then
        local u = units[i]
        b.unit = u
        b:SetAttribute("unit", u)
        for _, k in ipairs({ "type1", "spell1", "type2", "spell2",
          "shift-type1", "shift-spell1", "shift-type2", "shift-spell2",
          "ctrl-type1", "ctrl-spell1", "ctrl-type2", "ctrl-spell2",
          "alt-type1", "alt-spell1", "alt-type2", "alt-spell2" }) do
          b:SetAttribute(k, nil)
        end
        if u then
          for _, c in ipairs(clicks) do
            b:SetAttribute(c.mod .. "type" .. c.button, "spell")
            b:SetAttribute(c.mod .. "spell" .. c.button, c.spell)
          end
          b:ClearAllPoints()
          local col, row = (i - 1) % M.COLS, math.floor((i - 1) / M.COLS)
          b:SetPoint("TOPLEFT", f, "TOPLEFT", col * (M.W + M.GAP), -row * (M.H + M.GAP))
          b:Show()
        else
          b:Hide()
        end
      end
    end
    f:SetHeight(math.max(M.H, math.ceil(#units / M.COLS) * (M.H + M.GAP)))
    f:SetShown(#units > 0)
    f.head:SetText(focused and "Assigned" or "Group")
    self.shown = units
    self:Refresh()
    local names = {}
    for _, u in ipairs(units) do names[#names + 1] = nameOf(u) or u end
    local line = string.format("%d bars (%s)%s: %s", #units, focused and "assigned" or "group",
      #clicks > 0 and "" or ", no heal known", table.concat(names, ", "))
    if line ~= self.lastLine then
      self.lastLine = line
      self:Info("heal panel (%s): %s", tostring(why), line)
    end
  end)
end

-- Health on the bars; safe in combat (the bar is not a secure frame).
function M:Refresh(unit)
  for _, b in ipairs(self.bars or {}) do
    if b.unit and (not unit or b.unit == unit) and b:IsShown() then
      local hp, max = C.Call("UnitHealth", b.unit), C.Call("UnitHealthMax", b.unit)
      if max ~= nil then pcall(b.bar.SetMinMaxValues, b.bar, 0, max) end
      if hp ~= nil then pcall(b.bar.SetValue, b.bar, hp) end
      b.label:SetText(nameOf(b.unit) or "")
      local rh, rm = C.Readable(hp), C.Readable(max)
      local low = type(rh) == "number" and type(rm) == "number" and rm > 0 and rh / rm < M.LOW
      local dead = C.Readable(C.Call("UnitIsDeadOrGhost", b.unit)) == true
      b.edge:SetShown(low and not dead or false)
      b.mark:SetText(dead and "dead" or (self:IsAssigned(nameOf(b.unit)) and "*" or ""))
      local inRange = C.Readable(C.Call("UnitInRange", b.unit))
      b.bar:SetAlpha((b.unit ~= "player" and inRange == false) and 0.45 or 1)
    end
  end
end

-- ------------------------------------------------------------------ assignments
function M:Assign(name, on)
  if type(name) ~= "string" or name == "" then return false end
  name = name:gsub("^%l", string.upper)
  self:Assigned()[name] = on and true or nil
  self:Layout("assign")
  return true
end

function M:ClearAssigned()
  local s = self:Settings()
  s.assigned = {}
  self:Layout("assign")
end

-- Group members you could assign (names), out of combat.
function M:Members()
  local out, me = {}, nameOf("player")
  local units = {}
  if C.Call("IsInRaid") then for i = 1, 40 do units[#units + 1] = "raid" .. i end
  else for i = 1, 4 do units[#units + 1] = "party" .. i end end
  for _, u in ipairs(units) do
    local n = C.Call("UnitExists", u) and nameOf(u)
    if n and n ~= me then out[#out + 1] = n end
  end
  return out
end

function M:Summary()
  local names = {}
  for n in pairs(self:Assigned()) do names[#names + 1] = n end
  table.sort(names)
  local clicks = {}
  for _, c in ipairs(self:Clicks()) do clicks[#clicks + 1] = c.label .. " " .. c.spell end
  return string.format("Heal bars: %s. Assigned: %s. Clicks: %s.", self:Settings().show == "off" and "off" or
    (self:Settings().show == "always" and "always shown" or "shown in a group"),
    #names > 0 and table.concat(names, ", ") or "nobody (the whole group shows)",
    #clicks > 0 and table.concat(clicks, ", ") or "no heal known yet")
end

function M:OnEnable()
  local function later(why) ns.Throttle("healpanel", 0.5, function() M:Layout(why) end) end
  self:On("PLAYER_ENTERING_WORLD", function() later("login") end)
  self:On("GROUP_ROSTER_UPDATE", function() later("group") end)
  self:On("UNIT_PET", function(_, _, unit) if unit == "player" then later("pet") end end)
  self:On("SPELLS_CHANGED", function() later("spells") end)
  self:On("UNIT_HEALTH", function(mod, _, unit) mod:Refresh(unit) end)
  self:On("UNIT_MAXHEALTH", function(mod, _, unit) mod:Refresh(unit) end)
end

function M:OnDisable()
  ns.ThrottleCancel("healpanel")
  if self.panel then self:Secure("hide", function() self.panel:Hide() end) end
end

function M:Activity()
  return string.format("%d heal bars, %d assigned", #(self.shown or {}), (function()
    local n = 0 for _ in pairs(self:Assigned()) do n = n + 1 end return n end)())
end

function M:ShowEditor()
  if not self.editor then
    local f = ns.UI:Window("Outrider_HealEditor", "Heal bindings", 480, 320, ns.db.char.healEditorPos or {})
    f.list = ns.UI:ScrollList(f.content, {
      rows = 8, rowHeight = 27,
      render = function(row, entry) row.text:SetText(entry.label .. ": " .. entry.spell) end,
    })
    f.list:SetPoint("TOPLEFT", 5, -8)
    f.list:SetPoint("RIGHT", -5, 0)
    f:Hide()
    self.editor = f
  end
  local rows = self:Clicks()
  table.sort(rows, function(a,b) return a.label < b.label end)
  self.editor.list:SetItems(rows)
  self.editor:SetShown(not self.editor:IsShown())
end

ns.AddCommand("heal", "[assign <name>|unassign <name>|clear|always|group|off|self on|off]  click-to-heal bars", function(arg)
  local cmd, rest = (arg or ""):match("^(%S*)%s*(.-)%s*$")
  local s = M:Settings()
  if cmd == "bind" then
    local button, spell = rest:match("^(%S+)%s+(.+)$")
    local ok, reason = M:SetBinding(button, spell)
    ns.Print(ok and ("heal binding " .. button .. ": " .. spell) or tostring(reason))
    return
  elseif cmd == "unbind" then
    local ok, reason = M:SetBinding(rest, nil)
    ns.Print(ok and ("heal binding " .. rest .. " reset") or tostring(reason))
    return
  elseif cmd == "editor" then M:ShowEditor() return
  elseif cmd == "assign" or cmd == "unassign" then
    if rest == "" and cmd == "assign" then rest = nameOf("target") or "" end
    if not M:Assign(rest, cmd == "assign") then ns.Print("Who? /ride heal assign <name> (or target them)") return end
  elseif cmd == "clear" then M:ClearAssigned()
  elseif cmd == "always" or cmd == "group" or cmd == "off" then s.show = cmd M:Layout("command")
  elseif cmd == "self" then s.withSelf = rest ~= "off" M:Layout("command")
  end
  ns.Print(M:Summary())
end)
