-- Command bar (P7-10): ten sample queries open the right thing. Data is test data.
local T, mock = ...

local function session()
  local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5 })
  game.env.Outrider_DataGear = { source = "test", items = {
    [502] = { "Sturdy Recurve", 22, 22, { { "vendor", 1412, 0.6, 0.6, "Varia Hardhide", nil, "Horde" } } } } }
  game.items = { [502] = { name = "Sturdy Recurve", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 } }
  game.itemStats = { [502] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 } }
  local ns = game:loadAddon()
  game:login()
  ns.db.global.pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.45, y = 0.45, name = "Varia Hardhide" }
  ns.db.global.pois["npc-2-spirit_healer"] = { id = "npc-2-spirit_healer", kind = "spirit_healer", mapID = 1412, x = 0.52, y = 0.52, name = "Spirit Healer" }
  if ns.MapPins then ns.MapPins:Invalidate() end -- placed directly, as the addon's own writers then do
  ns.db.global.sightings[5807] = { { t = game.now, state = "alive", mapID = 1412, x = 0.3, y = 0.3, layer = 1 } }
  ns.db.global.discovered = ns.db.global.discovered or {}
  ns.db.global.discovered.npcs = ns.db.global.discovered.npcs or {}
  ns.db.global.discovered.npcs[5807] = { name = "The Rake", classification = "rare", mapID = 1412 }
  return game, ns
end

local function first(ns, q) local r = ns.Find:Search(q)[1] return r and r.kind, r and r.label end

T.describe("find", function()
  T.it("ten sample queries pick the right kind of result", function()
    local _, ns = session()
    local cases = {
      { "rake", "rare" }, { "spirit", "place" }, { "bank", "place" }, { "varia", "npc" }, { "bow", "gear" },
      { "recurve", "gear" }, { "macro pull", "macro" }, { "feed", "tab" }, { "errands", "tab" }, { "forecasts", "tab" },
    }
    for _, c in ipairs(cases) do
      local kind, label = first(ns, c[1])
      T.eq(kind, c[2], "query '" .. c[1] .. "' gave " .. tostring(label))
    end
  end)

  T.it("running a result opens the panel or sets the waypoint; never errors", function()
    local game, ns = session()
    T.ok(ns.Find:Run("rake"))
    T.eq(ns.Waypoints.current.title, "The Rake")
    T.ok(ns.MapPins.card:IsShown())
    ns.Find:Run("bow")
    T.eq(ns.Hub.current, "gear")
    local said = {}
    for _, it in ipairs(ns.Hub.byId.gear.panel.form.items) do if it.note then said[#said + 1] = it.note:GetText() or "" end end
    T.contains(table.concat(said, " "), "matching 'bow'")
    ns.Find:Run("feed")
    T.eq(ns.Hub.current, "feed")
    T.no(ns.Find:Run("zzzz nothing"))
    game:slash("find")
    T.ok(ns.Find.frame:IsShown())
    T.eq(#ns.Errors.list, 0)
  end)
end)
