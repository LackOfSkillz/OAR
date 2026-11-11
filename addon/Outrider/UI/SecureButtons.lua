-- UI/SecureButtons.lua
-- Pool of SecureActionButtonTemplate buttons for rare alerts, the tame
-- helper and macro buttons. The click does the work (a hardware event from
-- Gary); Lua never calls a protected function.
-- Secure buttons can't be created, retargeted, shown or hidden in combat, so:
--   * PREWARM buttons are created out of combat at login, so Acquire in
--     combat still returns one;
--   * every attribute/show/hide change goes through ns.Combat:Run, keyed per
--     button, so only the latest change per button is applied after combat.

local _, ns = ...
local SB = { name = "secure", free = {}, all = {}, PREWARM = 4, MAX = 24 }
ns.SecureButtons = SB

local function create()
  if #SB.all >= SB.MAX then return nil end
  local id = #SB.all + 1
  local b = CreateFrame("Button", "Outrider_SecureButton" .. id, UIParent, "SecureActionButtonTemplate")
  b.outriderID = id
  b:SetSize(32, 32)
  -- Modern clients fire secure clicks on key down when ActionButtonUseKeyDown
  -- is set and on up otherwise; registering both covers either setting.
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:Hide()
  SB.all[id] = b
  return b
end

local function key(btn, what) return "secbtn:" .. btn.outriderID .. ":" .. what end

function SB:Prewarm(n)
  ns.Combat:Run("secure:prewarm", function()
    for _ = #self.all + 1, n or self.PREWARM do
      local b = create()
      if not b then break end
      self.free[#self.free + 1] = b
    end
  end, "secure:prewarm")
end

-- Returns a button (or nil if the pool is empty in combat or at MAX).
function SB:Acquire(owner)
  local b = table.remove(self.free)
  if not b and not ns.Compat.InCombat() then b = create() end
  if not b then
    ns.Log:Warn("secure", "no free secure button for %s", tostring(owner))
    return nil
  end
  b.owner = owner
  -- Top the pool back up out of combat so the next in-combat Acquire works.
  if #self.free == 0 then self:Prewarm(#self.all + 1) end
  return b
end

function SB:SetMacro(btn, text)
  btn.wantMacro = text
  return ns.Combat:Run("secure:macro", function()
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", btn.wantMacro)
    btn.macro = btn.wantMacro
  end, key(btn, "macro"))
end

function SB:SetShown(btn, on)
  return ns.Combat:Run("secure:show", function() btn:SetShown(on and true or false) end, key(btn, "show"))
end

-- Place a secure button; also combat-deferred (moving it is protected too).
function SB:Place(btn, ...)
  local n, args = select("#", ...), { ... }
  return ns.Combat:Run("secure:place", function()
    btn:ClearAllPoints()
    btn:SetPoint(unpack(args, 1, n))
  end, key(btn, "place"))
end

function SB:Release(btn)
  if not btn or not btn.owner then return end
  btn.owner, btn.wantMacro = nil, nil
  ns.Combat:Cancel(key(btn, "macro"))
  ns.Combat:Cancel(key(btn, "show"))
  ns.Combat:Cancel(key(btn, "place"))
  ns.Combat:Run("secure:release", function()
    btn:SetAttribute("type", nil)
    btn:SetAttribute("macrotext", nil)
    btn.macro = nil
    btn:Hide()
    btn:ClearAllPoints()
  end, key(btn, "release"))
  self.free[#self.free + 1] = btn
end

function SB:Counts() return #self.all, #self.free end

-- ------------------------------------------------------- /ride selftest button
-- A small visible secure button. First call: /wave. Each later call swaps
-- between /cheer and /wave (in combat the swap is queued until combat ends).
function SB:SelfTest()
  local t = self.test
  if not t then
    t = self:Acquire("selftest")
    if not t then ns.Print("no secure button available (try out of combat)") return end
    self.test = t
    if not rawget(t, "label") then
      t.label = t:CreateFontString(nil, "OVERLAY")
      ns.Theme:StyleText(t.label, "small", "text")
      t.label:SetPoint("TOP", t, "BOTTOM", 0, -2)
      local bg = t:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(ns.Theme:Color("accent"))
    end
    t:HookScript("OnClick", function() ns.Log:Info("selftest", "secure button clicked (%s)", tostring(t.macro)) end)
    self:Place(t, "CENTER", UIParent, "CENTER", 0, 120)
    self:SetShown(t, true)
  end
  local macro = (t.wantMacro == "/wave") and "/cheer" or "/wave"
  local now = self:SetMacro(t, macro)
  t.label:SetText("Outrider test: " .. macro)
  ns.Log:Info("selftest", "secure button macro %s %s", macro, now and "set" or "queued until combat ends")
  ns.Print("test button: %s %s. Click the blue square.", macro, now and "ready" or "queued until combat ends")
end

function SB:Init()
  self:Prewarm(self.PREWARM)
end
