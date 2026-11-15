-- Modules/Professions.lua  (P5-02)
-- When a profession window opens, record per character:
--   ns.db.char.professions[name] = { skill, max, at, recipes = { [recipeID] =
--     { name, learned, reagents = { [itemID] = count } } } }
-- Modern C_TradeSkillUI first (GetAllRecipeIDs is present on Forever, probe
-- 2026-11-11), Classic GetTradeSkillInfo as fallback. Everything in pcall;
-- the first scan logs its shape so Claude can confirm the API (auto-collected).
-- Learned recipes also feed the account-wide "recipe" knowledge for planners.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Professions", {
  title = "Professions and recipes",
  phase = "P5",
  order = 71,
  defaults = {},
})
ns.Professions = M

function M:OnEnable()
  self:On("TRADE_SKILL_SHOW", function(mod) ns.Timer.After(0.5, function() mod:Scan("show") end, "prof:scan") end)
  self:On("TRADE_SKILL_LIST_UPDATE", function(mod) ns.Throttle("prof:update", 2, function() mod:Scan("update") end) end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:ScanSkills() end)
  self:On("SKILL_LINES_CHANGED", function(mod) mod:ScanSkills() end)
end

function M:Store()
  local c = ns.db.char
  c.professions = type(c.professions) == "table" and c.professions or {}
  c.professions[""] = nil
  return c.professions
end

-- Skill levels for every profession, from the character's skill list.
function M:ScanSkills()
  local get, info = rawget(_G, "GetProfessions"), rawget(_G, "GetProfessionInfo")
  if type(get) ~= "function" or type(info) ~= "function" then return end
  local ok, a, b, c, d, e = pcall(get)
  if not ok then return end
  local store = self:Store()
  for _, idx in ipairs({ a, b, c, d, e }) do
    if idx then
      local ok2, name, _, skill, max = pcall(info, idx)
      if ok2 and type(name) == "string" then
        local p = store[name] or { recipes = {} }
        p.skill, p.max = C.Readable(skill), C.Readable(max)
        store[name] = p
      end
    end
  end
end

local function reagentsModern(recipeID)
  -- also used by Crafter to say what is missing
  local schem = C.Call("C_TradeSkillUI.GetRecipeSchematic", recipeID, false)
  if type(schem) ~= "table" or type(schem.reagentSlotSchematics) ~= "table" then return nil end
  local out = {}
  for _, slot in ipairs(schem.reagentSlotSchematics) do
    local r = slot.reagents and slot.reagents[1]
    if r and r.itemID then out[r.itemID] = (out[r.itemID] or 0) + (slot.quantityRequired or 1) end
  end
  return out
end

-- The open profession window's name. Forever sometimes gives an empty
-- professionName on one of the two infos (Alchemy was once stored under "",
-- and the training button kept reopening the window, 2026-11-14), so take
-- the first non-empty name from either.
function M.OpenName()
  local base = C.Call("C_TradeSkillUI.GetBaseProfessionInfo")
  local line = C.Call("C_TradeSkillUI.GetProfessionInfo")
  for _, info in ipairs({ base, line }) do
    if type(info) == "table" then
      for _, k in ipairs({ "professionName", "parentProfessionName" }) do
        local v = C.Readable(info[k])
        if type(v) == "string" and v ~= "" then return v end
      end
    end
  end
  return nil
end

function M:ScanModern()
  local ids = C.Call("C_TradeSkillUI.GetAllRecipeIDs")
  if type(ids) ~= "table" or #ids == 0 then return nil end
  local base = C.Call("C_TradeSkillUI.GetBaseProfessionInfo")
  local line = C.Call("C_TradeSkillUI.GetProfessionInfo") or base
  local name = M.OpenName()
  local recipes = {}
  for _, id in ipairs(ids) do
    local info = C.Call("C_TradeSkillUI.GetRecipeInfo", id)
    if type(info) == "table" and info.learned ~= false then
      -- diff: the client's color, 0 orange, 1 yellow, 2 green, 3 grey (relativeDifficulty)
      local product, makes = M.Output(id)
      recipes[id] = { name = C.Readable(info.name), learned = info.learned ~= false, reagents = reagentsModern(id),
        diff = C.Readable(info.relativeDifficulty), skillUps = C.Readable(info.numSkillUps), product = product, makes = makes }
    end
  end
  M.lastLine = type(base) == "table" and C.Readable(base.professionID) or nil
  local skill = type(base) == "table" and base.skillLevel or nil
  local max = type(base) == "table" and base.maxSkillLevel or nil
  return name, recipes, skill, max
