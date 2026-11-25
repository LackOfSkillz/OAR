-- OI04-11: Quartermaster early reservations.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Quartermaster
end

T.describe("Quartermaster reservations (OI04-11)", function()
  T.it("reserved stock is never counted twice across holds", function()
    local _, _, Q = session()
    local holds = { { itemID = 2589, count = 6, purpose = "kept by you" }, { itemID = 2589, count = 6, purpose = "your craft queue" } }
    local out = Q.Allocate(holds, { [2589] = { mine = 8, alts = {} } })
    T.eq(out[1].fromMine, 6) T.eq(out[1].short, 0)
    T.eq(out[2].fromMine, 2, "only what's left") T.eq(out[2].short, 4)
  end)

  T.it("own stock first, then alts; an alt's count over a week old is flagged stale", function()
    local _, _, Q = session()
    local now = 1800000000
    local out = Q.Allocate({ { itemID = 1, count = 10, purpose = "x" } },
      { [1] = { mine = 3, alts = { { char = "Lumen-F", count = 4, at = now - 86400 }, { char = "Old-F", count = 5, at = now - 10 * 86400 } } } }, now)
    T.eq(out[1].fromMine, 3)
    T.eq(out[1].fromAlts[1].count, 4) T.eq(out[1].fromAlts[1].stale, nil)
    T.eq(out[1].fromAlts[2].count, 3) T.eq(out[1].fromAlts[2].stale, true)
    T.ok(out[1].stale)
  end)

  T.it("the craft queue's needs and your own holds both count; yours first", function()
    local _, ns, Q = session()
    local CQ = ns.Modules:Get("CraftQueue")
    CQ.enabled = true
    CQ.Needed = function() return { [2589] = 4 } end
    Q.HoldItem(2592, 10, "a friend's order")
    local holds = Q.Holds()
    T.eq(holds[1].itemID, 2592) T.eq(holds[1].explicit, true)
    T.eq(holds[2].purpose, "your craft queue")
  end)

  T.it("the item tooltip says what it's held for, with stale alts flagged; nothing is blocked", function()
    local game, ns, Q = session()
    ns.db.global.inventory = ns.db.global.inventory or {}
    ns.db.global.inventory[ns.db.key] = { bags = { [2589] = 2 }, at = game.now }
    ns.db.global.inventory["Old-Forever"] = { bags = { [2589] = 10 }, at = game.now - 30 * 86400 }
    Q.HoldItem(2589, 5, "your tailoring")
    local line = Q.Line(2589)
    T.ok(line:find("Held: 5 for your tailoring") and line:find("over a week old"), line)
    local lines = ns.Modules:Get("Inventory"):TooltipLines(2589)
    T.ok(table.concat(lines, "|"):find("Held:"), "shown on the tooltip")
    local fh = assert(io.open("addon/Outrider/Intelligence/Quartermaster.lua"))
    local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
    fh:close()
    T.ok(not code:find("UseContainerItem") and not code:find("SendMail") and not code:find("PickupContainerItem"), "never moves or sells")
  end)

  T.it("held gold (goal reserve plus an explicit hold) isn't spendable in gear advice", function()
    local _, ns, Q = session()
    ns.NexusGoals:Create("gold", { priority = 1, reserveCopper = 50000 })
    Q.Store().gold = { copper = 20000, purpose = "mount" }
    T.eq(Q.GoldHeld(), 70000)
  end)
end)
