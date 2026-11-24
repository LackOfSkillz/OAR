-- Core/Probe.lua
-- "/ride probe" records which APIs actually exist on this client build, so
-- every later phase is built on facts, not on what retail or Classic Era do.
-- Results go to Outrider_DB.global.probe; tools/read-logs.ps1 -Probe prints them
-- and Claude writes docs/PROBE_RESULTS.md from them (task P0-08).
-- Read-only: nothing here changes game state.

local _, ns = ...
local Probe = { name = "probe" }
ns.Probe = Probe

-- { path, phase that depends on it, note }
Probe.APIS = {
  -- core
  { "C_AddOns.GetAddOnMetadata", "P1" }, { "C_AddOns.IsAddOnLoaded", "P1" }, { "C_AddOns.LoadAddOn", "P1" },
  { "C_QuestLog.GetNextWaypoint", "P3", "the game's own next step for a quest (cave entrances, flights)" },
  { "C_QuestLog.GetNextWaypointText", "P3" }, { "C_Map.GetUserWaypoint", "P3", "the game's own map pin" },
  { "JoinTemporaryChannel", "P8", "hidden channel for the Outrider network test" }, { "GetChannelName", "P8" }, { "LeaveChannelByName", "P8" },
  { "C_Timer.After", "P1" }, { "GetLootRollItemLink", "P6" }, { "GetLootRollItemInfo", "P6" }, { "C_Timer.NewTicker", "P1" }, { "GetServerTime", "P1" }, { "CheckInteractDistance", "P3", "sure NPC spots from standing next to them" },
  { "issecretvalue", "P1", "secret values present" }, { "Settings.RegisterCanvasLayoutCategory", "P1" },
  { "Settings.RegisterAddOnCategory", "P1" }, { "InterfaceOptions_AddCategory", "P1", "old options API" },
  { "UpdateAddOnMemoryUsage", "P1" }, { "GetAddOnMemoryUsage", "P1" }, { "C_AddOns.GetAddOnMemoryUsage", "P1" },
  -- units, rares, hunter
  { "C_AssistedCombat.GetNextCastSpell", "P4", "Blizzard one-button rotation" },
  { "C_AssistedCombat.IsAvailable", "P4" }, { "C_AssistedCombat.GetActionSpell", "P4" },
  { "C_AssistedCombat.GetRotationSpells", "P4" },
  -- Official ways to see a fight without the combat log (requirement 2026-11-16).
  -- Presence only; names to check, nothing is called. Blizzard's damage meter
  -- (its frame is registered in Edit Mode on this client):
  { "C_DamageMeter.IsDamageMeterAvailable", "P4", "damage meter" },
  { "C_DamageMeter.GetAvailableCombatSessions", "P4", "damage meter" },
  { "C_DamageMeter.GetCombatSessionFromType", "P4", "damage meter" },
  { "C_DamageMeter.GetCombatSessionFromID", "P4", "damage meter" },
  { "C_DamageMeter.GetCombatSessionSourceFromType", "P4", "damage meter" },
  { "C_DamageMeter.GetCombatSessionSourceFromID", "P4", "damage meter" },
  { "C_EncounterTimeline.GetEventList", "P4", "boss timeline" }, { "C_CooldownViewer.GetCooldownViewerCategorySet", "P4", "cooldown manager" },
  { "C_Spell.GetSpellCooldown", "P4" }, { "C_Spell.GetSpellCharges", "P4" }, { "C_UnitAuras.GetPlayerAuraBySpellID", "P4" },
  -- stats, threat and XP (pet and player)
  { "UnitDamage", "P4" }, { "UnitAttackSpeed", "P4" }, { "UnitRangedDamage", "P4" }, { "UnitAttackPower", "P4" },
  { "UnitRangedAttackPower", "P4" }, { "GetCritChance", "P4" }, { "GetRangedCritChance", "P4" }, { "GetHitModifier", "P4" },
  { "UnitArmor", "P4" }, { "UnitStat", "P4" }, { "GetDodgeChance", "P4" },
  { "UnitThreatSituation", "P4", "who the mob is hitting" }, { "UnitDetailedThreatSituation", "P4", "threat %" },
  { "UnitInRange", "P4", "heal bars" }, { "UnitIsDeadOrGhost", "P4", "heal bars" }, { "GetNumGroupMembers", "P4", "heal bars" },
  { "UnitXP", "P4" }, { "UnitXPMax", "P4" }, { "GetXPExhaustion", "P4", "rested XP" },
  { "UnitGUID", "P2" }, { "UnitClassification", "P2" }, { "UnitCreatureFamily", "P2" },
  { "UnitCreatureType", "P2" }, { "C_NamePlate.GetNamePlates", "P2" }, { "C_NamePlate.GetNamePlateForUnit", "P2" },
  { "C_VignetteInfo.GetVignettes", "P2", "expected absent/empty for rares" },
  { "GetPetHappiness", "P2" }, { "GetPetLoyalty", "P2" }, { "GetPetExperience", "P2" },
  { "GetPetTrainingPoints", "P2" }, { "GetPetFoodTypes", "P2" }, { "GetStablePetInfo", "P2" },
  { "GetNumStableSlots", "P2" }, { "HasPetUI", "P2" }, { "PlaySound", "P2" }, { "PlaySoundFile", "P2" },
  { "C_Spell.GetSpellInfo", "P2" }, { "GetSpellInfo", "P2" }, { "IsSpellKnown", "P4" }, { "IsPlayerSpell", "P4" },
  { "GetInventoryItemCount", "P2", "ammo count" },
  -- follow-ups after the 2026-11-11 probe (Classic pet/spell/item globals missing)
  { "C_StableInfo.GetStablePetInfo", "P2" }, { "C_StableInfo.GetNumActivePets", "P2" },
  { "C_StableInfo.GetNumStablePets", "P2" }, { "C_PetInfo.GetPetTamersForMap", "P2" },
  { "GetPetFoodList", "P2" }, { "C_UnitAuras.GetAuraDataByIndex", "P2" }, { "UnitPower", "P2", "pet focus" },
  { "C_Spell.PickupSpell", "P4" }, { "C_SpellBook.GetNumSpellBookSkillLines", "P4" },
  { "C_SpellBook.PickupSpellBookItem", "P4" }, { "C_Item.EquipItemByName", "P6" },
  { "C_EventUtils.IsEventValid", "P0", "event check without registering" },
  -- map and navigation
  { "C_Map.GetBestMapForUnit", "P3" }, { "C_Map.GetPlayerMapPosition", "P3" }, { "C_Map.GetMapInfo", "P3" },
  { "C_Map.SetUserWaypoint", "P3" }, { "C_Map.ClearUserWaypoint", "P3" }, { "C_Map.GetWorldPosFromMapPos", "P3" },
  { "C_SuperTrack.SetSuperTrackedUserWaypoint", "P3" }, { "UiMapPoint.CreateFromCoordinates", "P3" },
  { "GetPlayerFacing", "P3" }, { "WorldMapFrame.AddDataProvider", "P3" }, { "MapCanvasDataProviderMixin", "P3" },
  { "MapCanvasPinMixin", "P3" }, { "C_Minimap.GetViewRadius", "P3" }, { "C_QuestLog.GetInfo", "P3" },
  { "GetQuestLogTitle", "P3", "Classic quest API" }, { "C_TaxiMap.GetAllTaxiNodes", "P3" }, { "GetTaxiMapID", "P3" }, { "C_Map.GetMapChildrenInfo", "P3" }, { "C_Map.GetMapRectOnMap", "P3", "zone levels" }, { "UnitOnTaxi", "P3" },
  -- talents (Forever may use the modern Traits system, not the Classic API)
  { "C_ClassTalents.GetActiveConfigID", "P6", "talents" }, { "C_Traits.GetConfigInfo", "P6", "talents" },
  { "C_Traits.GetTreeNodes", "P6", "talents" }, { "C_Traits.GetNodeInfo", "P6", "talents" },
  { "C_Traits.GetEntryInfo", "P6", "talents" }, { "C_Traits.GetDefinitionInfo", "P6", "talents" },
  { "C_Traits.GetTreeCurrencyInfo", "P6", "talents" }, { "GetNumTalentTabs", "P6", "Classic talents" },
  { "GetTalentInfo", "P6", "Classic talents" }, { "UnitCharacterPoints", "P6", "Classic talents" },

  -- macros
  { "CreateMacro", "P4" }, { "EditMacro", "P4" }, { "GetNumMacros", "P4" }, { "GetMacroIndexByName", "P4" },
  { "PickupSpell", "P4" }, { "PlaceAction", "P4" }, { "GetActionInfo", "P4" },
  -- professions, bags, auction, fishing
  { "C_Container.GetContainerNumSlots", "P5" }, { "C_Container.GetContainerItemInfo", "P5" },
  { "GetContainerNumSlots", "P5", "Classic bag API" }, { "C_TradeSkillUI.GetAllRecipeIDs", "P5" },
  { "C_TradeSkillUI.CraftRecipe", "P5" }, { "C_TradeSkillUI.GetCraftableCount", "P5" }, { "C_TradeSkillUI.OpenTradeSkill", "P5" }, { "C_TradeSkillUI.IsTradeSkillReady", "P5" },
  { "GetNumTradeSkills", "P5", "Classic trade skill API" }, { "GetTradeSkillInfo", "P5" },
  { "GetNumCrafts", "P5", "Classic enchanting API" }, { "GetProfessions", "P5" }, { "GetSkillLineInfo", "P5" },
  { "C_AuctionHouse.SendSearchQuery", "P5", "modern AH" }, { "C_AuctionHouse.ReplicateItems", "P5" },
  { "QueryAuctionItems", "P5", "Classic AH" }, { "C_Item.GetItemInfo", "P5" }, { "GetItemInfo", "P5" },
  { "C_TooltipInfo.GetBagItem", "P5" }, { "TooltipDataProcessor.AddTooltipPostCall", "P5" },
  { "GetLootSlotInfo", "P5" }, { "GetMerchantNumItems", "P5" }, { "GetMerchantItemCostInfo", "P5" }, { "GetMerchantItemCostItem", "P5" },
  { "C_CurrencyInfo.GetCurrencyListSize", "P5" }, { "C_CurrencyInfo.GetCurrencyListInfo", "P5" }, { "C_TooltipInfo.GetBagItem", "P5" },
  { "C_Reputation.GetNumFactions", "P5" }, { "C_Reputation.GetFactionDataByIndex", "P5" }, { "C_MerchantFrame.GetBuybackItemID", "P5" },
  -- gear
  { "C_Item.GetItemStats", "P6" }, { "GetItemStats", "P6" }, { "C_EquipmentSet.GetEquipmentSetIDs", "P6" },
  { "EquipItemByName", "P6" }, { "GetQuestItemInfo", "P6" }, { "GetNumQuestChoices", "P6" },
  -- interface
  { "EditModeManagerFrame", "P7" }, { "C_EditMode.GetLayouts", "P7" }, { "BackdropTemplateMixin", "P7" },
  { "Masque", "P7", "optional addon" }, { "C_CVar.SetCVar", "P7" }, { "SetCVar", "P7" },
  -- social / sync
  { "C_ChatInfo.RegisterAddonMessagePrefix", "P8" }, { "C_ChatInfo.SendAddonMessage", "P8" },
  { "C_FriendList.GetNumFriends", "P8" }, { "C_FriendList.GetFriendInfoByIndex", "P8" },
  { "C_FriendList.SendWho", "P8" }, { "C_FriendList.GetNumWhoResults", "P8" }, { "C_FriendList.GetWhoInfo", "P8" },
  { "GetPlayerInfoByGUID", "P8" }, { "C_MapExplorationInfo.GetExploredMapTextures", "P3" }, { "C_Map.GetMapArtLayers", "P3" }, { "C_Map.GetMapArtLayerTextures", "P3" }, { "C_Map.GetMapInfoAtPosition", "P3" }, { "C_Map.GetMapGroupMembersInfo", "P3" }, { "C_AuctionHouse.GetCommoditySearchResultsQuantity", "P5" },
  { "C_Map.GetMapChildrenInfo", "P3" }, { "C_FriendList.SetWhoToUi", "P8" }, { "ChatFrameUtil.SendTell", "P8" }, { "ChatFrame_SendTell", "P8" },
  { "C_PartyInfo.InviteUnit", "P8" }, { "C_GuildInfo.Invite", "P8" }, { "CanGuildInvite", "P8" }, { "GetGuildRosterInfo", "P8" }, { "GetClassInfo", "P8" },
  { "C_BattleNet.GetFriendAccountInfo", "P8" }, { "BNGetNumFriends", "P8" }, { "IsInGuild", "P8" },
  { "IsTrialAccount", "P8" }, { "IsVeteranTrialAccount", "P8" }, { "GetGuildRosterInfo", "P8" },
}

