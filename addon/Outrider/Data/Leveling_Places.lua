-- Data/Leveling_Places.lua
-- More places for the leveling knowledge base: flight masters, riding and
-- profession trainers, recipe and book vendors, reputation quartermasters
-- and quest starts worth doing while leveling.
-- Source: Wowhead's WoW Forever guides (wowhead.com/forever, read in the
-- browser 2026-11-21); each entry names its guide in `source`.
-- Hard rule 7: copied as written, /way numbers divided by 100, verified =
-- false until Gary has seen them in game. Zones by NAME (the game turns names
-- into map IDs). Only entries the guides give coordinates for. The Zephras
-- Isle trainers and Riverglades places already live in Data/Leveling.lua and
-- are not repeated here. Boats and zeppelins are left to the travel links.

local _, ns = ...

local function src(guide) return "wowhead.com " .. guide .. " (read 2026-11-21)" end
local FLY  = src("Flight Points, Zeppelins, and Ships guide")
local RIDE = src("Learning to Ride and Getting Your First Mount guide")
local COOK = src("Cooking Profession Overview")
local FAID = src("First Aid Profession Overview")
local FISH = src("Fishing Profession Overview")
local HERB = src("Herbalism Profession Overview")
local MINE = src("Mining Profession Overview")
local SKIN = src("Skinning Profession Overview")
local ALCH = src("Alchemy Profession Overview")
local ENCH = src("Enchanting Overview")
local ENGI = src("Engineering Overview")
local GELK = src("Gelkis Clan Centaur Reputation Guide")
local MAGR = src("Magram Clan Centaur Reputation Guide")
local NCLW = src("Nightclaw Druids Reputation Guide")
local TMBR = src("Timbermaw Hold Reputation Guide")
local ACA  = src("Azeroth Commerce Authority Guide")
local DSL  = src("Durotar Supply and Logistics Guide")
local LIB  = src("Collecting Library Books guide")
local LEG  = src("Legacy System Overview")
local TUR  = src("Tarnished Undermine Real Currency Guide")
local STQ  = src("Sunken Temple Class Quests Guide")

local function slug(s) return (tostring(s):lower():gsub("[^%a]", "")) end
local A, H = "Alliance", "Horde"

