-- Every page and every button, checkbox and chip has a tooltip.
local T, mock = ...

local function openAll(class)
  local game = mock.new({ class = class, level = 20 })
  local ns = game:loadAddon()
  game:login()
  game:advance(3)
  ns.Hub:Toggle()
  for _, t in ipairs(ns.Hub.tabs) do ns.Hub:ShowTab(t.id) end
  return ns
end

T.describe("tooltips everywhere", function()
  T.it("every page and control on every class's hub has a tooltip", function()
    local missing = {}
    for _, cls in ipairs({ "HUNTER", "PRIEST", "MAGE", "WARRIOR", "DRUID" }) do
      local ns = openAll(cls)
      for label in pairs(ns.UI.untipped) do missing[label] = true end
    end
    local list = {}
    for l in pairs(missing) do list[#list + 1] = l end
    table.sort(list)
    T.eq(#list, 0, "no tooltip for: " .. table.concat(list, " || "))
  end)
end)
