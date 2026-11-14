-- Every shipped data pack must validate, and macros must follow the house rules.
local T, mock = ...

local game = mock.new()
local ns = game:loadAddon()

T.describe("shipped data packs", function()
  T.it("register without validation warnings", function()
    for _, line in ipairs(ns.Log:Tail(10000)) do
      T.ok(line.m ~= "data", "data warning: " .. tostring(line.x))
    end
    T.ok(#ns.Data:All("macro") >= 20, "macro library seeded")
  end)

  T.it("macros fit in 255 characters with long placeholder values", function()
    for _, m in ipairs(ns.Data:All("macro")) do
      local filled = m.body:gsub("{RARE_LINES}", string.rep("/targetexact Twelve Chars\n", 8))
      filled = filled:gsub("{[%u_]+}", string.rep("x", 24))
      T.ok(#filled <= 255, m.id .. " is " .. #filled .. " characters when filled")
    end
  end)

  T.it("Auto Shot and aspects use ! so a second press never toggles them off", function()
    for _, m in ipairs(ns.Data:All("macro")) do
      for line in m.body:gmatch("[^\n]+") do
        if line:match("^/cast") then
          T.no(line:find("[^!]Auto Shot") and not line:find("#showtooltip"), m.id .. ": Auto Shot without !")
          for aspect in line:gmatch("([!]?)Aspect of the") do
            T.eq(aspect, "!", m.id .. ": aspect without !")
          end
        end
      end
    end
  end)

  T.it("only uses known slash commands", function()
    local ok = { cast = true, castsequence = true, use = true, target = true, targetexact = true, targetenemy = true,
      cleartarget = true, stopmacro = true, petattack = true, petfollow = true, petpassive = true, startattack = true,
      stopattack = true, focus = true, clearfocus = true, dismount = true, stopcasting = true, cancelaura = true, cancelform = true }
    for _, m in ipairs(ns.Data:All("macro")) do
      for line in m.body:gmatch("[^\n]+") do
        local cmd = line:match("^/(%a+)")
        if cmd then T.ok(ok[cmd], m.id .. ": unexpected command /" .. cmd) end
        T.ok(line:match("^/") or line:match("^#showtooltip") or line:match("^{[%u_]+}$"), m.id .. ": odd line " .. line)
      end
    end
  end)

  T.it("every entry names its source", function()
    for _, m in ipairs(ns.Data:All("macro")) do T.ok(m.source, m.id .. " has no source") end
  end)
end)
