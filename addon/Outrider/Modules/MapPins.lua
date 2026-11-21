-- Modules/MapPins.lua  (P3-03 world map pins, P3-05 pin cards)
-- Pins for known places (POICapture) and rares (packs, sightings, discovery)
-- on the world map. Drawn as our own small frames on the map canvas
-- (WorldMapFrame:GetCanvas()), placed at x * width, y * height, redrawn when
-- the map opens or changes (post-hooks only, nothing Blizzard's replaced).
-- Click a pin: a card with what we know and a Waypoint button (a normal
-- frame, no secure actions, so it works in combat too).
-- Filters per character: which kinds show.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("MapPins", {
  title = "World map pins",
  phase = "P3",
  order = 53,
  defaults = { hidden = {} },
})
ns.MapPins = M

local COLORS = {
  rare = "warn", spirit_healer = "accent", flight_master = "good", vendor = "text", repair = "text",
  trainer = "accent", bank = "good", auction = "good", stable_master = "good", mailbox = "muted",
  innkeeper = "good", guild_master = "muted", tabard = "muted",
}
local LABELS = {
  rare = "Rare", spirit_healer = "Spirit healer", flight_master = "Flight master", vendor = "Vendor",
  repair = "Repair", trainer = "Trainer", bank = "Bank", auction = "Auction house",
  stable_master = "Stable master", mailbox = "Mailbox", note = "Your map note", innkeeper = "Innkeeper", guild_master = "Guild master",
  tabard = "Tabard vendor", quest_giver = "Quest giver", herb = "Herb", ore = "Ore", fish = "Fishing spot", pool = "Fishing pool",
  guildmate = "Guildmate", trail = "Your trail", ride = "Ride you took", transport = "Portal, boat or zeppelin",
  dungeon = "Dungeon entrance", objective = "Quest objective", turnin = "Quest turn-in", qpath = "Quest NPC path",
}
M.LABELS = LABELS

-- Markers (Gary, 2026-11-11: "less 8 bit", colour by group, different
-- symbols): the client's own minimap tracking icons as the symbol, a soft
-- ring in the group colour behind it. Groups: merchant, trainer, service, rare.
local TRACK = "Interface\\Minimap\\Tracking\\"
local GROUP = {
  vendor = "merchant", repair = "merchant",
  trainer = "trainer",
  innkeeper = "service", bank = "service", auction = "service", flight_master = "service", stable_master = "service",
  mailbox = "service", guild_master = "service", tabard = "service", spirit_healer = "service",
  rare = "rare", note = "service", quest_giver = "quest", herb = "gather", ore = "gather", fish = "gather", pool = "gather", guildmate = "guild",
  trail = "trail", ride = "ride", transport = "ride", dungeon = "dungeon", objective = "quest", turnin = "quest", qpath = "quest",
}
M.RARE_STATE = { alive = { 1, 0.25, 0.25 }, open = { 1, 0.78, 0.3 }, dead = { 0.5, 0.5, 0.55 }, waiting = { 0.5, 0.5, 0.55 } }
M.GROUP_COLOR = {
  merchant = { 1.00, 0.80, 0.25 }, trainer = { 0.35, 0.65, 1.00 }, service = { 0.40, 0.85, 0.45 }, rare = { 1.00, 0.30, 0.30 },
  quest = { 0.75, 0.45, 1.00 }, gather = { 0.80, 0.60, 0.35 }, guild = { 0.25, 1.00, 0.25 },
  trail = { 0.95, 0.78, 0.35 }, ride = { 0.55, 0.75, 1.00 }, dungeon = { 0.85, 0.40, 1.00 },
}
M.GROUP_LABEL = { merchant = "Merchants", trainer = "Trainers", service = "Services", rare = "Rares", quest = "Quest givers", gather = "Herbs, ore & fish" }
local ICON = {
  innkeeper = TRACK .. "Innkeeper", bank = TRACK .. "Banker", auction = TRACK .. "Auctioneer",
  flight_master = TRACK .. "FlightMaster", stable_master = TRACK .. "StableMaster", mailbox = TRACK .. "Mailbox",
  repair = TRACK .. "Repair", spirit_healer = "Interface\\Icons\\Spell_Holy_Resurrection",
  guild_master = "Interface\\Icons\\INV_Misc_Note_02", tabard = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
  rare = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
  ride = "Interface\\Icons\\INV_Misc_Map_01",
  transport = "Interface\\Icons\\Spell_Arcane_TeleportStormWind",
  objective = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
  turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  dungeon = "Interface\\Icons\\INV_Misc_Key_14",
  quest_giver = "Interface\\GossipFrame\\AvailableQuestIcon",
  -- these fell back to the game's "no icon" circle (a dark "..." on the map)
  qpath = "Interface\\COMMON\\Indicator-Yellow", note = "Interface\\Icons\\INV_Misc_Note_01",
  guildmate = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon",
  herb = "Interface\\Icons\\INV_Misc_Flower_02", ore = "Interface\\Icons\\INV_Ore_Copper_01", fish = "Interface\\Icons\\INV_Misc_Fish_02", pool = "Interface\\Icons\\INV_Misc_Fish_14",
}
-- class names that make a trainer a class trainer (else profession)
local CLASSES = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid", "Pet" }

function M.Group(kind) return GROUP[kind] or "service" end

-- Texture path for a pin (pure: by kind, then title / goods for vendors and trainers).
-- Outrider's own pin glyphs (art batch 4c) replace the game icons as they
-- arrive; anything not delivered keeps the game icon below.
M.PIN_ART = {
  repair = "pin_repair", trainer = "pin_trainer", flight_master = "pin_flight", innkeeper = "pin_inn",
  mailbox = "pin_mail", bank = "pin_bank", auction = "pin_auction", stable_master = "pin_stable",
  spirit_healer = "pin_spirit", rare = "pin_rare", quest_giver = "pin_questgiver", turnin = "pin_turnin",
  objective = "pin_objective", herb = "pin_herb", ore = "pin_ore", fish = "pin_fish", pool = "pin_fish",
  dungeon = "pin_dungeon", note = "pin_note",
}
local function ownArt(name) return name and ns.Art and ns.Art:Path(name) or nil end

function M.IconFor(pin)
  if pin.icon then return pin.icon end
  local kind, p = pin.kind, pin.poi or pin
  if kind == "vendor" then
    local goods = p and p.goods and table.concat(p.goods, ",") or ""
    local title = (p and p.title or ""):lower()
    local ammo = goods:find("ammo") or title:find("bowyer") or title:find("gunsmith") or title:find("ammo")
    local own = ownArt(ammo and "pin_ammo" or "pin_vendor")
    if own then return own end
  else
    local own = ownArt(M.PIN_ART[kind])
    if own then return own end
  end
  if kind == "trainer" then
    local title = p and p.title or ""
    for _, c in ipairs(CLASSES) do if title:find(c, 1, true) then return TRACK .. "Class" end end
    return TRACK .. "Profession"
  end
  if kind == "vendor" then
    local goods = p and p.goods and table.concat(p.goods, ",") or ""
    local title = (p and p.title or ""):lower()
    if goods:find("ammo") or title:find("bowyer") or title:find("gunsmith") or title:find("ammo") then return TRACK .. "Ammunition" end
    if goods:find("food") or title:find("food") or title:find("cook") or title:find("innkeeper") then return TRACK .. "Food" end
    if goods:find("reagent") or title:find("reagent") then return TRACK .. "Reagents" end
    if title:find("poison") then return TRACK .. "Poisons" end
    return TRACK .. "Repair"
  end
  return ICON[kind] or (TRACK .. "None")
end

-- Gathering nodes are a thin hollow square (Gary, 2026-11-14): Blizzard's
-- Find Herbs / Find Minerals dot shows inside it when the node is really up,
-- an empty square means it's gone. Green = Gary saw it up lately, grey = he
-- picked it lately (LootLog:NodeState).
M.GATHER = { herb = true, ore = true, fish = true }
M.STATE_COLOR = { up = { 0.35, 1.00, 0.35, 1 }, picked = { 0.55, 0.55, 0.55, 0.6 } }

local function outline(frame)
  if frame.edges then return frame.edges end
  local e = {}
  local sides = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }
  for i, pts in ipairs(sides) do
    local t = frame:CreateTexture(nil, "OVERLAY")
    t:SetPoint(pts[1]) t:SetPoint(pts[2])
    if i <= 2 then t:SetHeight(1.5) else t:SetWidth(1.5) end
    e[i] = t
  end
  frame.edges = e
  return e
