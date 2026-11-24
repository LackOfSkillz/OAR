-- Modules/Feedback.lua  (bug reports and ideas; requirement 2026-11-21: a player
-- can create a report or request in the game UI that ends up on our GitHub,
-- simple enough for an 8th-grade reader)
-- WoW lets an addon send nothing to the internet, so Outrider builds the
-- report and a ready-made GitHub link; the player copies it (Ctrl+C), pastes
-- it in a web browser and clicks Submit. Three steps on one page (Help, Report
-- or idea; /ride report):
--   1 pick "Something's broken" or "I have an idea"
--   2 say it in your own words
--   3 Make my report -> copy the link -> paste it in your browser
-- Outrider adds what a fix needs: version and build, game version, the page
-- you were on, class, race, level, zone and the last few Outrider errors.
-- Never your character's name unless you switch that on; never chat, gold,
-- friends or other players. Every report is also kept in your saved data
-- (ns.db.global.feedback, last MAX) so it isn't lost if you close the box.
-- Issues go to the public release repo; its templates add the bug / idea label.

local _, ns = ...
local C = ns.Compat
local UI, Theme = ns.UI, ns.Theme
local M = ns:NewModule("Feedback", {
  title = "Report a problem or an idea",
  phase = "P8",
  order = 90,
  defaults = {},
})
ns.Feedback = M

M.REPO = "https://github.com/LackOfSkillz/outrider-releases"
M.MAX = 20            -- reports kept on your PC
M.URL_MAX = 7000      -- browsers and GitHub take links up to about 8000 characters
M.TEXT_MAX = 1500     -- letters in "tell us more"
M.KINDS = {
  bug = { word = "Something's broken", template = "bug_report.md", prefix = "[Bug] ",
    ask = "What happened? What did you expect? What were you doing when it happened?" },
  idea = { word = "I have an idea", template = "feature_request.md", prefix = "[Idea] ",
    ask = "What would you like Outrider to do? How would it help you?" },
}

function M:OnInitialize()
  local g = ns.db.global
  g.feedback = type(g.feedback) == "table" and g.feedback or {}
end

