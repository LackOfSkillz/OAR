-- Alt handoffs (P6-08). Items are test data.
local T, mock = ...

local function setup(game)
  game.items = {
    [401] = { name = "Swift Cloak", equipLoc = "INVTYPE_CLOAK", bind = 2 },
    [402] = { name = "Bound Cloak", equipLoc = "INVTYPE_CLOAK", bind = 1 },
    [400] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK" },
  }
  game.itemStats = { [401] = { ITEM_MOD_AGILITY_SHORT = 6 }, [402] = { ITEM_MOD_AGILITY_SHORT = 9 }, [400] = { ITEM_MOD_AGILITY_SHORT = 2 } }
  game.worn = { [15] = 400 }
end

T.describe("handoffs", function()
  T.it("hunter hears about a BoE upgrade in the priest's bags once; priest gets the mail toast", function()
    local game = mock.new()
    setup(game)
    local ns = game:loadAddon()
    game:login()
    ns.db.global.inventory["Lumen-Forever"] = { bags = { [401] = 1, [402] = 1 }, bank = {} }
    local found = ns.Handoffs:Scan()
    T.eq(#found, 1)
    T.eq(found[1].itemID, 401)
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].text:GetText(), "Lumen holds Swift Cloak")
    ns.Handoffs:Scan()
    T.eq(ns.Toast:Count(), 1, "once per item")
    T.eq(ns.Handoffs.db["Lumen-Forever"][1].to, ns.db.key)
    -- pretend we are now on Lumen at a mailbox
    ns.Handoffs.db[ns.db.key] = { { to = "Torrant-Forever", itemID = 401, name = "Swift Cloak", pct = 200 } }
    game:fire("MAIL_SHOW")
    T.contains(ns.Toast.visible[#ns.Toast.visible].title:GetText(), "Mail Swift Cloak to Torrant")
    T.eq(#ns.Errors.list, 0)
  end)
end)
