-- Modules/MacroTree.lua  (requirement 2026-11-19: a macro page laid out like the
-- talents page, macros pre-created in level tiers (1 to 10 and up), icons to
-- drag onto the action bar, each with an explanation, so that even a new
-- player gets an experienced player's macros.)
--
-- The Macros page as a skill tree:
--   * Your keys: the fight keys (Fight, Pull, Strike, Heal, Pet...) that
--     Outrider rewrites as you learn spells; set up once. Under them, what the
--     main key does press by press, from the fight plan's reasons.
--   * The tree: rows are level bands (1-10 ... 51-60), columns are "Every
--     <class>" and one per talent tree. Each cell holds the macros that unlock
--     there: the class macro library and the plan's extra keys (Burst, Break,
--     Recover, Trap...). Level and tree come from the macro itself or from the
--     spells in it (the fight plan's learn table: level and talent tree).
--   * Click an icon to read it (when to press, what it does, every line in
--     plain words); drag it to your action bar. Dragging writes the macro first
--     if it isn't in your macros yet (out of combat, from your drag: rule 1).
--   * A PvE / PvP switch shows the PvP versions; it changes only this view.
-- Nothing here casts anything: these are ordinary macros you press.

-- Files: MacroTree.lua (module, tooltips, new-unlock notice), MacroTreeModel.lua (model),
-- MacroTreePage.lua (the page).
local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local E = ns.MacroEngine
local T = ns:NewModule("MacroTree", {
  title = "Macros page: skill tree, tooltips, missing buffs",
  phase = "P4",
  order = 62,
  -- seen: macros you've looked at (no "new" badge); planned: the build you
  -- chose before 10 talent points; tooltips: Outrider's words under a macro
  -- on your action bar; buffs: the missing-buffs row
  defaults = { seen = {}, planned = nil, tooltips = true, buffs = true, singles = false },
})
ns.MacroTree = T

-- ------------------------------------------------------------------ module
-- One chat line per session when macros unlock (rule 6); the page shows a
-- "new" badge on each until you open it.
function T:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin, isReload)
    if isLogin or isReload or not mod.baseline then mod.baseline = mod:UnlockedIds() end
  end)
  local function check(mod) ns.Throttle("macrotree:new", 3, function() mod:CheckNew() end) end
  self:On("PLAYER_LEVEL_UP", check)
  self:On("SPELLS_CHANGED", function(mod) mod.tipCache = nil check(mod) end)
  self:On("LEARNED_SPELL_IN_TAB", check)
  -- Outrider's words under one of its macros on your action bar (a hook: the
  -- game's tooltip stays as it is, two lines are added under it)
  if not self.tipHooked and GameTooltip and type(rawget(_G, "hooksecurefunc")) == "function" then
    self.tipHooked = true
    hooksecurefunc(GameTooltip, "SetAction", function(tt, slot)
      if T.enabled and T:Settings().tooltips and not C.IsAddOnLoaded("MacroKit") then ns.Safe("macrotree:tooltip", T.AddTooltip, T, tt, slot) end
    end)
  end
end

-- name -> { when, what } for every macro Outrider can write for you
function T:TipFor(name)
  if not self.tipCache then
    local c = {}
    for _, k in ipairs(self:Keys()) do
      c[k.name] = { when = T.KEY_WHEN[k.name] or "Press it in every fight.", what = k.entry.explain }
    end
    for _, it in ipairs(self:Items("pve")) do
      if not c[it.name] then
        local tag = it.tags and it.tags[1]
        c[it.name] = { when = T.WHEN[tag or ""], what = it.why }
      end
    end
    self.tipCache = c
  end
  return self.tipCache[name]
end

function T:AddTooltip(tt, slot)
  local kind, id = C.Call("GetActionInfo", slot)
  if kind ~= "macro" or not id then return end
  local name = C.Call("GetMacroInfo", id)
  local lib = ns.MacroLibrary
  if type(name) ~= "string" or not (lib and lib:Settings().installed[name]) then return end
  local t = self:TipFor(name)
  if not t then return end
  tt:AddLine(" ")
  if t.when then tt:AddLine("Outrider: " .. t.when, 0.95, 0.82, 0.45, true) end
  if t.what and t.what ~= "" then tt:AddLine(t.what, 0.8, 0.8, 0.8, true) end
  tt:Show()
