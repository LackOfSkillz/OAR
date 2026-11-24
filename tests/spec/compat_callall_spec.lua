-- Compat.Call returns at most five values; Compat.CallAll keeps them all.
-- Four modules read a sixth or seventh value through Call and always got nil
-- (Census names, Favor values, LootRolls need/greed, PetStatus autocast),
-- found 2026-11-24 while building OI03-06. This keeps it from coming back.
local T, mock = ...

T.describe("Compat.CallAll", function()
  T.it("Call stops at five values; CallAll keeps every one", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game.env.OutriderTestSeven = function() return 1, 2, 3, 4, 5, 6, 7 end
    T.eq(select("#", ns.Compat.Call("OutriderTestSeven")), 5)
    local a = { ns.Compat.CallAll("OutriderTestSeven") }
    T.eq(#a, 7) T.eq(a[7], 7)
    T.eq(ns.Compat.CallAll("NoSuchFunctionAnywhere"), nil)
    game.env.OutriderTestSeven = function() error("boom") end
    T.eq(ns.Compat.CallAll("OutriderTestSeven"), nil, "an error is nil, as with Call")
  end)

  T.it("no addon code reads more than five values from Compat.Call", function()
    local files = mock.listLua("addon/Outrider")
    local bad = {}
    for _, path in ipairs(files) do
      local fh = io.open(path)
      if fh then
        local n = 0
        for line in fh:lines() do
          n = n + 1
          local vars = line:match("local%s+([%w_,%s]-)%s*=%s*C%.Call%(") or line:match("local%s+([%w_,%s]-)%s*=%s*ns%.Compat%.Call%(")
          if vars then
            local count = select(2, vars:gsub(",", ",")) + 1
            if count > 5 then bad[#bad + 1] = path .. ":" .. n end
          end
          local k = line:match("select%((%d+),%s*C%.Call%(") or line:match("select%((%d+),%s*ns%.Compat%.Call%(")
          if k and tonumber(k) > 5 then bad[#bad + 1] = path .. ":" .. n end
        end
        fh:close()
      end
    end
    T.ok(#files > 50, "addon files listed")
    T.eq(#bad, 0, table.concat(bad, ", "))
  end)
end)
