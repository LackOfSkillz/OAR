-- Core/Boot.lua
-- Last file in the TOC. Wires the lifecycle:
--   ADDON_LOADED (ours) -> SavedVariables exist: DB, log, errors, module init
--   PLAYER_LOGIN        -> UI, minimap, modules enabled for this character
--   PLAYER_LOGOUT       -> stamp lastSave (fires on /reload too)

local ADDON, ns = ...
local Boot = { name = "boot" }
ns.Boot = Boot

local function newSession()
  local t = time and time() or 0
  local r = math.random and math.random(0, 4095) or 0
  return string.format("%05x%03x", t % 1048576, r)
end

function Boot:OnAddonLoaded(_, name)
  if name ~= ADDON then return end
  ns.Events:Off("ADDON_LOADED", Boot)
  local clock = rawget(_G, "debugprofilestop")
  local t0 = clock and clock()
  ns.session = newSession()
  ns.bootClock = GetTime and GetTime() or 0
  ns.Log:Attach()
  ns.DB:Init()
  ns.Errors:Attach()
  ns.DB:StartSession(ns.session)
  local sv, loads = ns.DB:SavedVariablesStatus()
  ns.Log:Info("boot", "session %s start: v%s build %s char %s loads %d sv=%s",
    ns.session, ns.version, ns.build, ns.db.key, loads, sv)
  ns.Modules:InitializeAll()
  -- OI01-04 runtime baseline: time spent in our own load step (ms)
  if t0 then ns.bootTimes = { initMs = clock() - t0 } end
end

function Boot:OnLogin()
  local clock = rawget(_G, "debugprofilestop")
  local t0 = clock and clock()
  ns.Errors:HookBugGrabber()
  ns.Errors:HookGlobal()
  ns.Conflicts:Detect()
  if ns.db.char.classAccent ~= false then ns.Theme:UseClassAccent() end -- class color by default (owner request 2026-11-13)
  ns.Safe("Theme:ApplyAccessibility", ns.Theme.ApplyAccessibility, ns.Theme)
  ns.Safe("Theme:RegisterMedia", ns.Theme.RegisterMedia, ns.Theme)
  ns.Settings:Init()
  ns.MinimapButton:Init()
  ns.SecureButtons:Init()
  ns.Modules:EnableAll()
  if ns.db.char.hub.shown then ns.Hub:Toggle() end
  local on = 0
  for _, m in ipairs(ns.Modules.list) do if m.enabled then on = on + 1 end end
  if t0 then
    ns.bootTimes = ns.bootTimes or {}
    ns.bootTimes.loginMs = clock() - t0
  end
  ns.Log:Info("boot", "login complete: %d/%d modules on, %d addons detected", on, #ns.Modules.list, #(ns.Conflicts.found or {}))
  -- One line per login so Gary can see Outrider is alive (setting: loginLine).
  if ns.db.global.loginLine ~= false then
    local scan = ns.Modules:Get("RareScan")
    local watch = {}
    if scan and scan.enabled then
      for k in pairs(scan:Settings().watch) do watch[#watch + 1] = ns.TitleCase(k) end
      table.sort(watch)
    end
    ns.Print("%d features on%s. /ride shows what each is doing.", on,
      #watch > 0 and (", watching for " .. table.concat(watch, ", ")) or "")
  end
end

function Boot:OnLogout()
  ns.DB:OnLogout()
  ns.Errors:Save()
  ns.Log:Info("boot", "session %s saved", tostring(ns.session))
end

ns.Events:On("ADDON_LOADED", Boot, function(...) Boot:OnAddonLoaded(...) end)
ns.Events:On("PLAYER_LOGIN", Boot, function() Boot:OnLogin() end)
ns.Events:On("PLAYER_LOGOUT", Boot, function() Boot:OnLogout() end)
ns.Events:On("ADDON_ACTION_BLOCKED", ns.Errors, function(...) ns.Errors:OnBlocked(...) end)
ns.Events:On("ADDON_ACTION_FORBIDDEN", ns.Errors, function(...) ns.Errors:OnBlocked(...) end)
