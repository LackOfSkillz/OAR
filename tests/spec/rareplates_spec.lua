-- Rare marker on nameplates (P7-07). Unit data is test data.
local T, mock = ...

local function mob(id, name, extra)
  local u = { guid = "Creature-0-5250-0-777-" .. id .. "-00001ABC", name = name, level = 20,
              classification = "normal", creatureType = "Beast", family = "Cat" }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

T.describe("rare plates", function()
  T.it("a rare's nameplate gets a star (gold when watched), normal mobs none, removed plates release it", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game.units = {
      nameplate1 = mob(82001, "Silver Rare", { classification = "rare" }),
      nameplate2 = mob(82002, "Plain Wolf"),
      nameplate3 = mob(82003, "Watched One"),
    }
    game:slash("watch Watched One")
    for i = 1, 3 do game:fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
    local P = ns.RarePlates
    T.ok(P.active.nameplate1 and P.active.nameplate1:IsShown())
    T.eq(P.active.nameplate2, nil)
    T.ok(P.active.nameplate3.watched)
    T.no(P.active.nameplate1.watched)
    game:fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    T.eq(P.active.nameplate1, nil)
    T.eq(#P.pool, 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)
