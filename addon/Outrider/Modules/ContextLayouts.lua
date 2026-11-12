-- Modules/ContextLayouts.lua  (P7-09 context layouts)
-- Works out what Gary is doing and, if he assigned an Edit Mode layout to
-- that context, switches to it with C_EditMode.SetActiveLayout (present on
-- Forever, PROBE_RESULTS P7-03). Only out of combat: switching layouts is
-- not allowed in combat, so after a fight it switches to whatever fits then.
-- Contexts, first match wins: battleground, dungeon (party/raid instance),
-- auction (AH open), crafting (profession window open), fishing (pole
-- equipped), city (resting: towns and inns), questing (everything else).
-- Nothing is assigned by default: with no layouts set this module only
-- tracks the context (shown in /ride layout and its Activity line).
--   /ride layout                       contexts, layouts, current
--   /ride layout <context> <layout>    assign (layout name as in Edit Mode)
--   /ride layout <context> off         clear

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("ContextLayouts", {
  title = "Edit Mode layout per situation",
  phase = "P7",
  order = 104,
  defaults = { layouts = {} },
})
ns.ContextLayouts = M

M.CONTEXTS = { "battleground", "dungeon", "auction", "crafting", "fishing", "city", "questing" }
M.PRESETS = { "Modern", "Classic" }

function M:OnInitialize() self.flags = {} end

function M:Detect()
  local inside, kind = C.Call("IsInInstance")
  if inside and (kind == "pvp" or kind == "arena") then return "battleground" end
  if inside and (kind == "party" or kind == "raid" or kind == "scenario") then return "dungeon" end
  if self.flags.auction then return "auction" end
  if self.flags.crafting then return "crafting" end
  if ns.Fishing and ns.Fishing.enabled and ns.Fishing:PoleEquipped() then return "fishing" end
  if C.Call("IsResting") then return "city" end
  return "questing"
end

-- { {index, name} } in SetActiveLayout numbering: presets first, then saved layouts.
function M:Layouts()
  local out = {}
  local presets = #M.PRESETS
  local mgr = rawget(_G, "EditModePresetLayoutManager")
  if type(mgr) == "table" and type(mgr.GetCopyOfPresetLayouts) == "function" then
    local ok, list = pcall(mgr.GetCopyOfPresetLayouts, mgr)
    if ok and type(list) == "table" and #list > 0 then
      presets = #list
      for i, l in ipairs(list) do out[#out + 1] = { index = i, name = tostring(l.layoutName or M.PRESETS[i] or ("Preset " .. i)) } end
    end
  end
  if #out == 0 then for i, n in ipairs(M.PRESETS) do out[#out + 1] = { index = i, name = n } end end
  local info = C.Call("C_EditMode.GetLayouts")
  if type(info) == "table" then
    for i, l in ipairs(info.layouts or {}) do out[#out + 1] = { index = presets + i, name = tostring(l.layoutName) } end
    self.active = info.activeLayout
  end
  if not self.loggedLayouts then
    self.loggedLayouts = true
    local parts = {}
    for _, l in ipairs(out) do parts[#parts + 1] = l.index .. "=" .. l.name end
    self:Info("edit mode layouts: %s (active %s)", table.concat(parts, ", "), tostring(self.active))
  end
  return out
end

function M:IndexOf(name)
  for _, l in ipairs(self:Layouts()) do if l.name:lower() == tostring(name):lower() then return l.index end end
end

function M:Update(why)
  local ctx = self:Detect()
  local changed = ctx ~= self.context
  self.context = ctx
  local want = self:Settings().layouts[ctx]
  if not want then
    if changed then self:Debug("context %s (no layout assigned)", ctx) end
    return false
  end
  if C.InCombat() then return false end
  local index = self:IndexOf(want)
  if not index then self:Info("context %s: layout '%s' not found in Edit Mode", ctx, want) return false end
  self:Layouts()
  if self.active == index then return false end
  local ok = pcall(C_EditMode.SetActiveLayout, index)
  self:Info("context %s -> layout '%s' (%s)%s", ctx, want, ok and "switched" or "refused", why and (", " .. why) or "")
  self.active = ok and index or self.active
  return ok
end

function M:OnEnable()
  local function on(flag, value) return function(mod) mod.flags[flag] = value mod:Update(flag) end end
  self:On("AUCTION_HOUSE_SHOW", on("auction", true))
  self:On("AUCTION_HOUSE_CLOSED", on("auction", false))
  self:On("TRADE_SKILL_SHOW", on("crafting", true))
  self:On("TRADE_SKILL_CLOSE", on("crafting", false))
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING",
      "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED" }) do
    self:On(e, function(mod) mod:Update(e) end)
  end
end

function M:Activity()
  local n = 0
  for _ in pairs(self:Settings().layouts) do n = n + 1 end
  return string.format("now: %s; %s", tostring(self.context or self:Detect()),
    n > 0 and (n .. " situations have a layout") or "no layouts assigned (/ride layout)")
end

ns.AddCommand("layout", "[<situation> <layout name>|off]  Edit Mode layout per situation", function(arg)
  local set = M:Settings().layouts
  local ctx, name = (arg or ""):match("^(%a+)%s+(.+)$")
  if ctx then
    ctx = ctx:lower()
    local valid = false
    for _, c in ipairs(M.CONTEXTS) do if c == ctx then valid = true end end
    if not valid then ns.Print("situations: %s", table.concat(M.CONTEXTS, ", ")) return end
    if name:lower() == "off" then
      set[ctx] = nil
      ns.Print("%s: no layout", ctx)
    elseif not M:IndexOf(name) then
      ns.Print("no Edit Mode layout called '%s'", name)
    else
      set[ctx] = name
      ns.Print("%s uses layout '%s'", ctx, name)
      M:Update("assigned")
    end
    return
  end
  local names = {}
  for _, l in ipairs(M:Layouts()) do names[#names + 1] = l.name end
  ns.Print("now: %s. Layouts: %s", tostring(M:Detect()), table.concat(names, ", "))
  for _, c in ipairs(M.CONTEXTS) do ns.Print("  %s: %s", c, set[c] or "-") end
end)
