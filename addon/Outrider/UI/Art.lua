-- UI/Art.lua
-- Pictures for the Expedition look (Gary, 2026-11-15). Custom art made by Gary
-- with GPT (docs/ART_REQUESTS.md) lives in Art\ as TGA files; Art\Manifest.lua
-- (written by tools/art.py) says which ones are installed. Anything missing
-- falls back to art that ships with the game, so the page never shows a blank
-- or green square.
--   ns.Art:Path(name)      the custom file, or nil
--   ns.Art:Kind(kind)      picture for a What now? step kind (custom or game icon)
--   ns.Art:Set(tex, name, fallback)  put one on a texture, trimming icon borders

local _, ns = ...
local Art = { name = "art" }
ns.Art = Art

local DIR = "Interface\\AddOns\\Outrider\\Art\\"

-- game art used until the custom pictures arrive
Art.FALLBACK = {
  kind_errand = "Interface\\Icons\\INV_Misc_Bag_08",
  kind_quest = "Interface\\Icons\\INV_Misc_Note_06",
  kind_gear = "Interface\\Icons\\INV_Chest_Chain",
  kind_dungeon = "Interface\\Icons\\INV_Misc_Key_14",
  kind_profession = "Interface\\Icons\\Trade_Alchemy",
  kind_rare = "Interface\\Icons\\Ability_Hunter_SniperShot",
  kind_gold = "Interface\\Icons\\INV_Misc_Coin_02",
  kind_gather = "Interface\\Icons\\INV_Misc_Flower_02",
  emblem = "Interface\\Icons\\INV_Misc_Map_01",
}

function Art:Has(name)
  return type(ns.ArtFiles) == "table" and ns.ArtFiles[name] == true
end

function Art:Path(name)
  if self:Has(name) then return DIR .. name end
  return nil
end

-- (path, isCustom) for a step kind
function Art:Kind(kind)
  local name = "kind_" .. tostring(kind)
  local custom = self:Path(name)
  if custom then return custom, true end
  return self.FALLBACK[name] or self.FALLBACK.kind_quest, false
end

-- Put art on a texture. Game icons get their dark border trimmed.
function Art:Set(tex, name, fallback)
  if not tex then return false end
  local custom = self:Path(name)
  if custom then
    tex:SetTexture(custom)
    if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    return true
  end
  local fb = fallback or self.FALLBACK[name]
  if fb then
    tex:SetTexture(fb)
    if tex.SetTexCoord then tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  end
  return false
end

function Art:SetKind(tex, kind)
  return self:Set(tex, "kind_" .. tostring(kind), self.FALLBACK["kind_" .. tostring(kind)] or self.FALLBACK.kind_quest)
end
