-- Macro engine (P4-01): fill, validate, explain.
local T, mock = ...

local function engine()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return ns.MacroEngine, ns
end

T.describe("macro engine", function()
  T.it("fills placeholders and lists missing ones", function()
    local E = engine()
    local out, missing = E.Fill("/targetexact {TARGET}\n/use {FOOD}", { TARGET = "Mystmane" })
    T.eq(out, "/targetexact Mystmane\n/use {FOOD}")
    T.same(missing, { "FOOD" })
  end)

  T.it("rejects command injection through placeholders", function()
    local E = engine()
    local body, missing = E.Fill("/targetexact {TARGET}", { TARGET = "Rare\n/cast Spell" })
    T.eq(body, "/targetexact {TARGET}")
    T.same(missing, { "TARGET" })
    local bad, no = E.Fill("{RARE_LINES}", {
      RARE_LINES = "/targetexact Test Beast\n/script malicious()"
    })
    T.eq(bad, "{RARE_LINES}")
    T.same(no, { "RARE_LINES" })
    local good, clean = E.Fill("{RARE_LINES}", {
      RARE_LINES = "/targetexact Rare One\n/targetexact Rare Two"
    })
    T.eq(good, "/targetexact Rare One\n/targetexact Rare Two")
    T.eq(#clean, 0)
    local accented = E.Fill("/targetexact {TARGET}", { TARGET = "Den'dralass" })
    T.eq(accented, "/targetexact Den'dralass")
  end)

  T.it("every macro in every pack validates with no errors", function()
    local E, ns = engine()
    local n = 0
    for _, m in ipairs(ns.Data:All("macro")) do
      n = n + 1
      local body = E.Fill(m.body, { TARGET = "Test Beast", FOOD = "Tough Jerky", MOUNT = "Horse" })
      for _, p in ipairs(E.Validate(body)) do
        T.ok(p.level ~= "error", m.id .. ": " .. p.msg)
      end
    end
    T.ok(n >= 19)
  end)

  T.it("flags real problems", function()
    local E = engine()
    T.eq(E.Errors(string.rep("/cast Arcane Shot\n", 20)), 1, "over 255")
    T.eq(E.Errors("/cast [mod:shift Arcane Shot"), 1, "unbalanced")
    local warn = E.Validate("/cast Auto Shot")
    T.contains(warn[1].msg, "!Auto Shot")
    T.contains(E.Validate("/cast [mod:shift] A; B")[1].msg, "#showtooltip")
  end)

  T.it("explains the tricky cases in plain English", function()
    local E = engine()
    T.eq(E.ExplainLine("/cast [@pet,dead][mod:shift] Revive Pet; Mend Pet"),
      "If your pet is dead, or Shift is held, cast Revive Pet; otherwise cast Mend Pet")
    T.eq(E.ExplainLine("/castsequence reset=6 Serpent Sting, Arcane Shot"),
      "Each press casts the next of: Serpent Sting, then Arcane Shot (starts over after 6 seconds idle)")
    T.eq(E.ExplainLine("/cast [nomod,@mouseover,harm,nodead][nomod] Hunter's Mark"),
      "If no modifier is held and your mouseover is hostile and alive, or no modifier is held, cast Hunter's Mark")
    T.eq(E.ExplainLine("/castsequence [combat] reset=combat/shift Tame Beast, Wing Clip"),
      "If you are in combat: each press casts the next of: Tame Beast, then Wing Clip (starts over after leaving combat or pressing with shift)")
    T.eq(E.ExplainLine("/stopmacro [noexists][noharm][dead]"), "Stop here if there is none, or if it is not hostile, or if it is dead")
    T.eq(E.ExplainLine("/use 13"), "Use item slot 13 (top trinket)")
    T.eq(E.ExplainLine("/cast !Auto Shot"), "Cast Auto Shot (a second press won't stop it)")
  end)

  T.it("Gary's tame macro validates and explains every line", function()
    local E, ns = engine()
    local body = ns.Modules:Get("TameHelper"):Body("Mystmane")
    T.eq(E.Errors(body), 0)
    T.eq(#E.Explain(body), 9)
  end)
end)
