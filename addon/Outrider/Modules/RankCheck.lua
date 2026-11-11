-- Modules/RankCheck.lua  (P4-06)
-- In Classic, learning a new rank does not upgrade the button already on
-- your bar (C13, to be confirmed on Forever). After the spellbook changes or
-- a trainer closes, look at every action slot holding a spell and compare
-- its rank with the highest rank known (Spellbook). If any are old, a toast
-- offers "Fix": out of combat, on Gary's click, each slot gets the highest
-- rank (pick up spell, place on the slot, clear the cursor).
-- At login it logs what it found either way (auto-collected), so we learn
-- whether Forever needs this at all.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("RankCheck", {
  title = "Old spell ranks on your bars",
  phase = "P4",
  order = 62,
  defaults = { toast = true },
})

M.SLOTS = 180

local function spellName(id)
  local info = C.Call("C_Spell.GetSpellInfo", id)
  if type(info) == "table" then return C.Readable(info.name) end
  return C.Readable((C.Call("GetSpellInfo", id)))
end

local function spellRank(id)
  local sub = C.Call("C_Spell.GetSpellSubtext", id) or C.Call("GetSpellSubtext", id)
  sub = C.Readable(sub)
  return tonumber(type(sub) == "string" and sub:match("(%d+)") or nil)
end

-- { { slot, name, id, rank, bestID, bestRank } } for buttons with an old rank.
function M:Find()
  local out, spells = {}, 0
  for slot = 1, self.SLOTS do
    local kind, id = C.Call("GetActionInfo", slot)
    if kind == "spell" and id then
      spells = spells + 1
      local name = spellName(id)
      local best = name and ns.Spellbook:Known(name)
      local rank = spellRank(id)
      if best and best.id and best.id ~= id and best.rank and rank and rank < best.rank then
        out[#out + 1] = { slot = slot, name = name, id = id, rank = rank, bestID = best.id, bestRank = best.rank }
      end
    end
  end
  return out, spells
end

function M:Check(why)
  if not ns.Spellbook or not ns.Spellbook.count then return end
  local old, spells = self:Find()
  self.old = old
  if why == "login" or #old > 0 then
    local slots = {}
    for _, o in ipairs(old) do slots[#slots + 1] = string.format("%d:%s r%d<r%d", o.slot, o.name, o.rank, o.bestRank) end
    self:Info("rank check (%s): %d spell buttons, %d old%s", tostring(why), spells, #old,
      #slots > 0 and (" [" .. table.concat(slots, ", ") .. "]") or "")
  end
  if #old > 0 and self:Settings().toast and why ~= "login-quiet" then
    ns.Toast:Show({
      title = #old == 1 and "1 button uses an old rank" or (#old .. " buttons use old ranks"),
      text = old[1].name .. " rank " .. old[1].rank .. " -> " .. old[1].bestRank .. (#old > 1 and " and more" or ""),
      color = "warn", duration = 30,
      action = { label = "Fix", fn = function() M:Fix() end },
    })
  end
end

-- Gary's click: replace each old button with the highest rank (out of combat).
function M:Fix()
  if C.InCombat() then ns.Print("not in combat: try again after the fight") return 0 end
  local pickup = C.Resolve("C_Spell.PickupSpell") or rawget(_G, "PickupSpell")
  local place, clear = rawget(_G, "PlaceAction"), rawget(_G, "ClearCursor")
  if type(pickup) ~= "function" or type(place) ~= "function" then self:Warn("cannot place actions here") return 0 end
  local fixed = 0
  for _, o in ipairs(self.old or {}) do
    if pcall(pickup, o.bestID) and pcall(place, o.slot) then
      fixed = fixed + 1
      self:Info("fixed slot %d: %s rank %d -> %d", o.slot, o.name, o.rank, o.bestRank)
    end
    if type(clear) == "function" then pcall(clear) end
  end
  ns.Print("updated %d button%s to the highest rank", fixed, fixed == 1 and "" or "s")
  self.old = {}
  return fixed
end

function M:OnEnable()
  -- Spellbook (loaded before this module) scans on the same event first.
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin) mod:Check(isLogin and "login" or "login-quiet") end)
  self:On("SPELLS_CHANGED", function(mod)
    ns.Throttle("rankcheck", 2, function() mod:Check("spells changed") end)
  end)
  self:On("TRAINER_CLOSED", function(mod) ns.Timer.After(1, function() mod:Check("trainer") end, "rankcheck:trainer") end)
end

function M:OnDisable() ns.ThrottleCancel("rankcheck") end

function M:Activity()
  local n = self.old and #self.old or 0
  return n == 0 and "no old ranks on your bars" or (n .. " buttons use old ranks")
end
