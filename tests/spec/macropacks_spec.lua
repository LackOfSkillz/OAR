-- Every macro in every pack (P4-08): valid body, 255 chars, unique ids,
-- names fit the in-game 16 character limit, required fields present.
local T, mock = ...

local CLASSES = { "WARRIOR", "ROGUE", "WARLOCK", "DRUID", "SHAMAN", "PALADIN", "PRIEST", "MAGE", "HUNTER" }
local NEW = { WARRIOR = true, ROGUE = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true }
local TAGS = { combat = true, heal = true, defensive = true, control = true, utility = true, pet = true, talent = true }

local function load()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return ns
end

T.describe("macro packs", function()
  T.it("every macro has a valid body of 255 characters or less", function()
    local ns = load()
    local E = ns.MacroEngine
    for _, m in ipairs(ns.Data:All("macro")) do
      local body = E.Fill(m.body, { TARGET = "Test Beast", FOOD = "Tough Jerky", DRINK = "Water", MOUNT = "Horse" })
      T.ok(#body <= 255, m.id .. " is " .. #body .. " characters")
      T.eq(E.Errors(body), 0, m.id)
      T.no((m.body .. (m.explain or "")):find("\226\128\148", 1, true), m.id .. " has an em dash")
    end
  end)

  T.it("ids are unique, names fit 16 characters and are unique per class", function()
    local ns = load()
    local ids, names = {}, {}
    for _, m in ipairs(ns.Data:All("macro")) do
      T.no(ids[m.id], "duplicate id " .. tostring(m.id))
      ids[m.id] = true
      T.ok(type(m.name) == "string" and #m.name >= 1 and #m.name <= 16, m.id .. " name length")
      local key = tostring(m.class) .. ":" .. m.name
      T.no(names[key], "duplicate name " .. key)
      names[key] = true
      T.ok(m.verified == false or m.verified == true, m.id .. " verified")
      T.ok(type(m.explain) == "string" and m.explain ~= "", m.id .. " explain")
      T.ok(type(m.source) == "string" and m.source ~= "", m.id .. " source")
      if NEW[m.class] then
        for _, t in ipairs(m.tags or {}) do T.ok(TAGS[t], m.id .. " tag " .. t) end
      end
    end
  end)

  -- 2026-11-19: the Macros page is a tree you pick from (a macro is only written
  -- when you pick it up), so a class has more than its 18 slots; 40 at most
  T.it("each class pack has 8 to 40 macros for that class only", function()
    local ns = load()
    local count = {}
    for _, m in ipairs(ns.Data:All("macro")) do count[m.class] = (count[m.class] or 0) + 1 end
    for _, c in ipairs(CLASSES) do
      T.ok((count[c] or 0) >= 8, c .. " has " .. tostring(count[c]))
    end
    for _, c in ipairs({ "WARRIOR", "ROGUE", "WARLOCK", "DRUID", "SHAMAN", "PALADIN" }) do
      T.ok(count[c] <= 40, c .. " has " .. count[c])
      for _, m in ipairs(ns.Data:All("macro")) do
        if m.class == c then T.eq(m.id:match("^(%a+)%-"), c:lower(), m.id) end
      end
    end
  end)
end)
