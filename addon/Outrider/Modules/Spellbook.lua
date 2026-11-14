-- Modules/Spellbook.lua  (P4-02)
-- Which spells this character knows: { [lowercase name] = { name, id, rank } },
-- keeping the highest rank per name. Modern C_SpellBook first (present on
-- Forever, probe 2026-11-11), Classic spell tabs as fallback. Refreshed on
-- SPELLS_CHANGED / LEARNED_SPELL_IN_TAB (throttled). Saved per character in
-- ns.db.char.spellbook so Claude can read it from the SavedVariables file
-- (auto-collected; also what RankCheck in P4-06 compares against).
-- Pack macros use English spell names; Known(name) answers by name.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Spellbook", {
  title = "Spellbook reader",
  phase = "P4",
  order = 60,
  defaults = {},
})
ns.Spellbook = M

M.spells = {}

local function rankOf(sub)
  return tonumber(type(sub) == "string" and sub:match("(%d+)") or nil)
end

function M:Add(out, name, id, sub)
  name = C.Readable(name)
  if type(name) ~= "string" or name == "" then return end
  local key = name:lower()
  local rank = rankOf(C.Readable(sub))
  local cur = out[key]
  if not cur or (rank or 0) > (cur.rank or 0) then out[key] = { name = name, id = id, rank = rank } end
end

function M:ScanModern(out)
  local SB = rawget(_G, "C_SpellBook")
  if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then return false end
  local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
  local lines = SB.GetNumSpellBookSkillLines() or 0
  for i = 1, lines do
    local line = SB.GetSpellBookSkillLineInfo(i)
    if type(line) == "table" and not line.shouldHide then
      local first = (line.itemIndexOffset or 0) + 1
      for idx = first, first + (line.numSpellBookItems or 0) - 1 do
        local info = SB.GetSpellBookItemInfo(idx, bank)
        if type(info) == "table" and info.spellID and not info.isPassive then
          self:Add(out, info.name, info.spellID, info.subName)
        end
      end
    end
  end
  return true
end

function M:ScanClassic(out)
  if not (rawget(_G, "GetNumSpellTabs") and rawget(_G, "GetSpellTabInfo") and rawget(_G, "GetSpellBookItemName")) then return false end
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, num = GetSpellTabInfo(tab)
    for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
      local name, sub = GetSpellBookItemName(i, "spell")
      local _, id = C.Call("GetSpellBookItemInfo", i, "spell")
      self:Add(out, name, id, sub)
    end
  end
  return true
end

function M:Scan()
  local out = {}
  local how = "none"
  local ok, done = pcall(self.ScanModern, self, out)
  if ok and done then how = "C_SpellBook"
  else
    ok, done = pcall(self.ScanClassic, self, out)
    if ok and done then how = "classic" end
  end
  self.spells, self.source = out, how
  local n = 0
  for _ in pairs(out) do n = n + 1 end
  self.count = n
  ns.db.char.spellbook = { at = time(), source = how, spells = ns.CopyTable(out) }
  if n ~= self.lastLogged then
    self.lastLogged = n
    self:Info("spellbook: %d spells via %s", n, how)
  end
  return out
end

function M:OnEnable()
  self:On("SPELLS_CHANGED", function(mod) ns.Throttle("spellbook", 0.5, function() mod:Scan() end) end)
  -- (LEARNED_SPELL_IN_TAB does not exist on Forever; SPELLS_CHANGED covers learning)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Scan() end)
end

function M:OnDisable() ns.ThrottleCancel("spellbook") end

-- entry or nil
function M:Known(name)
  return type(name) == "string" and self.spells[name:lower()] or nil
end

function M:Activity()
  return string.format("%d spells known (%s)", self.count or 0, tostring(self.source or "not scanned"))
end

ns.AddCommand("spells", "[filter]  list the spells Outrider sees in your spellbook", function(arg)
  local list = {}
  for _, s in pairs(M.spells) do
    if not arg or s.name:lower():find(arg:lower(), 1, true) then list[#list + 1] = s end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  ns.Print("%d spells%s:", #list, arg and (" matching " .. arg) or "")
  for i = 1, math.min(#list, 30) do
    local s = list[i]
    ns.Print("  %s%s (%s)", s.name, s.rank and (" rank " .. s.rank) or "", tostring(s.id))
  end
end)
