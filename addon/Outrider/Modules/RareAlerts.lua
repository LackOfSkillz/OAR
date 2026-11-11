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
  defaults = { mode = "all", sound = true, soundName = "RAID_WARNING", toast = true, cooldown = 300 },
})

local L = {
  nearby = "nearby", targeted = "targeted", hovered = "under your mouse",
}
local HOW = { nameplate = L.nearby, target = L.targeted, mouseover = L.hovered }

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
  return table.concat(parts, " · ")
end

function M:OnRareSeen(_, info)
  local now = GetTime and GetTime() or time()
  local ok, why = self:ShouldAlert(info, now)
  if not ok then self:Debug("no alert npcID=%d: %s", info.npcID, why) return end
  self.lastAlert[info.npcID] = now
  self.lastInfo = info
  local s = self:Settings()
  local button = { label = "Target", macro = "/targetexact " .. info.name }
  local tame = ns.Modules:Get("TameHelper")
  local myLevel = ns.Compat.Call("UnitLevel", "player") or 0
  if tame and tame.enabled and info.tameable and (not info.level or info.level <= myLevel) then
    button = { label = "Pull/Tame", macro = tame:Body(info.name) }
  end
  if s.toast and info.name then
    ns.Toast:Show({
      title = "Rare: " .. info.name,
      text = self:Text(info),
      color = "warn",
      sound = s.sound and ns.Toast:SoundID(s.soundName) or nil,
      duration = 20,
      button = button,
    })
  elseif s.sound then
    ns.Compat.Call("PlaySound", ns.Toast:SoundID(s.soundName), "Master")
  end
  self:Info("alert npcID=%d %s how=%s layer=%s", info.npcID, tostring(info.name), info.how, tostring(info.layer))
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