end

function M.Paint(frame, pin)
  local hollow = M.GATHER[pin.kind] or pin.box
  if hollow then
    local st = not pin.box and ns.LootLog and ns.LootLog.enabled and ns.LootLog:NodeState(pin.mapID, pin.x, pin.y)
    local c = pin.box or M.STATE_COLOR[st or ""] or M.GROUP_COLOR.gather or { 0.4, 0.9, 0.4 }
    frame.ring:Hide() frame.icon:Hide()
    local edges = outline(frame)
    for i, t in ipairs(edges) do
      local w = pin.box and 2.5 or 1.5
      if i <= 2 then t:SetHeight(w) else t:SetWidth(w) end
      t:SetColorTexture(c[1], c[2], c[3], c[4] or 0.9) t:Show()
    end
    return
  end
  -- Focus dims *other quest pins*, not unrelated rares, vendors or gathering.
  -- Both world-map and minimap pins use this single painting routine.
  local focus = ns.QuestTracker and ns.QuestTracker.enabled and ns.QuestTracker:Settings().focus
  local isQuest = pin.kind == "objective" or pin.kind == "turnin" or pin.kind == "qpath" or pin.kind == "quest_giver"
  local isFocused = pin.questID == focus
  if focus and isQuest and pin.quests then
    for _, quest in ipairs(pin.quests) do
      if quest.id == focus or quest.questID == focus then isFocused = true break end
    end
  end
  frame:SetAlpha(focus and isQuest and not isFocused and 0.3 or 1)
  frame.ring:Show() frame.icon:Show()
  if frame.edges then for _, t in ipairs(frame.edges) do t:Hide() end end
  local c = pin.ringColor or pin.questColor or M.GROUP_COLOR[M.Group(pin.kind)] or { 1, 1, 1 }
  frame.ring:SetColorTexture(c[1], c[2], c[3], (pin.questColor or pin.ringColor) and 0.95 or 0.55)
  -- a dead rare dims a little, never out of sight: it still marks where it
  -- spawns (Gary, 2026-11-20: a dead rare's pin was too faint to find)
  if pin.faded then frame:SetAlpha(0.85) end
  local ok = frame.icon:SetTexture(M.IconFor(pin))
  if ok == false then
    frame.icon:SetColorTexture(c[1], c[2], c[3], 1) -- missing file: plain round dot
  else
    frame.icon:SetVertexColor(1, 1, 1, 1)
  end
end

-- Round ring + icon on a marker frame of the given size.
function M.Decorate(frame, size)
  frame:SetSize(size, size)
  frame.ring = frame:CreateTexture(nil, "BACKGROUND")
  frame.ring:SetAllPoints()
  local mask = frame.CreateMaskTexture and frame:CreateMaskTexture()
  if mask then
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    frame.ring:AddMaskTexture(mask)
  end
  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetPoint("TOPLEFT", 2, -2)
  frame.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  if mask and frame.icon.AddMaskTexture then frame.icon:AddMaskTexture(mask) end
end

-- Pins for one map: { id, kind, x, y, name, npcID?, poi?, rare? } (pure).
-- PinsFor is called 5x a second by the minimap while moving; building new
-- tables each time made memory read 3 MB (2026-11-11). Results are cached
-- per map and dropped when a place, sighting, filter or rare pack changes.
M.cache = {}
function M:Invalidate() self.cache = {} end

ns.Events:On("OTR_POI_ADDED", M, function() M:Invalidate() end)
ns.Events:On("OTR_SIGHTING_ADDED", M, function() M:Invalidate() end)
ns.Events:On("OTR_DATA_CHANGED", M, function() M:Invalidate() end)

local NONE = {}
function M:PinsFor(mapID)
  if self:Settings().off then return NONE end
  if ns.LocationShare and ns.LocationShare:Prune() then self:Invalidate() end
  -- also rebuild if places were added or removed without an event
  local n = 0
  for _ in pairs(ns.db.global.pois or {}) do n = n + 1 end
  local cached = self.cache[mapID]
  if cached and cached.poiCount == n then return cached.pins end
  local out = self:BuildPins(mapID)
  self.cache[mapID] = { pins = out, poiCount = n }
  return out
end

-- Quest givers: attach the quests on offer for this character and the color
-- of the best one; false when a known giver has nothing left to offer.
function M.AddQuests(pin, packEntry)
  if not packEntry or not packEntry.quests then return true end
  local list = ns.NPCPack:QuestsFor(packEntry)
  if #list == 0 then return false end
  pin.quests, pin.questColor = list, ns.NPCPack.DIFF_COLOR[list[1].diff]
  return true
end

-- Questie-style quest tooltip (gallery idea, 2026-11-18): each NPC's name in
-- green, then its quests as "[15] Dry Times" in difficulty colour with the
-- state on the right ("Available" / "Complete"), for every quest NPC stacked
-- on this spot. Returns true when it drew something.
local function addGiver(tt, d)
  local isTurnin = d.kind == "turnin"
  if not (isTurnin or (d.kind == "quest_giver" and d.quests and #d.quests > 0)) then return false end
  local name = d.giver or d.npcName or (isTurnin and (d.title or ""):match(" to (.+)$")) or d.name or "?"
  tt:AddLine(tostring(name), 0.4, 0.85, 0.5)
  if isTurnin then
    local quest = tostring(d.name or ""):gsub("^Turn in: ", "")
    tt:AddDoubleLine("  " .. quest, "Complete", 1, 0.82, 0, 0.4, 0.85, 0.5)
    return true
  end
  for i = 1, math.min(6, #d.quests) do
    local q = d.quests[i]
    local c = ns.NPCPack.DIFF_COLOR[q.diff] or { 1, 1, 1 }
    tt:AddDoubleLine(string.format("  [%d] %s", q.level or 0, tostring(q.name)), "Available", c[1], c[2], c[3], 1, 0.82, 0)
  end
  if #d.quests > 6 then tt:AddLine(string.format("  and %d more", #d.quests - 6), 0.56, 0.59, 0.65) end
  return true
end

function M.QuestTooltip(tt, data)
  local drew = addGiver(tt, data)
  for _, m in ipairs(data.more or {}) do
    if addGiver(tt, m) then drew = true end
  end
  return drew
end

-- Tooltip/card lines for a quest giver's quests (at most 5).
function M.QuestLines(pin)
  local out = {}
  for i = 1, math.min(5, #(pin.quests or {})) do out[#out + 1] = ns.NPCPack.QuestLine(pin.quests[i]) end
  if pin.quests and #pin.quests > 5 then out[#out + 1] = string.format("and %d more", #pin.quests - 5) end
  return out
end

function M:BuildPins(mapID)
  local out, hidden = {}, self:Settings().hidden
  local faction = C.Call("UnitFactionGroup", "player")
  local own = {}
  for id, p in pairs(ns.db.global.pois or {}) do
    if p.npcID then own[p.npcID] = true end
    if p.mapID == mapID and not hidden[p.kind] and (p.faction == nil or p.faction == faction) then
      local pin = { id = id, kind = p.kind, mapID = mapID, x = p.x, y = p.y, name = p.name or LABELS[p.kind], npcID = p.npcID, poi = p }
      if M.AddQuests(pin, p.kind == "quest_giver" and ns.NPCPack and p.npcID and ns.NPCPack:Npc(p.npcID, mapID)) then out[#out + 1] = pin end
    end
  end
  -- The leveling guides (Data/Leveling.lua): trainers, flight masters,
  -- dungeon entrances and quest hubs, unless you recorded that NPC yourself.
  -- trust: your own places, then the NPC pack, then the guides (docs/POI_AUDIT.md:
  -- the pack was wrong 1% of the time against Gary's sightings, the guides 7%)
  local ownName, guided = {}, {}
  for _, p in pairs(ns.db.global.pois or {}) do if p.name then ownName[p.name] = true end end
  if ns.NPCPack then for _, p in ipairs(ns.NPCPack:PlacesFor(mapID)) do if p.name then ownName[p.name] = true end end end
  local zone = ns.Travel and ns.Travel.ZoneName(mapID)
  local GUIDE_KIND = { trainer = "trainer", flight_master = "flight_master", dungeon = "dungeon", quest_hub = "note" }
  for _, g in ipairs(zone and ns.Data:All("place") or {}) do
    local kind = GUIDE_KIND[g.kind]
    if kind and g.zone == zone and not ownName[g.name] then
      guided[g.name] = true
      if not hidden[kind] and (g.faction == nil or g.faction == faction) then
        out[#out + 1] = { id = "guide-" .. g.id, kind = kind, mapID = mapID, x = g.x, y = g.y, name = g.name,
          poi = { kind = kind, name = g.name, title = g.title, source = "guide", note = g.note } }
      end
    end
  end
  -- Optional private NPC pack (D10); NPCs Gary visited himself win.
  if ns.NPCPack then
    for _, p in ipairs(ns.NPCPack:PlacesFor(mapID)) do
      if not own[p.npcID] and not hidden[p.kind] and (p.faction == nil or p.faction == faction) then
        local pin = { id = p.id, kind = p.kind, mapID = mapID, x = p.x, y = p.y, name = p.name, npcID = p.npcID, poi = p }
        if M.AddQuests(pin, p.kind == "quest_giver" and p) then out[#out + 1] = pin end
      end
    end
  end
  if ns.MapTab then for _, note in ipairs(ns.MapTab:NotesFor(mapID)) do out[#out + 1] = note end end
  -- Guildmates sharing their location (P8-04), class colored
  if ns.LocationShare and ns.LocationShare.enabled and not hidden.guildmate then
    local colors = rawget(_G, "RAID_CLASS_COLORS") or {}
    for _, g in ipairs(ns.LocationShare:PeersOn(mapID)) do
      local cc = g.class and colors[g.class]
      local cls = g.class and (g.class:sub(1, 1) .. g.class:sub(2):lower())
      out[#out + 1] = { id = "guild-" .. g.full, kind = "guildmate", mapID = mapID, x = g.x, y = g.y, name = g.name,
        ringColor = cc and { cc.r, cc.g, cc.b } or nil,
        icon = cls and ("Interface" .. "\\" .. "Icons" .. "\\" .. "ClassIcon_" .. cls) or nil }
    end
  end
  -- Gathering nodes Gary found (LootLog)
  if ns.LootLog and ns.LootLog.enabled then
    for i, n in ipairs(ns.LootLog:NodesFor(mapID)) do
      if not hidden[n.kind] then
        out[#out + 1] = { id = "node-" .. n.kind .. "-" .. i, kind = n.kind, mapID = mapID, x = n.x, y = n.y,
          name = (n.name or n.kind) .. " (x" .. (n.count or 1) .. ")" ..
            (n.sharedBy and (", from " .. (tostring(n.sharedBy):match("^[^-]+") or "guild")) or "") }
      end
    end
  end
  -- Portals, boats, zeppelins and the tram leaving from this map, where the
  -- departure spot is known (a guide's spot, or the dock by the flight
  -- master); rides you took are the Trail's own pins below.
  if not hidden.transport and ns.Travel then
    for i, d in ipairs(ns.Travel:Departures()) do
      local a = d.from
      if a.mapID == mapID and d.where ~= "zone" and d.where ~= "taken" then
        out[#out + 1] = { id = "transport-" .. i, kind = "transport", mapID = mapID, x = a.x, y = a.y, name = d.name,
          title = d.where == "flight" and ("from " .. tostring(d.place) .. ": the dock is by the flight master") or ("from " .. tostring(d.place)) }
      end
    end
  end
  -- Dungeon and raid entrances (gap analysis 2026-11-17), from the dungeon pack
  if not hidden.dungeon and ns.DungeonGuide then
    local ok, byName = pcall(ns.DungeonGuide.ByName, ns.DungeonGuide)
    for name, e in pairs(ok and byName or {}) do
      if e.map == mapID and e.x and e.y then
        out[#out + 1] = { id = "dungeon-" .. name, kind = "dungeon", mapID = mapID, x = e.x, y = e.y, name = name,
          title = "Dungeon entrance (community data, unverified)" }
      end
    end
  end
  -- Breadcrumbs: where you walked, and rides you took from here (Trail)
  if ns.Trail and ns.Trail.enabled then
    for _, pin in ipairs(ns.Trail:Pins(mapID, hidden)) do out[#out + 1] = pin end
  end
  -- Where your quests' objectives are (QuestObjectives, from the private quest pack)
  if ns.QuestObjectives then
    for _, pin in ipairs(ns.QuestObjectives:Pins(mapID, hidden)) do out[#out + 1] = pin end
  end
  -- Herb and ore spawns from the node pack, for what this character can gather
  if ns.NodePack then
    for _, pin in ipairs(ns.NodePack:Pins(mapID, hidden)) do out[#out + 1] = pin end
  end
  if not hidden.rare then
    local seen = {}
    local function addRare(npcID, name, x, y)
      if seen[npcID] or not x or not y then return end
      seen[npcID] = true
      out[#out + 1] = { id = "rare-" .. npcID, kind = "rare", mapID = mapID, x = x, y = y, name = name, npcID = npcID, rare = true }
    end
    for npcID, list in pairs(ns.db.global.sightings or {}) do
      for i = #list, 1, -1 do
        local s = list[i]
        if s.mapID == mapID then
          local d = ns.db.global.discovered and ns.db.global.discovered.npcs[npcID]
          local pack = ns.Data:Get("rare", npcID)
          addRare(npcID, (pack and pack.name) or (d and d.name) or ("NPC " .. npcID), s.x, s.y)
          break
        end
      end
    end
    for _, e in ipairs(ns.Data:All("rare")) do
      if e.mapID == mapID and e.spawns and e.spawns[1] then addRare(e.npcID, e.name, e.spawns[1].x, e.spawns[1].y) end
    end
    -- Spots Gary reported a rare at before Outrider saw it (Data poi kind
    -- "rare_spot", Gary 2026-11-20). Gone once a known rare pin is within ~4%.
    for _, e in ipairs(ns.Data:All("poi")) do
      if e.kind == "rare_spot" and e.mapID == mapID then
        local near = false
        for _, pin in ipairs(out) do
          if pin.kind == "rare" and math.abs(pin.x - e.x) < 0.04 and math.abs(pin.y - e.y) < 0.04 then near = true break end
        end
        if not near then
          out[#out + 1] = { id = "rarespot-" .. e.id, kind = "rare", mapID = mapID, x = e.x, y = e.y, rare = true,
            name = e.name or "A rare spawns near here", stateLine = e.note }
        end
      end
    end
    -- Every rare and rare elite in the creature pack (Gary, 2026-11-13: "how
    -- was I supposed to find that rare elite?"), at every spawn spot it has
    -- (Gary, 2026-11-14: Slydris has 4).
    local mobs = ns.Finder and ns.Finder:Mobs()
    for _, r in ipairs(mobs and mobs[mapID] or {}) do
      local rank, pts = r[5], r[6]
      if (rank == 2 or rank == 4) and pts and pts[1] then
        local label = string.format("%s (%s, level %d)", r[2], rank == 2 and "rare elite" or "rare", r[4])
        local many = #pts > 2
        -- Every spawn spot, also for a rare already seen (Gary, 2026-11-17:
        -- Den'dralass's other spots were hidden behind her one sighting).
        local first = 3
        if not seen[r[1]] then
          addRare(r[1], many and (label .. ", spawn spot 1") or label, pts[1], pts[2])
        else
          first = 1
        end
        for i = first, #pts - 1, 2 do
          out[#out + 1] = { id = "rare-" .. r[1] .. "-" .. ((i + 1) / 2), kind = "rare", mapID = mapID, x = pts[i], y = pts[i + 1],
            name = label .. ", spawn spot " .. ((i + 1) / 2), npcID = r[1], rare = true }
        end
      end
    end
    -- Rare pins coloured by what Outrider knows on your layer (gallery idea from
    -- RareScanner, 2026-11-18): red = alive now, amber = respawn window open,
    -- grey and faded = dead or waiting; the tooltip says it in words.
    local S, layer = ns.Sightings, ns.Layers and ns.Layers.current
    if S and S.Window then
      for _, pin in ipairs(out) do
        if pin.kind == "rare" and pin.npcID then
          local ok, w = pcall(S.Window, S, pin.npcID, layer)
          local st = ok and type(w) == "table" and w.state or nil
          -- "alive" sticks to the last sighting: red only if that was recent
          if st == "alive" and not (w.last and w.last.t and time() - w.last.t < 900) then st = "stale" end
          pin.ringColor = M.RARE_STATE[st or ""]
          pin.faded = st == "dead" or st == "waiting"
          if st and st ~= "unknown" and S.Describe then
            local ok2, line = pcall(S.Describe, S, pin.npcID, layer)
            if ok2 then pin.stateLine = line end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

-- ------------------------------------------------------------ show / hide
-- (Gary, 2026-11-17: "be able to hide them or show them in the ui") A
-- "Pins" button on the world map opens switches per group of pins and one
-- for all of them; the same settings as the Map pins tab on Map and places, per character, also
-- for the minimap.
M.MENU = {
  { "Rares", { "rare" } },
  { "Quests", { "quest_giver", "objective", "turnin", "qpath" } },
  { "Vendors and repair", { "vendor", "repair" } },
  { "Trainers", { "trainer" } },
  { "Services", { "innkeeper", "bank", "auction", "flight_master", "stable_master", "mailbox", "guild_master", "tabard", "spirit_healer" } },
  { "Herbs, ore and fish", { "herb", "ore", "fish", "pool" } },
  { "Travel and dungeons", { "transport", "ride", "dungeon" } },
  { "Your trail", { "trail" } },
  { "Guildmates", { "guildmate" } },
  { "Your notes", { "note" } },
}

function M:AllShown() return not self:Settings().off end

function M:GroupShown(kinds)
  local hidden = self:Settings().hidden
  for _, k in ipairs(kinds) do if not hidden[k] then return true end end
  return false
end

function M:Changed()
  self:Invalidate()
  if self.map and self.map:IsShown() then self:Refresh() end
  local mini = ns.Modules:Get("MinimapPins")
  if mini and mini.enabled and mini.Update then mini:Update() end
  if self.menu and self.menu:IsShown() then self.menu:Sync() end
end

function M:SetGroup(kinds, on)
  local hidden = self:Settings().hidden
  for _, k in ipairs(kinds) do hidden[k] = (not on) or nil end
  self:Changed()
end

function M:SetAll(on)
  self:Settings().off = (not on) or nil
  self:Changed()
end

function M:ToggleMenu()
  if not self.menu then
    local f = CreateFrame("Frame", "Outrider_MapPinsMenu", self.map, ns.Theme:BackdropTemplate())
    ns.Theme:ApplyPanel(f, "raised", "border")
    f:SetFrameStrata("DIALOG")
    f:SetSize(240, 40 + (#M.MENU + 1) * 26)
    f:SetPoint("TOPRIGHT", self.button, "BOTTOMRIGHT", 0, -4)
    local head = ns.UI.Text(f, "normal", "goldText")
    head:SetPoint("TOPLEFT", 10, -10)
    head:SetText("Outrider pins")
    f.rows = {}
    local all = ns.UI:Check(f, "All Outrider pins", function() return M:AllShown() end, function(on) M:SetAll(on) end)
    all:SetPoint("TOPLEFT", 6, -30)
    all:SetWidth(228)
    f.rows[1] = all
    for i, g in ipairs(M.MENU) do
      local kinds = g[2]
      local row = ns.UI:Check(f, g[1], function() return M:GroupShown(kinds) end, function(on) M:SetGroup(kinds, on) end)
      row:SetPoint("TOPLEFT", 6, -30 - i * 26)
      row:SetWidth(228)
      f.rows[#f.rows + 1] = row
    end
    function f:Sync() for _, r in ipairs(self.rows) do r:Refresh() end end
    f:Hide()
    self.menu = f
  end
  self.menu:SetShown(not self.menu:IsShown())
  if self.menu:IsShown() then self.menu:Sync() end
end

function M:MakeButton()
  if self.button or not self.map then return end
  local b = ns.UI:Button(self.map, "Pins", 60, function() M:ToggleMenu() end)
  b:SetFrameStrata("HIGH")
  local anchor = self.map.ScrollContainer or self.map
  b:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -8, -8)
  self.button = b
end

function M:OnEnable()
  local map = rawget(_G, "WorldMapFrame")
  if not map or not map.GetCanvas then self:Warn("no world map canvas: pins off") return end
  self.map = map
  if not self.hooked then
    self.hooked = true
    map:HookScript("OnShow", function() if M.enabled then M:MakeButton() M:Refresh() end end)
    if type(map.OnMapChanged) == "function" then
      hooksecurefunc(map, "OnMapChanged", function() if M.enabled then M:Refresh() end end)
    end
  end
  self:On("OTR_POI_ADDED", function(mod) if mod.map:IsShown() then mod:Refresh() end end)
  self:On("OTR_SIGHTING_ADDED", function(mod) if mod.map:IsShown() then mod:Refresh() end end)
  self.pool, self.used = self.pool or {}, {}
end

function M:OnDisable()
  self:ReleaseAll()
  if self.menu then self.menu:Hide() end
  if self.card then self.card:Hide() end
end

function M:ReleaseAll()
  for _, pin in ipairs(self.used or {}) do pin:Hide() self.pool[#self.pool + 1] = pin end
  self.used = {}
end

-- World map readability (Gary, 2026-11-11: "having trouble seeing my position
-- and direction on the map"): smaller pins, drawn under Blizzard's pins, a
-- clear circle around the player, and pins of the same group that sit
-- within CLUSTER of each other merged into one ("and 3 more here" on hover).
-- Rares and guildmates are never merged.
M.PIN_SIZE, M.CLUSTER, M.CLEAR = 13, 0.02, 0.03
M.RARE_SCALE = 2 -- rares on the zone map: twice the size of other pins
local NO_MERGE = { rare = true, note = true, guild = true, trail = true, ride = true, transport = true }

function M.Declutter(pins, px, py)
  local out, cells = {}, {}
  for _, p in ipairs(pins) do
    local dx, dy = px and (p.x - px), py and (p.y - py)
    local nearPlayer = dx and (dx * dx + dy * dy) < M.CLEAR * M.CLEAR
    if not nearPlayer then
      local group = M.Group(p.kind)
      if NO_MERGE[group] then
        out[#out + 1] = p
      else
        local key = group .. ":" .. math.floor(p.x / M.CLUSTER) .. ":" .. math.floor(p.y / M.CLUSTER)
        local head = cells[key]
        if head then
          head.more = head.more or {}
          head.more[#head.more + 1] = p
        else
          local copy = {}
          for k, v in pairs(p) do copy[k] = v end
          copy.more = nil
          cells[key] = copy
          out[#out + 1] = copy
        end
      end
    end
  end
  return out
end

-- Frame level for our pins (Gary, 2026-11-17: Zephras Isle map showed none
-- of 300 built pins). "canvas level + 1" can sit under Blizzard's map art
-- layers; the map's own pin level manager knows the real order. Our pins go
-- just under the town/area icons (and so under the player arrow).
function M:PinLevel(canvas)
  local map = self.map
  local mgr = map and map.GetPinFrameLevelsManager and select(2, pcall(map.GetPinFrameLevelsManager, map))
  if type(mgr) == "table" and mgr.GetValidFrameLevel then
    local ok, lvl = pcall(mgr.GetValidFrameLevel, mgr, "PIN_FRAME_LEVEL_AREA_POI")
    if ok and type(lvl) == "number" and lvl > 1 then return lvl - 1, "manager" end
  end
  return (canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 1, "canvas"
end

function M:AcquirePin(canvas)
  local pin = table.remove(self.pool)
  if not pin then
    pin = CreateFrame("Button", nil, canvas)
    M.Decorate(pin, M.PIN_SIZE)
    -- rares stand out on the zone map: a red halo and the name under the pin
    pin.halo = pin:CreateTexture(nil, "BACKGROUND", nil, -1)
    pin.halo:SetPoint("CENTER")
    pin.halo:SetSize(M.PIN_SIZE + 8, M.PIN_SIZE + 8)
    pin.halo:SetColorTexture(1, 0.2, 0.2, 0.45)
    if pin.CreateMaskTexture and pin.halo.AddMaskTexture then
      local m = pin:CreateMaskTexture()
      if m then m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m:SetAllPoints(pin.halo)
      pin.halo:AddMaskTexture(m) end
    end
    pin.halo:Hide()
    pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
    pin.label:Hide()
    pin:SetScript("OnClick", function(self) M:ShowCard(self.data) end)
    pin:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if (self.data.kind == "quest_giver" or self.data.kind == "turnin") and M.QuestTooltip(GameTooltip, self.data) then
        GameTooltip:Show()
        return
      end
      GameTooltip:AddLine(self.data.name or "?")
      local first, second = ns.POI.Describe(self.data.poi or self.data, LABELS[self.data.kind] or self.data.kind)
      GameTooltip:AddLine(first, ns.Theme:Color("muted"))
      if second then GameTooltip:AddLine(second, ns.Theme:Color("text")) end
      if self.data.stateLine then GameTooltip:AddLine(ns.TitleCase(self.data.stateLine:sub(1, 1)) .. self.data.stateLine:sub(2), ns.Theme:Color(self.data.ringColor and "goldText" or "muted")) end
      for _, l in ipairs(M.QuestLines(self.data)) do GameTooltip:AddLine(l) end
      if M.GATHER[self.data.kind] and ns.LootLog then
        local line, color = ns.LootLog:StateLine(self.data)
        if line then GameTooltip:AddLine(line, ns.Theme:Color(color)) end
      end
      local more = self.data.more
      if more and #more > 0 then
        GameTooltip:AddLine(string.format("and %d more here:", #more), ns.Theme:Color("muted"))
        for i = 1, math.min(6, #more) do GameTooltip:AddLine("  " .. tostring(more[i].name or more[i].kind), ns.Theme:Color("text")) end
      end
      GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  pin:SetParent(canvas)
  -- just above the map art, below Blizzard's own pins (player arrow, party, quests)
  pin:SetFrameLevel((self:PinLevel(canvas)))
  self.used[#self.used + 1] = pin
  return pin
end

function M:Refresh()
  if not self.map then return end
  self:ReleaseAll()
  local mapID = self.map.GetMapID and self.map:GetMapID()
  if not mapID then return end
  local canvas = self.map:GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = (canvas.GetScale and canvas:GetScale() or 1)
  local pmap, px, py = C.PlayerPosition("player")
  if pmap ~= mapID then px, py = nil, nil end
  for _, data in ipairs(M.Declutter(self:PinsFor(mapID), px, py)) do
    local pin = self:AcquirePin(canvas)
    pin.data = data
    -- keep pins the same size on screen when the map canvas is zoomed
    -- rares are twice the size, with a red halo and their name (Gary, 2026-11-20:
    -- "make it really noticeable")
    local big = data.kind == "rare" and not data.small
    pin:SetScale((data.small and 0.55 or big and M.RARE_SCALE or 1) / (scale > 0 and scale or 1))   -- breadcrumbs are small dots
    M.Paint(pin, data)
    if pin.halo then
      pin.halo:SetShown(big)
      -- the name once per rare (not on every extra spawn spot)
      local first = big and not tostring(data.id or ""):match("^rare%-%d+%-%d+$")
      pin.label:SetText(first and (tostring(data.name or ""):match("^([^%(,]+)") or "") or "")
      pin.label:SetShown(first and true or false)
      if first then pin:SetFrameLevel(pin:GetFrameLevel() + 2) end
    end
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", data.x * w * scale, -data.y * h * scale)
    pin:Show()
  end
  self.shown = #self.used
  if not self.logged then
    self.logged = true
    self:Info("map %d opened: %d pins", mapID, self.shown)
    -- where the pins really are, to check they're visible (one line a session)
    local lvl, how = self:PinLevel(canvas)
    local first = self.used[1]
    local fx, fy = first and first.GetCenter and first:GetCenter()
    local cl, cb, cw, ch = canvas.GetRect and canvas:GetRect()
    local max = self.map.IsMaximized and select(2, pcall(self.map.IsMaximized, self.map))
    self:Info("map pins drawn: level %s (%s, canvas %s), canvas %sx%s at scale %.2f, first pin at %s,%s (canvas %s,%s %sx%s), maximized %s",
      tostring(lvl), how, tostring(canvas.GetFrameLevel and canvas:GetFrameLevel()), tostring(w), tostring(h), scale,
      tostring(fx and math.floor(fx)), tostring(fy and math.floor(fy)), tostring(cl and math.floor(cl)), tostring(cb and math.floor(cb)),
      tostring(cw and math.floor(cw)), tostring(ch and math.floor(ch)), tostring(max))
  else self:Debug("map %d: %d pins", mapID, self.shown) end
end

-- ------------------------------------------------------------- pin card
function M:ShowCard(data)
  local card = self.card
  if not card then
    card = UI:Window("Outrider_PinCard", "", 280, 170, ns.db.char.pinCard)
    card:SetFrameStrata("TOOLTIP")
    local c = card.content
    card.kind = UI.Text(c, "small", "muted") card.kind:SetPoint("TOPLEFT", 0, 0)
    card.body = UI.Text(c, "normal", "text") card.body:SetPoint("TOPLEFT", 0, -18)
    card.body:SetWidth(256) card.body:SetJustifyH("LEFT")
    card.way = UI:Button(c, "Waypoint", 90, function()
      local d = card.data
      ns.Waypoints:Set(d.mapID, d.x, d.y, d.name)
    end)
    card.way:SetPoint("BOTTOMLEFT", 0, 0)
    card.watch = UI:Button(c, "Watch", 90, function()
      local scan = ns.Modules:Get("RareScan")
      local d = card.data
      if scan and d.npcID then scan:Watch(d.npcID, not scan:IsWatched(d.npcID, d.name)) end
      M:ShowCard(d)
    end)
    card.watch:SetPoint("LEFT", card.way, "RIGHT", 6, 0)
    ns.db.char.pinCard = ns.db.char.pinCard or {}
    self.card = card
  end
  card.data = data
  card.title:SetText(data.name or "?")
  card.kind:SetText(string.format("%s  |  %.1f, %.1f", LABELS[data.kind] or data.kind, data.x * 100, data.y * 100))
  card.body:SetText(self:CardText(data))
  local scan = ns.Modules:Get("RareScan")
  card.watch:SetShown(data.npcID ~= nil and scan ~= nil)
  if scan and data.npcID then card.watch.label:SetText(scan:IsWatched(data.npcID, data.name) and "Watching" or "Watch") end
  card:Show()
  self:Info("pin card %s (%s)", tostring(data.name), data.kind)
end

function M:CardText(data)
  local lines = {}
  if data.rare then
    lines[#lines + 1] = ns.Sightings:Describe(data.npcID, ns.Layers and ns.Layers.current)
    local pack = ns.Data:Get("rare", data.npcID)
    if pack and pack.notes then lines[#lines + 1] = pack.notes end
    if pack and pack.beast and pack.beast.family then
      lines[#lines + 1] = pack.beast.family .. (pack.verified and "" or " (unverified)")
    end
  elseif data.poi then
    local p = data.poi
    local first, second = ns.POI.Describe(p, LABELS[p.kind] or p.kind)
    lines[#lines + 1] = first
    if second then lines[#lines + 1] = second end
    lines[#lines + 1] = string.format("Visited %d time%s, last %s", p.n or 1, (p.n or 1) == 1 and "" or "s",
      p.lastSeen and date("%Y-%m-%d", p.lastSeen) or "?")
    if p.faction then lines[#lines + 1] = p.faction end
    for _, l in ipairs(M.QuestLines(data)) do lines[#lines + 1] = l end
  end
  return table.concat(lines, "\n")
end

function M:Activity()
  local n = 0
  for _ in pairs(ns.db.global.pois or {}) do n = n + 1 end
  return string.format("%d places can show on the map%s", n, self.shown and (", " .. self.shown .. " on the open map") or "")
end
