-- Intelligence/Confidence.lua  (OI07-08: one way to say how sure Outrider is)
-- Badge(entry) gives a word, never only a colour: Verified, Observed,
-- Community, Inferred or Unknown, with a source line and when and on which
-- build it was seen. "Verified" needs evidence: verified = true AND a
-- verifiedOn (date or build) or a note naming who saw it; without that it
-- drops to Community. An estimate always says it is one (Estimate()).
--   Badge(entry)  -> { level, word, text, source, colour }
--   Text(entry)   -> "[Verified] seen 2026-11-11, build 70862 (source)"
-- Colours are only a second hint (colour-blind safe palette from the Theme).

local _, ns = ...
local CF = {}
ns.Confidence = CF
CF.WORDS = { verified = "Verified", observed = "Observed", community = "Community", inferred = "Inferred", unknown = "Unknown" }
CF.COLOURS = { verified = "good", observed = "good", community = "warn", inferred = "muted", unknown = "muted" }

local function evidence(e)
  local v = e.verifiedOn
  if type(v) == "table" and (v.date or v.build or v.note) then return v end
  return nil
end

function CF.Level(e)
  if type(e) ~= "table" then return "unknown" end
  if e.verified == true and evidence(e) then return "verified" end
  if e.observed or e.confidence == "observed" or (type(e.seen) == "number" and e.seen > 0) then return "observed" end
  if e.verified == true or e.confidence == "verified" or e.confidence == "community" then return "community" end
  if e.confidence == "inferred" then return "inferred" end
  if e.source then return "community" end
  return "unknown"
end

function CF.Badge(e)
  local level = CF.Level(e)
  local v = type(e) == "table" and evidence(e) or nil
  local when = {}
  if v and v.date then when[#when + 1] = "seen " .. tostring(v.date) end
  if v and v.build then when[#when + 1] = "build " .. tostring(v.build) end
  if type(e) == "table" and e.flavor == "classic" then when[#when + 1] = "Classic data, may be wrong on Forever" end
  local src = type(e) == "table" and e.source and tostring(e.source) or nil
  return { level = level, word = CF.WORDS[level], colour = CF.COLOURS[level], when = table.concat(when, ", "), source = src }
end

function CF.Text(e)
  local b = CF.Badge(e)
  local parts = { "[" .. b.word .. "]" }
  if b.when ~= "" then parts[#parts + 1] = b.when end
  if b.source then parts[#parts + 1] = "(" .. b.source .. ")" end
  return table.concat(parts, " ")
end

-- an estimate: the value, the word "estimate", what it rests on
function CF.Estimate(text, basis, n)
  return string.format("%s (estimate%s%s)", tostring(text), basis and (" from " .. basis) or "", n and string.format(", %d record%s", n, n == 1 and "" or "s") or "")
end
