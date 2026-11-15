-- Modules/Advisor.lua  (P9-02 /ride ask and the Advisor tab)
-- /ride ask (out of combat): takes a fresh snapshot and shows it as a code
-- to copy (Ctrl+C); Claude answers with an advice code that Gary pastes with
-- the tab's "Paste advice" button. No reload (Gary, 2026-11-11). The older
-- disk route stays: /ride ask reload, then Advice.lua after a /reload.
-- Advisor hub tab: the items ns.Advice:Load() accepted (whitelisted actions
-- only), each with title, why, confidence and a "Do it" button. Buttons only
-- do harmless, non-protected things:
--   waypoint    -> Outrider waypoint
--   track_quest -> add the quest to the objective tracker
--   open_panel  -> open a hub tab
--   show_item   -> show the item's tooltip
-- When there is no advice the tab says why (no file, stale, other character).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Advisor", {
  title = "Advisor (suggestions from your companion app)",
  phase = "P9",
  order = 100,
  defaults = {},
})
ns.Advisor = M

M.PANEL_TAB = { hub = "overview", rares = "rares", pet = "pet", macros = "macros", gear = "gear",
  professions = "crafting", map = "map" }

function M:Items()
  local items, why, answer = ns.Advice:Load()
  self.reason, self.answer = why, answer
  return items, why, answer
end

-- Performs one cleaned advice item; returns ok, message.
function M:Perform(item)
  if type(item) ~= "table" or not ns.Advice.ALLOWED[item.action] then return false, "not allowed" end
  local a = item.args or {}
  if item.action == "waypoint" then
    ns.Waypoints:Set(a.mapID, a.x, a.y, item.title)
    return true, "waypoint set"
  elseif item.action == "track_quest" then
    if C.InCombat() then return false, "not in combat" end
    local ok = pcall(C_QuestLog.AddQuestWatch, a.questID)
    return ok, ok and "quest tracked" or "could not track that quest"
  elseif item.action == "open_panel" then
    local tab = M.PANEL_TAB[a.panel]
    if not tab then return false, "unknown panel" end
    ns.Hub:Build():Show()
    ns.Hub:ShowTab(tab)
    return true, "opened " .. a.panel
  elseif item.action == "show_item" then
    local tip = rawget(_G, "ItemRefTooltip")
    if not tip then return false, "no item window" end
    pcall(ShowUIPanel, tip)
    local ok = pcall(tip.SetHyperlink, tip, "item:" .. a.itemID)
    return ok, ok and "item shown" or "item not cached yet"
  end
  return false, "not allowed"
end

M.REASON_TEXT = {
  ["no advice file"] = "No advice yet. Click Ask, press Ctrl+C, tell Claude 'advise', then Paste advice.",
  ["advice is stale"] = "The advice answers an older snapshot. Click Ask again.",
  ["advice is for another character"] = "That advice is for another character.",
  ["wrong schema"] = "The advice file is from another version and was ignored.",
}

function M:Activity()
  local items, why = self:Items()
  if #items > 0 then return #items .. " suggestions in the Advisor tab" end
  return M.REASON_TEXT[why] or tostring(why)
end

ns.Hub:AddTab("advisor", "Advisor", function(p)
  -- the answer (schema 2): headline, summary and what it couldn't check
  p.answer = UI:Card(p, true)
  p.answer:SetPoint("TOPLEFT", 0, 0)
  p.answer:SetSize(560, 112)
  p.answer.headline = UI.Display(p.answer, "card", "text")
  p.answer.headline:SetPoint("TOPLEFT", 12, -10)
  p.answer.headline:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.summary = UI.Text(p.answer, "normal", "body")
  p.answer.summary:SetPoint("TOPLEFT", 12, -34)
  p.answer.summary:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.summary:SetJustifyH("LEFT") p.answer.summary:SetJustifyV("TOP")
  p.answer.summary:SetHeight(44)
  p.answer.limits = UI.Text(p.answer, "small", "muted")
  p.answer.limits:SetPoint("TOPLEFT", 12, -82)
  p.answer.limits:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.limits:SetJustifyH("LEFT")
  p.head = UI.Text(p, "small", "muted")
  p.head:SetPoint("TOPLEFT", p.answer, "BOTTOMLEFT", 0, -8)
  p.head:SetWidth(560) p.head:SetJustifyH("LEFT")
  p.list = UI:ScrollList(p, {
    rows = 8, rowHeight = 40,
    render = function(row, item)
      row.text:SetText(item.title .. "  |cff888888(" .. item.confidence .. ")|r\n|cffbbbbbb" .. item.why .. "|r")
    end,
    onClick = function(item)
      local ok, msg = M:Perform(item)
      M:Info("advice '%s' -> %s", item.title, tostring(msg))
      p.head:SetText((ok and "" or "|cffff6060") .. tostring(msg))
    end,
  })
  p.list:SetPoint("TOPLEFT", p.head, "BOTTOMLEFT", 0, -8)
  p.list:SetWidth(560)
  p.paste = UI:Button(p, "Paste advice", 120, function()
    UI:TextDialog("Paste advice", "", "paste", function(text)
      local n, why = ns.Advice:Paste(text)
      if n == 0 then return false, M.REASON_TEXT[why] or why end
      M:Info("pasted advice: %d suggestions", n)
      p:Refresh()
      return true
    end)
  end)
  p.paste:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -8)
  p.ask = UI:Button(p, "Ask (copy snapshot)", 150, function() ns.Snapshot:AskAdvisor() end)
  p.ask:SetPoint("LEFT", p.paste, "RIGHT", 8, 0)
  function p:Refresh()
    local items, why, answer = M:Items()
    if answer then
      self.answer:Show()
      self.answer.headline:SetText(answer.headline or "")
      self.answer.summary:SetText(answer.summary or "")
      local lim = table.concat(answer.limits or {}, "  |  ")
      self.answer.limits:SetText(lim ~= "" and ("Not checked: " .. lim) or "")
      self.head:ClearAllPoints()
      self.head:SetPoint("TOPLEFT", self.answer, "BOTTOMLEFT", 0, -8)
    else
      self.answer:Hide()
      self.head:ClearAllPoints()
      self.head:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    end
    self.list:SetItems(items)
    self.head:SetText(#items > 0 and "Click a suggestion to do it. Nothing happens on its own."
      or (M.REASON_TEXT[why] or tostring(why)))
  end
end, 50)

ns.AddCommand("ask", "[reload]  snapshot for your advisor: shows a code to copy (or 'reload' to save it to disk)", function(arg)
  if C.InCombat() then ns.Print("not in combat") return end
  ns.Snapshot:AskAdvisor(arg == "reload" and "reload" or nil)
end)
