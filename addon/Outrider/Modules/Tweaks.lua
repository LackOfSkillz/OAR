-- Modules/Tweaks.lua
-- Small switches (gap analysis 2026-11-17, Leatrix Plus / MinimapButtonButton
-- / Prat style). All off until switched on in Settings.
--   * Hide clutter: big zone names, red error text, the talking head. Faded
--     to invisible (alpha), never hidden or moved, so nothing of Blizzard's
--     is fought over; switching off puts them back.
--   * Camera: zoom out further (the cameraDistanceMaxZoomFactor setting,
--     out of combat).
--   * Minimap buttons: other addons' LibDBIcon buttons gathered into one
--     Outrider button; a click opens them in a row (each still runs its own
--     click). Uses LibDBIcon's own Hide/Show, so their addons agree.
--   * Wowhead link: hover an item, NPC or spell and press the key binding
--     (or /ride wowhead): a box with its WoW Forever Wowhead address to copy.
--   * Chat history: the last 50 lines of the main chat window come back
--     after a /reload or the next login, greyed.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Tweaks", {
  title = "Small switches",
  phase = "P7",
  order = 50,
  defaults = { zoneText = false, errors = false, talkingHead = false, zoom = false, buttonBag = false, history = false },
})
ns.Tweaks = M

M.ZOOM_FAR, M.ZOOM_DEFAULT = 2.6, 1.9
M.HISTORY = 50
M.WOWHEAD = "https://www.wowhead.com/forever/"

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

-- ------------------------------------------------------------------ clutter
M.CLUTTER = {
  zoneText = { "ZoneTextFrame", "SubZoneTextFrame" },
  errors = { "UIErrorsFrame" },
  talkingHead = { "TalkingHeadFrame" },
}

function M:ApplyClutter()
  local s = self:Settings()
  for key, frames in pairs(M.CLUTTER) do
    for _, name in ipairs(frames) do
      local f = rawget(_G, name)
      if f and f.SetAlpha then pcall(f.SetAlpha, f, s[key] and 0 or 1) end
    end
  end
end

-- ------------------------------------------------------------------ camera
function M:ApplyZoom()
  local want = self:Settings().zoom and M.ZOOM_FAR or nil
  if not want and not self.zoomTouched then return end
  self.zoomTouched = true
  ns.Combat:Run("tweaks:zoom", function()
    local set = C.Resolve("C_CVar.SetCVar") or C.Resolve("SetCVar")
    if type(set) == "function" then pcall(set, "cameraDistanceMaxZoomFactor", tostring(want or M.ZOOM_DEFAULT)) end
  end, "tweaks")
end

-- ------------------------------------------------------------------ minimap buttons
local function icon()
  local stub = rawget(_G, "LibStub")
  return stub and stub("LibDBIcon-1.0", true)
end

