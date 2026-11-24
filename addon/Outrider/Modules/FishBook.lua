-- Modules/FishBook.lua
-- Fish collection, milestones, when fish bite and what to cook (requirement
-- 2026-11-24: borrow FishFry's best ideas; ideas only, nothing copied).
--
--   * Collection: every fish you've caught, with this character's count and
--     the account's, common / rare (green or better) / trophy ("17 Pound
--     Catfish": the name says so), first catch date.
--   * Milestones: catch totals, kinds of fish, rare and trophy catches, skill;
--     bronze, silver and gold with points. One toast when one is earned
--     (setting); Share shows a line to copy into chat.
--   * When they bite: every catch is counted by server hour (4-hour blocks)
--     per zone, so a fish caught mostly at night shows it. Measured from your
--     own catches only, nothing assumed.
--   * Cook your fish: the raw fish in your bags, what each cooks into from
--     your known Cooking recipes, how many you can make, what's missing.
-- Reads loot, skill and recipe data other modules collect. Nothing acts.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("FishBook", {
  title = "Fish collection and milestones",
  phase = "P5",
  order = 78,
  defaults = { toast = true },
})
ns.FishBook = M
ns.FishCook = M

M.BLOCKS = { "Late night", "Early morning", "Morning", "Afternoon", "Evening", "Night" }
M.BLOCK_HOURS = { "0-4", "4-8", "8-12", "12-16", "16-20", "20-24" }
M.MIN_BLOCK = 10   -- catches a time block needs before it's compared

function M:OnInitialize()
  local g = ns.db.global
  g.fishBook = type(g.fishBook) == "table" and g.fishBook or {}
  local b = g.fishBook
  b.fish = type(b.fish) == "table" and b.fish or {}          -- [id] = { first, char, q, name }
  b.hours = type(b.hours) == "table" and b.hours or {}        -- [mapID] = { [block] = { t = n, [id] = n } }
  b.earned = type(b.earned) == "table" and b.earned or {}     -- [milestone key] = { t, char }
  self.book = b
end

function M:CharFish()
  local c = ns.db.char
  c.fishCaught = type(c.fishCaught) == "table" and c.fishCaught or {}
  return c.fishCaught
end

-- the server hour (the game's clock), else this PC's
function M.Hour()
  local h = C.Call("GetGameTime")
  h = tonumber(C.Readable(h))
  if h then return h end
  return tonumber(date("%H")) or 0
end
function M.Block(hour) return math.floor((hour or 0) / 4) % 6 + 1 end

-- ------------------------------------------------------------ catching
function M:OnLoot(_, kind, items)
  if kind ~= "fish" or type(items) ~= "table" then return end
  local mapID = C.PlayerPosition("player") or 0
  local blk = M.Block(M.Hour())
  local zone = self.book.hours[mapID] or {}
  self.book.hours[mapID] = zone
  local slot = zone[blk] or { t = 0 }
  zone[blk] = slot
  local mine = self:CharFish()
  for _, it in ipairs(items) do
    local id, n = tonumber(it.id), it.count or 1
    if id then
      mine[id] = (mine[id] or 0) + n
      slot.t = slot.t + n
      slot[id] = (slot[id] or 0) + n
      local f = self.book.fish[id]
      local info = C.ItemInfo(id)
      if not f then
        f = { first = time(), char = ns.db.key, name = it.name or (info and info.name) }
        self.book.fish[id] = f
        self:Info("new fish for the collection: %s", tostring(f.name or id))
      end
      if info then f.q = info.quality f.name = f.name or info.name end
    end
  end
  self:Check()
end

-- ------------------------------------------------------------ collection
function M.Trophy(name) return type(name) == "string" and name:find("%d+ Pound") ~= nil end

function M.Rarity(f)
  if M.Trophy(f.name) then return "Trophy", "warn" end
  if (tonumber(f.q) or 1) >= 2 then return "Rare", "good" end
  return "Common", "plain"
end

-- { {id, name, char, account, first, rarity, color} } most caught first
function M:Collection()
  local stats = ns.FishingGuide and ns.FishingGuide.stats and ns.FishingGuide.stats.fish or {}
  local mine = self:CharFish()
  local ids = {}
  for id in pairs(stats) do ids[id] = true end
  for id in pairs(self.book.fish) do ids[id] = true end
  local out = {}
  for id in pairs(ids) do
    local s, b = stats[id] or {}, self.book.fish[id] or {}
    local info = C.ItemInfo(id)
    local e = { id = id, name = b.name or s.name or (info and info.name) or ("item " .. id), q = b.q or (info and info.quality),
      char = mine[id] or 0, account = math.max(s.n or 0, mine[id] or 0), first = b.first, icon = info and info.icon }
    e.rarity, e.color = M.Rarity(e)
    out[#out + 1] = e
  end
  table.sort(out, function(a, b) if a.account ~= b.account then return a.account > b.account end return a.name < b.name end)
  return out
end

-- ------------------------------------------------------------ when they bite
-- { blocks = { {name, hours, total, n, share} }, overall, best, none = {...}, ready }
function M:BiteTimes(id)
  id = tonumber(id)
  local blocks = {}
  for i = 1, 6 do blocks[i] = { name = M.BLOCKS[i], hours = M.BLOCK_HOURS[i], total = 0, n = 0 } end
  local sumN, sumT = 0, 0
  for _, zone in pairs(self.book.hours) do
    local seen = false
    for _, slot in pairs(zone) do if slot[id] then seen = true end end
    if seen then
      for b, slot in pairs(zone) do
        if blocks[b] then
          blocks[b].total = blocks[b].total + (slot.t or 0)
          blocks[b].n = blocks[b].n + (slot[id] or 0)
          sumT, sumN = sumT + (slot.t or 0), sumN + (slot[id] or 0)
        end
      end
    end
  end
  local res = { blocks = blocks, overall = sumT > 0 and sumN / sumT or nil, none = {} }
  local ready = 0
  for _, b in ipairs(blocks) do
    if b.total >= M.MIN_BLOCK then
      ready = ready + 1
      b.share = b.n / b.total
      if res.overall and res.overall > 0 then
        if b.n >= 3 and b.share >= res.overall * 1.5 and (not res.best or b.share > res.best.share) then res.best = b end
        if b.n == 0 and res.overall >= 0.1 and b.total >= M.MIN_BLOCK * 1.5 then res.none[#res.none + 1] = b end
      end
    end
  end
  res.ready = ready >= 2
  return res
end

function M:BiteLine(id)
  local r = self:BiteTimes(id)
  if not r.ready then return nil end
  local parts = {}
  if r.best then
    parts[#parts + 1] = string.format("Bites most %s (%s server time): %d%% of catches then, %d%% other times",
      r.best.name:lower(), r.best.hours, math.floor(r.best.share * 100 + 0.5), math.floor(r.overall * 100 + 0.5))
  end
  for _, b in ipairs(r.none) do
    parts[#parts + 1] = string.format("never caught %s (%s) in %d catches there", b.name:lower(), b.hours, b.total)
  end
  if #parts == 0 then return "Bites at any time of day, as far as your catches show." end
  return table.concat(parts, "; ") .. "."
end

-- ------------------------------------------------------------ milestones
local TIER = { bronze = 5, silver = 10, gold = 25 }
local function totals(self)
  local col = self:Collection()
  local t = { catches = 0, kinds = #col, rare = 0, trophy = 0 }
  for _, f in ipairs(col) do
    t.catches = t.catches + f.account
    if f.rarity == "Trophy" then t.trophy = t.trophy + f.account
    elseif f.rarity == "Rare" then t.rare = t.rare + f.account end
  end
  local stats = ns.FishingGuide and ns.FishingGuide.stats
  if stats and (stats.catches or 0) > t.catches then t.catches = stats.catches end
  local skill = ns.FishingHUD and ns.FishingHUD.Skill and ns.FishingHUD:Skill()
  t.skill = tonumber(skill) or 0
  return t
end

M.LIST = {}
local function add(key, title, text, what, goal, tier)
  M.LIST[#M.LIST + 1] = { key = key, title = title, text = text, what = what, goal = goal, tier = tier, points = TIER[tier] }
end
add("c1", "First bite", "Catch your first fish.", "catches", 1, "bronze")
add("c50", "Fifty fish", "Catch 50 fish.", "catches", 50, "bronze")
add("c100", "A hundred fish", "Catch 100 fish.", "catches", 100, "bronze")
add("c250", "Steady angler", "Catch 250 fish.", "catches", 250, "silver")
add("c500", "Five hundred", "Catch 500 fish.", "catches", 500, "silver")
add("c1000", "A thousand fish", "Catch 1,000 fish.", "catches", 1000, "silver")
add("c2500", "Never leaves the water", "Catch 2,500 fish.", "catches", 2500, "gold")
add("c5000", "Living legend of the lake", "Catch 5,000 fish.", "catches", 5000, "gold")
add("k5", "Five kinds", "Catch 5 different kinds of fish.", "kinds", 5, "bronze")
add("k10", "Ten kinds", "Catch 10 different kinds of fish.", "kinds", 10, "bronze")
add("k20", "Twenty kinds", "Catch 20 different kinds of fish.", "kinds", 20, "silver")
add("k35", "Thirty-five kinds", "Catch 35 different kinds of fish.", "kinds", 35, "gold")
add("r1", "Something shiny", "Catch a green or better item while fishing.", "rare", 1, "bronze")
add("r10", "Lucky line", "Catch 10 green or better items while fishing.", "rare", 10, "silver")
add("r25", "Treasure hunter", "Catch 25 green or better items while fishing.", "rare", 25, "gold")
add("t1", "Trophy", "Catch a trophy fish (one with its weight in the name).", "trophy", 1, "silver")
add("t10", "Trophy wall", "Catch 10 trophy fish.", "trophy", 10, "gold")
add("s75", "Apprentice angler", "Reach Fishing 75.", "skill", 75, "bronze")
add("s150", "Journeyman angler", "Reach Fishing 150.", "skill", 150, "bronze")
add("s225", "Expert angler", "Reach Fishing 225.", "skill", 225, "silver")
add("s300", "Artisan angler", "Reach Fishing 300.", "skill", 300, "gold")

-- { {key, title, text, tier, points, have, goal, earned = {t, char}?} } earned first, then closest
function M:Milestones()
  local t = totals(self)
  local out = {}
  for _, m in ipairs(M.LIST) do
    local e = {}
    for k, v in pairs(m) do e[k] = v end
    e.have = math.min(t[m.what] or 0, m.goal)
    e.earned = self.book.earned[m.key]
    out[#out + 1] = e
  end
  return out, t
end

function M:Points()
  local p, n = 0, 0
  for _, m in ipairs(M.LIST) do if self.book.earned[m.key] then p, n = p + m.points, n + 1 end end
  return p, n
end

-- Earn what's reached. The first check after install earns the backlog
-- quietly (no toast storm), with one log line.
function M:Check()
  local list = self:Milestones()
  local quiet = not self.book.started
  local new = {}
  for _, m in ipairs(list) do
    if not m.earned and m.have >= m.goal then
      self.book.earned[m.key] = { t = time(), char = ns.db.key }
      new[#new + 1] = m
    end
  end
  self.book.started = true
  if #new == 0 then return new end
  if quiet then
    self:Info("fishing milestones: %d already reached", #new)
  else
    for _, m in ipairs(new) do
      self:Info("milestone earned: %s (%s, %d pts)", m.title, m.tier, m.points)
      if self:Settings().toast and ns.Toast then
        ns.Toast:Show({ title = "Fishing milestone: " .. m.title, text = m.text .. string.format(" (%s, %d points)", m.tier, m.points),
          color = "good", duration = 8 })
      end
    end
  end
  return new
end

-- The line to share, shown in a copy box: Outrider sends no chat itself
-- (security check OI01-13); the player pastes it where they like.
function M:ShareText(key)
  for _, x in ipairs(M.LIST) do
    if x.key == key and self.book.earned[key] then return string.format("Fishing milestone: %s (%s)", x.title, x.text) end
  end
  return nil
end

function M:Share(key)
  local text = self:ShareText(key)
  if not text then return false end
  if ns.UI and ns.UI.TextDialog then ns.UI:TextDialog("Share this milestone", text, "copy") end
  return true
end

-- ------------------------------------------------------------ cook your fish
local function isFish(id)
  local stats = ns.FishingGuide and ns.FishingGuide.stats and ns.FishingGuide.stats.fish or {}
  if stats[id] or M.book and M.book.fish[id] then return true end
  local info = C.ItemInfo(id)
  return info and type(info.name) == "string" and info.name:find("^Raw ") ~= nil or false
end

-- { {fishID, fishName, fishHave, recipe, n, diff, missing = {...}, entry} } for fish in your bags
function M:Rows()
  local H = ns.ProfessionHub
  if not (H and H.Recipes and H.Have) then return {} end
  local ok, r = pcall(H.Recipes, H, "Cooking")
  if not ok or type(r) ~= "table" then return {} end
  local out = {}
  local function take(list, ready)
    for _, e in ipairs(list or {}) do
      for itemID in pairs(e.recipe and e.recipe.reagents or {}) do
        if isFish(itemID) then
          local have = H.Have(itemID)
          if have > 0 then
            out[#out + 1] = { fishID = itemID, fishName = H.ItemName(itemID), fishHave = have, recipe = e.name,
              n = ready and e.n or 0, diff = e.diff, missing = e.missing or {}, entry = e }
          end
        end
      end
    end
  end
  take(r.now, true)
  take(r.next, false)
  table.sort(out, function(a, b)
    if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
    if a.diff ~= b.diff then return a.diff < b.diff end
    return a.recipe < b.recipe
  end)
  return out
end

function M:Cook(row)
  local H = ns.ProfessionHub
  if not (H and row and row.entry) then return "unknown" end
  return H:Make("Cooking", row.entry)
end

-- ------------------------------------------------------------ the page
local DIFF = { [0] = { "skill-up: orange", "warn" }, [1] = { "skill-up: yellow", "gold" }, [2] = { "skill-up: green", "good" }, [3] = { "no skill-up", "plain" } }

ns.Hub:AddTab("fishbook", "Fish collection", function(p)
  local UI = ns.UI
  UI:FormPage(p, {
    { "header", "Fish collection" },
    { "note", "Every fish you've caught, the milestones you've earned and when each fish bites. 1. Fish. 2. Look here. 3. Share a milestone: copy its line into chat." },
    { "stats", function()
      local col = M:Collection()
      local pts, n = M:Points()
      local _, t = M:Milestones()
      return {
        { cap = "Kinds of fish", value = tostring(#col), color = "gold" },
        { cap = "Fish caught", value = tostring(t.catches), note = "all your characters" },
        { cap = "Milestones", value = n .. " / " .. #M.LIST, note = pts .. " points" },
      }
    end },
    { "header", "Your fish", icon = "INV_Misc_Fish_02" },
    { "cards", function()
      local out = {}
      for i, f in ipairs(M:Collection()) do
        if i > 30 then break end
        local where = ns.FishingLog and ns.FishingLog.WhereBites and ns.FishingLog:WhereBites(f.id)[1]
        local lines = {}
        local bite = M:BiteLine(f.id)
        if bite then lines[#lines + 1] = bite end
        if where then lines[#lines + 1] = "Bites best at " .. where.name .. "." end
        if f.first then lines[#lines + 1] = "First caught " .. date("%b %d, %Y", f.first) .. "." end
        out[#out + 1] = { pic = f.icon or "Interface\\Icons\\INV_Misc_Fish_02", title = f.name,
          tags = { { f.rarity, f.color }, { "This character " .. f.char, "plain" }, { "Account " .. f.account, "gold" } },
          line = table.concat(lines, " ") }
      end
      return out
    end },
    { "note", function() return #M:Collection() == 0 and "Nothing yet: every catch lands here." or "" end },
    { "header", "Milestones", icon = "INV_Misc_Trophy_03" },
    { "cards", function()
      local list = M:Milestones()
      table.sort(list, function(a, b)
        if (a.earned ~= nil) ~= (b.earned ~= nil) then return a.earned ~= nil end
        local fa, fb = a.have / a.goal, b.have / b.goal
        if fa ~= fb then return fa > fb end
        return a.goal < b.goal
      end)
      local out = {}
      for _, m in ipairs(list) do
        local color = m.tier == "gold" and "gold" or m.tier == "silver" and "plain" or "warn"
        local tags = { { m.tier:sub(1, 1):upper() .. m.tier:sub(2), color }, { m.points .. " pts", "plain" } }
        if m.earned then tags[#tags + 1] = { "Earned " .. date("%b %d", m.earned.t), "good" }
        else tags[#tags + 1] = { m.have .. " / " .. m.goal, "plain" } end
        out[#out + 1] = { pic = "Interface\\Icons\\" .. (m.earned and "INV_Misc_Trophy_03" or "INV_Misc_QuestionMark"), title = m.title,
          tags = tags, line = m.text,
          actions = m.earned and { { "Share", function() M:Share(m.key) end, "Shows one line about this milestone to copy into chat." } } or nil }
      end
      return out
    end },
    { "check", "A toast when you earn a milestone", function() return M:Settings().toast end, function(on) M:Settings().toast = on end },
  })
end)

function M:OnEnable()
  self:On("OTR_LOOT", self.OnLoot)
  self:On("CHAT_MSG_SKILL", function(mod) mod:Check() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Check() end)
end

function M:Activity()
  local pts, n = self:Points()
  return string.format("%d kinds of fish, %d milestones (%d points)", #self:Collection(), n, pts)
end
