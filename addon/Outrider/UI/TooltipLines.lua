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

TL.ORDER = { verdict = 10, value = 20, owned = 30, needed = 40, beast = 50, target = 60 }
local ENUM = { item = "Enum.TooltipDataType.Item", unit = "Enum.TooltipDataType.Unit" }

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
  local out = {}
  for _, p in ipairs(self.providers[kind] or {}) do
    if not p.owner or p.owner.enabled then
      local ok, lines = ns.Safe("tooltip:" .. p.key, p.fn, tip, data)
      if ok and type(lines) == "table" then
        for _, l in ipairs(lines) do out[#out + 1] = type(l) == "table" and l or { l } end
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
    tip:AddLine(tostring(l[1]), r, g, b)
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
