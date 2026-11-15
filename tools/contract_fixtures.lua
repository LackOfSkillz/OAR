-- tools/contract_fixtures.lua <out file>
-- Writes the /ride ask snapshot code of the fixed contract session
-- (tests/lib/contract_session.lua). tools/contract_fixtures.ps1 runs this,
-- then the companion, to refresh tests/fixtures/contract/.
package.path = "./tests/lib/?.lua;" .. package.path
local session = require("contract_session")
local _, ns = session()
local f = assert(io.open(arg[1], "wb"))
f:write(ns.Snapshot:Code())
f:close()
io.write("snapshot fixture written: " .. arg[1] .. "\n")