end

function T:OnDisable() ns.ThrottleCancel("macrotree:new") end

-- ids of the tree's macros you can use now
function T:UnlockedIds()
  local lib = ns.MacroLibrary
  if lib and not lib.held then return lib:Hold(self.UnlockedIds, self) end
  local out = {}
  for _, it in ipairs(self:Items("pve")) do
    local st = self:State(it)
    if st ~= "locked" and not (type(st) == "string" and st:find("^needs")) then out[it.id] = it.name end
  end
  return out
end

-- newly usable and not yet looked at: { names }
function T:CheckNew()
  if not self.baseline then self.baseline = self:UnlockedIds() return {} end
  local now, fresh = self:UnlockedIds(), {}
  local seen = self:Settings().seen
  for id, name in pairs(now) do
    if not self.baseline[id] and not seen[id] then fresh[#fresh + 1] = name end
  end
  self.baseline = now
  table.sort(fresh)
  if #fresh > 0 then
    if not self.toldNew then
      self.toldNew = true
      ns.Print("new macros on your Macros page: %s (drag them to your bar)", table.concat(fresh, ", "))
    end
    self:Info("macros unlocked: %s", table.concat(fresh, ", "))
  end
  return fresh
end

function T:Activity()
  local n, new = 0, 0
  local seen = self:Settings().seen
  for id in pairs(self:UnlockedIds()) do n = n + 1 if not seen[id] then new = new + 1 end end
  return string.format("%d macros ready for you on the Macros page, %d not looked at yet", n, new)
end

T.BANDS = { { 1, 10 }, { 11, 20 }, { 21, 30 }, { 31, 40 }, { 41, 50 }, { 51, 60 } }
-- words that are tags, not talent trees (the rogue tree "combat" is also the "in a fight" tag)
T.GENERIC_TAGS = { combat = true, control = true, defensive = true, utility = true, heal = true, pet = true, rare = true,
  talent = true, cooldown = true }
-- a game icon per kind of macro, until the spell's own icon or Outrider's art (batch 6) is there
T.TAG_ICON = { combat = "INV_Sword_04", control = "Ability_Hunter_SniperShot", defensive = "INV_Chest_Plate06",
  utility = "INV_Misc_Bag_08", heal = "Spell_Holy_SurgeOfLight", pet = "Ability_Hunter_BeastTaming", rare = "Ability_Tracking",
  burst = "Spell_Holy_SurgeOfLight", ["break"] = "INV_Chest_Plate06", recover = "INV_Misc_PocketWatch_01",
  trap = "Ability_Tracking" }
-- when to press it, by what it's for (the explanation on every macro)
T.WHEN = {
  combat = "In the fight, whenever its spell is ready.",
  control = "When an enemy starts casting, runs away, or a second one joins the fight.",
  defensive = "When your health drops fast or the fight is going wrong.",
  utility = "Between fights, out of combat.",
  heal = "When you or a friend needs health.",
  pet = "To tell your pet what to do.",
  rare = "When a rare you're hunting is near.",
  burst = "At the start of a hard fight: a rare, an elite, a fight you might lose, or a duel.",
  ["break"] = "When you're stunned, feared, slowed or about to die.",
  recover = "Between fights, or while your target can't act.",
  trap = "Before the pull, or when a second enemy runs at you.",
}
T.KEY_WHEN = {
  Fight = "Over and over, from the moment you pick a target until it dies. This is the button you press most.",
  Pull = "Once, from range, to start a fight on your terms.",
  Strike = "The second key: press it when the moment comes (it says which below).",
  Heal = "When you or a friend needs health; point the mouse at a friend to heal them.",
  Pet = "Between fights or when your pet is hurt: it revives, calls or heals your pet.",
  Reach = "When the enemy is out of melee range.",
  Stop = "When an enemy starts casting (plain press), or you need it stunned or out of the fight (hold Shift, Ctrl or Alt).",
  Save = "When the fight goes wrong: plain press first, the modifiers when that isn't enough.",
  Burst = "At the start of a hard fight or a boss, once your cooldowns are ready.",
  Recover = "Between fights to eat and drink; in a fight when your health is low.",
  Team = "In a group: plain press to hit what the tank or leader hits; Shift to mark a focus to interrupt or watch.",
}

-- ------------------------------------------------------------------ model
