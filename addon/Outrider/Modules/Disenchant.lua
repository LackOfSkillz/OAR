-- Modules/Disenchant.lua
-- "Disenchant" value on gear tooltips (Gary, 2026-11-22: match Auctionator).
-- What disenchanting a green or blue weapon or armor piece likely gives, at
-- the auction house prices Outrider has seen for those materials.
-- Source: the classic disenchanting tables (Wowpedia, "Disenchanting
-- tables", patch 1.12): item level band -> dust, essence and shard with
-- their odds. verified = false: WoW Forever may have changed them, so the
-- line says "estimate". Weapons swap the dust and essence odds.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Disenchant", {
  title = "Disenchant value on tooltips",
  phase = "P5",
  order = 80,
  defaults = {},
})
ns.Disenchant = M
M.verified = false

-- materials (item ids)
local STRANGE, SOUL, VISION, DREAM, ILLUSION = 10940, 11083, 11137, 11176, 16204
local LMAGIC, GMAGIC, LASTRAL, GASTRAL, LMYSTIC, GMYSTIC = 10938, 10939, 10998, 11082, 11134, 11135
local LNETHER, GNETHER, LETERNAL, GETERNAL = 11174, 11175, 16202, 16203
local SGLIM, LGLIM, SGLOW, LGLOW, SRAD, LRAD, SBRIL, LBRIL, NEXUS = 10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344, 20725

-- uncommon (green) armor: { maxItemLevel, {dust, avg}, {essence, avg}, {shard} , shardChance, essenceChance }
M.GREEN = {
  { 15, { STRANGE, 1.5 }, { LMAGIC, 1.5 }, nil, 0, 0.20 },
  { 20, { STRANGE, 2.5 }, { GMAGIC, 1.5 }, { SGLIM, 1 }, 0.05, 0.20 },
  { 25, { STRANGE, 5 }, { LASTRAL, 1.5 }, { SGLIM, 1 }, 0.10, 0.15 },
  { 30, { SOUL, 1.5 }, { GASTRAL, 1.5 }, { LGLIM, 1 }, 0.05, 0.20 },
  { 35, { SOUL, 3.5 }, { LMYSTIC, 1.5 }, { SGLOW, 1 }, 0.05, 0.20 },
  { 40, { VISION, 1.5 }, { GMYSTIC, 1.5 }, { LGLOW, 1 }, 0.05, 0.20 },
  { 45, { VISION, 3.5 }, { LNETHER, 1.5 }, { SRAD, 1 }, 0.05, 0.20 },
  { 50, { DREAM, 1.5 }, { GNETHER, 1.5 }, { LRAD, 1 }, 0.05, 0.20 },
  { 55, { DREAM, 3.5 }, { LETERNAL, 1.5 }, { SBRIL, 1 }, 0.05, 0.20 },
  { 60, { ILLUSION, 1.5 }, { GETERNAL, 1.5 }, { LBRIL, 1 }, 0.05, 0.20 },
  { 65, { ILLUSION, 3.5 }, { GETERNAL, 2.5 }, { LBRIL, 1 }, 0.05, 0.20 },
}
-- rare (blue): a shard, almost always
M.BLUE = {
  { 25, SGLIM }, { 30, LGLIM }, { 35, SGLOW }, { 40, LGLOW }, { 45, SRAD }, { 50, LRAD }, { 55, SBRIL }, { 65, LBRIL },
}
M.NEXUS = NEXUS

local function priceOf(id)
  local ah = ns.Prices and ns.Prices:Get(id)
  return ah
end

-- { {itemID, chance, avg} } for an item, or nil when it can't be disenchanted here
function M.Outcomes(itemID)
  local info = C.ItemInfo(itemID)
  if not info or not info.ilvl or info.ilvl < 5 then return nil end
  -- C.Call keeps five values; the class is the sixth
  local f = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(f) ~= "function" then return nil end
  local ok, _, _, _, _, _, classID = pcall(f, itemID)
  if not ok then return nil end
  if classID ~= 2 and classID ~= 4 then return nil end
  local ilvl = info.ilvl
  if info.quality == 2 then
    for _, b in ipairs(M.GREEN) do
      if ilvl <= b[1] then
        local ess = classID == 2 and 0.75 or b[6]
        local shard = b[5]
        local dust = 1 - ess - shard
        local out = { { b[2][1], dust, b[2][2] }, { b[3][1], ess, b[3][2] } }
        if b[4] and shard > 0 then out[#out + 1] = { b[4][1], shard, b[4][2] } end
        return out
      end
    end
  elseif info.quality == 3 then
    for _, b in ipairs(M.BLUE) do
      if ilvl <= b[1] then
        local out = { { b[2], ilvl > 55 and 0.995 or 1, 1 } }
        if ilvl > 55 then out[#out + 1] = { NEXUS, 0.005, 1 } end
        return out
      end
    end
  end
  return nil
end

-- The likely value in copper, and whether every material had a price.
function M.Value(itemID)
  local outs = M.Outcomes(itemID)
  if not outs then return nil end
  local total, known, all = 0, 0, true
  for _, o in ipairs(outs) do
    local p = priceOf(o[1])
    if p then total = total + p * o[2] * o[3] known = known + 1 else all = false end
  end
  if known == 0 then return nil end
  return math.floor(total + 0.5), all
end

ns.TooltipLines:Add("item", "disenchant", M, function(_, data)
  local id = data and C.Readable(data.id)
  if type(id) ~= "number" then return nil end
  local v, all = M.Value(id)
  if not v then return nil end
  return { { all and "Disenchant (estimate)" or "Disenchant (estimate, some prices unknown)", "goldText", right = ns.Prices.Coins(v) } }
end)

function M:Activity()
  return "disenchant value on green and blue gear (estimate from auction prices)"
end
