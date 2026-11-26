-- Vanguard/Plan.lua
-- VG03-05/06/07: what would make you (and the group) more ready, ranked.
--   Plan.Actions(prepRows, assessment, opts) -> { actions, advice }
--     actions: things YOU can do (repair, buy food, fill a slot, enchant...)
--     advice:  plain text about the group ("no healer yet"); never an action
--              on another player, never a message or an invite.
--   Plan.Candidates() -> WhatNow-shaped candidates for the Nexus planner, so
--     the plan's validator, budget and evidence rules apply unchanged
--     (Intelligence/Adapters.lua takes them as the "vanguard" producer).
-- Rules:
--   * a cost we don't know is "unknown", never free (costCopper nil); a
--     researched vendor price fills it in, labeled "check the vendor";
--   * a known cost that would eat into your gold reserve (Treasurer) is
--     marked and ranked last, not recommended;
--   * an enchant on a slot you could still replace waits for that decision
--     (prerequisite: the slot first);
--   * ranking: critical first, then how much readiness it adds, then known
--     cheap before unknown, then id (stable).

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local V = ns.Vanguard
local Pl = { VERSION = 1, MAX = 12 }
V.Plan = Pl

local TITLE = {
  repair = "Repair your gear", bags = "Free some bag space (sell or bank)", food = "Buy food", drink = "Buy drink",
  ammo = "Buy ammo", reagent = "Buy reagents", gear = "Fill an empty gear slot", enchant = "Get an enchant",
}
local WEIGHT = { repair = 3, food = 2, drink = 2, ammo = 3, reagent = 1, bags = 1, gear = 2, enchant = 1 }
local KIND = { repair = "errand", bags = "errand", food = "errand", drink = "errand", ammo = "errand", reagent = "errand", gear = "gear", enchant = "gear" }

local function reserveCheck(cost)
  if type(cost) ~= "number" or not (ns.Treasurer and ns.Treasurer.Fits) then return nil end
  local ok, r = pcall(ns.Treasurer.Fits, cost)
  if ok and type(r) == "table" then return r.fits end
end

-- opts: { upgrades = { [slot] = true } } slots the place could upgrade
function Pl.Actions(prep, assessment, opts)
  opts = opts or {}
  local actions, advice = {}, {}
  for _, r in ipairs(prep or {}) do
    if r.state == "missing" and r.action and TITLE[r.action] then
      local a = { id = r.id, kind = KIND[r.action], action = r.action, weight = WEIGHT[r.action] or 1,
        critical = r.action == "repair" or r.action == "ammo", title = TITLE[r.action], why = r.text,
        costCopper = r.costCopper, prerequisites = {}, confidence = "observed", source = "your bags, gear and spellbook" }
      if r.want and r.have then a.title = string.format("%s: %d more", a.title, r.want - r.have) end
      if r.item then a.title = a.title .. " (" .. r.item .. ")" end
      if r.action == "gear" and r.slot then a.title = "Fill your empty " .. (V.Prep.SLOT_NAME[r.slot] or "slot") end
      if r.action == "enchant" and r.slot then
        a.title = "Enchant your " .. (V.Prep.SLOT_NAME[r.slot] or "gear")
        if opts.upgrades and opts.upgrades[r.slot] then
          a.prerequisites[#a.prerequisites + 1] = "decide on the " .. (V.Prep.SLOT_NAME[r.slot] or "slot") .. " upgrade first"
          a.waits = true
        end
      end
      -- a researched vendor price (Data/VanguardFacts.lua): cost = what's missing x price
      local price = r.priceKey and V.Facts and V.Facts.Price(r.priceKey)
      if a.costCopper == nil and price and tonumber(price.copper) and r.want and r.have then
        local per = tonumber(price.per) or 1
        a.costCopper = math.ceil((r.want - r.have) / per) * price.copper
        a.costSource = "vendor price from " .. tostring(price.kind == "forever" and "a Forever source" or "a Classic source") .. "; check the vendor"
      end
      if a.costCopper == nil and (r.action ~= "bags") then a.costUnknown = true end
      if r.action == "bags" then a.costCopper = 0 end
      local fits = reserveCheck(a.costCopper)
      if fits == false then a.overReserve = true end
      actions[#actions + 1] = a
    end
  end
  -- group advice from the assessment (text only)
  for _, r in ipairs(assessment and assessment.results or {}) do
    if r.u == 0 or r.u < 1 then
      if r.category == "role" then advice[#advice + 1] = "Group: " .. r.rule .. " " .. r.text .. " (look for one; nothing is sent for you)"
      elseif r.category == "utility" then advice[#advice + 1] = "Group: " .. r.rule .. ": " .. r.text
      elseif r.category == "level" then advice[#advice + 1] = "Group: " .. r.text
      elseif r.category == "access" then
        actions[#actions + 1] = { id = "access", kind = "errand", action = "access", weight = 3, critical = true,
          title = "Get access first (key or attunement)", why = r.text, costUnknown = true, prerequisites = {}, confidence = "manual",
          source = "your own answer" }
      end
    end
  end
  table.sort(actions, function(a, b)
    local ra = (a.overReserve and 1 or 0) + (a.waits and 1 or 0)
    local rb = (b.overReserve and 1 or 0) + (b.waits and 1 or 0)
    if ra ~= rb then return ra < rb end
    if (a.critical and 1 or 0) ~= (b.critical and 1 or 0) then return a.critical == true end
    if a.weight ~= b.weight then return a.weight > b.weight end
    local ca, cb = a.costUnknown and math.huge or (a.costCopper or 0), b.costUnknown and math.huge or (b.costCopper or 0)
    if ca ~= cb then return ca < cb end
    return a.id < b.id
  end)
  for i = #actions, Pl.MAX + 1, -1 do actions[i] = nil end
  return actions, advice
end

-- for the Nexus planner (only while Group check is on; it's a preview)
function Pl.Candidates()
  local M = ns.VanguardModule
  if not (M and M.IsEnabled and M:IsEnabled()) then return {} end
  local rows = M:PrepRows()
  local acts = Pl.Actions(rows, nil, { upgrades = M:UpgradeSlots() })
  local out = {}
  for _, a in ipairs(acts) do
    if not a.overReserve and not a.waits and a.action ~= "access" then
      out[#out + 1] = { key = "vg:" .. a.id, kind = a.kind, title = a.title, benefit = math.min(1, 0.2 + a.weight * 0.2),
        confidence = 0.8, label = "observed", costCopper = a.costCopper, why = a.why, panel = "vanguard_prep" }
    end
  end
  return out
end
