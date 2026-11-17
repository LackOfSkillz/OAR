-- The user guide: the in-game Help text and docs/USER_GUIDE.md come from the
-- same data, and the generated file must be current.
local T, mock = ...

T.describe("help and user guide", function()
  T.it("every section has entries with a title and text; the Help tab builds", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    T.ok(#ns.HelpData >= 10)
    for _, sec in ipairs(ns.HelpData) do
      T.ok(type(sec[1]) == "string" and #sec[3] > 0, sec[1])
      for _, t in ipairs(sec[3]) do T.ok(#t[1] > 0 and #t[2] > 20, t[1]) end
    end
    T.ok(ns.Hub.byId.help, "Help tab registered")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("docs/USER_GUIDE.md is generated from the current help text", function()
    local f = io.open("docs/USER_GUIDE.md", "rb")
    T.ok(f, "docs/USER_GUIDE.md exists")
    local doc = f:read("*a")
    f:close()
    local game = mock.new()
    local ns = game:loadAddon()
    for _, sec in ipairs(ns.HelpData) do
      for _, t in ipairs(sec[3]) do
        T.ok(doc:find("**" .. t[1] .. ".** " .. t[2], 1, true), "in the guide: " .. t[1] .. " (run python tools/lua.py tools/build_guide.lua)")
      end
    end
  end)
end)
