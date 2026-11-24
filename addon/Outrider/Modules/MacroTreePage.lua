-- Modules/MacroTreePage.lua
-- The Macros page: layout helpers, slot buttons and rendering. Split from Modules/MacroTree.lua (OI01-09); behaviour unchanged.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local T = ns.MacroTree

function T.ColumnWidths(grid, ncols, avail, step)
  local need, total = {}, 0
  for c = 1, ncols do
    local most = 0
    for b = 1, #(grid or {}) do most = math.max(most, #((grid[b] or {})[c] or {})) end
    need[c] = math.max(T.MIN_COL, most * step + 12)
    total = total + need[c]
  end
  local w = {}
  if total <= avail then
    local extra = math.floor((avail - total) / math.max(1, ncols))
    for c = 1, ncols do w[c] = need[c] + extra end
  else
    local others = total - need[1]
    if ncols > 1 and avail - others >= step * 4 + 12 then
      for c = 2, ncols do w[c] = need[c] end
      w[1] = avail - others
    else
      for c = 1, ncols do w[c] = math.max(step + 4, math.floor(avail * need[c] / total)) end
    end
  end
  local x, xs = 0, {}
  for c = 1, ncols do xs[c] = x x = x + w[c] end
  return xs, w
end

-- ------------------------------------------------------------------ page
local ICON, BIG = 36, 54
local COLOR = { gold = { 0.95, 0.78, 0.30 } }

local function slotButton(parent, size)
  local b = CreateFrame("Button", nil, parent, ns.Theme:BackdropTemplate())
  b:SetSize(size, size)
  ns.Theme:ApplyPanel(b, "bg", "strong")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  -- tidy-up 2026-11-20: the level number sits inside the icon, and "new" is a
  -- small gold dot in the corner (the word ran into the next icon and the caption)
  b.badge = UI.Text(b, "small", "text")
  b.badge:SetPoint("BOTTOMRIGHT", -2, 2)
  b.dot = b:CreateTexture(nil, "OVERLAY")
  b.dot:SetSize(7, 7)
  b.dot:SetPoint("TOPRIGHT", -3, -3)
  b.dot:SetColorTexture(1, 0.84, 0.35, 1)
  b.dot:Hide()
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetPoint("TOPLEFT", -3, 3)
  b.ring:SetPoint("BOTTOMRIGHT", 3, -3)
  b.ring:SetColorTexture(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 0.35)
  b.ring:Hide()
  b:RegisterForDrag("LeftButton")
  return b
end

