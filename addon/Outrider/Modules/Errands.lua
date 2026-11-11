-- Modules/Errands.lua  (P8-06 town errand list)
-- When Gary enters a rest area (town or inn, PLAYER_UPDATE_RESTING), works
-- out what this character should do there and shows one toast with the
-- count (at most once per 10 minutes); the Errands hub tab lists them, and
-- clicking a row sets a waypoint to the nearest NPC of that kind (P3-07).
-- Errands: repair (lowest durability under 60%), sell junk (grey items),
-- buy ammo (hunter, under the Ammo module's low mark), visit the trainer
-- (new even level since the last trainer visit; Classic ranks come every
-- 2 levels), AH shopping list items (CraftQueue). Reagents and alt mail
-- handoffs are left for later (no verified reagent data yet).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Errands", {
  title = "Town errand list",
  phase = "P8",
  order = 92,
  defaults = { toast = true, trainedAt = 0, repairBelow = 0.6 },
})
ns.Errands = M

M.QUIET = 600

function M:OnEnable()
  self:On("PLAYER_UPDATE_RESTING", self.OnResting)
  self:On("TRAINER_SHOW", function(mod) mod:Settings().trainedAt = C.Call("UnitLevel", "player") or 0 end)
end

function M.Durability()
  local low
  for slot = 1, 18 do
    local cur, max = C.Call("GetInventoryItemDurability", slot)
    if type(cur) == "number" and type(max) == "number" and max > 0 then
      local f = cur / max
      if not low or f < low then low = f end
    end
  end
  return low
end

-- { {text, kind} } in the order to do them
function M:List()
  local out, s = {}, self:Settings()
  local d = M.Durability()
  if d and d < s.repairBelow then out[#out + 1] = { text = string.format("Repair (gear at %d%%)", math.floor(d * 100)), kind = "repair" } end
  if ns.Merchant then
    local junk, value = ns.Merchant:Junk(), 0
    for _, j in ipairs(junk) do value = value + j.value end
    if #junk > 0 then out[#out + 1] = { text = string.format("Sell %d junk items (%s)", #junk, ns.Prices.Money(value)), kind = "vendor" } end
  end
  local ammo = ns.Modules:Get("Ammo")
  if ns.PlayerClass() == "HUNTER" and ammo and ammo.enabled then
    local n = ammo:Count()
    if n and n < ammo:Settings().low then out[#out + 1] = { text = string.format("Buy ammo (%d left)", n), kind = "vendor" } end
  end
  local level = C.Call("UnitLevel", "player") or 1
  local trainAt = level - level % 2
  if trainAt >= 2 and s.trainedAt < trainAt then out[#out + 1] = { text = "Visit your class trainer (level " .. trainAt .. ")", kind = "trainer" } end
  if ns.CraftQueue then
    local missing = 0
    for _, r in ipairs(ns.CraftQueue:Shopping()) do if r.missing > 0 then missing = missing + 1 end end
    if missing > 0 then out[#out + 1] = { text = string.format("Auction house: %d items on your shopping list", missing), kind = "auction" } end
  end
  return out
end

function M:OnResting()
  if not C.Call("IsResting") or not self:Settings().toast or C.InCombat() then return end
  local now = time()
  if self.toldAt and now - self.toldAt < self.QUIET then return end
  local list = self:List()
  self:Info("errands: %d (%s)", #list, (function() local t = {} for _, e in ipairs(list) do t[#t + 1] = e.kind end return table.concat(t, ",") end)())
  if #list == 0 then return end
  self.toldAt = now
  ns.Toast:Show({ title = #list == 1 and "1 errand in town" or (#list .. " errands in town"), text = list[1].text,
    color = "accent", duration = 15, action = { label = "List", fn = function()
      local f = ns.Hub:Build() f:Show() ns.Hub:ShowTab("errands") end } })
end

function M:Go(e)
  if not ns.Nearest then return end
  local ok, msg = ns.Nearest:Go(e.kind)
  ns.Print(tostring(msg))
  return ok
end

-- P9-01: today's town list
function M:Snapshot()
  local out = {}
  for i, e in ipairs(self:List()) do out[i] = { kind = e.kind, text = e.text } end
  return { errands = out }
end

function M:Activity()
  local n = #self:List()
  return n == 0 and "nothing to do in town" or (n .. " errands for the next town")
end

ns.Hub:AddTab("errands", "Errands", function(p)
  p.head = UI.Text(p, "small", "muted")
  p.head:SetPoint("TOPLEFT", 0, 0)
  p.head:SetText("Things to do in town. Click one for a waypoint to the nearest NPC.")
  p.list = UI:ScrollList(p, {
    rows = 10, rowHeight = 24,
    render = function(row, e) row.text:SetText(e.text) end,
    onClick = function(e) M:Go(e) end,
  })
  p.list:SetPoint("TOPLEFT", p.head, "BOTTOMLEFT", 0, -8)
  p.list:SetWidth(420)
  function p:Refresh() self.list:SetItems(M:List()) end
end, 47)

ns.AddCommand("errands", "what to do in town for this character", function()
  local list = M:List()
  if #list == 0 then ns.Print("no errands") return end
  for i, e in ipairs(list) do ns.Print("%d. %s", i, e.text) end
end)
