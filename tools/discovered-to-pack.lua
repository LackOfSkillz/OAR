-- tools/discovered-to-pack.lua  (P2-02 helper)
-- Prints rare / rare-elite NPCs Outrider's discovery recorded, as Data/Rares.lua
-- entries for Claude to review and paste. Reads SavedVariables, writes nothing.
--   python tools/lua.py tools/discovered-to-pack.lua "<...>\SavedVariables\Outrider.lua"
local path = arg[1]
if not path then io.write("usage: discovered-to-pack.lua <Outrider.lua>\n") return end
local f = assert(io.open(path, "rb"))
local src = f:read("*a")
f:close()
local env = {}
local chunk = assert(loadstring(src))
setfenv(chunk, env)   -- SavedVariables are data; run with an empty environment
chunk()
local g = env.Outrider_DB and env.Outrider_DB.global or {}
local npcs = g.discovered and g.discovered.npcs or {}
local ids = {}
for id, e in pairs(npcs) do
  if e.classification == "rare" or e.classification == "rareelite" then ids[#ids + 1] = id end
end
table.sort(ids)
for _, id in ipairs(ids) do
  local e = npcs[id]
  io.write(string.format(
    '  { npcID = %d, name = %q, mapID = %s, verified = false, level = { %s, %s },%s%s\n    spawns = { { x = %.3f, y = %.3f } }, source = "discovery" },\n',
    id, e.name or "?", tostring(e.mapID), tostring(e.level), tostring(e.level),
    e.classification == "rareelite" and " elite = true," or "",
    e.family and string.format(" beast = { family = %q },", e.family) or "",
    e.x or 0, e.y or 0))
end
io.write(string.format("-- %d rares out of %d NPCs\n", #ids, (function() local n = 0 for _ in pairs(npcs) do n = n + 1 end return n end)()))
