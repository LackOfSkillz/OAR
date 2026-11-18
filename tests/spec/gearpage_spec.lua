-- Gear page paper-doll (premium rebuild 2026-11-18).
local T, mock = ...

T.describe("gear paper-doll", function()
  T.it("shows every equipment slot and filters upgrades by the clicked slot", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    ns.Hub:Toggle()
    ns.Hub:ShowTab("gear")
    local N = ns.Nearby
    local doll = N:Doll(ns.Hub.frame)
    T.eq(#doll.slots, #N.DOLL)
    doll.slots[1].__scripts.OnClick(doll.slots[1])
    T.eq(N.slotFilter, 1, "head picked")
    doll.slots[1].__scripts.OnClick(doll.slots[1])
    T.eq(N.slotFilter, nil, "click again for all")
    T.eq(#ns.Errors.list, 0)
  end)
end)
