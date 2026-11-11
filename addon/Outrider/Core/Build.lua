-- Core/Build.lua
-- tools/deploy.ps1 overwrites the DEPLOYED copy of this file with a timestamp
-- and git hash, so "/ride version" proves which build Gary is running.
-- Leave the source copy as "dev".
local _, ns = ...
ns.build = "dev"