Probe.EVENTS = {
  "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "VIGNETTE_MINIMAP_UPDATED",
  "UNIT_PET", "PET_STABLE_SHOW", "TRADE_SKILL_SHOW", "CRAFT_SHOW", "AUCTION_HOUSE_SHOW",
  "MERCHANT_SHOW", "GOSSIP_SHOW", "TRAINER_SHOW", "TAXIMAP_OPENED", "LOOT_OPENED", "QUEST_COMPLETE",
  "BAG_UPDATE_DELAYED", "CHAT_MSG_ADDON", "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_ACTION_BLOCKED",
  "ADDON_ACTION_FORBIDDEN",
  -- official fight events (checked with IsEventValid, never registered)
  "UNIT_COMBAT", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "PLAYER_XP_UPDATE",
  "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
  "ENCOUNTER_TIMELINE_EVENT_ADDED", "COOLDOWN_VIEWER_DATA_LOADED",
}
-- Never tested by registering: on Forever even trying makes Blizzard block
-- Outrider and offer to disable it (seen 2026-11-11). See ns.Events.FORBIDDEN.

function Probe:Run()
  local out = { at = time(), build = {}, apis = {}, events = {}, constants = {}, units = {} }
  if GetBuildInfo then
    local version, build, date, interface = GetBuildInfo()
    out.build = { version = version, build = build, date = date, interface = interface }
  end
  out.constants.WOW_PROJECT_ID = rawget(_G, "WOW_PROJECT_ID")
  out.constants.MAX_ACCOUNT_MACROS = rawget(_G, "MAX_ACCOUNT_MACROS")
  out.constants.MAX_CHARACTER_MACROS = rawget(_G, "MAX_CHARACTER_MACROS")
  out.constants.NUM_BAG_SLOTS = rawget(_G, "NUM_BAG_SLOTS")

  local present, missing = 0, 0
  for _, row in ipairs(self.APIS) do
    local has = ns.Compat.Has(row[1])
    out.apis[row[1]] = has
    if has then present = present + 1 else missing = missing + 1 end
  end
  out.summary = { present = present, missing = missing }

  -- Does each event exist? Prefer the client's own check, which registers
  -- nothing; fall back to a test registration. Forbidden events are skipped.
  local isValid = C_EventUtils and C_EventUtils.IsEventValid
  local f
  for _, event in ipairs(self.EVENTS) do
    if ns.Events.FORBIDDEN[event] then
      out.events[event] = "skipped (forbidden)"
    elseif isValid then
      local ok, valid = pcall(isValid, event)
      out.events[event] = ok and (valid and true or "not valid") or "check failed"
    else
      f = f or CreateFrame("Frame")
      local ok, err = pcall(f.RegisterEvent, f, event)
      out.events[event] = ok and true or tostring(err)
      pcall(f.UnregisterEvent, f, event)
    end
  end
  for event in pairs(ns.Events.FORBIDDEN) do out.events[event] = "skipped (forbidden)" end

  out.addonBuild = ns.build
  out.units = self:RecordUnits("probe")
  out.editMode = self:EditMode()
  ns.db.global.probe = out
  ns.Log:Info("probe", "build %s (%s) interface %s: %d APIs present, %d missing",
    tostring(out.build.version), tostring(out.build.build), tostring(out.build.interface), present, missing)
  return out
