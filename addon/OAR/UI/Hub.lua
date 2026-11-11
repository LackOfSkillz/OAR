-- UI/Hub.lua
-- The one OAR window: who you are, which modules are on for THIS character
-- and why, detected addons, export/import/copy, errors. Opened by the
-- minimap button or /oar. Feature modules add their own tabs in later phases
-- via ns.Hub:AddSection(title, builder).

local _, ns = ...
local Hub = { name = "hub", sections = {} }
ns.Hub = Hub
local UI, Theme = ns.UI, ns.Theme

local MAX_ROWS = 14

function Hub:AddSection(title, build)
  self.sections[#self.sections + 1] = { title = title, build = build }
end

function Hub:Build()
  if self.frame then return self.frame end
  local f = UI:Window("OAR_Hub", "OAR", 560, 470, ns.db.char.hub)
  self.frame = f
  local c = f.content

  f.who = UI.Text(c, "normal", "muted")
  f.who:SetPoint("TOPLEFT", 0, 0)

  local heading = UI.Text(c, "large", "accent")
  heading:SetPoint("TOPLEFT", 0, -24)
  heading:SetText("Modules for this character")

  f.rows = {}
  for i = 1, MAX_ROWS do
    local row = UI:Check(c, "", function() local r = f.rows[i] return r and r.mod and r.mod.enabled end,
      function(on)
        local mod = f.rows[i] and f.rows[i].mod
        if not mod then return end
        local ok, err = ns.Modules:SetEnabled(mod.name, on)
        if not ok then ns.Print("%s: %s", mod.name, err) end
        Hub:Refresh()
      end)
    row:SetPoint("TOPLEFT", 0, -46 - (i - 1) * 22)
    row:SetWidth(520)
    f.rows[i] = row
  end

  f.addons = UI.Text(c, "small", "muted")
  f.addons:SetPoint("BOTTOMLEFT", 0, 70)
  f.addons:SetWidth(520)
  f.addons:SetJustifyH("LEFT")

  f.status = UI.Text(c, "small", "muted")
  f.status:SetPoint("BOTTOMLEFT", 0, 34)
  f.status:SetWidth(520)
  f.status:SetJustifyH("LEFT")

  local export = UI:Button(c, "Export", 96, function()
    local s, err = ns.Profiles:Export()
    if s then UI:TextDialog("Export settings (" .. ns.db.key .. ")", s, "copy")
    else ns.Print("export failed: %s", tostring(err)) end
  end)
  export:SetPoint("BOTTOMLEFT", 0, 0)

  local import = UI:Button(c, "Import", 96, function()
    UI:TextDialog("Import settings into " .. ns.db.key, "", "paste", function(text)
      local ok, err = ns.Profiles:Import(text)
      if ok then ns.Print("settings imported. Type /reload to apply everything.") end
      return ok, err
    end)
  end)
  import:SetPoint("LEFT", export, "RIGHT", 6, 0)

  local copy = UI:Button(c, "Copy from...", 110, function() Hub:ShowCopyMenu() end)
  copy:SetPoint("LEFT", import, "RIGHT", 6, 0)

  f.errorsBtn = UI:Button(c, "Errors", 96, function() ns.Slash:Run("errors") end)
  f.errorsBtn:SetPoint("LEFT", copy, "RIGHT", 6, 0)

  local reload = UI:Button(c, "Reload UI", 96, function() ReloadUI() end)
  reload:SetPoint("BOTTOMRIGHT", 0, 0)

  f:SetScript("OnShow", function() Hub:Refresh() ns.db.char.hub.shown = true end)
  f:SetScript("OnHide", function() ns.db.char.hub.shown = false end)
  return f
end

function Hub:Refresh()
  local f = self.frame
  if not f then return end
  local meta = ns.db.char.meta
  f.who:SetText(string.format("%s  |  %s %s  |  v%s  build %s", ns.db.key, tostring(meta.class),
    tostring(meta.level or "?"), ns.version, ns.build))

  local status = ns.Modules:Status()
  for i, row in ipairs(f.rows) do
    local s = status[i]
    if s then
      row.mod = ns.Modules:Get(s.name)
      row.label:SetText(s.title)
      row.note:SetText((s.phase and (s.phase .. "  ") or "") .. (s.enabled and "" or tostring(s.reason)))
      row:Refresh()
      row:Show()
    else
      row.mod = nil
      row:Hide()
    end
  end

  local found = ns.Conflicts:Detect()
  local names = {}
  for _, k in ipairs(found) do names[#names + 1] = k.addon .. " (" .. k.relation .. ")" end
  f.addons:SetText("Detected addons: " .. (#names > 0 and table.concat(names, ", ") or "none"))

  local sv, loads = ns.DB:SavedVariablesStatus()
  f.status:SetText(string.format("Saved settings read back: %s  |  loads %d  |  errors %d  |  %s",
    sv, loads, #ns.Errors.list, ns.Probe:Summary()))
  f.errorsBtn.label:SetText("Errors (" .. #ns.Errors.list .. ")")
end

function Hub:ShowCopyMenu()
  local f = self.frame
  if not f.copyMenu then
    local m = CreateFrame("Frame", nil, f, Theme:BackdropTemplate())
    m:SetSize(240, 10)
    m:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 220, 44)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    Theme:ApplyPanel(m, "raised")
    m.buttons = {}
    f.copyMenu = m
  end
  local m = f.copyMenu
  for _, b in ipairs(m.buttons) do b:Hide() end
  local n = 0
  for _, ch in ipairs(ns.DB:Characters()) do
    if not ch.current and n < 10 then
      n = n + 1
      local b = m.buttons[n] or UI:Button(m, "", 228)
      m.buttons[n] = b
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 6, -6 - (n - 1) * 26)
      b.label:SetText(ch.key .. "  " .. tostring(ch.class or ""))
      b:SetScript("OnClick", function()
        local ok, err = ns.Profiles:CopyFrom(ch.key)
        ns.Print(ok and ("copied settings from " .. ch.key .. ". Type /reload to apply everything.") or tostring(err))
        m:Hide()
        Hub:Refresh()
      end)
      b:Show()
    end
  end
  if n == 0 then ns.Print("no other characters saved yet: log in on another character once.") return end
  m:SetHeight(12 + n * 26)
  m:SetShown(not m:IsShown())
end

function Hub:Toggle()
  local f = self:Build()
  f:SetShown(not f:IsShown())
end
