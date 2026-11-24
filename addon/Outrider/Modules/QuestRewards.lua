-- Modules/QuestRewards.lua  (P6-04)
-- Quest turn-in with reward choices: names the best choice for this
-- character in a short toast and marks its button (a small glow on the
-- Blizzard reward button; nothing of theirs is replaced). Best = biggest
-- upgrade that is usable now; if none, the highest vendor value. Choosing
-- stays Gary's click.
-- Bags: gear that would be an upgrade gets one toast the first time it is
-- seen this session (out of combat, never in instances).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("QuestRewards", {
  title = "Best quest reward and bag upgrades",
  phase = "P6",
  order = 81,
  defaults = { bagToasts = true, toastedUpgrades = {} },
})
ns.QuestRewards = M

-- Returns index, reason, link for the best reward choice (nil if none).
function M:Best()
  local n = C.Call("GetNumQuestChoices") or 0
  if n < 2 then return nil end
  local bestUp, bestUpPct, bestVal, bestValCopper, bestOnAH
  for i = 1, n do
    local link = C.Call("GetQuestItemLink", "choice", i)
    if link then
      local r = ns.GearScore and ns.GearScore:Compare(link)
      if r and not r.why and r.pct > 0.5 and (not bestUpPct or r.pct > bestUpPct) then bestUp, bestUpPct = i, r.pct end
      local info = C.ItemInfo(link)
      local v = info and info.sellPrice or 0
      -- worth more on the auction house? (gap analysis 2026-11-17)
      local id = tonumber(tostring(link):match("item:(%d+)"))
      local ah = id and ns.Prices and ns.Prices.Get and (ns.Prices:Get(id))
      local onAH = type(ah) == "number" and ah > v
      if onAH then v = ah end
      if not bestValCopper or v > bestValCopper then bestVal, bestValCopper, bestOnAH = i, v, onAH end
    end
  end
  if bestUp then
    return bestUp, string.format("+%d%% upgrade", math.floor(bestUpPct + 0.5)), C.Call("GetQuestItemLink", "choice", bestUp)
  end
  if bestVal then
    return bestVal, "sells for " .. ns.Prices.Money(bestValCopper) .. (bestOnAH and " on the auction house" or ""), C.Call("GetQuestItemLink", "choice", bestVal)
  end
end

function M:Mark(index)
  local frame = rawget(_G, "QuestInfoRewardsFrame")
  local buttons = frame and frame.RewardButtons
  local b = buttons and buttons[index]
  if self.glow then self.glow:Hide() end
  if not b then return end
  if not self.glow then
    self.glow = UIParent:CreateTexture(nil, "OVERLAY")
    self.glow:SetColorTexture(ns.Theme:Color("good"))
    self.glow:SetAlpha(0.35)
  end
  self.glow:ClearAllPoints()
  self.glow:SetAllPoints(b)
  self.glow:Show()
end

function M:OnQuestComplete()
  local i, why, link = self:Best()
  if not i then return end
  self:Mark(i)
  local info = link and C.ItemInfo(link)
  ns.Toast:Show({ title = "Best reward: " .. tostring(info and info.name or ("choice " .. i)), text = why, color = "good", duration = 12 })
  self:Info("quest reward pick %d (%s) %s", i, tostring(info and info.name), why)
end

function M:ScanBags()
  if not self:Settings().bagToasts or C.InCombat() or C.Call("IsInInstance") or not ns.GearScore then return end
  -- Each upgrade is announced once per character, across reloads and logins
  -- (bug 2026-11-18: the same items popped up after every /reload).
  local s = self:Settings()
  if type(s.toastedUpgrades) ~= "table" then ns.KeepBad(s.toastedUpgrades, "QuestRewards:s.toastedUpgrades") s.toastedUpgrades = {} end
  self.toasted = s.toastedUpgrades
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local link = C.ItemLinkAt(bag, slot)
      local id = link and tonumber(link:match("item:(%d+)"))
      if id and not self.toasted[id] then
        local text, color = ns.GearScore:Verdict(link)
        if color == "good" then
          self.toasted[id] = true
          local info = C.ItemInfo(link)
          ns.Toast:Show({ title = "Upgrade in your bags", text = tostring(info and info.name) .. ": " .. text, color = "good", duration = 10 })
          self:Info("bag upgrade %s (%s)", tostring(info and info.name), text)
        end
      end
    end
  end
end

function M:OnEnable()
  self:On("QUEST_COMPLETE", self.OnQuestComplete)
  self:On("QUEST_FINISHED", function(mod) if mod.glow then mod.glow:Hide() end end)
  self:On("BAG_UPDATE_DELAYED", function(mod) ns.Throttle("questrewards:bags", 2, function() mod:ScanBags() end) end)
end

function M:OnDisable() ns.ThrottleCancel("questrewards:bags") if self.glow then self.glow:Hide() end end

function M:Activity() return "picks the best quest reward; toasts upgrades in your bags" end
