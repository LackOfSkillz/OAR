-- Intelligence/Profiles.lua - class-neutral metadata, never guessed from secrets.
-- I2-01-01/02: no spell/talent IDs or assumed talent-read APIs.
local _, ns = ...
local P = { SCHEMA = 3 }
ns.ClassProfiles = P
P.ROLES = {
  WARRIOR = { "tank", "melee" },
  PALADIN = { "tank", "melee", "healer" },
  HUNTER = { "ranged", "pet" },
  ROGUE = { "melee" },
  PRIEST = { "healer", "caster" },
  SHAMAN = { "healer", "caster", "melee" },
  MAGE = { "caster" },
  WARLOCK = { "caster", "pet" },
  DRUID = { "tank", "melee", "caster", "healer" },
  UNKNOWN = {},
}
P.GOALS = { "level", "gold", "gear", "professions", "explore", "mix" }
local validGoal = {}
for _, goal in ipairs(P.GOALS) do validGoal[goal] = true end

function P.Resolve(token)
  token = ns.Compat.Readable(token)
  if type(token) ~= "string" or not P.ROLES[token] then return "UNKNOWN", P.ROLES.UNKNOWN end
  return token, P.ROLES[token]
end

function P.CanPlay(token, role)
  local _, roles = P.Resolve(token)
  if type(role) ~= "string" then return false end
  for _, available in ipairs(roles) do if available == role then return true end end
  return false
end

function P.State()
  if not (ns.db and ns.db.char) then return { schema = P.SCHEMA } end
  local char = ns.db.char
  local state = char.intelligenceProfile
  if type(state) ~= "table" then
    state = {}
    char.intelligenceProfile = state
  end
  if state.schema ~= P.SCHEMA then
    -- Preserve explicit player preferences. Never infer an old role token.
    local oldRole = state.role
    state = { schema = P.SCHEMA, role = oldRole }
    char.intelligenceProfile = state
  end
  return state
end

function P.Current()
  local token = P.Resolve(ns.PlayerClass())
  local state = P.State()
  local role = P.CanPlay(token, state.role) and state.role or "UNKNOWN"
  return { class = token, role = role, source = role == "UNKNOWN" and "unconfirmed" or "player" }
end

function P.SetRole(role)
  local token = P.Resolve(ns.PlayerClass())
  if role ~= "UNKNOWN" and not P.CanPlay(token, role) then return false, "unsupported role" end
  local state = P.State()
  state.role = role
  if ns.Events then ns.Events:Fire("OTR_INTELLIGENCE_PROFILE_CHANGED") end
  return true
end

function P.GoalValid(goal) return validGoal[goal] == true end

-- A role never disables universal quest, travel, economy or profession advice.
function P.Allows(token, role, hint)
  token = P.Resolve(token)
  if hint == nil or hint == "universal" then return true end
  if type(hint) ~= "table" or hint.class ~= token then return false end
  if hint.role == nil then return true end
  return role ~= "UNKNOWN" and P.CanPlay(token, role) and hint.role == role
end
