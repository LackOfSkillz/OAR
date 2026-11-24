-- UI/Pages/World.lua
-- Waypoints and rare alert pages. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff

local function iconTiles(items, perRow)
  perRow = perRow or 6
  return function(host)
    local f = CreateFrame("Frame", nil, host)
    local TW, TH, GAP = 112, 76, 8
    f:SetSize(perRow * (TW + GAP), math.ceil(#items / perRow) * (TH + GAP))
    for i, it in ipairs(items) do
      local b = CreateFrame("Button", nil, f, ns.Theme:BackdropTemplate())
      b:SetSize(TW, TH)
      b:SetPoint("TOPLEFT", ((i - 1) % perRow) * (TW + GAP), -math.floor((i - 1) / perRow) * (TH + GAP))
      ns.Theme:ApplyPanel(b, "raised", "border")
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(36, 36)
      b.icon:SetPoint("TOP", 0, -8)
      if not (ns.Art and it[2] and ns.Art:Set(b.icon, it[2], "Interface\\Icons\\" .. (it[3] or "INV_Misc_QuestionMark"))) then
        b.icon:SetTexture("Interface\\Icons\\" .. (it[3] or "INV_Misc_QuestionMark"))
      end
      b.label = UI.Text(b, "normal", "text")
      b.label:SetPoint("BOTTOM", 0, 9)
      b.label:SetText(it[1])
      b:SetScript("OnClick", function() ns.Safe("tile:" .. it[1], it[4]) end)
      b:SetScript("OnEnter", function(self) ns.Theme:ApplyPanel(self, "hover", "gold") end)
      b:SetScript("OnLeave", function(self) ns.Theme:ApplyPanel(self, "raised", "border") end)
      UI.Tip(b, it[1], it[5] or ("Points the gold arrow at the nearest " .. it[1]:lower() .. "."))
    end
    return f
  end
end
ns.ClassPage = ns.ClassPage or {}
ns.ClassPage.IconTiles = iconTiles

-- The trainers that matter to this character (requirement 2026-11-20: waypoints
-- to all trainers and anything else relevant to the character):
-- class trainer, weapon master, pet trainer for hunters, the cooking, first
-- aid and fishing trainers everyone can use, and one per profession learned.
local SECONDARY = { "Cooking", "First Aid", "Fishing" }
local function trainerTiles()
  local items = {}
  local cls = ns.PlayerClass and ns.PlayerClass() or ""
  local clsName = C.Readable(C.Call("UnitClass", "player")) or "Class"
  items[#items + 1] = { clsName .. " trainer", "class_" .. cls:lower(), "INV_Misc_Book_09", Run("near class"),
    "Your " .. clsName:lower() .. " trainer: new spells and ranks." }
  items[#items + 1] = { "Weapon master", "pin_weaponmaster", "INV_Sword_04", Run("near trainer weapon master"), "Learn to use more kinds of weapons." }
  if cls == "HUNTER" then
    items[#items + 1] = { "Pet trainer", "pin_pettrainer", "Ability_Hunter_BeastCall", Run("near trainer pet trainer"), "Pet skills for your pet." }
  end
  local profs, seen = {}, {}
  for name, d in pairs(ns.db.char.professions or {}) do
    if type(d) == "table" and d.skill then profs[#profs + 1] = name seen[name] = true end
  end
  table.sort(profs)
  for _, n in ipairs(SECONDARY) do if not seen[n] then profs[#profs + 1] = n end end
  local icons = ns.ProfExtras and ns.ProfExtras.PROF_ICON or {}
  for _, name in ipairs(profs) do
    items[#items + 1] = { name, "prof_" .. name:lower():gsub(" ", ""), icons[name] or "INV_Misc_Book_09",
      (function()
        local d = seen[name] and ns.db.char.professions[name]
        local need = d and ns.Nearest and ns.Nearest.NextRank(d.max)
        return function()
          local _, msg = ns.Nearest:Go("trainer:" .. name:lower() .. (need and (":" .. need) or ""))
          ns.Print(tostring(msg))
        end
      end)(),
      (seen[name] and "Your " or "Learn ") .. name:lower() .. (seen[name] and " trainer: the next rank and new recipes." or " here: anyone can.") }
  end
  return items
end

local function placeTiles()
  local hunter = ns.PlayerClass and ns.PlayerClass() == "HUNTER"
  local places = {
    { "Inn", "pin_inn", "INV_Misc_Rune_01", Run("near inn"), "The nearest inn: rest for bonus XP and set your hearthstone." },
    { "Vendor", "pin_vendor", "INV_Misc_Bag_10", Run("near vendor"), "The nearest vendor: sell junk, buy food and drink." },
    { "Repair", "pin_repair", "Trade_BlackSmithing", Run("near repair"), "The nearest place to repair your gear." },
    { "Flight", "pin_flight", "Ability_Mount_Gryphon_01", Run("near flight"), "The nearest flight master." },
    { "Mail", "pin_mail", "INV_Letter_15", Run("near mail"), "The nearest mailbox." },
    { "Bank", "pin_bank", "INV_Misc_Coin_02", Run("near bank"), "The nearest bank." },
    { "Auction", "pin_auction", "INV_Misc_Coin_01", Run("near ah"), "The nearest auction house." },
    { "Spirit healer", "pin_spirit", "Spell_Holy_Resurrection", Run("near spirit"), "The nearest spirit healer." },
  }
  -- stable and ammo only for the class that needs them
  if hunter then
    places[#places + 1] = { "Stable", "pin_stable", "Ability_Hunter_BeastCall", Run("near stable"), "The nearest stable master." }
    places[#places + 1] = { "Ammo", "pin_ammo", "INV_Ammo_Arrow_02", Run("near ammo"), "The nearest arrow and bullet vendor." }
  end
  return places
end
ns.ClassPage.PlaceTiles, ns.ClassPage.TrainerTiles = placeTiles, trainerTiles

ns.Hub:AddTab("waypoints", "Waypoints", function(p)
  local places, trainers = placeTiles(), trainerTiles()
  local rows = function(n) return math.ceil(n / 6) * 84 + 4 end
  UI:FormPage(p, {
    { "header", "Your arrow" },
    -- where the arrow points, at a glance (premium rebuild 2026-11-18)
    { "stats", function()
      local W = ns.Waypoints
      local w = W.current
      local d = w and W:Distance()
      local q = W:Settings().queue or {}
      return {
        { cap = "Arrow to", value = w and tostring(w.title or "a spot") or "Nothing", color = w and "gold" or nil },
        { cap = "Distance", value = d and (math.floor(d + 0.5) .. " yd") or "—" },
        { cap = "Queued stops", value = tostring(#q), note = #q > 0 and "the arrow moves on by itself" or "none" },
      }
    end },
    { "note", function()
      local w = ns.Waypoints.current
      return w and ("Arrow to " .. tostring(w.title) .. ", " .. tostring(ns.Waypoints:Activity())) or "No waypoint set."
    end },
    { "buttons", { { "Clear arrow", Run("way clear") }, { "Say my coordinates", Run("coords") } } },
    { "header", "Take me to the nearest..." },
    { "note", "Press a place: the gold arrow points to the closest one Outrider knows. Follow it; it clears when you arrive." },
    -- picture tiles (requirement 2026-11-20): the map-pin pictures, one press each
    { "custom", iconTiles(places, 6), rows(#places) },
    { "header", "Your trainers" },
    { "note", "Every trainer that matters to you, nearest first when you press one. A trainer Outrider hasn't seen yet says so: talk to one once, or stand next to it." },
    { "custom", iconTiles(trainers, 6), rows(#trainers) },
    { "header", "Go to map coordinates" },
    { "note", "Got coordinates from a quest or a friend, like 45.2 61.8? Type them here." },
    { "input", "Coordinates (x y)", "45.2 61.8", "Set arrow", function(t) ns.Slash:Run("way " .. t) end },
    { "check", "Arrow to the spirit healer when you die", function() return set("Nearest").spiritOnDeath end,
      function(on) set("Nearest").spiritOnDeath = on end },
  })
end)

-- ---------------------------------------------------------- Rare alerts
ns.Hub:AddTab("rarealerts", "Rare alerts", function(p)
  local function watched()
    local out = {}
    for k in pairs(set("RareScan").watch or {}) do out[#out + 1] = k end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
  end
  UI:FormPage(p, {
    { "header", "Watch list" },
    { "input", "Watch a rare", "Mystmane, or an NPC id", "Watch", function(t) ns.Slash:Run("watch " .. t) end },
    { "note", "Click a name to stop watching it." },
    { "list", 5, function(row, k) row.text:SetText(ns.TitleCase(tostring(k))) end,
      function(k) ns.Slash:Run("unwatch " .. tostring(k)) p:Refresh() end, watched,
      empty = "No rare on your watch list. Type a name above and press Watch." },
    { "header", "Timers" },
    { "note", function() return ns.RareTimer and ns.RareTimer:Activity() or "" end, 36 },
    { "header", "How you're told" },
    { "check", "Sound", function() return set("RareAlerts").sound end, function(on) set("RareAlerts").sound = on end },
    { "check", "Different sound for rare elites", function() return set("RareAlerts").eliteSound ~= false end, function(on) set("RareAlerts").eliteSound = on end },
    { "note", "A rare flashes blue. A rare elite flashes red for longer, with its own alarm: it hits hard." },
    { "buttons", { { "Try a rare alert", function() ns.RareAlerts:Preview(false) end }, { "Try an elite alert", function() ns.RareAlerts:Preview(true) end } } },
    { "check", "Pop-up", function() return set("RareAlerts").toast end, function(on) set("RareAlerts").toast = on end },
    { "check", "Only rares on your watch list", function() return set("RareAlerts").mode == "watch" end,
      function(on) set("RareAlerts").mode = on and "watch" or "all" end },
    { "header", "Recently met" },
    { "buttons", { { "Last 10 NPCs met", Run("discovered 10") }, { "Rares tab", function() ns.Hub.frame.tabBar:Select("rares") end } } },
  })
end)