ns.Hub:AddTab("macros", "Macros", function(p)
  T:Info("macros page: building")
  local Theme = ns.Theme
  p.mode = "pve"
  p.who = UI.Text(p, "normal", "goldText")
  p.who:SetPoint("TOPLEFT", 2, 0)
  p.pve = UI:Button(p, "PvE", 56, function() p.mode = "pve" p:Refresh() end)
  p.pvp = UI:Button(p, "PvP", 56, function() p.mode = "pvp" p:Refresh() end)
  UI.Tip(p.pve, "PvE", "Macros for questing and dungeons.")
  UI.Tip(p.pvp, "PvP", "The PvP versions, for battlegrounds, duels and world PvP. Only changes this view.")
  p.singles = UI:Button(p, "Show singles", 104, function()
    T:Settings().singles = not T:Settings().singles
    p:Refresh()
  end)
  UI.Tip(p.singles, "Singles", "The one-spell macros a combined key already covers (Kick, Evasion, Bandage...). Hidden by default; show them if you'd rather have separate buttons.")

  -- the detail panel on the right
  local d = UI:Card(p)
  d:SetWidth(300)
  d:SetPoint("TOPRIGHT", -4, -26)
  d:SetPoint("BOTTOMRIGHT", -4, 0)
  p.detail = d
  p.pvp:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 26)
  p.pve:SetPoint("RIGHT", p.pvp, "LEFT", -6, 0)
  -- character macro slots: a character holds 18
  p.slots = UI.Text(p, "small", "muted")
  p.slots:SetPoint("RIGHT", p.pve, "LEFT", -12, 0)
  -- before 10 talent points: pick the build you're heading for
  p.plan = UI:Dropdown(p, 170, {}, function() return T:Settings().planned or "levelling" end, function(v)
    T:Settings().planned = v ~= "levelling" and v or nil
    if ns.HunterFight and ns.HunterFight.enabled then ns.HunterFight:Update("planned build") end
    T:Info("planned build: %s", tostring(v))
    p:Refresh()
  end)
  p.plan:SetPoint("RIGHT", p.slots, "LEFT", -12, 0)
  UI.Tip(p.plan, "Planned build", "Before 10 talent points, pick the build you're heading for: your keys and the tree follow it. Your talents take over from 10 points.")
  d.title = UI.Display(d, "side", "goldText") d.title:SetPoint("TOPLEFT", 14, -10) d.title:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.title:SetJustifyH("LEFT")
  d.sub = UI.Text(d, "small", "muted") d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4) d.sub:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.sub:SetJustifyH("LEFT")
  d.text = UI.Text(d, "small", "text") d.text:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -10) d.text:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.text:SetJustifyH("LEFT") if d.text.SetJustifyV then d.text:SetJustifyV("TOP") end
  d.msg = UI.Text(d, "small", "warn") d.msg:SetPoint("BOTTOMLEFT", 14, 44) d.msg:SetPoint("RIGHT", d, "RIGHT", -12, 0) d.msg:SetJustifyH("LEFT")
  -- three buttons inside the card (tidy-up 2026-11-19: Copy text stuck out past its edge)
  d.pick = UI:Button(d, "Pick up", 96, function() p:PickCurrent() end)
  d.pick:SetPoint("BOTTOMLEFT", 14, 12)
  UI.SetPrimary(d.pick, true)
  UI.Tip(d.pick, "Pick up", "Writes the macro if it isn't in your macros yet, then puts it on your cursor: click an action bar slot to drop it.")
  d.remove = UI:Button(d, "Remove", 80, function()
    local it = p.current
    if not (it and ns.MacroLibrary) then return end
    local ok, why = ns.MacroLibrary:Remove(it.key and it.key.entry or it.entry)
    d.msg:SetText(ok and "Removed from your macros." or tostring(why))
    p:Refresh()
  end)
  d.remove:SetPoint("LEFT", d.pick, "RIGHT", 6, 0)
  d.copy = UI:Button(d, "Copy text", 86, function()
    local it = p.current
    if not it then return end
    local x = T:Explain(it, it.key)
    UI:TextDialog(it.name, x.body, "copy")
  end)
  d.copy:SetPoint("LEFT", d.remove, "RIGHT", 6, 0)
  UI.Tip(d.copy, "Copy text", "Shows the macro's text to copy, so you can change it and make your own.")
  -- your own macro next to Outrider's (FightPlan's check): Use Outrider's / Keep mine
  d.useOurs = UI:Button(d, "Use Outrider's", 120, function()
    local f = p.own
    local F = ns.HunterFight
    local mine = f and F and F:Entry(f.kind or "ranged")
    local ok, why = false, "nothing to install"
    if mine then ok, why = ns.MacroLibrary:Install(mine) end
    d.msg:SetText(ok and ("Outrider's " .. mine.name .. " is in your macros. Drag it to your bar in place of yours.") or tostring(why))
    p:Refresh(true)
  end)
  d.useOurs:SetPoint("BOTTOMLEFT", 14, 12)
  d.keep = UI:Button(d, "Keep mine", 100, function()
    local f = p.own
    if f and ns.FightPlan then ns.FightPlan:KeepMine(f.name, f.body) end
    p.own, p.current = nil, nil
    d.msg:SetText("Kept. Outrider won't mention this macro again unless you change it.")
    p:Refresh(true)
  end)
  d.keep:SetPoint("LEFT", d.useOurs, "RIGHT", 6, 0)
  d.useOurs:Hide() d.keep:Hide()

  -- your keys
  local keys = UI:Card(p)
  keys:SetPoint("TOPLEFT", 0, -26)
  keys:SetPoint("RIGHT", d, "LEFT", -12, 0)
  keys:SetHeight(128)
  p.keys = keys
  -- combined keys row (requirement 2026-11-20: fewer macros, each with Shift / Ctrl / Alt layers)
  keys.comboHead = UI.Text(keys, "normal", "goldText")
  keys.comboHead:SetPoint("TOPLEFT", 12, -124)
  keys.comboHead:SetText("Combined keys  |cff8f96a6one button each, hold Shift, Ctrl or Alt for the other layers|r")
  keys.combo = {}
  keys.head = UI.Text(keys, "normal", "goldText") keys.head:SetPoint("TOPLEFT", 12, -8)
  keys.head:SetText("Your keys  |cff8f96a6set up once; Outrider rewrites them as you learn spells|r")
  keys.flow = UI.Text(keys, "small", "muted") keys.flow:SetPoint("TOPLEFT", 12, -104) keys.flow:SetPoint("RIGHT", keys, "RIGHT", -12, 0)
  keys.flow:SetJustifyH("LEFT")
  keys.btns = {}

  -- the tree
  local tree = CreateFrame("Frame", nil, p)
  tree:SetPoint("TOPLEFT", keys, "BOTTOMLEFT", 0, -10)
  tree:SetPoint("RIGHT", d, "LEFT", -12, 0)
  tree:SetPoint("BOTTOM", p, "BOTTOM", 0, 34)
  p.tree = tree
  tree.colHeads, tree.rowHeads, tree.cells, tree.pool, tree.emblems = {}, {}, {}, {}, {}
  -- a painted backdrop behind the tree when installed (art batch 6: macro_tree_<class>, else macro_tree)
  tree.bg = tree:CreateTexture(nil, "BACKGROUND")
  tree.bg:SetAllPoints()
  tree.bg:SetAlpha(0.35)
  tree.bg:Hide()
  p.legend = UI.Text(p, "small", "muted")
  p.legend:SetPoint("BOTTOMLEFT", 2, 14)
  p.legend:SetPoint("RIGHT", d, "LEFT", -12, 0)
  p.legend:SetJustifyH("LEFT")
  p.legend:SetText("Click an icon to read it; drag it (or Pick up) onto your action bar.  Gold frame: on your bar.  Gold dot: new.  Grey with a number: unlocks at that level.")
  -- banner: one of your own macros misses parts of your build
  p.ownLine = UI.Text(p, "small", "warn")
  p.ownLine:SetPoint("BOTTOMLEFT", p.legend, "TOPLEFT", 0, 6)
  -- banner: your own macros with an old spell name or an exact copy
  p.auditLine = UI.Text(p, "small", "warn")
  -- banner: Outrider macros from the build you had before a respec
  p.oldLine = UI.Text(p, "small", "warn")
  p.oldLine:SetPoint("BOTTOMLEFT", p.ownLine, "TOPLEFT", 0, 8)
  p.auditLine:SetPoint("BOTTOMLEFT", p.oldLine, "TOPLEFT", 0, 8)
  p.auditLine:SetPoint("RIGHT", d, "LEFT", -12, 0)
  p.auditLine:SetJustifyH("LEFT")
  p.oldBtn = UI:Button(p, "Clear them", 90, function()
    local n, kept = T:ClearOldBuild()
    d.msg:SetText(string.format("Removed %d.%s", n, #kept > 0 and (" Kept: " .. table.concat(kept, "; ")) or ""))
    p:Refresh(true)
  end)
  p.oldBtn:SetHeight(20)
  p.oldBtn:SetPoint("LEFT", p.oldLine, "RIGHT", 8, 0)
  UI.Tip(p.oldBtn, "Clear them", "Removes the macros Outrider wrote for your old build. A macro you changed stays.")
  p.ownBtn = UI:Button(p, "Compare", 80, function() if p.findings and p.findings[1] then p:ShowOwn(p.findings[1]) end end)
  p.ownBtn:SetHeight(20)
  p.ownBtn:SetPoint("LEFT", p.ownLine, "RIGHT", 8, 0)
  p.export = UI:Button(p, "Export", 80, function()
    local s, err = ns.MacroLibrary and ns.MacroLibrary:Export()
    if s then UI:TextDialog("Outrider macros (" .. ns.db.key .. ")", s, "copy") else d.msg:SetText(tostring(err)) end
  end)
  p.export:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", -12, 8)
  p.import = UI:Button(p, "Import", 80, function()
    UI:TextDialog("Import macros into " .. ns.db.key, "", "paste", function(text)
      local n, skipped = ns.MacroLibrary:Import(text)
      if not n then return false, skipped end
      d.msg:SetText(string.format("Installed %d.%s", n, #skipped > 0 and (" Skipped: " .. table.concat(skipped, "; ")) or ""))
      p:Refresh()
      return true
    end)
  end)
  p.import:SetPoint("RIGHT", p.export, "LEFT", -6, 0)
  p.singles:SetPoint("RIGHT", p.import, "LEFT", -6, 0)
  -- how your macro buttons behave (moved from Settings, 2026-11-20 layout):
  -- an Options button opens a small panel above it
  local function mset(name) local m = ns.Modules:Get(name) return m and m:Settings() or {} end
  p.opts = UI:Card(p, true)
  p.opts:SetSize(380, 112)
  p.opts:SetFrameStrata("DIALOG")
  p.opts:Hide()
  p.optBtn = UI:Button(p, "Options", 90, function() p.opts:SetShown(not p.opts:IsShown()) if p.opts:IsShown() then p.opts:Refresh() end end)
  p.optBtn:SetPoint("RIGHT", p.singles, "LEFT", -6, 0)
  UI.Tip(p.optBtn, "Options", "How your macro buttons behave: the missing-buffs row, tooltips and quiet presses.")
  p.opts:SetPoint("BOTTOMLEFT", p.optBtn, "TOPLEFT", 0, 6)
  p.opts.checks = {
    UI:Check(p.opts, "Missing-buffs row above your bars", function() return mset("BuffRow").on end,
      function(on) mset("BuffRow").on = on if ns.BuffRow then ns.BuffRow:Update("settings") end end),
    UI:Check(p.opts, "Outrider's explanation in macro tooltips on your bars", function() return T:Settings().tooltips end,
      function(on) T:Settings().tooltips = on end),
    UI:Check(p.opts, "Quiet presses: no 'not ready yet' text or voice", function() return mset("HandyKeys").quiet end,
      function(on) if ns.HandyKeys then ns.HandyKeys:SetQuiet(on) end end),
  }
  for i, c in ipairs(p.opts.checks) do c:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 30) c:SetWidth(350) end
  function p.opts:Refresh() for _, c in ipairs(self.checks) do c:Refresh() end end

  local function hookButton(b)
    b:SetScript("OnClick", function(self) p:ShowItem(self.item) end)
    b:SetScript("OnDragStart", function(self) p:ShowItem(self.item) p:PickCurrent() end)
    b:SetScript("OnEnter", function(self)
      local it = self.item
      if not it then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(it.name)
      GameTooltip:AddLine(it.stateText or "", 0.75, 0.75, 0.75, true)
      if it.isNew then GameTooltip:AddLine("New: you haven't opened this one yet", 0.95, 0.78, 0.3, true) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local function paint(b, it, onBars, size)
    b.item = it
    local tex, own = T.Icon(it)
    -- Outrider's own key art when installed (art batch 6: macro_key_fight ...)
    local keyArt = it.key and ns.Art and ns.Art:Path("macro_key_" .. tostring(it.name):lower())
    if keyArt then tex = keyArt end
    b.icon:SetTexture(tex)
    local st = it.key and (ns.MacroLibrary and ns.MacroLibrary:State(it.key.entry) or "ready") or T:State(it)
    it.state = st
    local locked = st == "locked" or (type(st) == "string" and st:find("^needs"))
    if b.icon.SetDesaturated then b.icon:SetDesaturated(locked and true or false) end
    b.icon:SetAlpha(locked and 0.55 or 1)
    local usable = not locked
    local new = usable and not it.key and not T:Settings().seen[it.id]
    b.badge:SetText(st == "locked" and tostring(it.level) or "")
    b.dot:SetShown(new and true or false)
    it.isNew = new and true or nil
    local on = onBars[it.name] and true or false
    b.ring:SetShown(on)
    Theme:ApplyPanel(b, "bg", on and "gold" or "strong")
    it.stateText = st == "locked" and string.format("Unlocks at level %d", it.level)
      or (on and "On your bar") or (st == "installed" and "In your macros; drag it to a bar")
      or (st == "changed" and "In your macros, but its text was changed") or (st == "ready" and "Ready: drag it to a bar")
      or tostring(st)
    b:SetSize(size, size)
    b:Show()
  end

  function p:PickCurrent()
    local it = self.current
    if not it then return end
    local ok, why
    if it.key then
      if C.InCombat() then ok, why = false, "not in combat"
      else
        local lib = ns.MacroLibrary
        local st = lib:State(it.key.entry)
        if st ~= "installed" then ok, why = lib:Install(it.key.entry) else ok = true end
        -- your own edits stay, but the drag still works with the macro as it is
        if not ok and st == "changed" then ok, why = true, nil end
        if ok then
          local index = C.Call("GetMacroIndexByName", it.key.entry.name) or 0
          if index > 0 then C.Call("PickupMacro", index) else ok, why = false, "the macro wasn't found" end
        end
      end
    else
      ok, why = T:PickUp(it)
    end
    d.msg:SetText(ok and (why or "On your cursor: click an action bar slot to drop it.") or tostring(why))
    self:Refresh(true)
  end

  -- your macro and Outrider's for the same key, side by side
  function p:ShowOwn(f)
    self.own, self.current = f, nil
    local FP, F = ns.FightPlan, ns.HunterFight
    local mine = F and F:Entry(f.kind or "ranged")
    d.title:SetText(f.name .. "  |cffffc74d(your macro)|r")
    d.sub:SetText("A better fit is available")
    local lines = { "|cff8f96a6Yours:|r", tostring(f.body or ""),
      string.format("\nCovers about %d%% of your build's %s rotation.", math.floor((f.score or 0) * 100 + 0.5),
        FP.SPEC_NAMES[FP:Spec()] or FP:Spec()) }
    if #(f.missing or {}) > 0 then lines[#lines + 1] = "Missing: " .. table.concat(f.missing, ", ") end
    for _, i in ipairs(f.issues or {}) do lines[#lines + 1] = "Problem: " .. i .. " (needs /stopmacro [channeling])" end
    if mine then lines[#lines + 1] = "\n|cfff1d58eOutrider's " .. mine.name .. ":|r" lines[#lines + 1] = mine.body end
    d.text:SetText(table.concat(lines, "\n"))
    d.pick:Hide() d.remove:Hide()
    d.useOurs:SetShown(mine ~= nil) d.keep:Show()
    d.msg:SetText("")
  end

  function p:ShowItem(it)
    if not it then return end
    self.current, self.own = it, nil
    d.useOurs:Hide() d.keep:Hide()
    if it.id and it.state ~= "locked" then T:Settings().seen[it.id] = true end
    local x = T:Explain(it, it.key)
    d.title:SetText(x.title)
    local names = ns.FightPlan and ns.FightPlan.SPEC_NAMES or {}
    local sub = it.key and (it.key.kind == "combo" and "Combined key" or "One of your keys") or (it.tree and ((names[it.tree] or it.tree) .. " build") or "Every build")
    d.sub:SetText(sub .. "\n" .. (it.stateText or ""))
    local parts = { "|cfff1d58eWhen to press|r", x.when }
    if x.what and x.what ~= "" then parts[#parts + 1] = "\n|cfff1d58eWhat it does|r" parts[#parts + 1] = x.what end
    local layers = it.key and it.key.entry and it.key.entry.layers
    if layers and layers ~= "" then
      parts[#parts + 1] = "\n|cfff1d58eHold to change it|r"
      for l in (layers .. "  ·  "):gmatch("(.-)  ·  ") do parts[#parts + 1] = l end
    end
    parts[#parts + 1] = "\n|cfff1d58eLine by line|r"
    for i, l in ipairs(x.lines) do parts[#parts + 1] = i .. ". " .. l end
    -- the macro itself, one line per line (tidy-up 2026-11-20: was run together with bars)
    parts[#parts + 1] = string.format("\n|cfff1d58eThe macro|r  |cff8f96a6%d / 255 characters|r", #(x.body or ""))
    for line in (x.body .. "\n"):gmatch("(.-)\n") do
      if line ~= "" then parts[#parts + 1] = "|cffb8c0d0" .. line .. "|r" end
    end
    d.text:SetText(table.concat(parts, "\n"))
    local st = it.state
    d.pick:SetShown(st ~= "locked")
    d.copy:Show()
    d.remove:SetShown(st == "installed" or st == "changed")
    d.msg:SetText(st == "locked" and string.format("Unlocks at level %d. It appears here so you can plan ahead.", it.level) or "")
  end

  T:Info("macros page: built")
  function p:Refresh(keepMsg)
    -- one set of macro values for the whole page (see MacroLibrary:Hold)
    if ns.MacroLibrary and not ns.MacroLibrary.held then
      local t0 = C.Call("debugprofilestop")
      local r = ns.MacroLibrary:Hold(self.Refresh, self, keepMsg)
      local t1 = C.Call("debugprofilestop")
      if t0 and t1 then T:Info("macros page drawn: %d icons in %.0f ms", self.count or 0, t1 - t0) end
      return r
    end
    local cls = ns.PlayerClass() or ""
    local FP = ns.FightPlan
    local spec = FP and FP.enabled and FP:Spec() or "levelling"
    local specName = FP and FP.SPEC_NAMES and FP.SPEC_NAMES[spec] or spec
    local used, max = T.Slots()
    self.slots:SetText(string.format("%s%d / %d character macros|r", used >= max and "|cffff6060" or "|cff8f96a6", used, max))
    -- the build menu, while talents don't decide yet
    local plan = T.Plan()
    local opts = { { "levelling", "Levelling (no build yet)" } }
    for _, t in ipairs(plan and plan.trees or {}) do opts[#opts + 1] = { t, "Plan: " .. ((FP and FP.SPEC_NAMES[t]) or t) } end
    if self.plan.SetOptions then self.plan:SetOptions(opts) else self.plan.options = opts end
    local fromTalents = FP and FP.enabled and spec ~= "levelling" and spec ~= (T:Settings().planned or "")
    local menu = not fromTalents and #opts > 1
    self.plan:SetShown(menu)
    -- tidy-up 2026-11-20: the build menu already names the build; the line only says when talents decide
    local buildText = spec == "levelling" and "levelling build" or (ns.TitleCase(specName or "") .. " build")
    if menu then buildText = buildText .. "  |cff8f96a6(talents decide from 10 points; until then pick one on the right)|r" end
    self.who:SetText(string.format("%s%s  ·  level %d  ·  %s", cls:sub(1, 1), cls:sub(2):lower(), T.Level(), buildText))
    if self.plan.Refresh then self.plan:Refresh() end
    UI.SetPrimary(self.pve, self.mode == "pve")
    UI.SetPrimary(self.pvp, self.mode == "pvp")
    local onBars = T.OnBars()

    -- keys
    local list = T:Keys()
    for i, k in ipairs(list) do
      local b = keys.btns[i]
      if not b then
        b = slotButton(keys, BIG)
        b.cap = UI.Text(keys, "small", "text")
        b.cap:SetPoint("TOP", b, "BOTTOM", 0, -3)
        hookButton(b)
        keys.btns[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", keys, "TOPLEFT", 16 + (i - 1) * (BIG + 34), -30)
      local it = { name = k.name, key = k, spells = T.SpellsIn(k.entry.body), tags = { "combat" }, level = 1 }
      paint(b, it, onBars, BIG)
      b.cap:SetText(k.name)
      b.cap:Show()
    end
    for i = #list + 1, #keys.btns do keys.btns[i]:Hide() keys.btns[i].cap:Hide() end
    local main = list[1]
    local flow = {}
    for _, s in ipairs(main and main.steps or {}) do
      local sp = T.SpellsIn(s.text)
      if #sp > 0 then flow[#flow + 1] = table.concat(sp, " / ") end
    end
    keys.flow:SetText(#flow > 0 and (main.name .. ", press by press:  " .. table.concat(flow, "  >  ")) or
      (#list == 0 and "Fight keys for your class come with the fight plans." or ""))

    -- handy keys, on the right of your keys
    local handy = (T:Grid(self.mode)).handy or {}
    keys.handy = keys.handy or {}
    if not keys.handyHead then
      keys.handyHead = UI.Text(keys, "small", "goldText")
      keys.handyHead:SetText("Handy keys")
    end
    -- tidy-up 2026-11-20: wider pitch and fixed-width captions so names don't run together
    local HP, HS = 72, 40
    keys.handyHead:ClearAllPoints()
    keys.handyHead:SetPoint("TOP", keys, "TOPRIGHT", -16 - (#handy * HP) / 2, -10)
    keys.handyHead:SetShown(#handy > 0)
    for i, it in ipairs(handy) do
      local b = keys.handy[i]
      if not b then
        b = slotButton(keys, HS)
        b.cap = UI.Text(keys, "small", "text")
        b.cap:SetPoint("TOP", b, "BOTTOM", 0, -4)
        b.cap:SetWidth(HP - 4)
        b.cap:SetJustifyH("CENTER")
        if b.cap.SetWordWrap then b.cap:SetWordWrap(false) end
        hookButton(b)
        keys.handy[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOP", keys, "TOPRIGHT", -16 - (#handy - i) * HP - HP / 2, -30)
      paint(b, it, onBars, HS)
      b.cap:SetText(it.name)
      b.cap:Show()
    end

    -- combined keys, a row of their own under your keys
    local combos = ns.ComboKeys and ns.ComboKeys.enabled and ns.ComboKeys:Entries() or {}
    local CP, CS = 84, 44
    for i, e in ipairs(combos) do
      local b = keys.combo[i]
      if not b then
        b = slotButton(keys, CS)
        b.cap = UI.Text(keys, "small", "text")
        b.cap:SetPoint("TOP", b, "BOTTOM", 0, -4)
        b.cap:SetWidth(CP - 4)
        b.cap:SetJustifyH("CENTER")
        hookButton(b)
        keys.combo[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", keys, "TOPLEFT", 16 + (i - 1) * CP + (CP - CS) / 2, -146)
      local it = { name = e.name, key = { entry = e, name = e.name, kind = "combo" }, spells = T.SpellsIn(e.body), tags = { "combo" }, level = 1 }
      paint(b, it, onBars, CS)
      b.cap:SetText(e.name)
      b.cap:Show()
    end
    for i = #combos + 1, #keys.combo do keys.combo[i]:Hide() keys.combo[i].cap:Hide() end
    keys.comboHead:SetShown(#combos > 0)
    keys:SetHeight(#combos > 0 and 232 or 128)
    -- the singles a combined key covers: hidden, with a switch to show them
    self.singles:SetText(T:Settings().singles and "Hide singles" or "Show singles")
    self.singles:SetShown(#combos > 0)

    -- tree
    for _, b in ipairs(tree.pool) do b:Hide() end
    local grid, cols = T:Grid(self.mode)
    local W = math.max(400, tree:GetWidth() or 0)
    if W < 300 then W = 520 end
    local labelW = 46
    local colX, colWs = T.ColumnWidths(grid, #cols, W - labelW, ICON + 4)
    for c = 1, #cols do colX[c] = colX[c] + labelW end
    for c, id in ipairs(cols) do
      local h = tree.colHeads[c]
      if not h then h = UI.Text(tree, "small", "text") tree.colHeads[c] = h end
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", tree, "TOPLEFT", colX[c], 0)
      h:SetWidth(colWs[c])
      h:SetJustifyH("CENTER")
      local names = FP and FP.SPEC_NAMES or {}
      local name = id == "every" and ("Every " .. cls:lower()) or (names[id] or id)
      local mine = id == spec
      h:SetText((mine and "|cfff1d58e" or "|cffbbbbbb") .. name .. (mine and "  (yours)" or "") .. "|r")
      h:Show()
      -- the build's emblem left of its name (art batch 6: spec_<class>_<tree>)
      local em = tree.emblems[c]
      if not em then em = tree:CreateTexture(nil, "ARTWORK") em:SetSize(16, 16) tree.emblems[c] = em end
      local art = id ~= "every" and ns.Art and ns.Art:Path("spec_" .. cls:lower() .. "_" .. id)
      if art then
        em:SetTexture(art)
        em:ClearAllPoints()
        em:SetPoint("RIGHT", h, "CENTER", -((h.GetStringWidth and h:GetStringWidth() or 60) / 2) - 4, 0)
        em:Show()
      else em:Hide() end
    end
    local bgArt = ns.Art and (ns.Art:Path("macro_tree_" .. cls:lower()) or ns.Art:Path("macro_tree"))
    if bgArt then tree.bg:SetTexture(bgArt) tree.bg:Show() else tree.bg:Hide() end
    for c = #cols + 1, #tree.colHeads do tree.colHeads[c]:Hide() end
    -- faint dividers between the columns
    tree.vlines = tree.vlines or {}
    for c = 2, #cols do
      local v = tree.vlines[c]
      if not v then v = tree:CreateTexture(nil, "BORDER") v:SetWidth(1) tree.vlines[c] = v end
      v:ClearAllPoints()
      v:SetPoint("TOPLEFT", tree, "TOPLEFT", colX[c], -16)
      v:SetPoint("BOTTOM", tree, "BOTTOM", 0, 0)
      v:SetColorTexture(1, 1, 1, 0.05)
      v:Show()
    end
    for c = #cols + 1, #tree.vlines do if tree.vlines[c] then tree.vlines[c]:Hide() end end
    if tree.here then tree.here:Hide() end
    -- each band as tall as its fullest cell (icons wrap inside a cell)
    local step = ICON + 4
    local n, y = 0, -20
    for bIdx, band in ipairs(T.BANDS) do
      local lines = 1
      for c = 1, #cols do
        local per = math.max(1, math.floor((colWs[c] - 4) / step))
        lines = math.max(lines, math.ceil(#grid[bIdx][c] / per))
      end
      local rh = tree.rowHeads[bIdx]
      if not rh then rh = UI.Text(tree, "small", "muted") tree.rowHeads[bIdx] = rh end
      rh:ClearAllPoints()
      rh:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, y - 12)
      local here = T.Band(T.Level()) == bIdx
      rh:SetText((here and "|cfff1d58e" or "") .. band[1] .. "-" .. band[2] .. (here and "|r" or ""))
      -- a faint line above each band, and a soft gold wash behind your own band (tidy-up 2026-11-20)
      tree.sep = tree.sep or {}
      local sep = tree.sep[bIdx]
      if not sep then sep = tree:CreateTexture(nil, "BORDER") sep:SetHeight(1) tree.sep[bIdx] = sep end
      sep:ClearAllPoints()
      sep:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, y)
      sep:SetPoint("RIGHT", tree, "RIGHT", 0, 0)
      sep:SetColorTexture(1, 1, 1, 0.07)
      sep:Show()
      local bandH = lines * step + 10
      if here then
        if not tree.here then tree.here = tree:CreateTexture(nil, "BACKGROUND", nil, 1) end
        tree.here:ClearAllPoints()
        tree.here:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, y)
        tree.here:SetPoint("RIGHT", tree, "RIGHT", 0, 0)
        tree.here:SetHeight(bandH)
        tree.here:SetColorTexture(0.95, 0.78, 0.30, 0.06)
        tree.here:Show()
      end
      for c = 1, #cols do
        local items = grid[bIdx][c]
        local per = math.max(1, math.floor((colWs[c] - 4) / step))
        for i, it in ipairs(items) do
          n = n + 1
          local btn = tree.pool[n]
          if not btn then btn = slotButton(tree, ICON) hookButton(btn) tree.pool[n] = btn end
          btn:ClearAllPoints()
          local row, col = math.floor((i - 1) / per), (i - 1) % per
          local inRow = math.min(per, #items - row * per)
          local x0 = colX[c] + math.floor((colWs[c] - inRow * step) / 2)
          btn:SetPoint("TOPLEFT", tree, "TOPLEFT", x0 + col * step, y - 4 - row * step)
          paint(btn, it, onBars, ICON)
        end
      end
      y = y - (lines * step + 10)
    end
    p.count = n
    -- your own macros that miss big parts of your build's rotation
    local own = {}
    for _, f in ipairs(FP and FP.findings or {}) do
      if not (FP.dismissed and FP.dismissed[f.name]) then own[#own + 1] = f end
    end
    self.findings = own
    local audit = T:Audit()
    self.audit = audit
    self.auditLine:SetText(#audit > 0 and string.format("Macro check: %s: %s, %s.%s", audit[1].name, audit[1].problem, audit[1].fix,
      #audit > 1 and string.format(" (%d more in /ride macrocheck)", #audit - 1) or "") or "")
    local old = T:OldBuild()
    local oldNames = {}
    for i, o in ipairs(old) do if i <= 4 then oldNames[#oldNames + 1] = o.name end end
    self.oldLine:SetText(#old > 0 and string.format("%d macro%s from your old build: %s%s.", #old, #old == 1 and "" or "s",
      table.concat(oldNames, ", "), #old > 4 and "..." or "") or "")
    self.oldBtn:SetShown(#old > 0)
    self.ownLine:SetText(#own > 0 and string.format("Your macro %s misses parts of your build's rotation.", own[1].name) or "")
    self.ownBtn:SetShown(#own > 0)
    if not keepMsg then d.msg:SetText("") end
    if self.own then self:ShowOwn(self.own)
    elseif self.current then self:ShowItem(self.current)
    elseif list[1] then self:ShowItem(keys.btns[1].item)
    elseif tree.pool[1] and tree.pool[1]:IsShown() then self:ShowItem(tree.pool[1].item) end
  end
end, 42)

ns.AddCommand("macrocheck", "your own macros: old spell names and exact copies", function()
  local list = T:Audit()
  if #list == 0 then ns.Print("macro check: nothing to fix") return end
  for i, f in ipairs(list) do if i <= 8 then ns.Print("%s: %s, %s", f.name, f.problem, f.fix) end end
end)