-- ------------------------------------------------------------ travel
-- Flight masters: { name, zone, place, x, y, faction } (nil faction = both)
local travel = {}
local FLIGHT = {
  -- Horde, Kalimdor
  { "Vhulgra", "Ashenvale", "Splintertree Post", 73.2, 61.6, H },
  { "Andruk", "Ashenvale", "Zoram'gar Outpost", 12.2, 33.8, H },
  { "Kroum", "Azshara", "Valormok", 22.0, 49.6, H },
  { "Thalon", "Desolace", "Shadowprey Village", 21.6, 74.0, H },
  { "Doras", "Orgrimmar", "Orgrimmar", 45.2, 63.8, H },
  { "Shardi", "Dustwallow Marsh", "Brackenwall Village", 35.6, 31.8, H },
  { "Brakkar", "Felwood", "Bloodvenom Post", 34.4, 53.8, H },
  { "Shyn", "Feralas", "Camp Mojache", 75.4, 44.2, H },
  { "Faustron", "Moonglade", "Moonglade", 32.2, 66.4, H },
  { "Tal", "Thunder Bluff", "Thunder Bluff", 46.8, 50.0, H },
  { "Runk Windtamer", "Silithus", "Cenarion Hold", 48.8, 36.6, H },
  { "Tharm", "Stonetalon Mountains", "Sun Rock Retreat", 45.2, 59.8, H },
  { "Bulkrek Ragefist", "Tanaris", "Gadgetzan", 51.6, 25.4, H },
  { "Devrak", "The Barrens", "The Crossroads", 51.6, 30.4, H },
  { "Omusa Thunderhorn", "The Barrens", "Camp Taurajo", 44.4, 59.2, H },
  { "Nyse", "Thousand Needles", "Freewind Post", 45.2, 49.2, H },
  { "Yugrek", "Winterspring", "Everlook", 60.4, 36.4, H },
  -- both factions (listed on both sides)
  { "Bluebell", "Mount Hyjal", "Mount Hyjal", 55.0, 82.8 },
  { "Fayran Elthas", "Mount Hyjal", "Mount Hyjal", 68.6, 44.0 },
  { "Bragok", "The Barrens", "Ratchet", 63.0, 37.2 },
  { "Gryfe", "Un'Goro Crater", "Marshal's Refuge", 45.2, 5.8 },
  -- Horde, Eastern Kingdoms (Grakna, Rog'mar, is in Data/Leveling.lua)
  { "Urda", "Arathi Highlands", "Hammerfall", 73.4, 36.8, H },
  { "Gorrik", "Badlands", "Kargath", 2.4, 44.0, H },
  { "Vahgruk", "Burning Steppes", "Flame Crest", 65.6, 24.2, H },
  { "Georgia", "Eastern Plaguelands", "Light's Hope Chapel", 80.2, 57.0, H },
  { "Zarise", "Hillsbrad Foothills", "Tarren Mill", 60.2, 18.6, H },
  { "Gorkas", "The Hinterlands", "Revantusk Village", 81.6, 81.8, H },
  { "Grisha", "Searing Gorge", "Thorium Point", 34.8, 30.8, H },
  { "Karos Razok", "Silverpine Forest", "The Sepulcher", 45.6, 42.6, H },
  { "Thysta", "Stranglethorn Vale", "Grom'gol Base Camp", 32.6, 28.4, H },
  { "Gringer", "Stranglethorn Vale", "Booty Bay", 26.8, 77.2, H },
  { "Breyk", "Swamp of Sorrows", "Stonard", 46.0, 54.6, H },
  { "Michael Garrett", "Undercity", "Undercity", 63.6, 48.6, H },
  -- Alliance, Kalimdor
  { "Daelyshia", "Ashenvale", "Astranaar", 34.4, 48.0, A },
  { "Jarrodenus", "Azshara", "Talrendis Point", 11.8, 77.6, A },
  { "Caylais Moonfeather", "Darkshore", "Auberdine", 36.4, 45.6, A },
  { "Baritanas Skyriver", "Desolace", "Nijel's Point", 64.6, 10.6, A },
  { "Baldruc", "Dustwallow Marsh", "Theramore Isle", 67.4, 51.4, A },
  { "Mishellena", "Felwood", "Talonbranch Glade", 62.4, 24.2, A },
  { "Fyldren Moonfeather", "Feralas", "Feathermoon Stronghold", 30.2, 43.2, A },
  { "Thyssiana", "Feralas", "Thalanaar", 89.4, 45.8, A },
  { "Sindrayl", "Moonglade", "Moonglade", 48.2, 67.2, A },
  { "Cloud Skydancer", "Silithus", "Cenarion Hold", 50.6, 34.4, A },
  { "Teloren", "Stonetalon Mountains", "Stonetalon Peak", 36.4, 7.2, A },
  { "Bera Stonehammer", "Tanaris", "Gadgetzan", 51.0, 29.2, A },
  { "Vesprystus", "Teldrassil", "Rut'theran Village", 58.4, 94.0, A },
  { "Maethrya", "Winterspring", "Everlook", 62.2, 36.6, A },
  -- Alliance, Eastern Kingdoms (Gretchen Mayberry, Farholde Keep, is in Data/Leveling.lua)
  { "Cedrik Prose", "Arathi Highlands", "Refuge Point", 45.8, 46.2, A },
  { "Alexandra Constantine", "Blasted Lands", "Nethergarde Keep", 65.6, 24.4, A },
  { "Borgus Stoutarm", "Burning Steppes", "Morgan's Vigil", 84.4, 68.2, A },
  { "Gryth Thurden", "Ironforge", "Ironforge", 55.6, 47.8, A },
  { "Felicia Maline", "Duskwood", "Darkshire", 77.6, 44.4, A },
  { "Khaelyn Steelwing", "Eastern Plaguelands", "Light's Hope Chapel", 81.6, 59.2, A },
  { "Dungar Longdrink", "Stormwind City", "Stormwind City", 71.0, 72.6, A },
  { "Darla Harris", "Hillsbrad Foothills", "Southshore", 49.4, 52.4, A },
  { "Guthrum Thunderfist", "The Hinterlands", "Aerie Peak", 11.0, 46.2, A },
  { "Thorgrum Borrelson", "Loch Modan", "Thelsamar", 33.8, 50.8, A },
  { "Ariena Stormfeather", "Redridge Mountains", "Lakeshire", 25.6, 59.6, A },
  { "Lanie Reed", "Searing Gorge", "Thorium Point", 37.8, 30.6, A },
  { "Gyll", "Stranglethorn Vale", "Booty Bay", 27.6, 77.6, A },
  { "Bibilfaz Featherwhistle", "Western Plaguelands", "Chillwind Camp", 42.8, 85.2, A },
  { "Thor", "Westfall", "Sentinel Hill", 56.6, 52.6, A },
  { "Shellei Brondir", "Wetlands", "Menethil Harbor", 9.6, 59.6, A },
}
for _, f in ipairs(FLIGHT) do
  travel[#travel + 1] = { id = "travel-fm-" .. slug(f[1]), kind = "flight_master", zone = f[2], place = f[3],
    x = f[4] / 100, y = f[5] / 100, name = f[1], title = "Flight Master", faction = f[6], source = FLY, verified = false }
end
ns.Data:Register("place", "wowhead-travel", travel)

-- ------------------------------------------------------------ trainers
-- { name, zone, place, x, y, faction, note }
local trainers = {}
local function addTrainers(prof, source, list, defaultNote)
  for _, t in ipairs(list) do
    trainers[#trainers + 1] = { id = "trainer-" .. slug(prof) .. "-" .. slug(t[1]), kind = "trainer", zone = t[2], place = t[3],
      x = t[4] / 100, y = t[5] / 100, name = t[1], title = prof .. " Trainer", faction = t[6],
      note = t[7] or defaultNote, source = source, verified = false }
  end
end

-- Riding: Apprentice Riding at 40 (60%), Journeyman at 60 (100%); learning it teaches your race's mount skill.
addTrainers("Riding", RIDE, {
  { "Kildar", "Orgrimmar", "Valley of Honor", 69.2, 13.2, H, "Orc riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Wolf Riding." },
  { "Velma Warnam", "Tirisfal Glades", "Brill", 60.0, 52.6, H, "Undead riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Undead Horsemanship." },
  { "Kar Stormsinger", "Mulgore", "Bloodhoof Village", 46.8, 61.8, H, "Tauren riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Kodo Riding." },
  { "Xar'Ti", "Durotar", "Sen'jin Village", 55.2, 75.6, H, "Troll riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Raptor Riding." },
  { "Genn Fairweather", "Zephras Isle", "west of Valanaar", 53.8, 81.2, nil, "Skyborne riding trainer (both factions), also sells the mounts; teaches Galestrider Riding." },
  { "Randal Hunter", "Elwynn Forest", "Eastvale Logging Camp", 84.2, 65.0, A, "Human riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Horse Riding." },
  { "Ultham Ironhorn", "Dun Morogh", "Gol'Bolar Quarry", 63.8, 50.2, A, "Dwarf riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Ram Riding." },
  { "Jartsam", "Darnassus", "Darnassus", 38.6, 16.0, A, "Night Elf riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Tiger Riding." },
  { "Binjy Featherwhistle", "Dun Morogh", "Kharanos", 49.2, 48.0, A, "Gnome riding trainer: Apprentice Riding at 40, Journeyman at 60; teaches Mechanostrider Piloting." },
})

local SEC = "teaches Apprentice and Journeyman (to 150); Expert comes from a book, Artisan from a quest"
addTrainers("Cooking", COOK, {
  { "Alegorn", "Darnassus", "Craftsmen's Terrace", 49.8, 21.0, A },
  { "Cook Ghilm", "Dun Morogh", "Gol'Bolar Quarry", 68.4, 54.6, A },
  { "Crystal Boughman", "Redridge Mountains", "Lakeshire", 22.8, 43.6, A },
  { "Daryl Riknussun", "Ironforge", "The Great Forge", 60.4, 38.0, A },
  { "Gremlock Pilsnor", "Dun Morogh", "Kharanos", 47.6, 52.4, A },
  { "Stephen Ryback", "Stormwind City", "Old Town", 78.2, 53.0, A },
  { "Tomas", "Elwynn Forest", "Goldshire", 44.2, 66.0, A },
  { "Zarrin", "Teldrassil", "Dolanaar", 57.0, 61.2, A },
  { "Hnaz Blunderflame", "Mount Hyjal", "Elderwild", 15.6, 50.2, A },
  { "Katherine Lee", "Alterac Mountains", "Dalaran", 12.6, 65.8, A },
  { "Aska Mistrunner", "Thunder Bluff", "centre of Thunder Bluff", 51.0, 52.8, H },
  { "Eunice Burch", "Undercity", "centre of the Undercity", 62.6, 44.6, H },
  { "William Pickman", "Tirisfal Glades", "Brill", 61.8, 51.6, H },
  { "Mudduk", "Stranglethorn Vale", "Grom'gol Base Camp", 31.4, 28.0, H },
  { "Pyall Silentstride", "Mulgore", "Bloodhoof Village", 45.0, 61.6, H },
  { "Slagg", "Arathi Highlands", "Hammerfall", 74.0, 33.8, H },
  { "Zamja", "Orgrimmar", "The Drag", 57.6, 53.6, H },
  { "Gorg", "Riverglades", "Rog'mar", 58.6, 44.6, H },
  { "Ortak Lomgok", "Mount Hyjal", "Elderwild", 13.0, 52.8, H },
}, SEC)

addTrainers("First Aid", FAID, {
  { "Dannelor", "Darnassus", "Craftsmen's Terrace", 51.6, 12.6, A },
  { "Shaina Fuller", "Stormwind City", "Cathedral of Light", 42.8, 26.6, A },
  { "Nissa Firestone", "Ironforge", "Great Forge", 54.8, 58.6, A, "Teaches to 150; also gives the optional Artisan breadcrumb Trauma (level 35, First Aid 225)." },
  { "Byancie", "Teldrassil", "Dolanaar", 55.2, 56.8, A },
  { "Michelle Belle", "Elwynn Forest", "Goldshire", 43.4, 65.6, A },
  { "Thamner Pol", "Dun Morogh", "Kharanos", 47.2, 52.6, A },
  { "Fremal Doohickey", "Wetlands", "Menethil Harbor", 10.8, 61.2, A },
  { "Angelique Butler", "Alterac Mountains", "Dalaran", 17.2, 61.0, A },
  { "Arnok", "Orgrimmar", "Valley of Spirits", 34.0, 84.4, H, "Teaches to 150; also gives the optional Artisan breadcrumb Trauma (level 35, First Aid 225)." },
  { "Mary Edras", "Undercity", "Rogues' Quarter", 73.6, 55.6, H },
  { "Pand Stonebinder", "Thunder Bluff", "Spirit Rise", 29.6, 21.4, H },
  { "Rawrk", "Durotar", "Razor Hill", 54.0, 42.0, H },
  { "Nurse Neela", "Tirisfal Glades", "Brill", 61.8, 52.8, H },
  { "Vira Younghoof", "Mulgore", "Bloodhoof Village", 46.8, 60.8, H },
}, SEC)

addTrainers("Fishing", FISH, {
  { "Androl Oakhand", "Teldrassil", "Rut'theran Village", 56.0, 93.6, A },
  { "Arnold Leland", "Stormwind City", "canal by the Trade District", 55.0, 69.6, A },
  { "Astaia", "Darnassus", "Temple Gardens", 47.6, 56.6, A },
  { "Brannock", "Feralas", "Feathermoon Stronghold", 32.2, 41.6, A },
  { "Donald Rabonne", "Hillsbrad Foothills", "Southshore", 50.6, 61.0, A },
  { "Grimnur Stonebrand", "Ironforge", "Forlorn Cavern", 48.4, 6.4, A },
  { "Harold Riggs", "Wetlands", "Menethil Harbor", 8.2, 58.6, A },
  { "Lee Brown", "Elwynn Forest", "Goldshire", 47.6, 62.2, A },
  { "Matthew Hooper", "Redridge Mountains", "Lakeshire", 26.8, 50.4, A },
  { "Paxton Ganter", "Dun Morogh", "Brewnall Village", 35.6, 40.4, A },
  { "Warg Deepwater", "Loch Modan", "Thelsamar", 40.6, 39.6, A },
  { "Myizz Luckycatch", "Stranglethorn Vale", "Booty Bay", 27.6, 77.0, nil },
  { "Armand Cromwell", "Undercity", "Magic Quarter", 80.8, 31.2, H },
  { "Clyde Kellen", "Tirisfal Glades", "Brightwater Lake", 67.2, 51.0, H },
  { "Kah Mistrunner", "Thunder Bluff", "Middle Tier", 56.0, 46.8, H },
  { "Katoom the Angler", "The Hinterlands", "Revantusk Village", 80.2, 81.4, H },
  { "Kil'Hiwana", "Ashenvale", "south of Blackfathom Deeps", 10.8, 33.6, H },
  { "Lau'Tiki", "Durotar", "south of Sen'jin Village", 53.2, 81.6, H },
  { "Lui'Mala", "Desolace", "Shadowprey Village", 22.6, 72.6, H },
  { "Lumak", "Orgrimmar", "Valley of Honor", 69.8, 29.6, H },
  { "Uthan Stillwater", "Mulgore", "Bloodhoof Village", 44.6, 60.6, H },
  { "Krix", "Riverglades", "Powderfuse Port", 79.2, 54.6, nil },
}, SEC)

addTrainers("Alchemy", ALCH, {
  { "Cyndra Kindwhisper", "Teldrassil", "Dolanaar", 57.6, 60.6, A, "teaches up to Apprentice (75)" },
  { "Ghak Healtouch", "Loch Modan", "Thelsamar", 37.0, 49.2, A, "teaches up to Apprentice (75)" },
  { "Alchemist Mallory", "Elwynn Forest", "Goldshire", 39.8, 48.6, A, "teaches up to Apprentice (75)" },
  { "Tel'Athir", "Stormwind City", "Mage Quarter", 55.6, 85.6, A, "teaches up to Apprentice (75)" },
  { "Vosur Brakthel", "Ironforge", "Tinker Town", 67.0, 54.2, A, "teaches up to Apprentice (75)" },
  { "Milla Fairancora", "Darnassus", "Craftsmen's Terrace", 55.8, 23.8, A, "teaches up to Apprentice (75)" },
  { "Kylanna", "Ashenvale", "Ashenvale", 50.0, 67.0, A, "teaches up to Journeyman (150)" },
  { "Lilyssia Nightbreeze", "Stormwind City", "Mage Quarter", 55.6, 85.8, A, "teaches up to Journeyman (150)" },
  { "Tally Berryfizz", "Ironforge", "Tinker Town", 67.2, 54.2, A, "teaches up to Journeyman (150)" },
  { "Ainethil", "Darnassus", "Craftsmen's Terrace", 55.0, 24.0, A, "teaches up to Expert (225)" },
  { "Linzy Blackbolt", "Alterac Mountains", "Dalaran", 18.6, 62.4, A, "teaches up to Expert (225)" },
  { "Kylanna Windwhisper", "Feralas", "Feathermoon Stronghold", 32.6, 43.8, A, "teaches up to Artisan (300)" },
  { "Carolai Anise", "Tirisfal Glades", "Brill", 59.4, 52.2, H, "teaches up to Apprentice (75)" },
  { "Miao'zan", "Durotar", "Sen'jin Village", 55.4, 74.0, H, "teaches up to Apprentice (75)" },
  { "Kray", "Thunder Bluff", "Thunder Bluff", 47.0, 34.6, H, "teaches up to Apprentice (75)" },
  { "Whuut", "Orgrimmar", "The Drag", 56.0, 33.8, H, "teaches up to Apprentice (75)" },
  { "Doctor Martin Felben", "Undercity", "The Apothecarium", 46.6, 74.6, H, "teaches up to Apprentice (75)" },
  { "Bena Winterhoof", "Thunder Bluff", "Thunder Bluff", 47.0, 33.0, H, "teaches up to Journeyman (150)" },
  { "Yelmak", "Orgrimmar", "The Drag", 56.6, 33.2, H, "teaches up to Journeyman (150)" },
  { "Doctor Marsh", "Undercity", "The Apothecarium", 51.6, 75.6, H, "teaches up to Journeyman (150)" },
  { "Serge Hinott", "Hillsbrad Foothills", "Tarren Mill", 61.6, 19.2, H, "teaches up to Journeyman (150)" },
  { "Doctor Herbert Halsey", "Undercity", "The Apothecarium", 48.2, 72.2, H, "teaches up to Expert (225)" },
  { "Rogvar", "Swamp of Sorrows", "Stonard", 48.4, 55.6, H, "teaches up to Artisan (300)" },
  { "Jaxin Chong", "Stranglethorn Vale", "Booty Bay", 28.0, 78.0, nil, "teaches up to Journeyman (150)" },
  { "Master Mycologist Shurome", "Felwood", "Emerald Sanctuary", 51.4, 82.0, nil, "teaches up to Artisan (300)" },
})

local ENCH_AJ = "teaches Apprentice and Journeyman"
addTrainers("Enchanting", ENCH, {
  { "Alanna Raveneye", "Teldrassil", "Oracle Glade, next to the bear shrine", 36.6, 34.2, A, ENCH_AJ },
  { "Thonys Pillarstone", "Ironforge", "Thistlefuzz Arcanery, Great Forge", 60.6, 44.0, A, ENCH_AJ },
  { "Betty Quin", "Stormwind City", "Mage Quarter, canal-side building", 43.0, 64.0, A, ENCH_AJ },
  { "Lalina Summermoon", "Darnassus", "Craftsmen's Terrace", 59.6, 12.6, A, ENCH_AJ },
  { "Lucan Cordell", "Stormwind City", "Mage Quarter", 43.0, 64.2, A, ENCH_AJ },
  { "Gimble Thistlefuzz", "Ironforge", "Thistlefuzz Arcanery, Great Forge", 60.0, 45.2, A, ENCH_AJ },
  { "Xylinnia Starshine", "Feralas", "Feathermoon Stronghold, under the Elven gazebo", 31.6, 44.2, A, ENCH_AJ },
  { "Kitta Firewind", "Elwynn Forest", "Tower of Azora, top level", 64.8, 70.6, A, "teaches Expert (needs level 20 and Enchanting 125)" },
  { "Mot Dawnstrider", "Thunder Bluff", "Dawnstrider Enchanters hut", 45.0, 38.0, H, ENCH_AJ },
  { "Vance Undergloom", "Tirisfal Glades", "Gallows' End Tavern, Brill", 61.6, 51.6, H, ENCH_AJ },
  { "Jhag", "Orgrimmar", "Godan's Runeworks, The Drag", 53.6, 38.2, H, ENCH_AJ },
  { "Malcomb Wynn", "Undercity", "Apothecarium, inner cloister", 62.8, 60.2, H, ENCH_AJ },
  { "Teg Dawnstrider", "Thunder Bluff", "Dawnstrider hut", 45.0, 38.4, H, ENCH_AJ },
  { "Godan", "Orgrimmar", "Godan's Runeworks, The Drag", 53.8, 38.4, H, ENCH_AJ },
  { "Lavinia Crowe", "Undercity", "Apothecarium", 62.6, 61.4, H, ENCH_AJ },
  { "Hgarth", "Stonetalon Mountains", "Sun Rock Retreat, NE side up a hidden path", 49.2, 57.2, H, "teaches Expert (needs level 20 and Enchanting 125)" },
})

-- The Engineering page does not say which faction each trainer serves.
addTrainers("Engineering", ENGI, {
  { "Bronk Guzzlegear", "Dun Morogh", "Dun Morogh", 50.2, 50.4, nil, "teaches Apprentice" },
  { "Finbus Geargrind", "Duskwood", "Duskwood", 77.4, 48.4, nil, "teaches up to Journeyman" },
  { "Jemma Quikswitch", "Ironforge", "Ironforge", 68.6, 45.0, nil, "teaches Apprentice" },
  { "Springspindle Fizzlegear", "Ironforge", "Ironforge", 68.8, 45.2, nil, "teaches up to Expert" },
  { "Tinkmaster Overspark", "Ironforge", "Ironforge", 70.6, 50.4, nil, "Gnomish Engineering" },
  { "Trixie Quikswitch", "Ironforge", "Ironforge", 68.2, 44.2, nil, "teaches up to Journeyman" },
  { "Deek Fizzlebizz", "Loch Modan", "Loch Modan", 45.8, 13.6, nil, "teaches Apprentice" },
  { "Lilliam Sparkspindle", "Stormwind City", "Stormwind City", 62.2, 30.6, nil, "teaches up to Expert" },
  { "Sprite Jumpsprocket", "Stormwind City", "Stormwind City", 61.8, 30.8, nil, "teaches Apprentice" },
  { "Franklin Lloyd", "Undercity", "Undercity", 76.6, 75.0, nil, "teaches up to Expert" },
  { "Graham Van Talen", "Undercity", "Undercity", 75.6, 73.2, nil, "teaches Apprentice" },
  { "Jenna Lemkenilli", "Darkshore", "Darkshore", 38.2, 41.0, nil, "teaches Apprentice" },
  { "Mukdrak", "Durotar", "Durotar", 52.2, 40.8, nil, "teaches Apprentice" },
  { "Twizwick Sprocketgrind", "Mulgore", "Mulgore", 61.8, 31.6, nil, "teaches Apprentice" },
  { "Nogg", "Orgrimmar", "Valley of Honor", 75.8, 25.2, nil, "teaches up to Journeyman" },
  { "Roxxik", "Orgrimmar", "Orgrimmar", 76.0, 25.0, nil, "teaches up to Expert" },
  { "Thund", "Orgrimmar", "Orgrimmar", 76.0, 23.2, nil, "teaches Apprentice" },
  { "Buzzek Bracketswing", "Tanaris", "Tanaris", 52.2, 27.6, nil, "teaches up to Artisan" },
  { "Nixx Sprocketspring", "Tanaris", "Gadgetzan", 52.4, 27.2, nil, "Goblin Engineering (specialization at level 30 and Engineering 200)" },
  { "Tinkerwiz", "The Barrens", "Ratchet", 62.6, 36.2, nil, "teaches Apprentice; starts the Goblin Engineering quest (level 30, Engineering 200)" },
  { "Melbin Powderfuse", "Riverglades", "Powderfuse Port", 77.6, 50.8, nil, "Goblin recipes" },
})

local APPR, ALLR = "teaches Apprentice only", "teaches all ranks"
addTrainers("Herbalism", HERB, {
  { "Nancy Songflower", "Elwynn Forest", "Northshire", 52.4, 43.8, A, APPR },
  { "Emrys Flintbeard", "Dun Morogh", "Coldridge Valley", 28.8, 66.6, A, APPR },
  { "Eleyna Duskbreeze", "Teldrassil", "Shadowglen", 59.8, 41.4, A, APPR },
  { "Firodren Mooncaller", "Darnassus", "Temple Gardens", 48.0, 68.0, A, ALLR },
  { "Reyna Stonebranch", "Ironforge", "Great Forge", 55.6, 58.0, A, ALLR },
  { "Tannysa", "Stormwind City", "Mage Quarter", 44.8, 77.0, A, ALLR },
  { "Shylamiir", "Stormwind City", "The Park", 15.2, 49.8, A, ALLR },
  { "Malorne Bladeleaf", "Teldrassil", "Dolanaar", 57.6, 60.6, A, ALLR },
  { "Herbalist Pomeroy", "Elwynn Forest", "near the gates of Stormwind City", 39.8, 48.4, A, ALLR },
  { "Kali Healtouch", "Loch Modan", "Thelsamar", 36.6, 48.4, A, ALLR },
  { "Alma Jainrose", "Redridge Mountains", "Lakeshire", 21.8, 45.8, A, ALLR },
  { "Cylania Rootstalker", "Ashenvale", "Silverwind Refuge", 50.6, 67.0, A, ALLR },
  { "Telurinon Moonshadow", "Wetlands", "Menethil Harbor", 8.0, 55.8, A, ALLR },
  { "Brant Jasperbloom", "Dustwallow Marsh", "Theramore Isle", 64.0, 47.6, A, ALLR },
  { "Edward Egan", "Alterac Mountains", "Dalaran", 18.4, 63.2, A, ALLR },
  { "Zor'la", "Durotar", "Valley of Trials", 42.6, 67.4, H, APPR },
  { "Garan Sunstrider", "Mulgore", "Red Cloud Mesa", 44.2, 77.8, H, APPR },
  { "Florence Nightshade", "Tirisfal Glades", "Death Knell", 32.4, 65.2, H, APPR },
  { "Jandi", "Orgrimmar", "The Drag", 55.6, 39.6, H, ALLR },
  { "Komin Winterhoof", "Thunder Bluff", "centre of Thunder Bluff", 49.8, 39.8, H, ALLR },
  { "Martha Alliestar", "Undercity", "Apothecarium", 54.8, 50.2, H, ALLR },
  { "Mishiki", "Durotar", "Sen'jin Village", 55.4, 75.0, H, ALLR },
  { "Faruza", "Tirisfal Glades", "Brill", 59.8, 52.0, H, ALLR },
  { "Aranae Venomblood", "Hillsbrad Foothills", "Tarren Mill", 61.6, 19.6, H, ALLR },
  { "Angrun", "Stranglethorn Vale", "Grom'gol Base Camp", 32.2, 27.6, H, ALLR },
  { "Ruw", "Feralas", "Camp Mojache", 76.0, 43.4, H, ALLR },
  { "Flora Silverwind", "Stranglethorn Vale", "Booty Bay", 27.6, 77.6, nil },
  { "Malvor", "Moonglade", "Nighthaven", 45.6, 46.8, nil },
})

addTrainers("Mining", MINE, {
  { "Kelsey Fargo", "Elwynn Forest", "Northshire", 47.2, 32.6, A, APPR },
  { "Sally Swiftwrench", "Dun Morogh", "Coldridge Valley", 28.8, 67.8, A, APPR },
  { "Fanorran Stilloak", "Teldrassil", "Shadowglen", 58.2, 41.6, A, APPR },
  { "Geofram Bouldertoe", "Ironforge", "The Great Forge", 50.4, 26.0, A, ALLR },
  { "Gelman Stonehand", "Stormwind City", "Dwarven District", 59.0, 37.6, A, ALLR },
  { "Yarr Hammerstone", "Dun Morogh", "Steelgrill's Depot", 50.0, 50.2, A, ALLR },
  { "Dank Drizzlecut", "Dun Morogh", "Gol'Bolar Quarry", 69.2, 55.4, A, ALLR },
  { "Brock Stoneseeker", "Loch Modan", "Thelsamar", 37.2, 46.8, A, ALLR },
  { "Kurdram Stonehammer", "Darkshore", "Auberdine", 38.2, 41.0, A, ALLR },
  { "Matt Johnson", "Duskwood", "Darkshire", 74.0, 49.6, A, ALLR },
  { "Norzsh", "Durotar", "Valley of Trials", 40.6, 68.0, H, APPR },
  { "Vartha Rockmane", "Mulgore", "Red Cloud Mesa", 44.2, 78.2, H, APPR },
  { "Walter Mason", "Tirisfal Glades", "Death Knell", 32.2, 65.8, H, APPR },
  { "Makaru", "Orgrimmar", "Valley of Honor", 73.0, 26.4, H, ALLR },
  { "Brek Stonehoof", "Thunder Bluff", "centre of Thunder Bluff", 34.6, 57.6, H, ALLR },
  { "Brom Killian", "Undercity", "War Quarter", 56.0, 37.0, H, ALLR },
  { "Krunn", "Durotar", "Razor Hill", 51.8, 40.8, H, ALLR },
  { "Johan Focht", "Silverpine Forest", "The Sepulcher", 43.4, 40.6, H, ALLR },
  { "Pikkle", "Tanaris", "Gadgetzan", 51.0, 28.0, nil },
  { "Grungle", "Riverglades", "Powderfuse Port", 77.6, 51.8, nil },
})

addTrainers("Skinning", SKIN, {
  { "Riley Peltskinner", "Elwynn Forest", "Northshire", 47.0, 39.8, A, APPR },
  { "Brighid Stormflayer", "Dun Morogh", "Coldridge Valley", 29.2, 67.6, A, APPR },
  { "Terunne Bearshaper", "Teldrassil", "Shadowglen", 59.4, 38.6, A, APPR },
  { "Balthus Stoneflayer", "Ironforge", "The Great Forge", 39.8, 33.0, A, ALLR },
  { "Eladriel", "Darnassus", "Craftsmen's Terrace", 64.2, 21.8, A, ALLR },
  { "Helene Peltskinner", "Elwynn Forest", "Goldshire", 46.2, 62.2, A, ALLR },
  { "Maris Granger", "Stormwind City", "Old Town", 67.8, 49.0, A, ALLR },
  { "Radnaal Maneweaver", "Teldrassil", "Road to Darnassus", 42.0, 50.0, A, ALLR },
  { "Wilma Ranthal", "Redridge Mountains", "Redridge Mountains", 88.8, 71.0, A, ALLR },
  { "Jayla", "Ashenvale", "Silverwind Refuge", 50.0, 67.2, A, ALLR },
  { "Kagil", "Durotar", "Valley of Trials", 40.8, 67.8, H, APPR },
  { "Nawka Wildsong", "Mulgore", "Red Cloud Mesa", 44.6, 76.8, H, APPR },
  { "Margaret Weaver", "Tirisfal Glades", "Death Knell", 32.6, 65.6, H, APPR },
  { "Killian Hagey", "Undercity", "Rogues' Quarter", 71.0, 59.4, H, ALLR },
  { "Kulleg Stonehorn", "Feralas", "Camp Mojache", 74.4, 43.0, H, ALLR },
  { "Malux", "Desolace", "Shadowprey Village", 23.2, 69.8, H, ALLR },
  { "Mooranta", "Thunder Bluff", "Thunder Bluff", 45.2, 43.6, H, ALLR },
  { "Rand Rhobart", "Tirisfal Glades", "outside the Undercity", 65.6, 60.0, H, ALLR },
  { "Thuwd", "Orgrimmar", "The Drag", 63.2, 45.2, H, ALLR },
  { "Yonn Deepcut", "Mulgore", "Bloodhoof Village", 45.6, 57.8, H, ALLR },
  { "Dranh", "The Barrens", "Camp Taurajo", 45.0, 59.0, H, ALLR },
})
ns.Data:Register("place", "wowhead-trainers", trainers)

-- ------------------------------------------------------------ reputation
local reps = {}
local function rep(t) t.verified = false reps[#reps + 1] = t end

rep({ id = "rep-gelkis-molkar", kind = "quartermaster", zone = "Desolace", place = "southwest Desolace", x = 0.356, y = 0.920,
  name = "Molkar", note = "Gelkis Clan Centaur quartermaster: recipes for Carved Centaur Totems (Honored 15 totems, Exalted 60). Rep with Gelkis lowers Magram.", source = GELK })
rep({ id = "rep-magram-gorhak", kind = "quartermaster", zone = "Desolace", place = "southwest side of the lake", x = 0.662, y = 0.794,
  name = "Gorhak", note = "Magram Clan Centaur quartermaster: recipes for Carved Centaur Totems (Honored 15, Exalted 60). Rep with Magram lowers Gelkis.", source = MAGR })
rep({ id = "rep-nightclaw-lotheluum", kind = "quest_start", zone = "Zephras Isle", place = "Valanaar", x = 0.640, y = 0.750,
  name = "Lotheluum Starbreeze", quest = "Unnerving Silence", level = 10,
  note = "Starts the Nightclaw Druids reputation chain (quests for levels 10-12).", source = NCLW })
rep({ id = "rep-nightclaw-elegael", kind = "quest_start", zone = "Zephras Isle", place = "just SW of the Nightfang cave, behind a tree", x = 0.616, y = 0.392,
  name = "Elegael Thornpaw", quest = "Feathers for Binding", level = 10,
  note = "Nightclaw Druids quests: Feathers for Binding, Tears of the Lady, Unwanted and Unworthy (1500 rep together).", source = NCLW })
rep({ id = "rep-nightclaw-vayn", kind = "quartermaster", zone = "Zephras Isle", place = "Nightfang cave entrance", x = 0.638, y = 0.360,
  name = "Vayn Moongaze", quest = "Mercy Falls on Deaf Ears",
  note = "Nightclaw Druids quartermaster. Then repeat More Al'Aketh Ears: 200 rep per 5 ears (best farm: Shrine of Akir).", source = NCLW })
rep({ id = "rep-timbermaw-grazle", kind = "quest_start", zone = "Felwood", place = "just south of Emerald Sanctuary", x = 0.510, y = 0.850,
  name = "Grazle", quest = "Timbermaw Ally", level = 55,
  note = "Timbermaw Hold starts at Hated: kill 6 each of Deadwood Warriors, Pathfinders and Gardeners SW of him (150 rep).", source = TMBR })
rep({ id = "rep-timbermaw-nafien", kind = "quest_start", zone = "Felwood", place = "outside Timbermaw Hold", x = 0.648, y = 0.082,
  name = "Nafien", quest = "Deadwood of the North", level = 55,
  note = "Timbermaw quest in Felpaw Village (150 rep). Be Unfriendly before you walk through the cave or the furbolgs attack.", source = TMBR })
rep({ id = "rep-timbermaw-salfa", kind = "quest_start", zone = "Winterspring", place = "outside Timbermaw Hold", x = 0.278, y = 0.346,
  name = "Salfa", quest = "Winterfall Activity", level = 55,
  note = "Timbermaw quest: 8 each of Winterfall Shaman, Den Watcher, Ursa (best at Winterfall Village east of Everlook), 150 rep.", source = TMBR })
rep({ id = "rep-timbermaw-ekkal", kind = "quest_start", zone = "Azshara", x = 0.420, y = 0.388,
  name = "Ekkal", quest = "Blackmaw Pouches",
  note = "Timbermaw rep in Azshara: repeatable Blackmaw Pouches, 5 pouches = 100 rep (pouches drop in Blackmaw Hold or sell on the AH).", source = TMBR })
rep({ id = "rep-timbermaw-meilosh", kind = "quartermaster", zone = "Felwood", place = "inside Timbermaw Hold", x = 0.656, y = 0.028,
  name = "Meilosh", note = "Timbermaw Hold vendor: recipes from Friendly to Revered. Also takes the Runecloth turn-in (30 Runecloth, 100 rep) at Friendly.", source = TMBR })
rep({ id = "rep-timbermaw-gorn", kind = "vendor", zone = "Felwood", place = "inside Timbermaw Hold", x = 0.652, y = 0.026,
  name = "Gorn One Eye", note = "At Honored with Timbermaw sells food, drink and ammo. At Exalted gives The Root of All Evil (group quest).", source = TMBR })

-- Azeroth Commerce Authority camp, Three Corners (Alliance). The guide gives /way #44 x, y.
rep({ id = "rep-aca-tamelyn", kind = "quartermaster", zone = "Redridge Mountains", place = "Three Corners", x = 0.106, y = 0.713,
  name = "Tamelyn Aldridge", faction = A,
  note = "Azeroth Commerce Authority rewards for Merchant's Favor: Packmule Treat (Minimule pet) 1500, Advertising License Application 1200 at Honored.", source = ACA })
rep({ id = "rep-aca-huey", kind = "vendor", zone = "Redridge Mountains", place = "Three Corners", x = 0.085, y = 0.721,
  name = "Huey Sunnydale", faction = A, note = "Sells Reins of the Pack Kodo (ground mount) for 6000 Merchant's Favor.", source = ACA })
rep({ id = "rep-aca-marcy", kind = "quest_start", zone = "Redridge Mountains", place = "Three Corners", x = 0.096, y = 0.709,
  name = "Marcy Baker", faction = A, quest = "Shipping Label",
  note = "Hand in filled Waylaid Supply Crates here. Shipping Label quests give 660 XP plus Merchant's Favor.", source = ACA })
local ACA_VENDORS = {
  { "Alynsia", "Enchanting", 11.2, 71.6 }, { "Nina Surefire", "Alchemy", 11.0, 72.3 },
  { "Kalsey Sanden", "Cooking", 10.8, 72.7 }, { "Fritz Fizzle", "Engineering", 10.5, 74.3 },
  { "Stondry Darkhammer", "Blacksmithing", 10.4, 74.7 }, { "Mivin Shadowweave", "Tailoring", 10.0, 73.0 },
  { "Daniel Stitchsong", "Leatherworking", 10.0, 72.9 },
}
for _, v in ipairs(ACA_VENDORS) do
  rep({ id = "rep-aca-" .. slug(v[1]), kind = "vendor", zone = "Redridge Mountains", place = "Three Corners", x = v[3] / 100, y = v[4] / 100,
    name = v[1], faction = A, note = v[2] .. " recipes for Merchant's Favor (Azeroth Commerce Authority); the skill 300 Certification gives a title.", source = ACA })
end
rep({ id = "rep-dsl-camp", kind = "quartermaster", zone = "The Barrens", place = "just outside the Crossroads", x = 0.42, y = 0.34,
  faction = H, note = "Durotar Supply and Logistics camp (Horde): hand in Waylaid Supply Crates for Merchant's Favor. The guide names no NPC.", source = DSL })
ns.Data:Register("place", "wowhead-reps", reps)

-- ------------------------------------------------------------ services
-- Recipe and book vendors, profession rank quests, library, Legacy rewards,
-- mount vendors, level-50 class quest steps.
local svc = {}
local function add(t) t.verified = false svc[#svc + 1] = t end

-- Mount vendors (RIDE): { name, zone, place, x, y, faction, note }
local MOUNTS = {
  { "Ogunaro Wolfrunner", "Orgrimmar", "Valley of Honor", 69.4, 12.4, H, "Orc mount vendor (wolves). Your first mount is free after you learn riding." },
  { "Zachariah Post", "Tirisfal Glades", "Brill", 59.8, 52.6, H, "Undead mount vendor (skeletal horses). Your first mount is free after you learn riding." },
  { "Harb Clawhoof", "Mulgore", "Bloodhoof Village", 46.6, 62.0, H, "Tauren mount vendor (kodos). Your first mount is free after you learn riding." },
  { "Tylana Clawhoof", "Stonetalon Mountains", "Stonetalon Mountains", 46.0, 59.8, H, "Sells the Lavender Kodo; the quest Your First Riding Kodo rewards it." },
  { "Zjolnir", "Durotar", "Sen'jin Village", 55.2, 75.6, H, "Troll mount vendor (raptors). Your first mount is free after you learn riding." },
  { "Katie Hunter", "Elwynn Forest", "Eastvale Logging Camp", 84.0, 65.4, A, "Human mount vendor (horses). Your first mount is free after you learn riding." },
  { "Unger Statforth", "Wetlands", "Wetlands", 8.6, 54.6, A, "Black Stallion Bridle (quest Your First Horse)." },
  { "Veron Amberstill", "Dun Morogh", "Gol'Bolar Quarry", 63.6, 50.6, A, "Dwarf mount vendor (rams). Your first mount is free after you learn riding." },
  { "Lelanai", "Darnassus", "Darnassus", 38.6, 15.6, A, "Night Elf mount vendor (tigers). Your first mount is free after you learn riding." },
  { "Milli Featherwhistle", "Dun Morogh", "Kharanos", 49.2, 48.0, A, "Gnome mount vendor (mechanostriders). Your first mount is free after you learn riding." },
}
for _, m in ipairs(MOUNTS) do
  add({ id = "svc-mount-" .. slug(m[1]), kind = "vendor", zone = m[2], place = m[3], x = m[4] / 100, y = m[5] / 100,
    name = m[1], title = "Mount Vendor", faction = m[6], note = m[7], level = 40, source = RIDE })
end

-- Cooking recipe and book sellers (COOK)
local COOKBOOKS = {
  { "Catherine Leland", "Stormwind City", "Stormwind City", 55.0, 69.6, A, "Sells Recipe: Brilliant Smallfish (Cooking 1) and Recipe: Bristle Whisker Catfish (Cooking 100)." },
  { "Sewa Mistrunner", "Thunder Bluff", "Thunder Bluff", 55.8, 47.6, H, "Sells Recipe: Brilliant Smallfish (Cooking 1)." },
  { "Tharynn Bouden", "Elwynn Forest", "Goldshire", 41.8, 67.0, A, "Sells Recipe: Longjaw Mud Snapper (Cooking 50)." },
  { "Naal Mistrunner", "Thunder Bluff", "Thunder Bluff", 51.0, 52.8, H, "Sells Recipe: Longjaw Mud Snapper (Cooking 50) and Recipe: Bristle Whisker Catfish (Cooking 100)." },
  { "Tansy Puddlefizz", "Ironforge", "Ironforge", 47.8, 6.6, A, "Sells Recipe: Mithril Head Trout (Cooking 175)." },
  { "Shankys", "Orgrimmar", "Orgrimmar", 70.0, 30.6, H, "Sells Recipe: Mithril Head Trout (Cooking 175)." },
  { "Gikkix", "Tanaris", "Steamwheedle Port", 66.6, 22.0, nil, "Sells Recipe: Spotted Yellowtail (Cooking 225), the 225-300 fish." },
  { "Shandrina", "Ashenvale", "NE of Talondeep Path", 49.6, 67.0, A, "Sells the Expert Cookbook (Cooking 150-225)." },
  { "Wulan", "Desolace", "Shadowprey Village", 26.2, 69.8, H, "Sells the Expert Cookbook (Cooking 150-225)." },
}
for _, v in ipairs(COOKBOOKS) do
  add({ id = "svc-cook-" .. slug(v[1]), kind = "vendor", zone = v[2], place = v[3], x = v[4] / 100, y = v[5] / 100,
    name = v[1], faction = v[6], note = v[7], source = COOK })
end
add({ id = "svc-cook-artisan", kind = "quest_start", zone = "Tanaris", place = "Gadgetzan", x = 0.526, y = 0.280,
  name = "Dirge Quikcleave", quest = "Clamlette Surprise", level = 35,
  note = "Artisan Cooking (needs level 35 and Cooking 225): 12 Giant Egg, 10 Zesty Clam Meat, 20 Alterac Swiss.", source = COOK })

-- First Aid (FAID)
add({ id = "svc-firstaid-deneb", kind = "vendor", zone = "Arathi Highlands", place = "Stromgarde Keep", x = 0.270, y = 0.588,
  name = "Deneb Walker", faction = A, level = 20,
  note = "Sells Expert First Aid - Under Wraps, Manual: Heavy Silk Bandage and Manual: Mageweave Bandage.", source = FAID })
add({ id = "svc-firstaid-balai", kind = "vendor", zone = "Dustwallow Marsh", place = "Brackenwall Village", x = 0.364, y = 0.304,
  name = "Balai Lok'Wein", faction = H, level = 20,
  note = "Sells Expert First Aid - Under Wraps, Manual: Heavy Silk Bandage and Manual: Mageweave Bandage.", source = FAID })
add({ id = "svc-firstaid-gustaf", kind = "quest_start", zone = "Dustwallow Marsh", place = "Theramore Isle", x = 0.676, y = 0.488,
  name = "Doctor Gustaf VanHowzen", faction = A, quest = "Triage", level = 35,
  note = "Artisan First Aid (level 35, First Aid 225). Also teaches the recipes at 240, 260 and 290.", source = FAID })
add({ id = "svc-firstaid-gregory", kind = "quest_start", zone = "Arathi Highlands", place = "Hammerfall", x = 0.734, y = 0.368,
  name = "Doctor Gregory Victor", faction = H, quest = "Triage", level = 35,
  note = "Artisan First Aid (level 35, First Aid 225). Also teaches the recipes at 240, 260 and 290.", source = FAID })

-- Fishing (FISH)
add({ id = "svc-fish-heming", kind = "vendor", zone = "Stranglethorn Vale", place = "Booty Bay", x = 0.274, y = 0.770,
  name = "Old Man Heming", level = 20, note = "Sells Expert Fishing - The Bass and You (Fishing 150-225).", source = FISH })
add({ id = "svc-fish-natpagle", kind = "quest_start", zone = "Dustwallow Marsh", x = 0.586, y = 0.600,
  name = "Nat Pagle", quest = "Nat Pagle, Angler Extreme", level = 35,
  note = "Artisan Fishing (level 35, Fishing 225): catch Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin.", source = FISH })

-- Library books (LIB)
add({ id = "svc-library-owen", kind = "quest_start", zone = "Undercity", place = "Magic Quarter", x = 0.740, y = 0.324,
  name = "Owen Thadd", faction = H, quest = "Friend of the Library",
  note = "Horde librarian: 10 books for an amulet, 20 for a ring, 25 for Truthseeker's Bow, Crest of Elucidation or Researcher's Night Light.", source = LIB })
add({ id = "svc-library-garion", kind = "quest_start", zone = "Stormwind City", place = "Mage Tower", x = 0.490, y = 0.864,
  name = "Garion Wendell", faction = A, quest = "Friend of the Library",
  note = "Alliance librarian: 10 books for an amulet, 20 for a ring, 25 for Truthseeker's Bow, Crest of Elucidation or Researcher's Night Light.", source = LIB })

-- Legacy rewards and Tarnished Undermine Reals
add({ id = "svc-legacy-wiley", kind = "vendor", zone = "The Barrens", place = "Ratchet", x = 0.620, y = 0.394,
  name = "Innkeeper Wiley", note = "Claim Legacy progress rewards: 15 points Replica Ironforge Air Rifle, 25 Spectral Bear Cub, 40 tabard, 55 bear mount.", source = LEG })
add({ id = "svc-tur-pix", kind = "vendor", zone = "Stranglethorn Vale", x = 0.284, y = 0.758,
  name = "Pix Xizzix", level = 55, note = "Sells trinkets, cloaks, rings, belts and relics for Tarnished Undermine Reals (from level 55+ dungeon bosses).", source = TUR })

-- Sunken Temple level-50 class quests (STQ): the step away from your trainer
local STC = {
  { "hunter-ogtinc", "HUNTER", "Ogtinc", "Azshara", "cliff edge above the beach", 42.4, 42.6, "Courser Antlers", "Hunter level-50 quest (The Hunter's Charm from your trainer): 2 Perfect Courser Antlers, then 6 Wavethrasher Scales, then Morphaz." },
  { "priest-ogtinc", "PRIEST", "Ogtinc", "Azshara", "cliff edge above the beach", 42.4, 42.6, "Of Coursers We Know", "Priest level-50 quest (Cenarion Aid from your trainer): 4 Healthy Courser Glands, Ichor of Undeath, then Blood of Morphaz." },
  { "mage-sanath", "MAGE", "Sanath Lim-yo", "Azshara", "Azshara", 28.0, 50.0, "Magecraft", "Mage level-50 quest from your trainer ends here; take his teleport to Archmage Xylem." },
  { "xylem", nil, "Archmage Xylem", "Azshara", "Azshara", 29.0, 40.0, "Magic Dust", "Mage (Magic Dust, Siren's Coral) and Rogue (Encoded Fragments) level-50 class quest steps." },
  { "druid-torwa", "DRUID", "Torwa Pathfinder", "Un'Goro Crater", "Un'Goro Crater", 71.0, 76.0, "Bloodpetal Poison", "Druid level-50 quest: 8 Gorishi Sting and 8 Bloodcap, then Toxic Test, then Atal'alarion in Sunken Temple." },
  { "paladin-ashlam", "PALADIN", "Commander Ashlam Valorfist", "Western Plaguelands", "Chillwind Camp", 42.0, 84.0, "Dispelling Evil", "Paladin level-50 quest: 20 Minion's Scourgestones from Western Plaguelands Scourge." },
  { "rogue-ravenholdt", "ROGUE", "Lord Jorach Ravenholdt", "Alterac Mountains", "Ravenholdt house", 84.0, 17.0, "A Simple Request", "Rogue level-50 quest: reach the house by the Hillsbrad ramp; then a Sealed Azure Bag from Timbermaw Shaman in Azshara." },
  { "shaman-bathrah", "SHAMAN", "Bath'rah the Windwatcher", "Alterac Mountains", "Alterac Mountains", 80.0, 66.0, "Spirit Totem", "Shaman level-50 quest: 8 Bloodshot Spider Eye and 8 Thick Black Claw, then Da Voodoo." },
  { "warlock-impsy", "WARLOCK", "Impsy", "Felwood", "Felwood", 41.0, 45.0, "The Wrong Stuff", "Warlock level-50 quest: bring Impsy a Felcloth, then 10 Rotting Wood and 4 Bloodvenom Essence." },
  { "warrior-fallenhero", "WARRIOR", "Fallen Hero of the Horde", "Swamp of Sorrows", "Swamp of Sorrows", 34.3, 66.1, "Warrior Kinship", "Warrior level-50 quest (A Troubled Spirit): 7 Helboars in Blasted Lands, then War on the Shadowsworn." },
}
for _, c in ipairs(STC) do
  add({ id = "svc-st-" .. c[1], kind = "quest_start", class = c[2], zone = c[4], place = c[5], x = c[6] / 100, y = c[7] / 100,
    name = c[3], quest = c[8], level = 50, note = c[9], source = STQ })
end
ns.Data:Register("place", "wowhead-services", svc)
