-- tools/nexus_fixtures.lua <out file>
-- Writes one OTR1 code per valid Nexus v4 fixture (docs/contracts/nexus_v4_fixtures.lua),
-- as "<record>\t<code>" lines, through the addon's own Serialize.Export. The
-- companion test decodes them and re-encodes them byte for byte (OI02-14).
-- Run: python tools/lua.py tools/nexus_fixtures.lua tests/fixtures/contract/nexus_v4_otr1.txt
package.path = "./tests/lib/?.lua;" .. package.path
local mock = require("wowmock")
mock.listLua = function() return {} end
local game = mock.new()
local ns = game:loadAddon()
game:login()

local fh = assert(io.open("docs/contracts/nexus_v4_fixtures.lua", "r"))
local text = fh:read("*a")
fh:close()
local env = {}
local chunk = assert(loadstring(text))
setfenv(chunk, env)
chunk()

local out = assert(io.open(arg[1], "wb"))
local n = 0
for _, case in ipairs(env.NexusFixtures) do
  if case.ok then
    out:write(case.record, "\t", ns.Serialize.Export(case.data), "\n")
    n = n + 1
  end
end
out:close()
io.write(string.format("wrote %d Nexus v4 codes to %s\n", n, arg[1]))
