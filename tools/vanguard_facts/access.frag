-- access (research 2026-11-26). IDs as printed by the sources; none checked in game.
local CC = "https://conquestcapped.com/guides/wow-forever/wow-forever-attunements/"
local CCD = "https://conquestcapped.com/guides/wow-forever/wow-forever-dalaran-attunement/"
local BALD = "https://bald.gg/wow-forever/blog/wow-forever-attunements"
local BALDMC = "https://bald.gg/wow-forever/blog/wow-forever-attunement-to-the-core"
local WIKI = "https://warcraft.wiki.gg/wiki/Heart_of_Disruption"
local function none(src, note) return { needs = "none", kind = "forever", source = src, note = note } end
for _, n in ipairs({ "The Hall of Thanes", "Ragefire Chasm", "Ruins of Lordaeron", "Wailing Caverns", "The Deadmines", "Shadowfang Keep",
  "Blackfathom Deeps", "The Stockade", "Excavation Site: Wetlands", "Razorfen Kraul", "Razorfen Downs", "Uldaman",
  "The Temple of Atal'Hakkar", "The Drowned City", "Alcaz Prison", "Blackmaw Hold", "Shaper's Terrace" }) do
  F.access[n] = none(CC)
end
F.access["Gnomeregan"] = none(CC, "Workshop Key (6893, from Electrocutioner 6000) opens the back door to the Engineering Labs")
F.access["Scarlet Monastery"] = none(CC, "Graveyard and Library open; Armory and Cathedral need The Scarlet Key (7146, from Doan's Strongbox at the end of the Library; each player can loot one)")
F.access["Zul'Farrak"] = none(CC, "Mallet of Zul'Farrak (9240) only summons the optional boss Gahz'rilla")
F.access["Maraudon"] = none(CC, "Scepter of Celebras (17191) is a portal shortcut, not needed to enter")
F.access["Blackrock Depths"] = none(BALD, "Shadowforge Key (11000, quest Dark Iron Legacy) opens the Shadowforge doors; Prison Cell Key (11140) opens the cells")
F.access["Dire Maul"] = none(CC, "East is open; West and North need the Crescent Key (18249, from Pusillin in East), 275 lockpicking or a seaforium charge")
F.access["Blackrock Spire"] = none(CC, "Lower is open; Upper needs a Seal of Ascension (12344 per one source; another says the item isn't in Forever data yet), one holder per group")
F.access["Stratholme"] = none(CC, "Main gate is open; the service gate needs the Key to the City (12382, from Magistrate Barthilas), or walk through from the live side")
F.access["Scholomance"] = { needs = "key", who = "one", item = 13704, itemName = "Skeleton Key", kind = "forever", source = CC,
  note = "from a 9-quest chain (The Key to Scholomance, level 55); 280 lockpicking or a seaforium charge also open it" }
F.access["City of Dalaran"] = { needs = "key", who = "one", item = 277507, itemName = "Dalaran Sewer Key", kind = "forever", source = CCD,
  quest = nil, note = "on your keyring while Heart of Disruption (Alliance 92458, Horde 96984) is in your log; abandoning it removes the key",
  conflict = "one source says Alliance needs no key" , also = WIKI }
F.access["Krol'dok Stronghold"] = { needs = "key", who = "one", item = 267089, itemName = "Krol'dok Compound Key", kind = "forever", source = BALD,
  disputed = true, conflict = "sources disagree whether the Compound Key is needed to enter" }
F.access["Onyxia's Lair"] = { needs = "attunement", who = "each", item = 16309, itemName = "Drakefire Amulet", kind = "forever",
  source = "https://worldofwarcraft.blizzard.com/news/24303009", also = CC,
  note = "in your bags, not equipped; per character. Alliance from Helendis Riverhorn (Burning Steppes), Horde from Warlord Goretooth (Kargath); both end with General Drakkisath in Upper Blackrock Spire" }
F.access["Barrow Deeps"] = none(CC, "the Vord'anaar Prison section inside needs the Brooch of the Wardens (277136); how to get it is unknown")
F.access["Hyjal Summit"] = none(CC)
F.access["Molten Core"] = { needs = "quest", who = "each", quest = 7848, questName = "Attunement to the Core", kind = "forever", source = BALDMC,
  note = "raid not announced for Forever; the quest exists in the data (Lothos Riftwaker, level 55)" }
