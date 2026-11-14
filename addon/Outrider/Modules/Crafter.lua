-- Modules/Crafter.lua
-- One-press profession macros (Gary, 2026-11-12): "Cook", "Brew", "Herb".
-- Each press of the macro runs "/ride make <Profession>", which:
--   * opens that profession's window if it isn't open (press again to make);
--   * picks the learned recipe you have every reagent for, best skill-up
--     colour first (orange, yellow, green, then grey), and makes as many as
--     your bags allow: the same as Blizzard's "Create All" button.
-- One craft request per press, only from Gary's press (hard rule 1); nothing
-- on a timer or an event. A refusal (no cooking fire nearby, bags full) is
-- logged from UI_ERROR_MESSAGE so a test needs only plain play.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Crafter", {
  title = "One-press profession macros",
  phase = "P5",
  order = 73,
  defaults = {},
})
ns.Crafter = M

M.MACROS = {
  { prof = "Cooking", name = "Cook", explain = "Stand by a fire and press: cooks what you have ingredients for, best skill-up first." },
  { prof = "Alchemy", name = "Brew", explain = "Press: brews what you have herbs and vials for, best skill-up first." },
  -- Herbalism only gathers on Forever (196 gathering entries, nothing to make,
  -- 2026-11-12), so its button turns on Find Herbs instead ("!" never turns it off).
  { prof = "Herbalism", name = "Herb", body = "#showtooltip Find Herbs\n/cast !Find Herbs",
    explain = "Press: turns on Find Herbs so herbs show on the minimap (never turns it off)." },
}

-- Professions this character has: name -> skillLine (from GetProfessions; no IDs typed in by hand).
function M:Owned()
  local out = {}
  local get, info = rawget(_G, "GetProfessions"), rawget(_G, "GetProfessionInfo")
  if type(get) ~= "function" or type(info) ~= "function" then return out end
  local ok, a, b, c, d, e = pcall(get)
  if not ok then return out end
  for _, idx in ipairs({ a, b, c, d, e }) do
    local ok2, name, _, _, _, _, _, line = pcall(info, idx)
    if ok2 and type(name) == "string" then out[name] = line or true end
  end
  -- Forever leaves Cooking out of GetProfessions (2026-11-12): also count any
  -- profession whose window was opened (Professions records it with its line).
  for name, p in pairs(ns.db.char.professions or {}) do
    if out[name] == nil and type(p) == "table" and (p.skill or next(p.recipes or {})) then out[name] = p.line or true end
  end
  return out
end

function M:Entry(def)
  return { id = "craft-" .. def.prof:lower(), name = def.name, class = "ALL", scope = "char", tags = { "profession" },
    body = def.body or ("#showtooltip " .. def.prof .. "\n/ride make " .. def.prof), explain = def.explain }
end

