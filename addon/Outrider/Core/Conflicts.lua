-- Core/Conflicts.lua
-- Other addons we either hook (use their data) or step aside for (turn our
-- overlapping module off by default). Shown in the hub so Gary can see why a
-- module is off. Folder names must match the addon's TOC folder exactly;
-- confirm them on Gary's PC in P1-13 and fix any that differ.

local _, ns = ...
local Conflicts = { name = "conflicts" }
ns.Conflicts = Conflicts

-- relation: "hook" = we read its data/API, "yield" = we step aside, "info" = just noted
Conflicts.KNOWN = {
  { addon = "Questie",       relation = "hook",  area = "quests, map" },
  { addon = "TomTom",        relation = "hook",  area = "waypoints" },
  { addon = "Auctionator",   relation = "hook",  area = "auction prices" },
  { addon = "TradeSkillMaster", relation = "hook", area = "auction prices" },
  { addon = "GearQuest",     relation = "hook",  area = "gear upgrades (if it exposes data)" },
  -- the Forever edition's folder (owner's AddOns, audit 2026-11-15: it was
  -- enabled but "0 addons detected")
  { addon = "GearQuestForever", relation = "hook", area = "gear upgrades (GearQuest Forever picks)" },
  { addon = "RareScanner",   relation = "yield", area = "rare alerts" },
  { addon = "_NPCScan",      relation = "yield", area = "rare alerts" },
  { addon = "ElvUI",         relation = "yield", area = "interface skin" },
  { addon = "EllesmereUI",   relation = "yield", area = "interface skin" },
  { addon = "Bartender4",    relation = "yield", area = "action bars" },
  { addon = "Baganator",     relation = "yield", area = "bags" },
  { addon = "Bagnon",        relation = "yield", area = "bags" },
  -- macro addons (2026-11-19): Outrider never overwrites their macros (it only edits its own), and
  -- the missing-buffs row and bar tooltips step aside so you don't get two of each
  { addon = "MacroKit",      relation = "yield", area = "macro buff row and bar tooltips" },
  { addon = "ArcaneShortcuts", relation = "info", area = "macros (Outrider never overwrites them)" },
  { addon = "!BugGrabber",   relation = "info",  area = "error capture (recommended)" },
  { addon = "BugSack",       relation = "info",  area = "error viewer (recommended)" },
  { addon = "Forever Data Protect", relation = "info", area = "SavedVariables workaround" },
  { addon = "ForeverSVBridge", relation = "info", area = "SavedVariables workaround" },
}

function Conflicts:Detect()
  local found = {}
  for _, k in ipairs(self.KNOWN) do
    if ns.Compat.IsAddOnLoaded(k.addon) then found[#found + 1] = k end
  end
  self.found = found
  return found
end

function Conflicts:Has(addon)
  for _, k in ipairs(self.found or self:Detect()) do
    if k.addon == addon then return true end
  end
  return false
end