end

M.Reagents = reagentsModern

-- What a recipe makes: itemID, how many (nil when the client doesn't say).
function M.Output(recipeID)
  local schem = C.Call("C_TradeSkillUI.GetRecipeSchematic", recipeID, false)
  if type(schem) ~= "table" then return nil end
  local id = C.Readable(schem.outputItemID)
  if type(id) ~= "number" or id <= 0 then return nil end
  local n = C.Readable(schem.quantityMin)
  return id, type(n) == "number" and n > 0 and n or 1
end

function M:ScanClassic()
  local n = C.Call("GetNumTradeSkills")
  if not n or n == 0 then return nil end
  local name, skill, max = C.Call("GetTradeSkillLine")
  local recipes = {}
  for i = 1, n do
    local rname, kind = C.Call("GetTradeSkillInfo", i)
    if rname and kind ~= "header" then
      local reagents = {}
      for r = 1, (C.Call("GetTradeSkillNumReagents", i) or 0) do
        local link = C.Call("GetTradeSkillReagentItemLink", i, r)
        local id = link and tonumber(link:match("item:(%d+)"))
        local _, _, count = C.Call("GetTradeSkillReagentInfo", i, r)
        if id then reagents[id] = count or 1 end
      end
      recipes["c" .. i .. ":" .. rname] = { name = rname, learned = true, reagents = reagents }
    end
  end
  return name, recipes, skill, max
end

function M:Scan(why)
  local ok, name, recipes, skill, max = pcall(self.ScanModern, self)
  local how = "C_TradeSkillUI"
  if not ok or not name then
    ok, name, recipes, skill, max = pcall(self.ScanClassic, self)
    how = "classic"
  end
  -- a window read with no profession name once stored Alchemy under "" (2026-11-14)
  if name == "" then name = nil end
  if not ok or not name or not recipes then
    if why == "show" then self:Warn("profession window opened but no recipes could be read") end
    return
  end
  local store = self:Store()
  local p = store[name] or {}
  p.recipes, p.at = recipes, time()
  p.skill, p.max = skill or p.skill, max or p.max
  if how == "C_TradeSkillUI" and type(M.lastLine) == "number" then p.line = M.lastLine end
  store[name] = p
  local n, withReagents = 0, 0
  for _, r in pairs(recipes) do n = n + 1 if r.reagents and next(r.reagents) then withReagents = withReagents + 1 end end
  if why == "show" or n ~= self.lastCount then
    self.lastCount = n
    self:Info("profession %s %s/%s: %d recipes (%d with reagents) via %s", tostring(name), tostring(p.skill),
      tostring(p.max), n, withReagents, how)
  end
end

-- P9-01: skill per profession (recipes stay out: too big for the advisor)
function M:Snapshot()
  local out = {}
  for name, p in pairs(ns.db.char.professions or {}) do
    local n = 0
    for _ in pairs(p.recipes or {}) do n = n + 1 end
    out[name] = { skill = p.skill, max = p.max, recipes = n }
  end
  return out
end

function M:Activity()
  local parts = {}
  for name, p in pairs(self:Store()) do
    local n = 0
    for _ in pairs(p.recipes or {}) do n = n + 1 end
    parts[#parts + 1] = string.format("%s %s/%s (%d recipes)", name, tostring(p.skill or "?"), tostring(p.max or "?"), n)
  end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, ", ") or "open a profession window to record it"
end
