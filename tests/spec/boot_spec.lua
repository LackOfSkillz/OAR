-- Loads the whole addon like the client does and checks the basics.
local T, mock = ...

local ALLOWED_GLOBALS = {
  Outrider = true, Outrider_DB = true, Outrider_Log = true, Outrider_Snapshots = true, Outrider_Advice = true,
  SLASH_OUTRIDER1 = true, SLASH_OUTRIDER2 = true,
  BINDING_HEADER_OUTRIDER = true, BINDING_NAME_OUTRIDER_FIND = true, BINDING_NAME_OUTRIDER_ASK = true, BINDING_NAME_OUTRIDER_PASTE = true, BINDING_NAME_OUTRIDER_CENSUS = true, BINDING_NAME_OUTRIDER_WOWHEAD = true, BINDING_NAME_OUTRIDER_AHPOST = true, BINDING_NAME_OUTRIDER_AHCANCEL = true, -- key binding labels (Bindings.xml)
}

T.describe("boot", function()
  T.it("loads every TOC file and logs in without errors", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    T.eq(#ns.Errors.list, 0, "errors after login")
    T.ok(ns.db and ns.db.key == "Torrant-Forever", "character key")
    T.ok(ns.session, "session id")
  end)

  T.it("writes no unexpected globals", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    for name in pairs(game.globalsWritten) do
      T.ok(ALLOWED_GLOBALS[name], "unexpected global written: " .. tostring(name))
    end
  end)

  T.it("never replaces a Blizzard global (that would taint it)", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    game:slash("status")
    local over = game:overwrittenGlobals()
    T.eq(#over, 0, "overwritten: " .. table.concat(over, ", "))
  end)

  T.it("registers the slash command and settings page", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    T.ok(game.env.SlashCmdList.OUTRIDER, "SlashCmdList.OUTRIDER")
    T.eq(game.env.SLASH_OUTRIDER1, "/outrider")
    T.eq(game.env.SLASH_OUTRIDER2, "/ride")
    T.ok(game.settingsRegistered, "Settings category registered")
  end)

  T.it("runs every /ride command without recording an error", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local samples = {
      help = "", hub = "", version = "", status = "", debug = "on", log = "5", mark = "P0 test",
      errors = "", probe = "", modules = "", module = "Welcome off", export = "", import = "",
      copy = "Nobody-Forever", chars = "", minimap = "off", snap = "", reset = "", selftest = "combat", perf = "", discovered = "5", watch = "The Rake", unwatch = "The Rake", tamemacro = "Test Beast", fight = "concussive off", make = "Cooking", herbs = "", journey = "xp", way = "50 50 test", coords = "", near = "spirit", spells = "", fishkey = "F", weights = "", score = "", gear = "list", share = "", errands = "", feed = "", undercut = "", copychat = "", spell = "", forecast = "", skillup = "", nearby = "", minipins = "", questpins = "", find = "", ask = "SKIP", layout = "", setup = "", access = "font 1.2", chat = "", now = "gold", paste = "", favor = "", trail = "", path = "", report = "", lag = "stop", zonelevels = "", talents = "", heal = "", census = "", bar = "on", runs = "", where = "Linen", wowhead = "", tracker = "level", sell = "list", restock = "list", mail = "all", mapextras = "fishing", history = "all", grave = "", rareroute = "watched", dungeonquests = "unknown", bossloot = "unknown", training = "20", zones = "", wish = "list", note = "list", altdetail = "nobody", auctions = "owned", ahsell = "", fishstats = "", discord = "", talentcode = "", fishwant = "", bags = "close", fights = "list", foodrules = "list", scale = "list", recipesources = "list", gearwindow = "", rareloot = "0", levelroute = "list", toolextras = "list", journal = "The Deadmines", market = "groups", bossnotes = "list", tour = "SKIP", fightplan = "", macrocheck = "", buffs = "on", plates = "", vendor = "", me = "", next = "", quiet = "on", radar = "", role = "list", deals = "", xp60 = "status", nextsession = "", bagswap = "", cozy = "", dqwrong = "Slaying the Beast wrong giver", unlock = "", lock = "", mapdock = "", mode = "advanced",
    }
    for _, name in ipairs(ns.Slash.order) do
      T.ok(samples[name] ~= nil, "add a sample for new command /ride " .. name)
      -- /ride ask reloads on purpose (P9-02: the typed command is the key press); advisor_spec covers it
      if samples[name] ~= "SKIP" then game:slash(name .. " " .. samples[name]) end
    end
    T.eq(#ns.Errors.list, 0, "errors after running every command")
    T.eq(game.reloads, 0, "no command should reload without confirmation")
  end)

  T.it("selftest error is captured, logged and not re-thrown", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game:slash("selftest error")
    T.eq(#ns.Errors.list, 1)
    T.contains(ns.Errors.list[1].msg, "deliberate error")
    local text = game:logout()
    T.contains(text, "deliberate error", "error saved to SavedVariables")
  end)

  T.it("version shows the build stamp", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    game:slash("version")
    T.contains(game:chatText(), "build dev")
    T.contains(game:chatText(), "70862")
  end)

  T.it("greets once per character, then stays quiet", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    T.contains(game:chatText(), "loaded for Torrant-Forever")
    local saved = game:logout()
    local game2 = mock.new({ savedVariables = saved })
    game2:loadAddon()
    game2:login()
    T.no(game2:chatText():find("loaded for", 1, true), "second login should be silent")
  end)
end)
