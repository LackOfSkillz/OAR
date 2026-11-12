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
  { "C_Timer.After", "P1" }, { "C_Timer.NewTicker", "P1" }, { "GetServerTime", "P1" },
  { "issecretvalue", "P1", "secret values present" }, { "Settings.RegisterCanvasLayoutCategory", "P1" },
  { "Settings.RegisterAddOnCategory", "P1" }, { "InterfaceOptions_AddCategory", "P1", "old options API" },
  { "UpdateAddOnMemoryUsage", "P1" }, { "GetAddOnMemoryUsage", "P1" }, { "C_AddOns.GetAddOnMemoryUsage", "P1" },
  -- units, rares, hunter
  { "C_AssistedCombat.GetNextCastSpell", "P4", "Blizzard one-button rotation" },
  { "C_AssistedCombat.IsAvailable", "P4" }, { "C_AssistedCombat.GetActionSpell", "P4" },
  { "C_AssistedCombat.GetRotationSpells", "P4" },
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
  { "GetQuestLogTitle", "P3", "Classic quest API" }, { "C_TaxiMap.GetAllTaxiNodes", "P3" },
  -- macros
  { "CreateMacro", "P4" }, { "EditMacro", "P4" }, { "GetNumMacros", "P4" }, { "GetMacroIndexByName", "P4" },
  { "PickupSpell", "P4" }, { "PlaceAction", "P4" }, { "GetActionInfo", "P4" },
  -- professions, bags, auction, fishing
  { "C_Container.GetContainerNumSlots", "P5" }, { "C_Container.GetContainerItemInfo", "P5" },
  { "GetContainerNumSlots", "P5", "Classic bag API" }, { "C_TradeSkillUI.GetAllRecipeIDs", "P5" },
  { "GetNumTradeSkills", "P5", "Classic trade skill API" }, { "GetTradeSkillInfo", "P5" },
  { "GetNumCrafts", "P5", "Classic enchanting API" }, { "GetProfessions", "P5" }, { "GetSkillLineInfo", "P5" },
  { "C_AuctionHouse.SendSearchQuery", "P5", "modern AH" }, { "C_AuctionHouse.ReplicateItems", "P5" },
  { "QueryAuctionItems", "P5", "Classic AH" }, { "C_Item.GetItemInfo", "P5" }, { "GetItemInfo", "P5" },
  { "C_TooltipInfo.GetBagItem", "P5" }, { "TooltipDataProcessor.AddTooltipPostCall", "P5" },
  { "GetLootSlotInfo", "P5" }, { "GetMerchantNumItems", "P5" }, { "C_MerchantFrame.GetBuybackItemID", "P5" },
  -- gear
  { "C_Item.GetItemStats", "P6" }, { "GetItemStats", "P6" }, { "C_EquipmentSet.GetEquipmentSetIDs", "P6" },
  { "EquipItemByName", "P6" }, { "GetQuestItemInfo", "P6" }, { "GetNumQuestChoices", "P6" },
  -- interface
  { "EditModeManagerFrame", "P7" }, { "C_EditMode.GetLayouts", "P7" }, { "BackdropTemplateMixin", "P7" },
  { "Masque", "P7", "optional addon" }, { "C_CVar.SetCVar", "P7" }, { "SetCVar", "P7" },
  -- social / sync
  { "C_ChatInfo.RegisterAddonMessagePrefix", "P8" }, { "C_ChatInfo.SendAddonMessage", "P8" },
  { "C_FriendList.GetNumFriends", "P8" }, { "C_FriendList.GetFriendInfoByIndex", "P8" },
  { "C_BattleNet.GetFriendAccountInfo", "P8" }, { "BNGetNumFriends", "P8" }, { "IsInGuild", "P8" },
  { "IsTrialAccount", "P8" }, { "IsVeteranTrialAccount", "P8" }, { "GetGuildRosterInfo", "P8" },
}

Probe.EVENTS = {
  "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "VIGNETTE_MINIMAP_UPDATED",
  "UNIT_PET", "PET_STABLE_SHOW", "TRADE_SKILL_SHOW", "CRAFT_SHOW", "AUCTION_HOUSE_SHOW",
  "MERCHANT_SHOW", "GOSSIP_SHOW", "TRAINER_SHOW", "TAXIMAP_OPENED", "LOOT_OPENED", "QUEST_COMPLETE",
  "BAG_UPDATE_DELAYED", "CHAT_MSG_ADDON", "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_ACTION_BLOCKED",
  "ADDON_ACTION_FORBIDDEN",
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

function Probe:Summary()
  local p = ns.db.global.probe
  if not p then return "no probe yet: type /ride probe" end
  return string.format("probe %s: build %s, %d present, %d missing", date("%Y-%m-%d %H:%M", p.at),
    tostring(p.build.build), p.summary.present, p.summary.missing)
end
