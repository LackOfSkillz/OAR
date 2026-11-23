-- Reveal unexplored map areas from what your characters explored (2026-11-17).
local T, mock = ...

local function start(explored)
  local game = mock.new({ class = "HUNTER", level = 20 })
  local function set(k, v) rawset(game.env, k, v) game.base[k] = v end
  game.explored = explored
  set("C_MapExplorationInfo", { GetExploredMapTextures = function(mapID) return (game.explored or {})[mapID] or {} end })
  local mapAPI = game.base.C_Map or {}
  mapAPI.GetMapArtLayers = function() return { { tileWidth = 256, tileHeight = 256, layerWidth = 1002, layerHeight = 668 } } end
  set("C_Map", mapAPI)
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.MapReveal
end

local A = { textureWidth = 300, textureHeight = 200, offsetX = 100, offsetY = 50, fileDataIDs = { 11, 12 } }
local B = { textureWidth = 128, textureHeight = 128, offsetX = 600, offsetY = 300, fileDataIDs = { 21 } }

T.describe("map reveal", function()
  T.it("records explored areas and shows what another character explored", function()
    local game, ns, M = start({ [99901] = { A, B } })
    T.eq(M:Record(99901), 2)
    T.eq(M:Record(99901), 0) -- nothing new the second time
    T.eq(#M:Missing(99901), 0)
    -- now a character that only explored A
    game.explored = { [99901] = { A } }
    local missing = M:Missing(99901)
    T.eq(#missing, 1)
    T.eq(missing[1].ids[1], 21)
  end)

  T.it("cuts an overlay into tiles the way Blizzard's own map does", function()
    local tiles = (function()
      local game, ns, M = start({})
      return M.Tiles({ w = 300, h = 200, x = 100, y = 50, ids = { 11, 12 } }, 256, 256)
    end)()
    T.eq(#tiles, 2)
    T.eq(tiles[1].w, 256)
    T.eq(tiles[2].w, 44)
    T.eq(tiles[2].x, 356)
    T.eq(tiles[2].u, 44 / 64)
    T.eq(tiles[1].h, 200)
    T.eq(tiles[1].v, 200 / 256)
  end)

  T.it("draws the missing areas on the world map, and nothing when switched off", function()
    local game, ns, M = start({ [99901] = { A, B } })
    M:Record(99901) -- another character explored A and B
    game.explored = { [99901] = { A } }
    game.mapShownID = 99901
    M.map = M.map or game.env.WorldMapFrame
    if not (M.map and M.map.GetCanvas) then return end -- no world map in this mock
    M:Refresh()
    T.ok(#M.used > 0)
    -- revealed areas are faintly tinted so they stand apart from explored land
    T.ok(M.TINT > 0.7 and M.TINT < 1, "a faint tint, not the old dark shadow")
    M:Settings().on = false
    M:Refresh()
    T.eq(#M.used, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("map extras", function()
  T.it("lists real undiscovered overlay positions and counts", function()
    local game, ns, M = start({ [99901] = { A, B } })
    M:Record(99901)
    game.explored = { [99901] = { A } }
    local result = M:MissingSummary(99901)
    T.eq(result.missing, 1)
    T.eq(result.locations[1].x, 600)
    T.eq(result.locations[1].y, 300)
    T.eq(result.source, "account observations only")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("shows tier guidance for fishing zones and dated but unverified Faire visits", function()
    local game, ns, M = start({})
    local f = M:FishingAdvice(1412)
    T.eq(f.zone, "Mulgore")
    T.eq(f.from, 1)
    local now = os.time({ year = 2026, month = 11, day = 18, hour = 12 })
    local faire = M:NextFaire(now)
    T.eq(faire.zone, "Mulgore")
    T.eq(faire.mapID, 1412)
    T.eq(faire.verified, false)
    game:slash("mapextras fishing")
    T.contains(game:chatText(), "suggested Fishing")
  end)
end)

T.describe("map reveal data", function()
  T.it("the game's own map areas for every Forever zone are loaded, with tiles", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    local d = ns.MapOverlays
    T.ok(d and d.build)
    local zones, areas = 0, 0
    for _, list in pairs(d.maps) do
      zones = zones + 1
      for _, e in ipairs(list) do
        areas = areas + 1
        T.ok(e[1] > 0 and e[2] > 0 and #e[5] >= 1, "each area has a size and tiles")
      end
    end
    T.ok(zones >= 40)
    T.ok(areas >= 500)
    -- a character that explored nothing sees every area of Mulgore as unexplored
    T.eq(#ns.MapReveal:Missing(1412), #d.maps[1412])
  end)
end)
