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
  defaults = { mode = "all", sound = true, soundName = "RAID_WARNING", eliteSound = true, eliteSoundName = "RAID_BOSS_EMOTE_WARNING", toast = true, cooldown = 300, flash = true, arrow = true, model = true },
})

ns.RareAlerts = M
local C = ns.Compat

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

-- Rare or rare elite (requirement 2026-11-21: tell rare and rare elite apart
-- with a different sound and visual cue): a rare is blue, a rare elite
-- is red, with its own deeper alarm and a longer flash. The class comes from
-- the unit (UnitClassification) or the rare pack (rank "rareelite").
M.LOOK = {
  rare = { word = "Rare", color = "accent", flash = { 0.35, 0.65, 1, 0.55 }, pulses = 4 },
  elite = { word = "RARE ELITE", color = "bad", flash = { 1, 0.15, 0.1, 0.6 }, pulses = 7,
    warn = "Elite: hits hard. Bring a friend or be ready." },
}
function M.IsElite(info)
  if info.classification then return info.classification == "rareelite" end
  local pack = info.npcID and ns.Data and ns.Data:Get("rare", info.npcID)
  return pack and (pack.elite == true or pack.classification == "rareelite") or false
end

-- The sound for this kind of rare: the elite alarm falls back to the ready
-- check sound when the client has no boss-warning sound (still different).
function M:SoundFor(elite)
  local s = self:Settings()
  if elite then
    if s.eliteSound == false then return nil end
    return ns.Toast:SoundID(s.eliteSoundName or "RAID_BOSS_EMOTE_WARNING") or ns.Toast:SoundID("READY_CHECK")
  end
  if not s.sound then return nil end
  return ns.Toast:SoundID(s.soundName)
end

