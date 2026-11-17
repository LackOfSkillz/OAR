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
    local game, ns, M = start({ [1412] = { A, B } })
    T.eq(M:Record(1412), 0) -- already recorded at login
    T.eq(#M:Missing(1412), 0)
    -- now a character that only explored A
    game.explored = { [1412] = { A } }
    local missing = M:Missing(1412)
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
    local game, ns, M = start({ [1412] = { A, B } })
    game.explored = { [1412] = { A } }
    game.mapShownID = 1412
    M.map = M.map or game.env.WorldMapFrame
    if not (M.map and M.map.GetCanvas) then return end -- no world map in this mock
    M:Refresh()
    T.ok(#M.used > 0)
    M:Settings().on = false
    M:Refresh()
    T.eq(#M.used, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)