function M:OtherButtons()
  local lib, out = icon(), {}
  if not lib then return out end
  local list = lib.GetButtonList and lib:GetButtonList() or {}
  for _, name in ipairs(list) do
    if name ~= "Outrider" then
      local b = lib.GetMinimapButton and lib:GetMinimapButton(name)
      if b then out[#out + 1] = { name = name, button = b } end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function M:Gather(on)
  local lib = icon()
  if not lib then return 0 end
  self.gathered = self.gathered or {}
  local n = 0
  for _, x in ipairs(self:OtherButtons()) do
    if on then
      if lib.Hide then pcall(lib.Hide, lib, x.name) self.gathered[x.name] = true n = n + 1 end
    elseif self.gathered[x.name] and lib.Show then
      pcall(lib.Show, lib, x.name)
      self.gathered[x.name] = nil
    end
  end
  self:BuildBag()
  if self.bag then self.bag:SetShown(on and n > 0) end
  return n
end

function M:BuildBag()
  if self.bag then return self.bag end
  local minimap = rawget(_G, "Minimap")
  if not minimap then return nil end
  local UI = ns.UI
  local b = CreateFrame("Button", "Outrider_ButtonBag", minimap)
  b:SetSize(22, 22)
  b:SetPoint("BOTTOMLEFT", minimap, "BOTTOMLEFT", 2, 2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
  UI.Tip(b, "Addon buttons", "Your other addons' minimap buttons, gathered here. Click to show them.")
  local tray = CreateFrame("Frame", nil, b, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(tray, "bg", "border")
  tray:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
  tray:SetHeight(30)
  tray:Hide()
  tray.slots = {}
  b.tray = tray
  b:SetScript("OnClick", function() M:ToggleTray() end)
  b:Hide()
  self.bag = b
  return b
end

function M:ToggleTray()
  local tray = self.bag and self.bag.tray
  if not tray then return end
  if tray:IsShown() then tray:Hide() return end
  local list = self:OtherButtons()
  for i, x in ipairs(list) do
    local s = tray.slots[i]
    if not s then
      s = CreateFrame("Button", nil, tray)
      s:SetSize(24, 24)
      s.icon = s:CreateTexture(nil, "ARTWORK")
      s.icon:SetAllPoints()
      s:SetScript("OnClick", function(self, button)
        local src = self.src
        local click = src and src.GetScript and src:GetScript("OnClick")
        if click then ns.Safe("tweaks:buttonbag", click, src, button or "LeftButton") end
      end)
      s:SetScript("OnEnter", function(self)
        local src = self.src
        local enter = src and src.GetScript and src:GetScript("OnEnter")
        if enter then pcall(enter, src) end
      end)
      s:SetScript("OnLeave", function(self)
        local src = self.src
        local leave = src and src.GetScript and src:GetScript("OnLeave")
        if leave then pcall(leave, src) end
      end)
      if s.RegisterForClicks then s:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
      tray.slots[i] = s
    end
    s.src = x.button
    local tex = x.button.icon and x.button.icon.GetTexture and x.button.icon:GetTexture()
    s.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    s:ClearAllPoints()
    s:SetPoint("LEFT", tray, "LEFT", 3 + (i - 1) * 26, 0)
    s:Show()
  end
  for i = #list + 1, #tray.slots do tray.slots[i]:Hide() end
  tray:SetWidth(math.max(30, #list * 26 + 6))
  tray:Show()
end

-- ------------------------------------------------------------------ wowhead
-- the Wowhead address for what the tooltip shows (item, NPC or spell)
function M.WowheadFor(tt)
  tt = tt or rawget(_G, "GameTooltip")
  if not (tt and tt.IsShown and tt:IsShown()) then return nil end
  if tt.GetItem then
    local _, link = tt:GetItem()
    local id = link and tonumber(tostring(link):match("item:(%d+)"))
    if id then return M.WOWHEAD .. "item=" .. id, link end
  end
  if tt.GetSpell then
    local name, id = tt:GetSpell()
    if tonumber(id) then return M.WOWHEAD .. "spell=" .. id, name end
  end
  if tt.GetUnit then
    local name, unit = tt:GetUnit()
    local npc = unit and C.UnitNpcID(unit)
    if npc then return M.WOWHEAD .. "npc=" .. npc, readable(name) end
  end
  return nil
end

function M:ShowWowhead()
  local url, what = M.WowheadFor()
  if not url then ns.Print("hover an item, NPC or spell first, then press the key") return end
  ns.UI:TextDialog("Wowhead: " .. tostring(what or ""), url, "copy")
end

-- ------------------------------------------------------------------ chat history
function M:SaveHistory()
  if not self:Settings().history then return end
  local f = rawget(_G, "ChatFrame1")
  if not (f and f.GetNumMessages and f.GetMessageInfo) then return end
  local total, out = f:GetNumMessages() or 0, {}
  for i = math.max(1, total - M.HISTORY + 1), total do
    local ok, text = pcall(f.GetMessageInfo, f, i)
    if ok and type(text) == "string" and not C.IsSecret(text) and not text:find("|cff808080%[before%]") then out[#out + 1] = text end
  end
  ns.db.char.chatHistory = out
end

function M:RestoreHistory()
  local list = ns.db.char.chatHistory
  if not (self:Settings().history and type(list) == "table" and #list > 0) then return end
  local f = rawget(_G, "ChatFrame1") or rawget(_G, "DEFAULT_CHAT_FRAME")
  if not (f and f.AddMessage) then return end
  for _, text in ipairs(list) do
    local plain = ns.Chat and ns.Chat.Plain and ns.Chat.Plain(text) or text
    pcall(f.AddMessage, f, "|cff808080[before] " .. plain .. "|r")
  end
  ns.db.char.chatHistory = nil
end

-- ------------------------------------------------------------------ module
function M:Apply()
  self:ApplyClutter()
  self:ApplyZoom()
  self:Gather(self:Settings().buttonBag)
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin, isReload)
    mod:ApplyClutter()
    mod:ApplyZoom()
    if isLogin or isReload then
      mod:RestoreHistory()
      if mod:Settings().buttonBag then ns.Timer.After(3, function() mod:Gather(true) end, "tweaks:gather") end
    end
  end)
  self:On("PLAYER_LOGOUT", self.SaveHistory)
end

function M:Activity()
  local on = {}
  for k, v in pairs(self:Settings()) do if v == true then on[#on + 1] = k end end
  table.sort(on)
  return #on > 0 and ("on: " .. table.concat(on, ", ")) or "all off"
end

ns.AddCommand("wowhead", "the Wowhead address of what you're hovering (item, NPC, spell), to copy", function() M:ShowWowhead() end)

_G.BINDING_NAME_OUTRIDER_WOWHEAD = "Wowhead link for what you hover"
