-- The TOC and the files on disk must agree, and the header must be sane.
local T, mock = ...

T.describe("toc", function()
  local files, meta = mock.tocFiles()

  T.it("lists only files that exist", function()
    for _, rel in ipairs(files) do
      T.ok(mock.readFile(mock.ROOT .. rel), "missing file listed in TOC: " .. rel)
    end
  end)

  T.it("lists every .lua file in the addon folder", function()
    local listed = {}
    for _, rel in ipairs(files) do listed[rel] = true end
    for _, path in ipairs(mock.listLua("addon/OAR")) do
      local rel = mock.relpath(path, "addon/OAR/"):sub(#"addon/OAR/" + 1)
      T.ok(listed[rel], "file not in TOC (it would never load): " .. rel)
    end
  end)

  T.it("loads Init first and Boot last", function()
    T.eq(files[1], "Core/Init.lua")
    T.eq(files[#files], "Core/Boot.lua")
  end)

  T.it("has the header fields WoW needs", function()
    T.ok(tonumber(meta.Interface), "Interface number")
    T.ok(meta.Version and meta.Version:match("^%d+%.%d+%.%d+"), "semantic Version")
    T.contains(meta.SavedVariables or "", "OAR_DB")
    T.contains(meta.SavedVariables or "", "OAR_Log")
  end)
end)