-- Library entries for the professions this character has.
function M:Entries()
  local owned, out = self:Owned(), {}
  for _, def in ipairs(M.MACROS) do
    if owned[def.prof] then out[#out + 1] = self:Entry(def) end
  end
  return out
end

-- Is the profession window open and loaded for this profession?
function M:OpenFor(prof)
  if not (C.Call("C_TradeSkillUI.IsTradeSkillReady") or self.windowOpen) then return false end
  local name = ns.Professions and ns.Professions.OpenName and ns.Professions.OpenName()
  if name then return name == prof end
  -- no name at all: trust the window if one of its recipes is one we stored for prof
  local p = ns.db.char.professions and ns.db.char.professions[prof]
  local ids = C.Call("C_TradeSkillUI.GetAllRecipeIDs")
  if type(p) == "table" and type(p.recipes) == "table" and type(ids) == "table" then
    for _, id in ipairs(ids) do if p.recipes[id] then return true end end
  end
  return false
end

local SKIP = { isRecraft = true, isSalvageRecipe = true, isGatheringRecipe = true, isDummyRecipe = true }

-- The best recipe to make now: returns recipeID, name, count, colour (0 orange .. 3 grey), or nil.
function M:Pick()
  local ids = C.Call("C_TradeSkillUI.GetAllRecipeIDs")
  if type(ids) ~= "table" then return nil end
  local best, closest
  local craftable = 0
  for _, id in ipairs(ids) do
    local info = C.Call("C_TradeSkillUI.GetRecipeInfo", id)
    if type(info) == "table" and not self.shapeLogged then
      self.shapeLogged = true
      local keys = {}
      for k in pairs(info) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      self:Debug("recipe info fields: %s", table.concat(keys, ","))
    end
    local skip = type(info) ~= "table" or info.learned == false or info.craftable == false
    if not skip then for k in pairs(SKIP) do if info[k] then skip = true end end end
    local n = not skip and self:Count(id, info) or 0
    if not skip then
      craftable = craftable + 1
      local diff = tonumber(C.Readable(info.relativeDifficulty)) or 2
      if n == 0 and (not closest or diff < closest.diff) then
        closest = { id = id, name = C.Readable(info.name) or tostring(id), diff = diff }
      end
    end
    if n > 0 and self.trainOnly and (tonumber(C.Readable(info.relativeDifficulty)) or 2) >= 3 then n = 0 end
    if self.onlyRecipe then
      if C.Readable(info and info.name) ~= self.onlyRecipe then n = 0 else n = math.min(n, 1) end
    elseif n > 0 and C.Readable(info and info.name) == "Basic Campfire" then
      n = 0 -- never burn wood while cooking; the fire has its own step
    end
    if n > 0 then
      local diff = tonumber(C.Readable(info.relativeDifficulty)) or 2
      if not best or diff < best.diff or (diff == best.diff and n > best.n) then
        best = { id = id, name = C.Readable(info.name) or tostring(id), n = n, diff = diff }
      end
    end
  end
  self.craftable, self.closest = craftable, closest
  if best then return best.id, best.name, best.n, best.diff end
end

function M.Have(itemID)
  local n = C.Call("C_Item.GetItemCount", itemID)
  if n == nil then n = C.Call("GetItemCount", itemID) end
  return tonumber(C.Readable(n)) or 0
end

-- "Empty Vial x1 (you have 0), Peacebloom x2 (you have 1)" for a recipe.
function M:Missing(recipeID)
  local reagents = ns.Professions and ns.Professions.Reagents and ns.Professions.Reagents(recipeID)
  if type(reagents) ~= "table" then return nil end
  local parts = {}
  for itemID, need in pairs(reagents) do
    local got = M.Have(itemID)
    if got < need then
      local info = C.ItemInfo(itemID)
      parts[#parts + 1] = string.format("%s x%d (you have %d)", info and info.name or ("item " .. itemID), need, got)
    end
  end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, ", ") or nil
end

-- How many we can make now. Forever's recipe info has no numAvailable
-- (fields measured 2026-11-12), so ask GetCraftableCount, else count the bags.
function M:Count(id, info)
  local n = tonumber(C.Readable(info and info.numAvailable))
  if n then return n end
  n = tonumber(C.Readable(C.Call("C_TradeSkillUI.GetCraftableCount", id)))
  if n then return n end
  local reagents = ns.Professions and ns.Professions.Reagents and ns.Professions.Reagents(id)
  if type(reagents) ~= "table" or not next(reagents) then return 0 end
  local fit
  for itemID, need in pairs(reagents) do
    local k = math.floor(M.Have(itemID) / math.max(need, 1))
    fit = fit and math.min(fit, k) or k
  end
  return fit or 0
end

local COLOURS = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }

-- One press of a profession macro.
function M:Make(prof)
  if C.InCombat() then ns.Print("%s: not in combat", prof) return "combat" end
  if C.Call("UnitCastingInfo", "player") then return "busy" end -- still making the last batch
  local owned = self:Owned()
  if not owned[prof] then ns.Print("you don't have %s", prof) return "unknown" end
  if not self:OpenFor(prof) then
    local line = owned[prof]
    local canOpen = type(line) == "number" and C_TradeSkillUI and type(C_TradeSkillUI.OpenTradeSkill) == "function"
    if canOpen then pcall(C_TradeSkillUI.OpenTradeSkill, line) end
    do
      if canOpen then
        ns.Print("%s window opened: press again to make", prof)
      else
        ns.Print("open %s once from your spellbook, then press again", prof)
      end
      self:Info("make %s: window was closed (%s)", prof, canOpen and "opened it" or "can't open it from code")
      return "opened"
    end
  end
  -- never stack up campfires (Gary, 2026-11-14): one already in the bags is placed instead
  if self.onlyRecipe == "Basic Campfire" and ns.ProfTrainer and ns.ProfTrainer:FireItem() then
    ns.Print("you already have a campfire in your bags: the next click places it")
    self:Info("make %s: campfire already in the bags, not making another", prof)
    if ns.ProfTrainer.Evaluate then ns.ProfTrainer.body = nil ns.ProfTrainer:Evaluate() end
    return "have"
  end
  local id, name, n, diff = self:Pick()
  if not id then
    local ids = C.Call("C_TradeSkillUI.GetAllRecipeIDs")
    local total = type(ids) == "table" and #ids or 0
    if (self.craftable or 0) == 0 then
      ns.Print("%s has no recipes to make%s", prof, total > 0 and " (it only gathers)" or "")
      self:Info("make %s: no recipes to make (%d entries, none craftable)", prof, total)
      return "nothing"
    end
    local c = self.closest
    local missing = c and self:Missing(c.id)
    if c and missing then
      ns.Print("%s: nothing to make yet. %s needs %s", prof, c.name, missing)
    else
      ns.Print("%s: nothing you have every ingredient for", prof)
    end
    self:Info("make %s: nothing to make (%d recipes); closest %s needs %s", prof, self.craftable, c and c.name or "-",
      tostring(missing))
    return "nothing"
  end
  local ok = pcall(C_TradeSkillUI.CraftRecipe, id, n)
  self.lastCraft = { t = C.Call("GetTime") or 0, prof = prof, name = name }
  self:Info("make %s: %d x %s (%s)%s", prof, n, name, COLOURS[diff] or tostring(diff), ok and "" or " - CraftRecipe failed")
  ns.Print("%s: making %d x %s", prof, n, name)
  return ok and "made" or "failed"
