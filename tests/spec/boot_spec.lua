-- Loads the whole addon like the client does and checks the basics.
local T, mock = ...

local ALLOWED_GLOBALS = {
  Outrider = true, Outrider_DB = true, Outrider_Log = true, Outrider_Snapshots = true, Outrider_Advice = true,
  SLASH_OUTRIDER1 = true, SLASH_OUTRIDER2 = true,
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
      copy = "Nobody-Forever", chars = "", minimap = "off", snap = "", reset = "", selftest = "combat", perf = "", discovered = "5", watch = "The Rake", unwatch = "The Rake", tamemacro = "Test Beast", way = "50 50 test", coords = "", near = "spirit", spells = "", fishkey = "F", weights = "", score = "", gear = "list", share = "", errands = "", feed = "",
    }
    for _, name in ipairs(ns.Slash.order) do
      T.ok(samples[name] ~= nil, "add a sample for new command /ride " .. name)
      game:slash(name .. " " .. samples[name])
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
