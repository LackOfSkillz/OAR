-- Modules/Ammo.lua  (HUNTER, P2-11)
-- Ammo left = GetInventoryItemCount("player", 0) (the Classic ammo slot;
-- GetInventoryItemCount is present on Forever, probe 2026-11-11). Warns once
-- per session under `low` (200) and once more under `critical` (50).
-- Logs the count at login so Claude can confirm the slot reads correctly
-- (auto-collected).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Ammo", {
  title = "Ammo warnings",
  phase = "P2",
  order = 37,
  classes = { HUNTER = true },
  defaults = { low = 200, critical = 50 },
})

M.SLOT = 0

function M:OnEnable()
  self.warned = {}
  self:On("UNIT_INVENTORY_CHANGED", function(mod, _, unit) if unit == "player" then mod:Check() end end)
  self:On("BAG_UPDATE_DELAYED", function(mod) mod:Check() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Check("login") end)
end

function M:OnDisable() ns.ThrottleCancel("ammo") end

function M:Count()
  local n = C.Call("GetInventoryItemCount", "player", self.SLOT)
  return type(n) == "number" and n or nil
end

function M:Check(why)
  ns.Throttle("ammo", 0.5, function() M:Evaluate(why) end)
end

function M:Evaluate(why)
  local n = self:Count()
  if why == "login" then
    local link = C.Call("GetInventoryItemLink", "player", self.SLOT)
    self:Info("ammo at login: %s (slot %d item %s)", tostring(n), self.SLOT, tostring(link and link:match("item:(%d+)")))
  end
  if not n then return end
  -- Forever reads the count but never a link for the ammo slot ("slot 0 item
  -- nil" at 38 arrows, 2026-11-13), so 0 means out, not "no quiver": say so
  -- once and point at the nearest vendor that sells ammo.
  if n == 0 then
    if (self.last or 0) > 0 then -- ran out while playing (at login, Home's to-do list says "Buy ammo")
      if not self.warned.out then
        self.warned.out = true
        local ok, msg = ns.Nearest and ns.Nearest:Go("ammo")
        ns.Toast:Show({ title = "Out of ammo", color = "bad", duration = 12,
          text = ok and ("Arrow set to " .. tostring(msg)) or "Buy arrows at a vendor that sells ammo." })
        self:Info("out of ammo (%s)", tostring(msg))
      end
    end
    self.last = 0
    return
  end
  self.warned.out = nil
  local s = self:Settings()
  if n < s.critical and not self.warned.critical then
    self.warned.critical, self.warned.low = true, true
    self:Alert(n, "Ammo almost out", "bad")
  elseif n < s.low and not self.warned.low then
    self.warned.low = true
    self:Alert(n, "Ammo running low", "warn")
  end
  self.last = n
end

function M:Alert(n, title, color)
  ns.Toast:Show({ title = title, text = string.format("%d left. Stock up at the next vendor.", n), color = color, duration = 10 })
  self:Info("ammo warning: %s (%d left)", title, n)
end

function M:Snapshot() return { ammo = self.last } end

function M:Activity()
  local n = self:Count()
  return n and string.format("%d ammo (warns under %d)", n, self:Settings().low) or "no ammo slot reading"
end
