-- raids (research 2026-11-26). Official = Blizzard raid overview
-- https://worldofwarcraft.blizzard.com/news/24303009 ; boss names for the new
-- raids are datamined (Warcraft Wiki order), order unconfirmed.
local BLIZ = "https://worldofwarcraft.blizzard.com/news/24303009"
local NOT_ANNOUNCED = "not announced for WoW Forever (Blizzard raid overview and roadmap, 2026-11-26)"
F.raids = {
  ["Barrow Deeps"] = { size = 10, min = 60, max = 60, status = "opens 2026-12-09", source = BLIZ, kind = "forever",
    note = "8 bosses (official); names datamined, order unconfirmed; one wiki line says 20 players, Blizzard says 10" },
  ["Hyjal Summit"] = { size = 20, min = 60, max = 60, status = "opens 2026-12-09", source = BLIZ, kind = "forever",
    note = "13 bosses (official); branching routes after the opener; names datamined, order unconfirmed" },
  ["Onyxia's Lair"] = { size = 40, min = 60, max = 60, status = "opens 2026-12-09", source = BLIZ, kind = "forever" },
  ["Zul'Gurub"] = { status = NOT_ANNOUNCED, source = BLIZ, kind = "forever" },
  ["Ruins of Ahn'Qiraj"] = { status = NOT_ANNOUNCED, source = BLIZ, kind = "forever" },
  ["Molten Core"] = { status = NOT_ANNOUNCED, source = BLIZ, kind = "forever" },
  ["Blackwing Lair"] = { status = NOT_ANNOUNCED, source = BLIZ, kind = "forever" },
  ["Temple of Ahn'Qiraj"] = { status = NOT_ANNOUNCED, source = BLIZ, kind = "forever" },
  ["Naxxramas"] = { status = NOT_ANNOUNCED, source = BLIZ, kind = "forever" },
}
local WIKI_BD = "https://warcraft.wiki.gg/wiki/Barrow_Deeps_(instance)"
local WIKI_HS = "https://warcraft.wiki.gg/wiki/Hyjal_Summit_(instance)"
local function list(names, src)
  local out = {}
  for i, n in ipairs(names) do out[i] = { name = n, unknown = true, source = src } end
  return out
end
F.bosses["Barrow Deeps"] = { kind = "forever", source = WIKI_BD, orderUnconfirmed = true, list = list({ "Deepscar Matriarch",
  "Khalith the Dreadspinner", "Amethrax", "Ravus and Darlissa", "Elder Tangleclaw", "Well of Sorrow", "Del'lynar Songwood", "Sonya Darkhallow" }, WIKI_BD) }
F.bosses["Hyjal Summit"] = { kind = "forever", source = WIKI_HS, orderUnconfirmed = true, list = list({ "Bandalar", "Time-Lost Battalion",
  "Old Gloomlurker", "Kathris the Haunted", "Elder Minderel", "Council of Thorns", "The Wild King", "Ancient of Decay", "Sylvesteris Dusksong",
  "Gharalis the Abyssal", "Anara Chillwind", "Tracker Stillwind", "Nythus the Dreambound" }, WIKI_HS) }
F.bosses["Onyxia's Lair"] = { kind = "forever", source = BLIZ, list = {
  { name = "Onyxia", npc = 10184, tags = { fire_res = "fire breath and flames (Blizzard recommends fire resistance)" }, source = BLIZ } } }
F.access["Onyxia's Lair"] = { needs = "attunement", who = "each", itemName = "Drakefire Amulet", kind = "forever", source = BLIZ,
  note = "in your bags, not equipped; Alliance chain from Helendis Riverhorn, Horde from Warlord Goretooth; ends with General Drakkisath in UBRS" }
F.access["Barrow Deeps"] = { needs = "none", kind = "forever", source = BLIZ }
F.access["Hyjal Summit"] = { needs = "none", kind = "forever", source = BLIZ }