-- ---------------------------------------------------------------- the report
-- Percent-encode for a link (RFC 3986 unreserved characters stay).
function M.Encode(s)
  return (tostring(s or ""):gsub("\n", "\r\n"):gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- What a fix needs, as { label, value } lines. withName adds name-realm.
function M.Details(withName)
  local out = {}
  local function add(k, v) if v ~= nil and v ~= "" then out[#out + 1] = { k, tostring(v) } end end
  add("Outrider", string.format("%s (build %s)", tostring(ns.version), tostring(ns.build)))
  local ver, build, _, iface = C.Call("GetBuildInfo")
  add("Game", ver and string.format("%s (%s, interface %s)", tostring(ver), tostring(build), tostring(iface)) or nil)
  local level = C.Call("UnitLevel", "player")
  local race = C.Readable(C.Call("UnitRace", "player"))
  local cls = C.Readable(C.Call("UnitClass", "player"))
  add("Character", string.format("level %s %s %s", tostring(level or "?"), tostring(race or ""), tostring(cls or "")):gsub("%s+", " "))
  if withName then
    local name, realm = C.Readable(C.Call("UnitName", "player")), C.Readable(C.Call("GetRealmName"))
    add("Name", name and (name .. (realm and ("-" .. realm) or "")) or nil)
  end
  local mapID, x, y = C.PlayerPosition("player")
  local zone = mapID and ns.Travel and ns.Travel.ZoneName and ns.Travel.ZoneName(mapID) or C.Readable(C.Call("GetZoneText"))
  add("Where", zone and (mapID and x and string.format("%s (map %d, %.1f, %.1f)", tostring(zone), mapID, x * 100, y * 100) or tostring(zone)) or nil)
  add("Page", ns.Hub and ns.Hub.lastPage)
  for _, l in ipairs(ns.LagCheck and ns.LagCheck.ReportLines() or {}) do add(l[1], l[2]) end
  return out
end

-- The last few Outrider errors (newest first), short.
function M.Errors(n)
  local out = {}
  local list = ns.Errors and ns.Errors.list or {}
  for i = #list, 1, -1 do
    local e = list[i]
    -- only Outrider's own (a field report carried a Blizzard chat frame error)
    local mine = type(e) == "table" and ((ns.Modules and ns.Modules.Get and ns.Modules:Get(e.where))
      or tostring(e.msg):find("Outrider", 1, true) or tostring(e.trace or ""):find("Outrider", 1, true))
    if mine then
      out[#out + 1] = string.format("%s: %s%s", tostring(e.where or "?"), tostring(e.msg or "?"), (e.count or 1) > 1 and (" (x" .. e.count .. ")") or "")
      if #out >= (n or 5) then break end
    end
  end
  return out
end

-- The issue text (GitHub markdown).
function M.Body(kind, text, details, errors)
  local K = M.KINDS[kind] or M.KINDS.bug
  local lines = { kind == "idea" and "### The idea" or "### What happened", "", (text ~= "" and text or "(no words given)"), "",
    "### Details (added by Outrider)", "" }
  for _, d in ipairs(details or {}) do lines[#lines + 1] = string.format("- **%s:** %s", d[1], d[2]) end
  if errors and #errors > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "<details><summary>Recent Outrider errors</summary>"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "```"
    for _, e in ipairs(errors) do lines[#lines + 1] = e end
    lines[#lines + 1] = "```"
    lines[#lines + 1] = "</details>"
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "_Sent from Outrider's in-game " .. K.word:lower() .. " form._"
  return table.concat(lines, "\n")
end

-- The link that opens a filled-in GitHub issue. Long text is trimmed so the
-- link stays under URL_MAX (errors first, then the player's words).
function M.Url(kind, title, text, details, errors)
  local K = M.KINDS[kind] or M.KINDS.bug
  local function build(t, e)
    return string.format("%s/issues/new?template=%s&title=%s&body=%s", M.REPO, K.template,
      M.Encode(K.prefix .. title), M.Encode(M.Body(kind, t, details, e)))
  end
  local e = errors or {}
  local url = build(text, e)
  while #url > M.URL_MAX and #e > 0 do
    e = { unpack(e, 1, #e - 1) }
    url = build(text, e)
  end
  local t = text
  while #url > M.URL_MAX and #t > 40 do
    t = t:sub(1, math.floor(#t * 0.8)) .. " [...]"
    url = build(t, e)
  end
  return url
end

-- Builds the report, keeps it on your PC, returns the link (or nil, why).
function M:Make(kind, title, text, withName)
  title = (tostring(title or ""):gsub("^%s+", ""):gsub("%s+$", ""))
  text = (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
  if not M.KINDS[kind] then return nil, "Pick one first: Something's broken or I have an idea." end
  if title == "" and text == "" then return nil, "Write a few words first, so we know what it's about." end
  if title == "" then title = text:sub(1, 60):gsub("\n.*", "") end
  local details = M.Details(withName)
  local errors = kind == "bug" and M.Errors(5) or {}
  local url = M.Url(kind, title, text, details, errors)
  local list = ns.db.global.feedback
  list[#list + 1] = { kind = kind, title = title, text = text, t = time(), url = url }
  while #list > M.MAX do table.remove(list, 1) end
  self:Info("%s report made: %s (%d characters)", kind, title, #url)
  return url
end

function M:Activity()
  local n = #(ns.db.global.feedback or {})
  return n == 0 and "no reports yet: Help, Report or idea" or string.format("%d report%s kept on this PC", n, n == 1 and "" or "s")
end

-- ---------------------------------------------------------------- the page
local function box(parent, w, h, multi, max, hint)
  local frame = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  frame:SetSize(w, h)
  Theme:ApplyPanel(frame, "raised")
  local e = CreateFrame("EditBox", nil, frame)
  e:SetPoint("TOPLEFT", 8, -6)
  e:SetPoint("BOTTOMRIGHT", -8, 6)
  e:SetAutoFocus(false)
  e:SetFontObject("ChatFontNormal")
  if multi then e:SetMultiLine(true) end
  e:SetMaxLetters(max)
  e.hint = UI.Text(frame, "normal", "muted")
  e.hint:SetPoint("TOPLEFT", 10, -8)
  e.hint:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
  e.hint:SetJustifyH("LEFT")
  e.hint:SetText(hint or "")
  e:SetScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if not multi then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
  frame:EnableMouse(true)
  frame:SetScript("OnMouseDown", function() e:SetFocus() end)
  frame.edit = e
  return frame
end

ns.Hub:AddTab("feedback", "Report or idea", function(p)
  p.kind = nil
  local K = M.KINDS
  -- step 1: two big choices
  p.q1 = UI.Display(p, "card", "goldText")
  p.q1:SetPoint("TOPLEFT", 4, -6)
  p.q1:SetText("1.  What do you want to tell us?")
  local function choice(kind, icon)
    local b = UI:Button(p, K[kind].word, 240, function() p.kind = kind p:Refresh() end)
    b:SetHeight(48)
    b.pic = b:CreateTexture(nil, "ARTWORK")
    b.pic:SetSize(32, 32)
    b.pic:SetPoint("LEFT", 10, 0)
    b.pic:SetTexture("Interface\\Icons\\" .. icon)
    return b
  end
  p.bug = choice("bug", "INV_Misc_Bomb_04")
  p.bug:SetPoint("TOPLEFT", p.q1, "BOTTOMLEFT", 0, -10)
  p.idea = choice("idea", "INV_Misc_Note_05")
  p.idea:SetPoint("LEFT", p.bug, "RIGHT", 16, 0)

  -- step 2: your own words
  p.q2 = UI.Display(p, "card", "goldText")
  p.q2:SetPoint("TOPLEFT", p.bug, "BOTTOMLEFT", 0, -22)
  p.q2:SetText("2.  Tell us in your own words")
  p.title = box(p, 600, 30, false, 90, "In a few words: what is it?")
  p.title:SetPoint("TOPLEFT", p.q2, "BOTTOMLEFT", 0, -10)
  p.text = box(p, 600, 150, true, M.TEXT_MAX, "")
  p.text:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -8)
  p.name = UI:Check(p, "Add my character name", function() return p.withName end, function(v) p.withName = v end)
  p.name:SetPoint("TOPLEFT", p.text, "BOTTOMLEFT", 0, -6)
  p.name.note:SetText("off: we only see your class, level and zone")

  -- step 3: make it and send it
  p.q3 = UI.Display(p, "card", "goldText")
  p.q3:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -14)
  p.q3:SetText("3.  Send it")
  p.make = UI:PrimaryButton(p, "Make my report", 200, function()
    local url, why = M:Make(p.kind, p.title.edit:GetText(), p.text.edit:GetText(), p.withName)
    if not url then p.status:SetText("|cffff6060" .. why .. "|r") return end
    p.status:SetText("Copy the link: press |cffffd100Ctrl+C|r in the box that just opened.")
    UI:TextDialog("Your report: copy this link", url, "copy", function()
      p.status:SetText("|cff40ff40Copied!|r  Now open your web browser, click the address bar, press |cffffd100Ctrl+V|r and |cffffd100Enter|r, then click |cffffd100Submit|r on the GitHub page. Thank you!")
      p.title.edit:SetText("")
      p.text.edit:SetText("")
    end)
  end)
  p.make:SetHeight(32)
  p.make:SetPoint("TOPLEFT", p.q3, "BOTTOMLEFT", 0, -10)
  p.status = UI.Text(p, "normal", "text")
  p.status:SetPoint("LEFT", p.make, "RIGHT", 14, 0)
  p.status:SetPoint("RIGHT", p, "RIGHT", -10, 0)
  p.status:SetJustifyH("LEFT")
  -- Laggy? A one-minute lag check (LagCheck); its result goes into the report.
  p.lagHead = UI.Display(p, "card", "goldText")
  p.lagHead:SetPoint("TOPLEFT", p.make, "BOTTOMLEFT", 0, -22)
  p.lagHead:SetText("Game feels slow? Check if it's Outrider")
  p.lagBtn = UI:Button(p, "Check for lag (1 minute)", 220, function()
    if ns.LagCheck.on then ns.LagCheck:Stop("stopped") else ns.LagCheck:Start() end
    p:Refresh()
  end)
  p.lagBtn:SetPoint("TOPLEFT", p.lagHead, "BOTTOMLEFT", 0, -8)
  p.lagText = UI.Text(p, "normal", "text")
  p.lagText:SetPoint("TOPLEFT", p.lagBtn, "BOTTOMLEFT", 0, -8)
  p.lagText:SetPoint("RIGHT", p, "RIGHT", -10, 0)
  p.lagText:SetJustifyH("LEFT")
  p.lagOff = {}
  for i = 1, 3 do
    local b = UI:Button(p, "Turn off", 200, function(self) if self.part then ns.Modules:SetEnabled(self.part, false) ns.Print("%s is off (Settings, Modules turns it back on)", self.part) p:Refresh() end end)
    b:SetPoint("TOPLEFT", p.lagText, "BOTTOMLEFT", (i - 1) * 210, -8)
    b:Hide()
    p.lagOff[i] = b
  end
  ns.Events:On("OTR_LAGCHECK", { name = "FeedbackPage" }, function() if p:IsShown() then p:Refresh() end end)

  p.note = UI.Text(p, "small", "muted")
  p.note:SetPoint("TOPLEFT", p.lagOff[1], "BOTTOMLEFT", 0, -16)
  p.note:SetPoint("RIGHT", p, "RIGHT", -10, 0)
  p.note:SetJustifyH("LEFT")
  p.note:SetText("The game can't send anything to the internet, so you post it yourself: it opens a page on GitHub with everything filled in (a free GitHub account is needed). "
    .. "We read every report. Your report is also kept in Outrider on this PC.")

  function p:Refresh()
    UI.SetPrimary(self.bug, self.kind == "bug")
    UI.SetPrimary(self.idea, self.kind == "idea")
    -- lag check
    local L = ns.LagCheck
    if L then
      self.lagBtn.label:SetText(L.on and "Stop the check" or "Check for lag (1 minute)")
      local r = ns.db.global.lagCheck
      self.lagText:SetText(L.on and ("Checking: play as usual for a minute (move, fight, open the map). " .. L:Activity() .. ".")
        or (r and L.Verdict(r) .. (r.parts and r.parts[1] and "  It goes into your next report." or "")
          or "Press it, then play as usual for one minute. Outrider measures how much of your game's time it uses."))
      for i, b in ipairs(self.lagOff) do
        local part = not L.on and r and r.level ~= "fine" and r.parts and r.parts[i]
        local mod = part and ns.Modules:Get(part.name)
        if mod and mod.enabled then b.part = part.name b.label:SetText("Turn off " .. (mod.spec and mod.spec.title or part.name)) b:Show()
        else b.part = nil b:Hide() end
      end
    end
    local k = self.kind and K[self.kind]
    self.text.edit.hint:SetText(k and k.ask or "Pick one above first.")
    -- the button always answers (bug 2026-11-21: a switched-off button
    -- still looked gold and "nothing happened"): with no choice it says so
    if self.kind and self.status:GetText() and self.status:GetText():find("Pick one", 1, true) then self.status:SetText("") end
  end
end, 62.5)

ns.AddCommand("report", "  report a problem or an idea (opens Help, Report or idea)", function()
  if ns.Hub then ns.Hub:Build():Show() ns.Hub:ShowTab("feedback") end
end)