function M:Text(info)
  local parts = {}
  if info.level then parts[#parts + 1] = "Level " .. info.level end
  if M.IsElite(info) then parts[#parts + 1] = "elite" end
  if info.family then parts[#parts + 1] = info.family end
  parts[#parts + 1] = HOW[info.how] or info.how
  -- which way to look (bug 2026-11-15: The Rake was lost among the beasts)
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
  if self:Settings().model then self:ShowModel(info) end
  local s = self:Settings()
  local button = { label = "Target", macro = "/targetexact " .. info.name }
  local tame = ns.Modules:Get("TameHelper")
  local myLevel = ns.Compat.Call("UnitLevel", "player") or 0
  local note
  if tame and tame.enabled and info.tameable and (not info.level or info.level <= myLevel) then
    button = { label = "Pull/Tame", macro = tame:Body(info.name) }
    -- Classic rule (confirmed 2026-11-11): you can't tame while you have a pet,
    -- even a dismissed one; it has to be in a stable slot.
    local petName = ns.Compat.Readable(ns.Compat.Call("UnitName", "pet"))
    if petName then note = "Stable " .. petName .. " first: /ride near stable" end
  end
  local elite = M.IsElite(info)
  local look = elite and M.LOOK.elite or M.LOOK.rare
  info.elite = elite
  local text = self:Text(info)
  if look.warn then text = look.warn .. "  " .. text end
  if note then text = text .. ". " .. note end
  local sound = self:SoundFor(elite)
  if s.toast and info.name then
    ns.Toast:Show({
      title = look.word .. ": " .. info.name,
      creature = info.npcID,
      text = text,
      color = look.color,
      sound = sound,
      duration = elite and 25 or 20,
      button = button,
    })
  elseif sound then
    ns.Compat.Call("PlaySound", sound, "Master")
  end
  -- Hard to miss while camping (requirement 2026-11-14): a pulse round the screen
  -- edge (blue for a rare, red and longer for a rare elite), and the arrow to
  -- her when her exact spot is known (minimap marker).
  if s.flash then self:Flash(look) end
  if ns.MinimapPins and ns.MinimapPins.enabled and ns.MinimapPins.MarkRare then ns.MinimapPins:MarkRare(info) end
  if s.arrow and info.exact and info.mapID and ns.Waypoints then
    ns.Waypoints:Set(info.mapID, info.x, info.y, "Rare: " .. info.name)
  end
  self:Info("alert npcID=%d %s (%s) how=%s layer=%s", info.npcID, tostring(info.name), elite and "rare elite" or "rare", info.how, tostring(info.layer))
end

-- DEEP-32: purely decorative model preview, never a protected action.
-- On clients with no working displayID lookup, show the existing icon toast.
function M:KnownLoot(npcID)
  local source = ns.db.global.rareLootSources
  local data = type(source) == "table" and source[npcID]
  if type(data) ~= "table" then return {} end
  local out = {}
  for _, row in ipairs(data) do
    if type(row) == "table" and type(row.id) == "number" and row.source then
      out[#out + 1] = { id = row.id, chance = row.chance, source = row.source }
    end
  end
  return out
end

function M:ShowModel(info)
  local id = tonumber(info.npcID)
  local pack = id and ns.Data:Get("rare", id)
  local displayID = pack and tonumber(pack.displayID)
  -- No arbitrary model guessing from an NPC ID; display ID must be sourced.
  if not displayID then return false, "model display ID not available" end
  local make = C.Resolve("CreateFrame")
  if type(make) ~= "function" then return false, "model API missing" end
  if not self.modelFrame then
    local ok, frame = pcall(make, "PlayerModel", nil, UIParent)
    if not ok or not frame then return false, "PlayerModel unavailable" end
    frame:SetSize(105, 105)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -110)
    if frame.EnableMouse then frame:EnableMouse(false) end
    self.modelFrame = frame
  end
  local frame = self.modelFrame
  if type(frame.SetDisplayInfo) ~= "function" then frame:Hide() return false, "model display unavailable" end
  if not pcall(frame.SetDisplayInfo, frame, displayID) then frame:Hide() return false, "model failed" end
  frame:Show()
  if self.modelTimer then self.modelTimer:Cancel() end
  self.modelTimer = ns.Timer.After(16, function() if M.modelFrame then M.modelFrame:Hide() end end, "rare:model")
  return true
end

function M:OnDisable()
  if self.modelTimer then self.modelTimer:Cancel() self.modelTimer = nil end
  if self.modelFrame then self.modelFrame:Hide() end
end

-- A red border round the whole screen that pulses 4 times (plain frame, not
-- secure; nothing clickable, so it never gets in the way).
function M:Flash(look)
  look = look or M.LOOK.rare
  local f = self.flash
  if not f then
    f = CreateFrame("Frame", "Outrider_RareFlash", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(false)
    f.edges = {}
    local function edge(a1, a2, w, h)
      local t = f:CreateTexture(nil, "OVERLAY")
      f.edges[#f.edges + 1] = t
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
        ag:SetScript("OnLoop", function() n = n + 1 if n >= (f.pulses or 4) then ag:Stop() f:Hide() n = 0 end end)
      end
      f.ag = ag
    end
    f:Hide()
    self.flash = f
  end
  local c = look.flash
  for _, t in ipairs(f.edges or {}) do t:SetColorTexture(c[1], c[2], c[3], c[4]) end
  f.pulses = look.pulses
  f.look = look
  f:Show()
  if f.ag then f.ag:Stop() f.ag:Play() end
end

-- What an alert looks and sounds like, from the Watch and alerts page (no
-- target button, nothing remembered).
function M:Preview(elite)
  local look = elite and M.LOOK.elite or M.LOOK.rare
  ns.Toast:Show({ title = look.word .. ": " .. (elite and "Example Elite" or "Example Rare"), color = look.color,
    text = (look.warn and (look.warn .. "  ") or "") .. "This is what you'll see and hear.", sound = self:SoundFor(elite), duration = 8, noFeed = true })
  if self:Settings().flash then self:Flash(look) end
  return look
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

ns.AddCommand("rareloot", "rareloot <npcID>  sourced known drops, never invented", function(arg)
  local id = tonumber(arg)
  if not id then ns.Print("usage: /ride rareloot <npcID>") return end
  local list = M:KnownLoot(id)
  if #list == 0 then ns.Print("no sourced drops for rare %d; drop pack not installed or unverified", id) return end
  for _, row in ipairs(list) do
    ns.Print("item %d%s (source: %s)", row.id,
      row.chance and string.format(", %.1f%% reported", row.chance) or "", row.source)
  end
end)
