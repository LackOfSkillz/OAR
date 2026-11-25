-- UI/Pages/Gold.lua
-- Trainers and tools, Money and Dungeons pages. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff

local function profRows()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local function make(prof) return function() if ns.Crafter then ns.Crafter:Make(prof) end end end
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  -- a skill bar per profession you have (premium rebuild 2026-11-18)
  r({ "stats", function()
    local out = {}
    for name, d in pairs(ns.db.char.professions or {}) do
      if type(d) == "table" and d.skill then
        out[#out + 1] = { cap = name, value = d.skill .. " / " .. tostring(d.max or "?"), color = "gold",
          fill = d.max and d.max > 0 and d.skill / d.max or nil }
      end
    end
    table.sort(out, function(x, y) return x.cap < y.cap end)
    return out
  end })
  -- each profession in plain words: where it stands and what to do next (requirement 2026-11-20)
  r({ "header", "What to do next" })
  r({ "cards", function()
    local out = {}
    local GATHER = { Herbalism = "pick herbs", Mining = "mine ore", Skinning = "skin beasts you kill", Fishing = "fish" }
    local icons = ns.ProfExtras and ns.ProfExtras.PROF_ICON or {}
    local names = {}
    for name, d in pairs(ns.db.char.professions or {}) do if type(d) == "table" and d.skill then names[#names + 1] = name end end
    table.sort(names)
    for _, name in ipairs(names) do
      local d = ns.db.char.professions[name]
      local skill, max = tonumber(d.skill) or 0, tonumber(d.max) or 0
      local line, tag, act
      if max > 0 and skill >= max then
        line = string.format("You've reached the most this rank allows (%d). Visit a %s trainer to learn the next rank and keep going.", max, name:lower())
        tag = { "visit a trainer", "gold" }
        -- a trainer who teaches the rank you need next, not just any (2026-11-21)
        local which, need = name:lower(), ns.Nearest and ns.Nearest.NextRank(max)
        local RANKS = { "Apprentice", "Journeyman", "Expert", "Artisan" }
        act = { { "Arrow to trainer", function()
          local _, msg = ns.Nearest:Go("trainer:" .. which .. (need and (":" .. need) or ""))
          ns.Print(tostring(msg))
        end, "Points the gold arrow at the nearest " .. which .. " trainer who teaches " .. (RANKS[need or 0] or "the next rank") .. "." } }
      elseif GATHER[name] then
        line = string.format("Raise it by doing it: %s. Harder ones give more skill as you go.", GATHER[name])
      else
        line = "Raise it by making things: the craft button and the training button below pick the best recipe for you."
      end
      local artName = "prof_" .. name:lower():gsub(" ", "")
      out[#out + 1] = { title = string.format("%s  %d / %d", name, skill, max), pic = "Interface\\Icons\\" .. (icons[name] or "INV_Misc_Book_09"),
        art = (ns.Art and ns.Art:Has(artName)) and artName or nil,
        line = line, tags = tag and { tag } or nil, actions = act, highlight = tag ~= nil }
    end
    if #out == 0 then
      out[1] = { title = "No professions yet", pic = "Interface\\Icons\\INV_Misc_Book_09",
        line = "Professions let you make or gather things to use and sell. Visit a profession trainer in a city to learn one." }
    end
    return out
  end })
  local crafts = {}
  if owned.Cooking then crafts[#crafts + 1] = { "Cook", make("Cooking") } end
  if owned.Alchemy then crafts[#crafts + 1] = { "Brew", make("Alchemy") } end
  if #crafts > 0 then
    r({ "header", "Craft in one click" })
    r({ "note", "Press it: Outrider makes the recipe that raises your skill most with what's in your bags, as many as you can. For cooking, stand next to a fire." })
    crafts[#crafts + 1] = { "Make bar macros", Run("make") }
    r({ "buttons", crafts })
  end
  -- One-button training for every crafting profession this character has.
  local T = ns.ProfTrainer
  local crafting = T and T.Professions and T:Professions() or {}
  if #crafting > 0 then
    r({ "header", "Skill-up button" })
    r({ "note", "When your bags hold enough to gain about 10 skill, a button pops up on your screen. Press it again and again: each press makes the next recipe that still gives skill (for cooking it builds a fire first)." })
    r({ "check", "Show the training button", function() return set("ProfTrainer").show end,
      function(on) set("ProfTrainer").show = on if T then T:Evaluate() end end })
    r({ "key", "Training key", function() return set("ProfTrainer").key end,
      function(k) if T then T:SetKey(k) end end, "presses the button while it shows" })
    for _, prof in ipairs(crafting) do
      r({ "check", "Offer " .. prof, function() return not (set("ProfTrainer").off or {})[prof] end,
        function(on)
          local s = set("ProfTrainer")
          s.off = s.off or {}
          s.off[prof] = (not on) or nil
          if T then T:Evaluate() end
        end })
    end
    r({ "note", function() local m = mod("ProfTrainer") return m and m.enabled and m:Activity() or "" end, 36 })
  end
  if next(owned) then
    -- the example is one of your own crafts (tour 2026-11-19: it said Alchemy to a leatherworker)
    local example
    for _, prof in ipairs({ "Leatherworking", "Tailoring", "Blacksmithing", "Engineering", "Alchemy", "Enchanting", "Cooking", "First Aid" }) do
      if owned[prof] then example = prof .. " 75" break end
    end
    if example then
      r({ "header", "Plan to a goal" })
      r({ "note", "Type a profession and the skill you want to reach, like the example. Outrider lists what to make and what to buy, cheapest first." })
      r({ "input", "Profession and target", example, "Plan", function(t) ns.Slash:Run("skillup " .. t) end, true })
    end
  end
  if owned.Herbalism then
    r({ "header", "Herbalism" })
    r({ "buttons", { { "Where each herb grows", Run("herbs") } } })
    r({ "note", function() local m = mod("HerbHelper") return m and m.enabled and m:Activity() or "" end })
  end
  if not next(owned) then
    r({ "header", "Professions" })
    r({ "note", "No professions yet. Visit a trainer; their tools appear here once you've learned one." })
  end
  -- trainer list, skill-up chance, craft cooldowns, profitable crafts, undercuts (gap analysis 2026-11-17)
  if ns.ProfExtras then
    local ok, extra = pcall(ns.ProfExtras.PageRows, ns.ProfExtras)
    for _, row in ipairs(ok and extra or {}) do r(row) end
  end
  return rows
end

ns.Hub:AddTab("profdetails", "Trainers and tools", function(p)
  UI:FormPage(p, profRows())
end)

-- ----------------------------------------------------------------- Money
-- Best ways to earn at this level and with these professions (MoneyGuide).
local function moneyRows()
  local G = ns.MoneyGuide
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  if not (G and G.enabled) then
    r({ "header", "Money" })
    r({ "note", "The Money guide module is off (Modules tab in Settings)." })
    return rows
  end
  local level = ns.Compat.Call("UnitLevel", "player") or 1
  r({ "header", "Money" })
  r({ "stats", function()
    local L, F = ns.Ledger, ns.Forecasts
    local net, perHour = 0, 0
    if L and L.Summary then net, perHour = L:Summary() end
    local g = F and F.Gold and F.Gold(ns.db.char.ledger)
    local coins = ns.Prices.Coins
    return {
      { cap = "Gold", value = coins(tonumber(ns.Compat.Readable(ns.Compat.Call("GetMoney"))) or 0), color = "gold" },
      { cap = "This session", value = (net < 0 and "-" or "+") .. coins(math.abs(net)), color = net > 0 and "good" or net < 0 and "bad" or nil },
      { cap = "Usual per hour", value = g and coins(math.floor(math.abs(g.perHour))) or "—",
        note = g and (g.sessions .. " sessions" .. (g.trend and (", " .. g.trend) or "")) or "log out once to start" },
    }
  end })
  r({ "header", "Best ways to earn at level " .. level })
  r({ "note", "Ranked for your level and professions. Guide numbers are early Forever reports (unverified); after 15 minutes of a kind of earning your own gold per hour replaces them." })
  local ranked = G:Rank(level)
  r({ "cards", function()
    local out = {}
    for i, x in ipairs(G:Rank(level)) do
      if i > 8 then break end
      local e = x.entry
      local actions = {}
      for z = 1, math.min(#(e.zones or {}), 2) do
        local zone = e.zones[z]
        actions[#actions + 1] = { "Find " .. zone, function() ns.Hub:Search(zone) end, "Finds " .. zone .. " on the Find page." }
      end
      -- a picture per way of earning when installed (money_mob, money_skin...), else the gold one
      local cat = type(e.category) == "table" and e.category[1] or e.category
      local own = cat and ns.Art and ns.Art:Has("money_" .. tostring(cat)) and ("money_" .. tostring(cat)) or "kind_gold"
      out[#out + 1] = { art = own, pic = "Interface\\Icons\\INV_Misc_Coin_02", title = e.title,
        tags = { { G.RateText(x), "gold" } }, line = (e.how or "") .. "  |cff888888(" .. tostring(e.source) .. ")|r",
        actions = actions, highlight = i == 1 }
    end
    return out
  end })
  if #ranked == 0 then r({ "note", "No tips for this level yet." }) end
  if ns.Favor and ns.Favor.enabled then
    r({ "header", "Merchant's Favor and crates" })
    r({ "note", function() return table.concat(ns.Favor:Lines(), "\n") end, 80 })
  end
  r({ "header", "Crafting for profit" })
  r({ "note", function() return table.concat(G:ProfitLines(5), "\n") end, 110 })
  r({ "header", "Your own earnings" })
  r({ "note", function()
    local lines = G:YourLines()
    return #lines > 0 and table.concat(lines, "\n") or "Nothing yet: loot, gather, skin or fish and Outrider adds up what it's worth."
  end, 80 })
  r({ "note", "Prices: auction price less 5% when Outrider has seen one (open the auction house now and then), else the vendor price." })
  -- selling at the auction house (moved from Professions, 2026-11-20 layout)
  r({ "header", "Selling at the auction house" })
  r({ "input", "Undercut by", "2% or 50c", "Set", function(t) ns.Slash:Run("undercut " .. t) end })
  r({ "note", function() local s = set("AuctionHelper") return "Your listings go this far under the cheapest one. Now: " .. (s.undercutCopper and (s.undercutCopper .. " copper") or ((s.undercutPct or 2) .. "%")) end })
  return rows
end

ns.Hub:AddTab("money", "Money", function(p)
  UI:FormPage(p, moneyRows())
end)

-- ------------------------------------------------------------- Dungeons
-- Ready now, best upgrades per dungeon, and the next tier (DungeonGuide).
local function dungeonRows()
  local D = ns.DungeonGuide
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  if not (D and D.enabled) then
    r({ "header", "Dungeons" })
    r({ "note", "The dungeon guide module is off (Modules tab in Settings)." })
    return rows
  end
  if not D:Pack() then
    r({ "header", "Dungeons" })
    r({ "note", "The dungeon data pack (Outrider_Data_Dungeons) isn't installed." })
    return rows
  end
  D:Warm()
  local level = ns.Compat.Call("UnitLevel", "player") or 1
  r({ "header", "Dungeons" })
  r({ "buttons", { { "Open dungeon journal", function()
    if ns.DungeonJournal then ns.DungeonJournal:Toggle()
    else ns.Print("Dungeon Journal module is disabled") end
  end, 210, "Browse bosses, loot, dungeon quests, readiness and entrances." } } })
  -- Ready check: a tile per check, green or red (premium look, 2026-11-16)
  r({ "header", "Ready check", icon = "INV_Misc_Book_08" })
  r({ "tiles", function()
    local out = {}
    for _, c in ipairs(D:ReadyCheck()) do
      local t = c.text:lower()
      local icon = t:find("repair") and "Trade_BlackSmithing" or t:find("food") and "INV_Misc_Food_15"
        or t:find("drink") and "INV_Drink_07" or t:find("bag") and "INV_Misc_Bag_08" or t:find("ammo") and "INV_Ammo_Arrow_02"
        or "INV_Misc_Note_01"
      out[#out + 1] = { ok = c.ok, text = c.text, icon = "Interface\\Icons\\" .. icon }
    end
    return out
  end })
  r({ "buttons", { { "Share with my party", function()
    local ok, why = D:ShareReady()
    ns.Print(ok and "ready check sent to your party" or ("not sent: " .. tostring(why or "sharing failed")))
  end, 180 } } })
  r({ "note", function() return D:PartyText() end })
  local function slug(name) return "dungeon_" .. name:lower():gsub("[^%w]", "") end
  local function chips(ups, later, n)
    local out = {}
    for _, u in ipairs(ups) do
      if (u.later and true or false) == (later and true or false) then
        out[#out + 1] = { itemID = u.itemID, text = string.format("|cff7fff7f%s|r %s", ns.GearScore.UpText(u.pct), tostring(u.name)),
          note = (u.boss and ("Drops from " .. u.boss) or "") .. (u.later and (", usable at " .. u.reqLevel) or "") }
        if #out >= (n or 3) then break end
      end
    end
    return out
  end
  local function cardFor(x, kind)
    local tags = { { string.format("Levels %d-%d", x.info.min, x.info.max), "plain" },
      { x.info.raid and (x.info.size .. "-player raid") or "5-player", "plain" } }
    if x.info.new then tags[#tags + 1] = { "New on Forever", "gold" } end
    local line, chipList
    if kind == "next" then
      tags[#tags + 1] = { "Next tier", "warn" }
      line = string.format("%d upgrades waiting once you're a little higher.", x.laterCount)
      chipList = chips(x.ups, true, 3)
    elseif x.status == "soon" then
      tags[#tags + 1] = { "Soon", "warn" }
      line = string.format("%d upgrades for you once you're closer to level %d.", x.laterCount, x.info.min)
      chipList = chips(x.ups, true, 3)
    elseif x.count == 0 then
      line = "Nothing here beats what you wear."
      chipList = {}
    else
      line = string.format("%d upgrades for you now:", x.count)
      chipList = chips(x.ups, false, 3)
    end
    return { art = slug(x.name), pic = "Interface\\Icons\\INV_Misc_Key_14", title = x.name, tags = tags, line = line,
      chips = chipList, highlight = kind == "next",
      actions = { { "Go to the entrance", function() D:Go(x) end, "Sets the arrow to the dungeon's entrance." } } }
  end
  r({ "header", "Next tier", icon = "INV_Chest_Plate06" })
  r({ "cards", function()
    local n = D:NextTier()
    return n and { cardFor(n, "next") } or {}
  end })
  r({ "note", function() return D:NextTier() and "" or "No upcoming dungeon with gear for you in the next few levels." end })
  r({ "header", "Ready now (level " .. level .. ")", icon = "INV_Misc_Key_14" })
  r({ "cards", function()
    local out = {}
    for _, x in ipairs(D:Rank()) do if x.status == "ready" then out[#out + 1] = cardFor(x) end end
    return out
  end })
  r({ "note", function()
    for _, x in ipairs(D:Rank()) do if x.status == "ready" then return "" end end
    return "No dungeon in your level range yet."
  end })
  r({ "header", "Coming up", icon = "INV_Misc_PocketWatch_01" })
  r({ "cards", function()
    -- the next tier is already its own card above: not twice (tour 2026-11-19)
    local out, nxt = {}, D:NextTier()
    for _, x in ipairs(D:Rank()) do
      if x.status == "soon" and not (nxt and nxt.name == x.name) then out[#out + 1] = cardFor(x) end
    end
    return out
  end })
  r({ "note", "Upgrades are scored for your class against what you wear. Hover an item for its tooltip. Level ranges and loot are community data, not yet checked in game." })
  return rows
end

ns.Hub:AddTab("dungeons", "Dungeons", function(p)
  local rows = dungeonRows()
  -- which dungeon, and why (Intelligence/DungeonDecision.lua, OI04-14): a
  -- section on top; the existing rows below are unchanged
  if ns.DungeonDecision then
    table.insert(rows, 2, { "header", "Which dungeon, and why", icon = "INV_Misc_Key_14" })
    table.insert(rows, 3, { "cards", function() return ns.DungeonDecision.Cards() end })
  end
  UI:FormPage(p, rows)
end)