end

-- P7-03 Edit Mode survey (read only): which layouts exist and which frames
-- Edit Mode already moves (so Outrider must never move them, only restyle),
-- and which common frames it does not cover.
Probe.EDIT_MODE_FRAMES = {
  "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "CompactRaidFrameContainer",
  "BossTargetFrameContainer", "ArenaEnemyFramesContainer", "MainMenuBar", "MainActionBar", "MultiBarBottomLeft",
  "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar",
  "MinimapCluster", "ObjectiveTrackerFrame", "QuestWatchFrame", "BuffFrame", "DebuffFrame", "PlayerCastingBarFrame",
  "CastingBarFrame", "ChatFrame1", "BagsBar", "MicroMenuContainer", "MicroMenu", "StatusTrackingBarManager",
  "MainStatusTrackingBarContainer", "LootFrame", "TalkingHeadFrame", "ExtraAbilityContainer", "GameTooltipDefaultContainer",
  "EncounterBar", "DurabilityFrame", "VehicleSeatIndicator", "ArchaeologyDigsiteProgressBar", "TimerTracker",
}

function Probe:EditMode()
  local out = { api = {}, layouts = {}, systems = {}, frames = {} }
  local em = rawget(_G, "C_EditMode")
  for _, fn in ipairs({ "GetLayouts", "SetActiveLayout", "SaveLayouts", "GetAccountSettings", "ConvertLayoutInfoToString" }) do
    out.api[fn] = type(em) == "table" and type(em[fn]) == "function" or false
  end
  if out.api.GetLayouts then
    local ok, info = pcall(em.GetLayouts)
    if ok and type(info) == "table" then
      out.activeLayout = info.activeLayout
      for i, l in ipairs(info.layouts or {}) do
        out.layouts[i] = { name = tostring(l.layoutName), type = l.layoutType }
      end
    end
  end
  local mgr = rawget(_G, "EditModeManagerFrame")
  out.manager = mgr ~= nil
  local isSystem = {}
  if mgr and type(mgr.registeredSystemFrames) == "table" then
    for _, f in ipairs(mgr.registeredSystemFrames) do
      local ok, name = pcall(f.GetName, f)
      name = ok and name or "?"
      isSystem[name] = true
      out.systems[#out.systems + 1] = name
    end
  end
  for _, name in ipairs(self.EDIT_MODE_FRAMES) do
    local f = rawget(_G, name)
    if f then
      local protected = f.IsProtected and select(1, pcall(f.IsProtected, f)) and f:IsProtected() or false
      out.frames[name] = (isSystem[name] and "edit mode" or "not in edit mode") .. (protected and ", protected" or "")
    end
  end
  local layoutNames = {}
  for _, l in ipairs(out.layouts) do layoutNames[#layoutNames + 1] = l.name end
  ns.Log:Info("probe", "edit mode: manager %s, %d layouts (%s), active %s, %d system frames",
    tostring(out.manager), #out.layouts, table.concat(layoutNames, ", "), tostring(out.activeLayout), #out.systems)
  return out
end

-- Unit readability differs in and out of combat, so keep the last few samples.
function Probe:RecordUnits(why)
  local units = self:Units()
  units.at = time()
  units.why = why
  local g = ns.db.global
  g.probeUnits = type(g.probeUnits) == "table" and g.probeUnits or {}
  table.insert(g.probeUnits, units)
  while #g.probeUnits > 6 do table.remove(g.probeUnits, 1) end
  local n = 0
  for k in pairs(units) do if k ~= "inCombat" and k ~= "position" and k ~= "at" and k ~= "why" then n = n + 1 end end
  ns.Log:Info("probe", "units sample (%s) inCombat=%s units=%d", tostring(why), tostring(units.inCombat), n)
  return units
end

-- What can we read about nearby units? Run once near mobs, once in combat.
function Probe:Units()
  local res = { inCombat = ns.Compat.InCombat() }
  local units = { "player", "target", "mouseover", "pet" }
  for i = 1, 5 do units[#units + 1] = "nameplate" .. i end
  for _, unit in ipairs(units) do
    if UnitExists and UnitExists(unit) then
      local guid = ns.Compat.Call("UnitGUID", unit)
      local name = ns.Compat.Call("UnitName", unit)
      res[unit] = {
        guidReadable = guid ~= nil and not ns.Compat.IsSecret(guid),
        nameReadable = name ~= nil and not ns.Compat.IsSecret(name),
        classification = ns.Compat.Readable(ns.Compat.Call("UnitClassification", unit)),
        family = ns.Compat.Readable(ns.Compat.Call("UnitCreatureFamily", unit)),
        npcID = (ns.Compat.UnitNpcID(unit)),
      }
    end
  end
  local mapID, x, y = ns.Compat.PlayerPosition()
  res.position = { mapID = mapID, x = x, y = y }
  return res
end

-- The shape of a value for the log: types and keys, never a secret value
-- (a secret is written as "secret" and never touched further, hard rule 4).
function Probe.Shape(v, depth, budget)
  budget = budget or { n = 0 }
  budget.n = budget.n + 1
  if budget.n > 200 then return "..." end
  if ns.Compat.IsSecret(v) then return "secret" end
  local t = type(v)
  if t == "string" then return string.format("%q", #v > 40 and v:sub(1, 40) .. "..." or v) end
  if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
  if t ~= "table" then return t end
  if (depth or 0) >= 3 then return "{...}" end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for i, k in ipairs(keys) do
    if i > 12 then parts[#parts + 1] = string.format("+%d more", #keys - 12) break end
    parts[#parts + 1] = tostring(k) .. "=" .. Probe.Shape(v[k], (depth or 0) + 1, budget)
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- Blizzard's damage meter (the official way to see a fight on this client;
-- the combat log is blocked). Call shapes aren't documented for Forever, so
-- this logs what each call returns, or the error it gives, after a fight.
-- Read only; nothing here changes the meter.
function Probe:DamageMeter(why)
  local dm = rawget(_G, "C_DamageMeter")
  if type(dm) ~= "table" then ns.Log:Info("probe", "damage meter (%s): no C_DamageMeter", tostring(why)) return end
  local enum = rawget(_G, "Enum") or {}
  local function try(label, fn, ...)
    if type(fn) ~= "function" then ns.Log:Info("probe", "dm %s: missing", label) return end
    local res = { pcall(fn, ...) }
    if not res[1] then ns.Log:Info("probe", "dm %s: error %s", label, tostring(res[2])) return end
    local out = {}
    for i = 2, math.max(2, #res) do out[#out + 1] = Probe.Shape(res[i]) end
    ns.Log:Info("probe", "dm %s -> %s", label, table.concat(out, " | "))
    return res[2]
  end
  ns.Log:Info("probe", "damage meter (%s): Enum.DamageMeterType=%s Enum.DamageMeterSessionType=%s", tostring(why),
    Probe.Shape(enum.DamageMeterType), Probe.Shape(enum.DamageMeterSessionType))
  try("IsDamageMeterAvailable()", dm.IsDamageMeterAvailable)
  local sessions = try("GetAvailableCombatSessions()", dm.GetAvailableCombatSessions)
  -- Measured 2026-11-16: the *FromType calls came back empty; sessions are
  -- read by ID (GetAvailableCombatSessions lists the last fights, sessionID
  -- grows). So: the newest session, damage done and taken, and the player's
  -- own breakdown (does it include the pet's attacks?).
  local meterTypes = type(enum.DamageMeterType) == "table" and enum.DamageMeterType or {}
  local newest
  if type(sessions) == "table" then
    for _, se in pairs(sessions) do
      local id = type(se) == "table" and ns.Compat.Readable(se.sessionID)
      if type(id) == "number" and (not newest or id > newest) then newest = id end
    end
  end
  if not newest then return end
  local guid = ns.Compat.Readable(ns.Compat.Call("UnitGUID", "player"))
  local petGuid = ns.Compat.Readable(ns.Compat.Call("UnitGUID", "pet"))
  for _, mName in ipairs({ "DamageDone", "DamageTaken", "EnemyDamageTaken" }) do
    local m = meterTypes[mName]
    if m then
      try(string.format("GetCombatSessionFromID(newest %d, %s)", newest, mName), dm.GetCombatSessionFromID, newest, m)
    end
  end
  local dmg = meterTypes.DamageDone or 0
  if guid then try("GetCombatSessionSourceFromID(newest, DamageDone, player)", dm.GetCombatSessionSourceFromID, newest, dmg, guid) end
  if petGuid then try("GetCombatSessionSourceFromID(newest, DamageDone, pet)", dm.GetCombatSessionSourceFromID, newest, dmg, petGuid) end
end

function Probe:Summary()
  local p = ns.db.global.probe
  if not p then return "no probe yet: type /ride probe" end
  return string.format("probe %s: build %s, %d present, %d missing", date("%Y-%m-%d %H:%M", p.at),
    tostring(p.build.build), p.summary.present, p.summary.missing)
end
