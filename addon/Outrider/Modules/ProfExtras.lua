-- Modules/ProfExtras.lua
-- Profession extras (gap analysis 2026-11-17, SkillUp / What's Training /
-- TSM style), shown on the Professions page:
--   * Trainer list: every trainer window you open is read (what it teaches,
--     what you can learn now, what needs more skill or level, and the cost),
--     per character. Class trainers too ("spells coming next").
--   * Skill-up chance per recipe from the colour the client reports
--     (orange always, yellow likely, green sometimes, grey never; the numbers
--     are SkillUp's Classic estimates, not measured).
--   * Craft cooldowns (transmutes, mooncloth...): read when the profession
--     window opens, kept per character; one line at login when one is ready.
--   * Profitable crafts (MoneyGuide) and your undercut auctions
--     (AuctionHelper, remembered from the last auction house visit) as cards.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("ProfExtras", {
  title = "Trainer list, skill-up chance and craft cooldowns",
  phase = "P5",
  order = 76,
  defaults = {},
})
ns.ProfExtras = M

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.craftCooldowns = type(g.craftCooldowns) == "table" and g.craftCooldowns or {}
  self.cds = g.craftCooldowns
end

-- ------------------------------------------------------------------ trainer
-- call a trainer API directly (C.Call keeps only five values)
local function call(name, ...)
  local f = C.Resolve(name)
  if type(f) ~= "function" then return nil end
  local r = { pcall(f, ...) }
  if not r[1] then return nil end
  table.remove(r, 1)
  return unpack(r)
end

function M:ReadTrainer()
  local n = tonumber(readable(call("GetNumTrainerServices"))) or 0
  if n == 0 then return nil end
  local trainer = readable(C.Call("UnitName", "npc")) or "trainer"
  local list, kind = {}, "class"
  for i = 1, math.min(n, 200) do
    local name, rank, status = call("GetTrainerServiceInfo", i)
    name, rank, status = readable(name), readable(rank), readable(status)
    if name and status ~= "header" then
      local skill, skillReq = call("GetTrainerServiceSkillReq", i)
      skill, skillReq = readable(skill), tonumber(readable(skillReq))
      if skill and skill ~= "" then kind = skill end
      list[#list + 1] = { name = name, rank = rank ~= "" and rank or nil, status = status,
        cost = tonumber(readable(call("GetTrainerServiceCost", i))) or 0,
        level = tonumber(readable(call("GetTrainerServiceLevelReq", i))) or 0, skill = skill, skillReq = skillReq }
    end
  end
  ns.db.char.trainers = ns.db.char.trainers or {}
  ns.db.char.trainers[kind] = { trainer = trainer, at = time(), list = list }
  self:Info("trainer %s (%s): %d entries", trainer, kind, #list)
  return kind, list
end

-- { ready = {...}, later = {...} } for one trainer kind ("class" or a profession)
function M:Upcoming(kind)
  local t = ns.db.char.trainers and ns.db.char.trainers[kind]
  local out = { ready = {}, later = {}, at = t and t.at, trainer = t and t.trainer }
  if not t then return out end
  for _, e in ipairs(t.list) do
    if e.status == "available" then out.ready[#out.ready + 1] = e
    elseif e.status == "unavailable" then out.later[#out.later + 1] = e end
  end
  table.sort(out.later, function(a, b)
    if (a.skillReq or 0) ~= (b.skillReq or 0) then return (a.skillReq or 0) < (b.skillReq or 0) end
    return (a.level or 0) < (b.level or 0)
  end)
  return out
end

function M:TrainerKinds()
  local out = {}
  for k in pairs(ns.db.char.trainers or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

-- DEEP-29: sourced-only unlearned recipe registry. Full independent
-- trainer/vendor/drop/quest coverage requires an attributed data pack.
function M:RecipeSources()
  ns.db.global.recipeSources = type(ns.db.global.recipeSources) == "table" and ns.db.global.recipeSources or {}
  return ns.db.global.recipeSources
end
function M:RecordRecipeSource(recipeID, name, kind, who, skill)
  recipeID = tonumber(recipeID)
  if not recipeID or type(name) ~= "string" or name == "" or
    not ({ trainer = true, vendor = true, drop = true, quest = true })[kind] then return false end
  self:RecipeSources()[recipeID] = { id = recipeID, name = name, kind = kind,
    who = who, skill = tonumber(skill), at = time(), source = "user supplied, unverified" }
  return true
end
function M:UnlearnedRecipes()
  local known = {}
  for _, p in pairs(ns.db.char.professions or {}) do
    for id in pairs(p.recipes or {}) do known[tonumber(id)] = true end
  end
  local result = {}
  for id, r in pairs(self:RecipeSources()) do
    if not known[id] then result[#result + 1] = r end
  end
  table.sort(result, function(a,b) return (a.skill or 0) < (b.skill or 0) end)
  return result
end
function M:ObserveUnlearned()
  local kind, list = self:ReadTrainer()
  if not kind then return end
  ns.db.char.unlearnedTrainer = ns.db.char.unlearnedTrainer or {}
  for _, r in ipairs(list or {}) do
    if r.name and r.status == "unavailable" then
      ns.db.char.unlearnedTrainer[r.name] = { name = r.name, kind = "trainer",
        trainer = kind, level = r.level, skill = r.skillReq, cost = r.cost,
        at = time(), source = "observed in trainer UI" }
    end
  end
end
ns.AddCommand("recipesources", "recipesources list | add <recipeID> <kind> <source>", function(arg)
  local id, kind, who = tostring(arg or ""):match("^add%s+(%d+)%s+(%a+)%s+(.+)$")
  if id then
    local data = C.Call("C_TradeSkillUI.GetRecipeInfo", tonumber(id))
    local name = type(data) == "table" and C.Readable(data.name) or ("recipe " .. id)
    ns.Print(M:RecordRecipeSource(id, name, kind, who) and "recipe source saved (unverified)" or "invalid recipe")
    return
  end
  local result = M:UnlearnedRecipes()
  ns.Print("%d recipes with explicit sources (not a complete recipe database)", #result)
  for i = 1, math.min(25, #result) do
    local r = result[i]
    ns.Print("%s: %s / %s", r.name, r.kind, tostring(r.who))
  end
end)

-- ------------------------------------------------------------------ chance
M.CHANCE = { [0] = "always", [1] = "likely", [2] = "sometimes", [3] = "never" }
function M.Chance(diff)
  local exp = ns.SkillUp and ns.SkillUp.EXPECTED and ns.SkillUp.EXPECTED[diff]
  if not exp then return nil end
  return string.format("%s (about %d%%)", M.CHANCE[diff] or "?", math.floor(exp * 100 + 0.5))
end

-- recipes still giving skill, best chance first: { {name, diff, chance} }
function M:SkillRecipes(prof)
  local p = ns.db.char.professions and ns.db.char.professions[prof]
  local out = {}
  for _, r in pairs(p and p.recipes or {}) do
    if type(r) == "table" and r.diff and r.diff < 3 then out[#out + 1] = { name = r.name, diff = r.diff, chance = M.Chance(r.diff) } end
  end
  table.sort(out, function(a, b) if a.diff ~= b.diff then return a.diff < b.diff end return tostring(a.name) < tostring(b.name) end)
  return out
end

-- ------------------------------------------------------------------ cooldowns
function M:ReadCooldowns()
  local ids = C.Call("C_TradeSkillUI.GetAllRecipeIDs")
  local mine = {}
  local cd = C.Resolve("C_TradeSkillUI.GetRecipeCooldown")
  if type(ids) == "table" and type(cd) == "function" then
    for _, id in ipairs(ids) do
      local ok, secs = pcall(cd, id)
      secs = ok and tonumber(readable(secs)) or nil
      if secs and secs > 0 then
        local info = C.Call("C_TradeSkillUI.GetRecipeInfo", id)
        local name = type(info) == "table" and readable(info.name) or ("recipe " .. id)
        mine[name] = time() + secs
      end
    end
  else
    local n = tonumber(C.Call("GetNumTradeSkills")) or 0
    for i = 1, n do
      local secs = tonumber(readable(C.Call("GetTradeSkillCooldown", i)))
      if secs and secs > 0 then
        local name = readable((C.Call("GetTradeSkillInfo", i)))
        if name then mine[name] = time() + secs end
      end
    end
  end
  local key = ns.db.key
  local cur = self.cds[key] or {}
  for name, at in pairs(mine) do cur[name] = at end
  self.cds[key] = next(cur) and cur or nil
  return mine
end

-- { {char, name, at, ready} } soonest first
function M:Cooldowns(now)
  now = now or time()
  local out = {}
  for char, list in pairs(self.cds) do
    for name, at in pairs(list) do out[#out + 1] = { char = char, name = name, at = at, ready = at <= now } end
  end
  table.sort(out, function(a, b) return a.at < b.at end)
  return out
end

function M:WarnReady()
  local ready = {}
  for _, c in ipairs(self:Cooldowns()) do
    if c.ready then ready[#ready + 1] = string.format("%s on %s", c.name, c.char:match("^[^-]+") or c.char) end
  end
  if #ready > 0 then ns.Print("ready to craft again: %s", table.concat(ready, ", ")) end
end

function M:ClearReady(name)
  local list = self.cds[ns.db.key]
  if list and list[name] and list[name] <= time() then list[name] = nil end
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("TRAINER_SHOW", function(mod) ns.Timer.After(0.3, function() mod:ObserveUnlearned() end, "profextras:trainer") end)
  self:On("TRAINER_UPDATE", function(mod) ns.Throttle("profextras:trainer", 1, function() mod:ReadTrainer() end) end)
  self:On("TRADE_SKILL_SHOW", function(mod) ns.Timer.After(0.5, function() mod:ReadCooldowns() end, "profextras:cd") end)
  self:On("TRADE_SKILL_LIST_UPDATE", function(mod) ns.Throttle("profextras:cd", 2, function() mod:ReadCooldowns() end) end)
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin) if isLogin then mod:WarnReady() end end)
  self:On("OWNED_AUCTIONS_UPDATED", function(mod)
    if ns.AuctionHelper then
      local ok, list = pcall(ns.AuctionHelper.Undercut, ns.AuctionHelper)
      if ok then ns.db.char.undercut = { at = time(), list = list } end
    end
  end)
end

function M:Activity()
  return string.format("%d trainers read, %d craft cooldowns", #self:TrainerKinds(), #self:Cooldowns())
end

-- ------------------------------------------------------------------ page rows
local function money(c) return ns.Prices and ns.Prices.Money and ns.Prices.Money(c) or tostring(c) end
local function ago(t)
  local d = time() - (t or 0)
  if d < 3600 then return math.max(1, math.floor(d / 60)) .. " min ago" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  return math.floor(d / 86400) .. " days ago"
end

-- extra Form rows for the Professions page (UI/Pages.lua profRows)
function M:PageRows()
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  r({ "header", "At the trainer", icon = "INV_Misc_Book_09" })
  r({ "note", function()
    if #M:TrainerKinds() == 0 then return "Open any trainer once (class or profession): Outrider lists what you can learn now, what comes next and what it costs." end
    return "From the last time you opened each trainer."
  end })
  r({ "cards", function()
    local out = {}
    for _, kind in ipairs(M:TrainerKinds()) do
      local u = M:Upcoming(kind)
      local cost = 0
      for _, e in ipairs(u.ready) do cost = cost + e.cost end
      local names = {}
      for i, e in ipairs(u.ready) do if i > 4 then break end names[#names + 1] = e.name .. (e.rank and (" " .. e.rank) or "") end
      local nxt = {}
      for i, e in ipairs(u.later) do
        if i > 3 then break end
        nxt[#nxt + 1] = string.format("%s at %s", e.name, e.skillReq and e.skillReq > 0 and (e.skill .. " " .. e.skillReq) or ("level " .. e.level))
      end
      local line = #u.ready > 0 and ("Learn now: " .. table.concat(names, ", ") .. (#u.ready > 4 and "..." or "")) or "Nothing new to learn right now."
      if #nxt > 0 then line = line .. "  |cff888888Next: " .. table.concat(nxt, "; ") .. "|r" end
      out[#out + 1] = { pic = "Interface\\Icons\\" .. (kind == "class" and "INV_Misc_Book_09" or "Trade_Alchemy"),
        title = kind == "class" and "Class trainer" or kind,
        tags = { { #u.ready .. " to learn", #u.ready > 0 and "gold" or "plain" }, { money(cost), "plain" }, { ago(u.at), "plain" } },
        line = line, highlight = #u.ready > 0 }
    end
    return out
  end })
  r({ "header", "Skill-up chance", icon = "Spell_Holy_SurgeOfLight" })
  r({ "note", "From each recipe's colour: orange always gives a point, yellow likely, green sometimes, grey never (Classic estimates). Open a profession window to update." })
  r({ "cards", function()
    local out = {}
    for prof in pairs(ns.db.char.professions or {}) do
      local list = M:SkillRecipes(prof)
      if #list > 0 then
        local parts = {}
        for i, x in ipairs(list) do if i > 5 then break end parts[#parts + 1] = string.format("%s: %s", tostring(x.name), x.chance or "?") end
        local p = ns.db.char.professions[prof]
        out[#out + 1] = { pic = "Interface\\Icons\\Trade_Alchemy", title = prof,
          tags = { { string.format("%d/%d", p.skill or 0, p.max or 0), "gold" }, { #list .. " still give skill", "plain" } },
          line = table.concat(parts, "; ") }
      end
    end
    return out
  end })
  r({ "header", "Craft cooldowns", icon = "INV_Misc_PocketWatch_01" })
  r({ "tiles", function()
    local out = {}
    for _, c in ipairs(M:Cooldowns()) do
      local left = c.at - time()
      out[#out + 1] = { ok = c.ready, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        text = string.format("%s (%s): %s", c.name, c.char:match("^[^-]+") or c.char,
          c.ready and "ready" or (left > 3600 and (math.floor(left / 3600) .. " h") or (math.ceil(left / 60) .. " min"))) }
    end
    return out
  end })
  r({ "note", function() return #M:Cooldowns() == 0 and "No craft cooldowns seen yet (transmutes, mooncloth). They show here after you use one." or "" end })
  r({ "header", "Profitable crafts", icon = "INV_Misc_Coin_02" })
  r({ "cards", function()
    local G = ns.MoneyGuide
    local ok, list = pcall(G and G.CraftProfits or error, G)
    local out = {}
    for i, c in ipairs(ok and list or {}) do
      if i > 5 or c.profit <= 0 then break end
      out[#out + 1] = { art = "kind_gold", pic = "Interface\\Icons\\INV_Misc_Coin_02", title = tostring(c.name),
        tags = { { "+" .. money(c.profit), "gold" }, { tostring(c.prof), "plain" } },
        line = string.format("Sells for %s, materials %s, after the auction house cut.", money(c.sell * (c.makes or 1)), money(c.cost)) }
    end
    return out
  end })
  r({ "note", "Profit uses the auction prices Outrider has seen; open the auction house now and then to keep them fresh." })
  r({ "header", "Undercut auctions", icon = "INV_Misc_Coin_01" })
  r({ "cards", function()
    local u = ns.db.char.undercut
    local out = {}
    for i, a in ipairs(u and u.list or {}) do
      if i > 6 then break end
      out[#out + 1] = { itemID = a.itemID, title = tostring(a.name), tags = { { "yours " .. money(a.mine), "warn" }, { "lowest " .. money(a.low), "plain" } },
        line = "Someone sells it cheaper. Cancel and repost it at the auction house if you want it to sell." }
    end
    return out
  end })
  r({ "note", function()
    local u = ns.db.char.undercut
    if not u then return "Open your auctions tab at the auction house once and Outrider lists any that were undercut." end
    return #u.list == 0 and ("None of your auctions were undercut (checked " .. ago(u.at) .. ").") or ("Checked " .. ago(u.at) .. ".")
  end })
  return rows
end
