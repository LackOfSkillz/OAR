-- Modules/LootRolls.lua
-- Need / Greed advice for group loot rolls (dungeon module, phase 3; built
-- 2026-11-15 while Gary was out). When a roll starts, Outrider works out:
--   Need   the item is a usable upgrade for you (and you may Need it)
--   Greed  for an alt: no use to you, but an upgrade for one of your
--          characters and it can be mailed (not bind on pickup)
--   Greed  otherwise, when you can Greed
--   Pass   when you can't use it and nobody of yours wants it
-- The advice shows on the item's tooltip while the roll is open, and each roll
-- is logged so the advice can be checked later. It never rolls: the Need /
-- Greed / Pass buttons stay Gary's clicks (hard rule 1).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("LootRolls", {
  title = "Loot roll advice (Need / Greed)",
  phase = "P6",
  order = 66,
  defaults = { minPct = 3 },
})
ns.LootRolls = M

function M:OnInitialize()
  self.rolls = {}
end

local function itemID(link)
  return tonumber(type(link) == "string" and link:match("item:(%d+)") or nil)
end

-- info = { link, bop, canNeed, canGreed }; returns roll, reason, color
function M:Advice(info)
  local link = info.link
  if not link then return nil end
  local G = ns.GearScore
  local r = G and G.Compare and G:Compare(link)
  local minPct = self:Settings().minPct or 3
  if r and not r.why and (r.pct or 0) >= minPct then
    if info.canNeed ~= false then
      return "Need", string.format("upgrade for you (+%d%%)", math.floor(r.pct + 0.5)), "good"
    end
  end
  local id = itemID(link)
  if id and not info.bop and ns.KitShare and ns.KitShare.BestFor then
    local ok, best = pcall(ns.KitShare.BestFor, ns.KitShare, id)
    if ok and best and best.tier == "alt" then
      return "Greed", string.format("for %s (+%d%%), mail it after", tostring(best.name):match("^[^-]+") or best.name,
        math.floor((best.pct or 0) + 0.5)), "accent"
    end
  end
  if info.canGreed ~= false then return "Greed", "not an upgrade for you; sell it", "muted" end
  return "Pass", "no use to you or your characters", "muted"
end

function M:OnStart(_, rollID)
  if not rollID then return end
  local link = C.Call("GetLootRollItemLink", rollID)
  if not link then return end
  local _, name, _, quality, bop, canNeed, canGreed = C.Call("GetLootRollItemInfo", rollID)
  local info = { link = link, bop = bop and true or false, canNeed = canNeed, canGreed = canGreed }
  local roll, why, color = self:Advice(info)
  if not roll then return end
  info.roll, info.why, info.color, info.id = roll, why, color, itemID(link)
  self.rolls[rollID] = info
  self:Info("loot roll %s: %s q%s bop=%s -> %s (%s)", tostring(rollID), tostring(name or link), tostring(quality),
    tostring(info.bop), roll, why)
end

function M:OnEnd(_, rollID)
  if rollID then self.rolls[rollID] = nil else self.rolls = {} end
end

-- the open roll for this item, if any
function M:ForLink(link)
  local id = itemID(link)
  if not id then return nil end
  for _, info in pairs(self.rolls) do if info.id == id then return info end end
  return nil
end

function M:OnEnable()
  self:On("START_LOOT_ROLL", self.OnStart)
  self:On("CANCEL_LOOT_ROLL", self.OnEnd)
  self:On("LOOT_ROLLS_COMPLETE", function(mod) mod:OnEnd(nil) end)
end

function M:Activity()
  local n = 0
  for _ in pairs(self.rolls) do n = n + 1 end
  return n > 0 and string.format("%d roll%s open", n, n == 1 and "" or "s") or "advice on group loot rolls"
end

ns.TooltipLines:Add("item", "roll", M, function(tip)
  if not tip.GetItem then return nil end
  local _, link = tip:GetItem()
  local info = link and M:ForLink(link)
  if not info then return nil end
  return { { string.format("Roll: %s (%s)", info.roll, info.why), info.color } }
end)
