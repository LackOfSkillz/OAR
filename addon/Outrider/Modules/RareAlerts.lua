-- Modules/RareAlerts.lua
-- Toast + sound when RareScan reports a living rare (OTR_RARE_SEEN), with a
-- Target button: a pooled secure button whose macro is /targetexact <name>.
-- Gary's click does the targeting (hard rule 1). Steps aside when
-- RareScanner is installed.
-- Per character: which rares alert (all / pack / watch), sound, toast,
-- and a per-NPC cooldown so a rare walking in and out of nameplate range
-- doesn't alert again and again.

local _, ns = ...
local M = ns:NewModule("RareAlerts", {
  title = "Rare alerts",
  phase = "P2",
  order = 30,
  yieldsTo = { "RareScanner" },
  defaults = { mode = "all", sound = true, soundName = "RAID_WARNING", toast = true, cooldown = 300, flash = true, arrow = true },
})

local L = {
  nearby = "nearby", targeted = "targeted", hovered = "under your mouse",
}
local HOW = { nameplate = L.nearby, target = L.targeted, mouseover = L.hovered, vignette = "on the minimap" }

function M:OnInitialize()
  self.lastAlert = {}
end

function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnRareSeen)
end

-- Returns true when this sighting should alert; reason string when not.
function M:ShouldAlert(info, now)
  local s = self:Settings()
  if info.dead then return false, "dead" end
  if s.mode == "pack" and not (info.pack or info.watched) then return false, "not in pack" end
  if s.mode == "watch" and not info.watched then return false, "not watched" end
  local last = self.lastAlert[info.npcID]
  if last and now - last < (s.cooldown or 300) then return false, "cooldown" end
  return true
end

function M:Text(info)
  local parts = {}
  if info.level then parts[#parts + 1] = "Level " .. info.level end
  if info.classification == "rareelite" then parts[#parts + 1] = "elite" end
  if info.family then parts[#parts + 1] = info.family end
  parts[#parts + 1] = HOW[info.how] or info.how
  -- which way to look (Gary, 2026-11-15: lost The Rake among the beasts)
  local dir = info.how == "nameplate" and info.unit and ns.RarePlates and ns.RarePlates.Direction(info.unit)
  if dir then parts[#parts + 1] = dir end
  return table.concat(parts, " · ")
end

function M:OnRareSeen(_, info)
  local now = GetTime and GetTime() or time()
  local ok, why = self:ShouldAlert(info, now)
  if not ok then self:Debug("no alert npcID=%d: %s", info.npcID, why) return end
  -- a sighting without a readable name (secret in combat, or shared) still alerts
  if type(info.name) ~= "string" or info.name == "" then
    local pack = ns.Data:Get("rare", info.npcID)
    info.name = pack and pack.name or ("NPC " .. tostring(info.npcID))
  end
  self.lastAlert[info.npcID] = now
  self.lastInfo = info
  local s = self:Settings()
  local button = { label = "Target", macro = "/targetexact " .. info.name }
  local tame = ns.Modules:Get("TameHelper")
  local myLevel = ns.Compat.Call("UnitLevel", "player") or 0
  local note
  if tame and tame.enabled and info.tameable and (not info.level or info.level <= myLevel) then
    button = { label = "Pull/Tame", macro = tame:Body(info.name) }
    -- Classic rule (Gary, 2026-11-11): you can't tame while you have a pet,
    -- even a dismissed one; it has to be in a stable slot.
    local petName = ns.Compat.Readable(ns.Compat.Call("UnitName", "pet"))
    if petName then note = "Stable " .. petName .. " first: /ride near stable" end
  end
  if s.toast and info.name then
    ns.Toast:Show({
      title = "Rare: " .. info.name,
      text = note and (self:Text(info) .. ". " .. note) or self:Text(info),
      color = "warn",
      sound = s.sound and ns.Toast:SoundID(s.soundName) or nil,
      duration = 20,
      button = button,
    })
  elseif s.sound then
    ns.Compat.Call("PlaySound", ns.Toast:SoundID(s.soundName), "Master")
  end
  -- Hard to miss while camping (Gary, 2026-11-14): a red pulse round the screen
  -- edge, and the arrow to her when her exact spot is known (minimap marker).
  if s.flash then self:Flash() end
  if s.arrow and info.exact and info.mapID and ns.Waypoints then
    ns.Waypoints:Set(info.mapID, info.x, info.y, "Rare: " .. info.name)
  end
  self:Info("alert npcID=%d %s how=%s layer=%s", info.npcID, tostring(info.name), info.how, tostring(info.layer))
end

-- A red border round the whole screen that pulses 4 times (plain frame, not
-- secure; nothing clickable, so it never gets in the way).
function M:Flash()
  local f = self.flash
  if not f then
    f = CreateFrame("Frame", "Outrider_RareFlash", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(false)
    local function edge(a1, a2, w, h)
      local t = f:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(1, 0.15, 0.1, 0.55)
      t:SetPoint(a1) t:SetPoint(a2)
      if w then t:SetWidth(w) end
      if h then t:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 28) edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 28)
    edge("TOPLEFT", "BOTTOMLEFT", 28, nil) edge("TOPRIGHT", "BOTTOMRIGHT", 28, nil)
    local ag = f.CreateAnimationGroup and f:CreateAnimationGroup()
    if ag then
      local a = ag:CreateAnimation("Alpha")
      if a then
        a:SetFromAlpha(1) a:SetToAlpha(0) a:SetDuration(0.6)
        ag:SetLooping("REPEAT")
        local n = 0
        ag:SetScript("OnLoop", function() n = n + 1 if n >= 4 then ag:Stop() f:Hide() n = 0 end end)
      end
      f.ag = ag
    end
    f:Hide()
    self.flash = f
  end
  f:Show()
  if f.ag then f.ag:Stop() f.ag:Play() end
end

function M:Snapshot()
  local i = self.lastInfo
  return i and { lastAlert = { npcID = i.npcID, name = i.name, t = i.t } } or nil
end

function M:Activity()
  local n = 0
  for _ in pairs(self.lastAlert) do n = n + 1 end
  return n == 0 and "waiting for a rare (toast + sound when one shows up)" or (n .. " alerts this session, last: " .. tostring(self.lastInfo and self.lastInfo.name))
end
