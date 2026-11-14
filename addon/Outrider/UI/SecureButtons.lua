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
  b:SetSize(64, 24)  -- fixed: resizing is protected in combat too
  -- Gary's client has ActionButtonUseKeyDown = 1. Registering AnyUp+AnyDown
  -- fired OnClick on both press and release (seen 2026-11-11), so register
  -- only the half that matches the setting, like Blizzard's action bars.
  local keyDown = ns.Compat.Call("C_CVar.GetCVar", "ActionButtonUseKeyDown")
  if keyDown == nil then keyDown = ns.Compat.Call("GetCVar", "ActionButtonUseKeyDown") end
  b:RegisterForClicks(tostring(keyDown) == "1" and "AnyDown" or "AnyUp")
  b:SetFrameStrata("DIALOG")
  -- Look (textures, text) is not protected and may change any time.
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(ns.Theme:Color("raised"))
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(ns.Theme:Color("accent"))
  b.hl:SetAlpha(0.35)
  b.text = b:CreateFontString(nil, "OVERLAY")
  ns.Theme:StyleText(b.text, "normal", "text")
  b.text:SetPoint("CENTER")
  b:Hide()
  SB.all[id] = b
  return b
end

-- Label + width only; safe in combat (no protected change).
function SB:SetLabel(btn, label)
  btn.text:SetText(label or "")
end

local function key(btn, what) return "secbtn:" .. btn.outriderID .. ":" .. what end

-- Width to fit its label (resizing is protected in combat, so deferred).
function SB:FitWidth(btn, min, max)
  local w = btn.text.GetStringWidth and btn.text:GetStringWidth()
  if type(w) ~= "number" then return end
  w = math.max(min or 64, math.min(max or 400, w + 20))
  return ns.Combat:Run("secure:width", function() btn:SetWidth(w) end, key(btn, "width"))
end

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

-- Spell on an item from the bags, the secure template's own way: type "spell"
-- with "target-item" casts the spell and puts it on that item (Feed Pet on a
-- food, Gary 2026-11-13: the macro version did nothing).
function SB:SetSpellOnItem(btn, spell, item)
  btn.wantSpell, btn.wantItem = spell, item
  return ns.Combat:Run("secure:spell", function()
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", btn.wantSpell)
    btn:SetAttribute("target-item", btn.wantItem)
    btn:SetAttribute("macrotext", nil)
    btn.macro = "/cast " .. tostring(btn.wantSpell) .. (btn.wantItem and (" on " .. btn.wantItem) or "")
  end, key(btn, "macro"))
end

-- Draw a secure button above a window it sits on, so the window doesn't catch
-- its clicks (the pet panel covered Feed: clicks never reached it, 2026-11-13).
function SB:Raise(btn, strata)
  return ns.Combat:Run("secure:raise", function() btn:SetFrameStrata(strata or "FULLSCREEN") end, key(btn, "raise"))
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
  SB:SetLabel(btn, "")
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
    t:HookScript("OnClick", function(_, button, down)
      ns.Log:Info("selftest", "secure button clicked (%s) button=%s down=%s keydownCVar=%s", tostring(t.macro), tostring(button),
        tostring(down), tostring(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("ActionButtonUseKeyDown")))
      ns.Events:Fire("OTR_TESTBUTTON_CLICKED", t.macro, down)
    end)
    self:Place(t, "CENTER", UIParent, "CENTER", 0, 120)
    self:SetShown(t, true)
  end
  local macro = (t.wantMacro == "/wave") and "/cheer" or "/wave"
  local now = self:SetMacro(t, macro)
  self:SetLabel(t, macro)
  ns.Log:Info("selftest", "secure button macro %s %s", macro, now and "set" or "queued until combat ends")
  ns.Print("test button: %s %s. Click the button above your character.", macro, now and "ready" or "queued until combat ends")
end

function SB:Init()
  self:Prewarm(self.PREWARM)
end
