-- Core/Slash.lua
-- /ride commands. Keep every command short and quiet; most Claude Code test
-- steps are "type /ride <something>, then /reload".

local _, ns = ...
local Slash = { name = "slash", commands = {}, order = {} }
ns.Slash = Slash

local function add(name, usage, fn)
  Slash.commands[name] = { usage = usage, fn = fn }
  Slash.order[#Slash.order + 1] = name
end

add("help", "list commands", function()
  ns.Print("commands:")
  for _, name in ipairs(Slash.order) do
    ns.Print("  /ride %s %s", name, Slash.commands[name].usage)
  end
end)

add("hub", "open or close the hub (same as /ride)", function() ns.Hub:Toggle() end)

add("version", "addon version, build stamp and client build", function()
  local v, b, _, iface = "", "", nil, ""
  if GetBuildInfo then v, b, _, iface = GetBuildInfo() end
  ns.Print("v%s build %s | client %s (%s) interface %s", ns.version, ns.build, tostring(v), tostring(b), tostring(iface))
  ns.Log:Info("slash", "version v%s build %s client %s %s iface %s", ns.version, ns.build, tostring(v), tostring(b), tostring(iface))
end)

add("status", "character, saved-settings check, modules, errors", function()
  local sv, loads = ns.DB:SavedVariablesStatus()
  local on, total = 0, 0
  if ns.DB.safeMode then ns.Print("|cffff6060safe mode|r: %s", ns.DB.safeMode) end
  for _, s in ipairs(ns.Modules:Status()) do total = total + 1 if s.enabled then on = on + 1 end end
  ns.Print("%s (%s) | saved settings read back: %s | loads %d", ns.db.key, ns.db.char.meta.class, sv, loads)
  ns.Print("modules %d/%d on | errors %d | queued for after combat %d | %s",
    on, total, #ns.Errors.list, ns.Combat:Pending(), ns.Probe:Summary())
  ns.Log:Info("slash", "status sv=%s loads=%d modules=%d/%d errors=%d", sv, loads, on, total, #ns.Errors.list)
end)

add("debug", "on|off  verbose logging to the saved log", function(arg)
  ns.db.global.debug = (arg == "on")
  ns.Print("debug %s", ns.db.global.debug and "on" or "off")
end)

add("log", "[n]  show the last n log lines (default 10)", function(arg)
  for _, line in ipairs(ns.Log:Tail(tonumber(arg) or 10)) do ns.Print(ns.Log:FormatLine(line)) end
end)

add("mark", "<text>  write a marker line so Claude can find this point in the log", function(arg)
  ns.Log:Mark(arg)
  ns.Print("marked: %s", arg or "")
end)

add("errors", "[clear]  show recent Outrider errors", function(arg)
  if arg == "clear" then ns.Errors:Clear() ns.Print("errors cleared") return end
  local list = ns.Errors:Recent(10)
  if #list == 0 then ns.Print("no errors") return end
  for _, e in ipairs(list) do ns.Print("|cffff6060x%d|r %s: %s", e.count, e.where, e.msg) end
end)

add("probe", "record which game APIs exist (then /reload)", function()
  local p = ns.Probe:Run()
  ns.Print("probe done: %d present, %d missing. Type /reload so the results are saved.", p.summary.present, p.summary.missing)
end)

add("modules", "list modules and why each is on or off", function()
  for _, s in ipairs(ns.Modules:Status()) do
    ns.Print("%s %s  %s", s.enabled and "|cff66dd77on |r" or "|cff999999off|r", s.name, s.enabled and "" or tostring(s.reason))
  end
end)

add("module", "<name> on|off  switch a module for this character", function(arg)
  local name, state = (arg or ""):match("^(%S+)%s+(%S+)$")
  if not name or (state ~= "on" and state ~= "off") then ns.Print("usage: /ride module <name> on|off") return end
  local ok, err = ns.Modules:SetEnabled(name, state == "on")
  if not ok then ns.Print("%s", err) return end
  local queued = ns.Combat:Pending() > 0
  ns.Print("%s %s%s", name, state, queued and " (after combat)" or "")
end)

add("export", "show this character's settings as a string", function()
  local s, err = ns.Profiles:Export()
  if s then ns.UI:TextDialog("Export settings (" .. ns.db.key .. ")", s, "copy") else ns.Print("%s", tostring(err)) end
end)

add("import", "paste a settings string", function()
  ns.UI:TextDialog("Import settings into " .. ns.db.key, "", "paste", function(text)
    local ok, err = ns.Profiles:Import(text)
    if ok then ns.Print("imported. Type /reload to apply everything.") end
    return ok, err
  end)
end)

add("copy", "<Name-Realm>  copy settings from another of your characters", function(arg)
  local ok, err = ns.Profiles:CopyFrom(arg)
  ns.Print(ok and "copied. Type /reload to apply everything." or tostring(err))
end)

add("chars", "list characters Outrider knows on this account", function()
  for _, c in ipairs(ns.DB:Characters()) do
    ns.Print("%s%s %s %s", c.current and "* " or "  ", c.key, tostring(c.class), tostring(c.level or ""))
  end
end)

add("minimap", "on|off  show or hide the minimap button", function(arg)
  ns.MinimapButton:SetHidden(arg == "off")
end)

add("snap", "save a snapshot of this character (for the future advisor)", function()
  ns.Snapshot:Collect()
  ns.Print("snapshot taken. It is written to disk on /reload or logout.")
end)

add("reset", "char|all confirm  wipe settings (needs the word confirm)", function(arg)
  local scope, confirm = (arg or ""):match("^(%S+)%s*(%S*)$")
  if confirm ~= "confirm" or (scope ~= "char" and scope ~= "all") then
    ns.Print("type /ride reset char confirm  or  /ride reset all confirm") return
  end
  if scope == "char" then ns.DB:ResetChar() else ns.DB:ResetAll() end
  ns.Print("reset %s. Reloading.", scope)
  ReloadUI()
end)

add("selftest", "error|combat|button|toast|widgets  checks for the test pipeline", function(arg)
  if arg == "error" then
    ns.Safe("selftest", function() error("Outrider selftest: deliberate error (this is expected)") end)
    ns.Print("deliberate error recorded. Type /reload so Claude can read it.")
  elseif arg == "combat" then
    ns.Combat:Run("selftest", function() ns.Log:Info("selftest", "combat queue ran") ns.Print("combat queue ran") end, "selftest")
    ns.Print(ns.Combat:Pending() > 0 and "queued until combat ends" or "ran immediately (not in combat)")
  elseif arg == "button" then
    ns.SecureButtons:SelfTest()
  elseif arg == "toast" then
    ns.Toast:SelfTest()
  elseif arg == "widgets" then
    ns.UI:WidgetTest()
  else
    ns.Print("usage: /ride selftest error|combat|button|toast|widgets")
  end
end)

function Slash:Run(line)
  line = (line or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = line:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if rest == "" then rest = nil end
  if cmd == "" then return ns.Hub:Toggle() end
  local c = self.commands[cmd]
  if not c then ns.Print("unknown command '%s'. /ride help", cmd) return end
  ns.Log:Debug("slash", "/ride %s %s", cmd, rest or "")
  ns.Safe("slash:" .. cmd, c.fn, rest)
end

SLASH_OUTRIDER1 = "/outrider"
SLASH_OUTRIDER2 = "/ride"
-- Never reassign SlashCmdList itself (that taints a Blizzard global); only add our key.
SlashCmdList.OUTRIDER = function(msg) Slash:Run(msg) end
