-- tools/afteraction_bench.lua [out.md] [seed]
-- OI03-14: the AfterAction measurement report from the repeatable fixture
-- (tests/lib/afteraction_fixture.lua) through the addon's own
-- AfterAction.Evidence. Mock client; fixture data, not live play.
-- Run: python tools/lua.py tools/afteraction_bench.lua docs/quality/afteraction_bench.md 42
package.path = "./tests/lib/?.lua;" .. package.path
local mock = require("wowmock")
mock.listLua = function() return {} end
local F = require("afteraction_fixture")
local game = mock.new()
local ns = game:loadAddon()
game:login()
local text = ns.AfterAction.EvidenceText(ns.AfterAction.Evidence(F.Build(tonumber(arg[2]) or 42)))
local fh = assert(io.open(arg[1] or "docs/quality/afteraction_bench.md", "w"))
fh:write(text)
fh:close()
io.write(text)