end

-- Why the game refused (no fire nearby, bags full...), within 3 s of a press.
function M:OnUIError(_, _, message)
  local last = self.lastCraft
  local msg = C.Readable(message)
  if not last or type(msg) ~= "string" then return end
  if (C.Call("GetTime") or 0) - last.t > 3 then self.lastCraft = nil return end
  self:Info("make %s refused: %s (%s)", last.prof, msg, last.name)
  self.lastCraft = nil
end

-- A craft macro Outrider made whose text changed in a new build gets the new
-- text at login, unless Gary edited it himself (his text then differs from
-- what Outrider wrote, and it is left alone).
function M:Refresh()
  local lib = ns.MacroLibrary
  if not lib then return end
  ns.Combat:Run("Crafter", function()
    local installed = lib:Settings().installed
    for _, e in ipairs(self:Entries()) do
      local rec = installed[e.name]
      local index = rec and C.Call("GetMacroIndexByName", e.name) or 0
      if rec and index > 0 then
        local _, _, body = C.Call("GetMacroInfo", index)
        if ns.MacroEngine.Same(body, rec.body) and not ns.MacroEngine.Same(rec.body, e.body) then
          local ok = lib:Install(e)
          self:Info("%s macro updated to the new text: %s", e.name, tostring(ok))
        end
      end
    end
  end, "crafter:refresh")
end

function M:OnEnable()
  -- Forever's IsTradeSkillReady kept saying no with the window open (the
  -- training button reopened Alchemy on every press, 2026-11-14), so the
  -- window's own open/close events are tracked too.
  self:On("TRADE_SKILL_SHOW", function(mod) mod.windowOpen = true end)
  self:On("TRADE_SKILL_CLOSE", function(mod) mod.windowOpen = false end)
  self:On("UI_ERROR_MESSAGE", self.OnUIError)
  self:On("PLAYER_ENTERING_WORLD", self.Refresh)
end

function M:Activity()
  local names = {}
  for _, e in ipairs(self:Entries()) do names[#names + 1] = e.name end
  return #names > 0 and ("macros for: " .. table.concat(names, ", ")) or "no crafting profession yet"
end

ns.AddCommand("make", "[Profession]  make what you have ingredients for (no name: create the Cook / Brew / Herb macros)", function(arg)
  if not M.enabled then ns.Print("the Crafter module is off") return end
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if arg ~= "" then
    -- "Cooking train": only recipes that still give skill (CookTrainer's button)
    local prof, train = arg:match("^(.-)%s+train$")
    -- "Cooking fire": craft one Basic Campfire, a Cooking recipe on Forever
    -- (not a spell, so /cast can't build it; Gary, 2026-11-14)
    local fireProf = arg:match("^(.-)%s+fire$")
    M.trainOnly = prof ~= nil
    M.onlyRecipe = fireProf and "Basic Campfire" or nil
    M:Make(ns.TitleCase((fireProf or prof or arg):lower()))
    M.trainOnly, M.onlyRecipe = false, nil
    return
  end
  local made, lib = {}, ns.MacroLibrary
  if not lib then return end
  for _, e in ipairs(M:Entries()) do
    if lib:State(e) ~= "installed" then
      local ok, why = lib:Install(e)
      if ok then made[#made + 1] = e.name else ns.Print("%s not made: %s", e.name, tostring(why)) end
    end
  end
  if #made > 0 then
    ns.Print("macros %s ready: open the macro window (/macro), Character tab, and drag them to your bar", table.concat(made, ", "))
  elseif #M:Entries() == 0 then
    ns.Print("no Cooking, Alchemy or Herbalism on this character")
  else
    ns.Print("your profession macros are already made")
  end
end)
