-- OI07-11 navigation and UI quality: every page at the largest text and window
-- sizes, every page two clicks away, Esc closes, every texture within the client's limits.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function readTga(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local h = f:read(18)
  f:close()
  if not h or #h < 18 then return nil end
  local w = h:byte(13) + h:byte(14) * 256
  local hh = h:byte(15) + h:byte(16) * 256
  return w, hh, h:byte(17)
end

local function pow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) or n == 1 end

T.describe("UI quality (OI07-11)", function()
  T.it("every page builds at the largest text and window size, and at the smallest", function()
    for _, size in ipairs({ { 1.5, 1.5 }, { 0.8, 0.7 } }) do
      local game, ns = session()
      local a = ns.Theme:Access()
      a.fontScale, a.uiScale = size[1], size[2]
      local saved = game:logout()
      local g2, ns2 = session({ savedVariables = saved, level = 20, class = "HUNTER" })
      g2:slash("")
      local f = ns2.Hub.frame
      for id in pairs(ns2.Hub.byId) do f.tabBar:Select(id) T.eq(ns2.Hub.current, id, id) end
      local e = ns2.Errors.list[1]
      T.eq(#ns2.Errors.list, 0, "errors at size " .. size[1] .. ": " .. (e and (tostring(e.where or e.source) .. " " .. tostring(e.msg or e.message)) or ""))
    end
  end)

  T.it("every page is two clicks away: a sidebar entry, then at most one sub-tab", function()
    local game, ns = session()
    game:slash("")
    local order = {}
    for _, id in ipairs(ns.Hub.frame.tabBar.order) do order[id] = true end
    for id, t in pairs(ns.Hub.byId) do
      if ns.Hub:Visible(t) then T.ok(order[ns.Hub.NavOf(id)], id .. " has a sidebar entry (" .. tostring(ns.Hub.NavOf(id)) .. ")") end
    end
  end)

  T.it("Esc closes the main window", function()
    local game, ns = session()
    game:slash("")
    local name = ns.Hub.frame.GetName and ns.Hub.frame:GetName()
    local found = false
    for _, n in ipairs(game.env.UISpecialFrames or {}) do if n == name then found = true end end
    T.ok(found, "the hub is in UISpecialFrames")
  end)

  T.it("every texture fits the client: power-of-two sides, at most 1024x256 or 512x512 of 32-bit pixels", function()
    local list = io.popen and io.popen('dir /b /s "addon\\Outrider\\Art\\*.tga" 2>nul')
    local files = {}
    if list then for line in list:lines() do files[#files + 1] = line end list:close() end
    if #files == 0 then
      local l2 = io.popen and io.popen('find addon/Outrider/Art -name "*.tga" 2>/dev/null')
      if l2 then for line in l2:lines() do files[#files + 1] = line end l2:close() end
    end
    T.ok(#files > 0, "found the art")
    for _, path in ipairs(files) do
      local w, h, bpp = readTga(path)
      T.ok(w and h, path)
      T.ok(pow2(w) and pow2(h), path .. " sides " .. tostring(w) .. "x" .. tostring(h))
      T.ok(w * h * (bpp or 32) / 8 <= 1048576, path .. " is over 1 MB of pixels (draws black on Forever)")
    end
  end)
end)
