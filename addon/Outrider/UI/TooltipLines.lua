-- UI/TooltipLines.lua  (P7-05: one ordered block of Outrider tooltip lines)
-- Modules add tooltip lines through ns.TooltipLines:Add(kind, key, owner, fn)
-- instead of hooking tooltips themselves. One post-call per tooltip kind
-- collects every provider's lines in a fixed order (ORDER below) so they
-- never interleave or appear twice:
--   kind  "item" | "unit"
--   key   order slot: verdict, value, owned, needed, beast, target
--   owner the module (its lines show only while it is enabled)
--   fn(tip, data) returns a list of lines: "text" or { text, colorName }
-- Each provider runs inside ns.Safe, so one failing never hides the others.

local _, ns = ...
local C = ns.Compat
local TL = { providers = { item = {}, unit = {} }, hooked = {} }
ns.TooltipLines = TL

TL.ORDER = { roll = 5, verdict = 10, value = 20, owned = 30, needed = 40, quest = 45, questuses = 46, beast = 50, player = 52, elite = 53, rarefight = 55, questleft = 58, target = 60, wishlist = 70 }
local ENUM = { item = "Enum.TooltipDataType.Item", unit = "Enum.TooltipDataType.Unit" }

-- Character-specific visibility options. Defaults retain existing behavior;
-- Shift gating is opt-in so older configurations do not silently lose data.
function TL:Settings()
  if not (ns.db and ns.db.char) then return { shiftOnly = false, limit = 0, hidden = {} } end
  local db = ns.db.char
  db.tooltipExtras = type(db.tooltipExtras) == "table" and db.tooltipExtras or {}
  local s = db.tooltipExtras
  if s.shiftOnly == nil then s.shiftOnly = false end
  if s.limit == nil then s.limit = 0 end -- 0 means unlimited per provider
  s.hidden = type(s.hidden) == "table" and s.hidden or {}
  return s
end

function TL:Enabled(key)
  return self:Settings().hidden[key] ~= true
end

function TL:SetEnabled(key, enabled)
  if type(key) ~= "string" or not self.ORDER[key] then return false end
  self:Settings().hidden[key] = enabled == false or nil
  return true
end

function TL:RefreshOnModifier(key)
  if key ~= "LSHIFT" and key ~= "RSHIFT" then return false end
  if not self:Settings().shiftOnly then return false end
  local tip = rawget(_G, "GameTooltip")
  if not (tip and tip.IsShown and tip:IsShown() and type(tip.RefreshData) == "function") then
    return false -- safely refresh by re-hovering on older clients
  end
  return pcall(tip.RefreshData, tip)
end

ns.AddCommand("toolextras", "toolextras shift|always|limit <0-10>|hide <key>|show <key>|list", function(arg)
  local s = TL:Settings()
  local command, rest = tostring(arg or "list"):match("^(%S+)%s*(.*)$")
  if command == "shift" or command == "always" then
    s.shiftOnly = command == "shift"
    ns.Print("Outrider tooltip extras: %s (re-hover if the current tooltip does not refresh)",
      s.shiftOnly and "hold Shift" or "always show")
  elseif command == "limit" then
    local n = tonumber(rest)
    if n and n >= 0 and n <= 10 and n == math.floor(n) then
      s.limit = n
      ns.Print("Outrider tooltip extras: up to %d line(s) per source (0 = unlimited)", n)
    else ns.Print("limit must be a whole number from 0 through 10") end
  elseif command == "hide" or command == "show" then
    if TL:SetEnabled(rest, command == "show") then ns.Print("%s tooltip lines: %s", rest, command)
    else ns.Print("unknown tooltip source key: %s", rest) end
  else
    local names = {}
    for key in pairs(TL.ORDER) do names[#names + 1] = key end
    table.sort(names)
    local parts = {}
    for _, key in ipairs(names) do parts[#parts + 1] = key .. (TL:Enabled(key) and "" or " (off)") end
    ns.Print("tooltip extras: %s; limit %d; sources: %s",
      s.shiftOnly and "Shift only" or "always", s.limit, table.concat(parts, ", "))
  end
end)

function TL:Add(kind, key, owner, fn)
  local list = self.providers[kind]
  if not list then return false end
  for i, p in ipairs(list) do if p.key == key then table.remove(list, i) break end end
  list[#list + 1] = { key = key, owner = owner, fn = fn, order = self.ORDER[key] or 99 }
  table.sort(list, function(a, b) return a.order < b.order end)
  self:Hook(kind)
  return true
end

function TL:Lines(kind, tip, data)
  local settings = self:Settings()
  if settings.shiftOnly and C.Readable(C.Call("IsShiftKeyDown")) ~= true then return {} end
  local out = {}
  local cap = tonumber(settings.limit) or 0
  cap = math.max(0, math.min(10, math.floor(cap)))
  for _, p in ipairs(self.providers[kind] or {}) do
    if self:Enabled(p.key) and (not p.owner or p.owner.enabled) then
      local ok, lines = ns.Safe("tooltip:" .. p.key, p.fn, tip, data)
      if ok and type(lines) == "table" then
        local n = 0
        for _, l in ipairs(lines) do
          if cap > 0 and n >= cap then break end
          if type(l) == "string" or type(l) == "table" then
            out[#out + 1] = type(l) == "table" and l or { l }
            n = n + 1
          end
        end
      end
    end
  end
  return out
end

function TL:Fill(kind, tip, data)
  if tip ~= rawget(_G, "GameTooltip") then return 0 end
  local lines = self:Lines(kind, tip, data)
  for _, l in ipairs(lines) do
    local r, g, b = ns.Theme:Color(l[2] or "accent")
    if l.right and tip.AddDoubleLine then
      -- two columns: label left, value right-aligned (Auctionator style)
      local rr, rg, rb = ns.Theme:Color(l.rightColor or "text")
      tip:AddDoubleLine(tostring(l[1]), tostring(l.right), r, g, b, rr, rg, rb)
    else
      tip:AddLine(tostring(l[1]), r, g, b)
    end
  end
  return #lines
end

function TL:Hook(kind)
  if self.hooked[kind] then return end
  local add, enum = C.Resolve("TooltipDataProcessor.AddTooltipPostCall"), C.Resolve(ENUM[kind])
  if type(add) == "function" and enum then
    self.hooked[kind] = true
    add(enum, function(tip, data) TL:Fill(kind, tip, data) end)
  elseif kind == "unit" and rawget(_G, "GameTooltip") and GameTooltip.HookScript then
    self.hooked[kind] = true
    GameTooltip:HookScript("OnTooltipSetUnit", function(tip) TL:Fill(kind, tip, nil) end)
  end
end
