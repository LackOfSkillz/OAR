-- Core/Probe.lua
-- "/oar probe" records which APIs actually exist on this client build, so
-- every later phase is built on facts, not on what retail or Classic Era do.
-- Results go to OAR_DB.global.probe; tools/read-logs.ps1 -Probe prints them
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
  { "UnitGUID", "P2" }, { "UnitClassification", "P2" }, { "UnitCreatureFamily", "P2" },
  { "UnitCreatureType", "P2" }, { "C_NamePlate.GetNamePlates", "P2" }, { "C_NamePlate.GetNamePlateForUnit", "P2" },
  { "C_VignetteInfo.GetVignettes", "P2", "expected absent/empty for rares" },
  { "GetPetHappiness", "P2" }, { "GetPetLoyalty", "P2" }, { "GetPetExperience", "P2" },
  { "GetPetTrainingPoints", "P2" }, { "GetPetFoodTypes", "P2" }, { "GetStablePetInfo", "P2" },
  { "GetNumStableSlots", "P2" }, { "HasPetUI", "P2" }, { "PlaySound", "P2" }, { "PlaySoundFile", "P2" },
  { "C_Spell.GetSpellInfo", "P2" }, { "GetSpellInfo", "P2" }, { "IsSpellKnown", "P4" }, { "IsPlayerSpell", "P4" },
  { "GetInventoryItemCount", "P2", "ammo count" },
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
  "ADDON_ACTION_FORBIDDEN", "COMBAT_LOG_EVENT_UNFILTERED",
}

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

  -- Can we register each event? (Some are blocked on Forever, e.g. the combat log.)
  local f = CreateFrame("Frame")
  for _, event in ipairs(self.EVENTS) do
    local ok, err = pcall(f.RegisterEvent, f, event)
    out.events[event] = ok and true or tostring(err)
    pcall(f.UnregisterEvent, f, event)
  end

  out.units = self:Units()
  ns.db.global.probe = out
  -- Unit readability differs in and out of combat, so keep the last few runs.
  local g = ns.db.global
  g.probeUnits = type(g.probeUnits) == "table" and g.probeUnits or {}
  out.units.at = out.at
  table.insert(g.probeUnits, out.units)
  while #g.probeUnits > 6 do table.remove(g.probeUnits, 1) end
  ns.Log:Info("probe", "build %s (%s) interface %s: %d APIs present, %d missing",
    tostring(out.build.version), tostring(out.build.build), tostring(out.build.interface), present, missing)
  return out
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
  if not p then return "no probe yet: type /oar probe" end
  return string.format("probe %s: build %s, %d present, %d missing", date("%Y-%m-%d %H:%M", p.at),
    tostring(p.build.build), p.summary.present, p.summary.missing)
end
