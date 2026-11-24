-- Modules/FightMeter.lua (DEEP-25)
-- Post-fight *client* numbers only. No combat log and no inference from
-- unreadable combat fields. C_DamageMeter fields were observed on Forever
-- build 70938; unknown versions fail soft. All reads occur after combat.
local _, ns = ...
local C, UI = ns.Compat, ns.UI
local M = ns:NewModule("FightMeter", {
  title = "Post-fight statistics (Blizzard meter)",
  phase = "P7", order = 106,
  defaults = { toast = false, keep = 30 },
})
ns.FightMeter = M
M.DAMAGE_DONE = 0 -- Enum.DamageMeterType.DamageDone in Forever probe
M.MAX_HISTORY = 30

function M:History()
  ns.db.char.fights = type(ns.db.char.fights) == "table" and ns.db.char.fights or {}
  return ns.db.char.fights
end

function M:Sessions()
  local list = C.Call("C_DamageMeter.GetAvailableCombatSessions")
  return type(list) == "table" and list or {}
end

-- A summary that is guaranteed not to require protected/secret math.
function M:Read(sessionID)
  if C.InCombat() then return nil, "combat still active" end
  local fn = C.Resolve("C_DamageMeter.GetCombatSessionFromID")
  if type(fn) ~= "function" then return nil, "damage meter unavailable" end
  local ok, raw = pcall(fn, sessionID, M.DAMAGE_DONE)
  if not ok or type(raw) ~= "table" then return nil, "no readable session" end
  local duration = tonumber(C.Readable(raw.durationSeconds))
  local total = tonumber(C.Readable(raw.totalAmount))
  if not (duration and duration > 0 and total and total >= 0) then return nil, "session values restricted" end
  local rows, player, pet = {}, 0, 0
  for _, source in ipairs(type(raw.combatSources) == "table" and raw.combatSources or {}) do
    local name, amount = C.Readable(source.name), tonumber(C.Readable(source.totalAmount))
    if type(name) == "string" and amount and amount >= 0 then
      local localPlayer = C.Readable(source.isLocalPlayer) == true
      local row = { name = name, amount = amount, dps = amount / duration, mine = localPlayer }
      rows[#rows + 1] = row
      if localPlayer then player = player + amount
      elseif ns.PetStatus and C.Readable(C.Call("UnitName", "pet")) == name then pet = pet + amount end
    end
  end
  table.sort(rows, function(a, b) return a.amount > b.amount end)
  while #rows > 20 do table.remove(rows) end
  return { id = sessionID, duration = duration, total = total,
    dps = total / duration, player = player, pet = pet, sources = rows, at = time(),
    source = "Blizzard C_DamageMeter", petSplitKnown = pet > 0 }
end

function M:Capture()
  if C.InCombat() then return false end
  local sessions = self:Sessions()
  for _, e in ipairs(sessions) do
    local id = type(e) == "table" and C.Readable(e.sessionID)
    if type(id) == "number" and not self.seen[id] then
      self.seen[id] = true
      local row = self:Read(id)
      if row then
        local name = C.Readable(e.name)
        row.name = type(name) == "string" and name or ("Fight " .. id)
        local history = self:History()
        history[#history + 1] = row
        while #history > self.MAX_HISTORY do ns.Archive:Shift("fights", history) end
        if self:Settings().toast and ns.Toast then
          ns.Toast:Show({ title = "Last fight: " .. row.name,
            text = string.format("%d damage, %.1f DPS in %.1fs (Blizzard)", row.total, row.dps, row.duration),
            color = "accent", duration = 8 })
        end
        self:Info("captured fight %s: %.1f DPS, %d damage", row.name, row.dps, row.total)
      end
    end
  end
  if self.window and self.window:IsShown() then self:Refresh() end
  return #sessions > 0
end

function M:Build()
  if self.window then return self.window end
  local f = UI:Window("Outrider_FightMeter", "After the fight", 480, 350, ns.db.char.fightWindow or {})
  self.window = f
  local hint = UI.Text(f.content, "small", "muted")
  hint:SetPoint("TOPLEFT", 4, -4)
  hint:SetWidth(450)
  hint:SetText("Blizzard's recorded sessions. Displayed out of combat; no combat-log access.")
  f.list = UI:ScrollList(f.content, {
    rows = 9, rowHeight = 27,
    render = function(row, entry)
      row.text:SetText(string.format("%s  |cff8fd1ff%.1f DPS|r  %d total / %.0fs",
        tostring(entry.name), entry.dps, entry.total, entry.duration))
    end,
  })
  f.list:SetPoint("TOPLEFT", 4, -30)
  f.list:SetPoint("RIGHT", -4, 0)
  f:Hide()
  return f
end

function M:Refresh()
  if not self.window then return end
  local out, history = {}, self:History()
  for i = #history, 1, -1 do out[#out + 1] = history[i] end
  self.window.list:SetItems(out)
end

function M:OnInitialize()
  self.seen = {}
  local history = self:History()
  for _, e in ipairs(history) do if e.id then self.seen[e.id] = true end end
end

function M:OnEnable()
  self:On("PLAYER_REGEN_ENABLED", function(mod)
    ns.Timer.After(2, function() if mod.enabled then mod:Capture() end end, "fightmeter:read")
  end)
  self:On("DAMAGE_METER_COMBAT_SESSION_UPDATED", function(mod)
    if not C.InCombat() then ns.Throttle("fightmeter:updated", 2, function() mod:Capture() end) end
  end)
end

function M:OnDisable()
  ns.ThrottleCancel("fightmeter:updated")
  if self.window then self.window:Hide() end
end

function M:Activity() return string.format("%d post-fight client sessions captured", #self:History()) end

ns.AddCommand("fights", "fights [list|show|toast on|toast off]  Blizzard post-fight meter", function(arg)
  arg = tostring(arg or "")
  if arg == "toast on" or arg == "toast off" then
    M:Settings().toast = arg == "toast on"
    ns.Print("post-fight alerts %s", M:Settings().toast and "on" or "off")
    return
  end
  M:Capture()
  if arg == "list" then
    local history = M:History()
    for i = #history, math.max(1, #history - 9), -1 do
      local e = history[i]
      ns.Print("%s: %.1f DPS, %d damage over %.0fs (Blizzard)", e.name, e.dps, e.total, e.duration)
    end
    return
  end
  local f = M:Build()
  M:Refresh()
  f:SetShown(not f:IsShown())
end)
