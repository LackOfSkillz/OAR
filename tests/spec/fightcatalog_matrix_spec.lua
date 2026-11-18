-- Fight plan catalog integrity across every class/spec/mode and all brackets.
-- This does not certify live spell behavior; every generated macro is
-- unverified until actually pressed in Forever.
local T = ...
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
                  "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local function catalog()
  local ns = {}
  assert(loadfile("addon/Outrider/Data/FightPlans.lua"))("Outrider", ns)
  return ns.FightPlans
end
T.describe("fight-plan source catalog matrix", function()
  T.it("contains nine distinct class plans, with no false verification claims", function()
    local c = catalog()
    T.no(c.verified)
    for _, cls in ipairs(CLASSES) do
      local p = c:Class(cls)
      T.ok(p, cls .. " missing")
      T.ok(type(p.trees) == "table" and #p.trees == 3, cls .. " three specs")
      T.ok(p.specs and p.specs.levelling, cls .. " levelling spec")
      T.ok(type(p.keys) == "table", cls .. " key map")
    end
    T.eq(c:Class("NOT_A_CLASS"), nil)
  end)
  T.it("validates all class/spec/mode bracket references and line limits", function()
    local c = catalog()
    local scenarios, slots, keys = 0, 0, 0
    for _, cls in ipairs(CLASSES) do
      local plan = c:Class(cls)
      for spec, modes in pairs(plan.specs) do
        for _, mode in ipairs({"pve", "pvp"}) do
          -- Levelling has a conservative PvE fallback until a specialization
          -- is established. Every named specialization still requires PvP.
          local byKind = modes[mode] or (spec == "levelling" and modes.pve)
          T.ok(type(byKind) == "table", cls .. " " .. spec .. " " .. mode .. " missing")
          scenarios = scenarios + 1
          for kind, brackets in pairs(byKind) do
            T.ok(type(brackets) == "table" and #brackets > 0, "empty " .. cls .. " " .. kind)
            local previous, resolved = 0, {}
            keys = keys + 1
            for _, bracket in ipairs(brackets) do
              T.ok(type(bracket.from) == "number" and bracket.from >= previous
                and bracket.from >= 1 and bracket.from <= 60, cls .. " " .. kind .. " level order")
              previous = bracket.from
              T.ok(type(bracket.slots) == "table", "slots must be listed")
              for _, sl in ipairs(bracket.slots) do
                if type(sl) == "table" then
                  T.ok(type(sl.line) == "string" and #sl.line > 0
                    and #sl.line <= 255, "line length in " .. cls)
                  T.ok(sl.line:sub(1,1) == "/" or sl.line:sub(1,1) == "#",
                    "unexpected command in " .. cls)
                  T.ok(type(sl.spells) == "table", "missing spell list")
                  T.ok(not sl.line:find("/run", 1, true)
                    and not sl.line:find("/script", 1, true), "executable code forbidden")
                  resolved[sl.line] = true
                else
                  T.ok(type(sl) == "string" and resolved[sl],
                    "unresolved prior line in " .. cls .. " " .. kind)
                end
                slots = slots + 1
              end
            end
          end
        end
      end
    end
    T.ok(scenarios >= 60, "all specs and levelling across nine classes and two modes")
    T.ok(keys > 100, "multiple keys per class/spec")
    T.ok(slots > 300, "expected generated catalog breadth")
  end)
end)
