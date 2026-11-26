-- vendor buy prices in copper (Wowhead Forever item tooltips, 2026-11-26).
-- per = how many items the price buys (ammo: a stack of 200, from the Classic
-- vendor lists; Forever's data has no batch field). Food and drink read as
-- per item (not confirmed). Soul Shard is not sold.
local W = "https://www.wowhead.com/forever/item="
local function P(id, name, copper, per, req) F.prices[id] = { name = name, copper = copper, per = per or 1, reqLevel = req, kind = "forever", source = W .. id } end
P(159, "Refreshing Spring Water", 25) P(1179, "Ice Cold Milk", 125, 1, 5) P(1205, "Melon Juice", 500, 1, 15)
P(1708, "Sweet Nectar", 1000, 1, 25) P(1645, "Moonberry Juice", 2000, 1, 35) P(8766, "Morning Glory Dew", 4000, 1, 45)
P(4540, "Tough Hunk of Bread", 25) P(4541, "Freshly Baked Bread", 125, 1, 5) P(4542, "Moist Cornbread", 500, 1, 15)
P(4544, "Mulgore Spice Bread", 1000, 1, 25) P(4601, "Soft Banana Bread", 2000, 1, 35) P(8950, "Homemade Cherry Pie", 4000, 1, 45)
P(117, "Tough Jerky", 25) P(2287, "Haunch of Meat", 125, 1, 5) P(3770, "Mutton Chop", 500, 1, 15)
P(3771, "Wild Hog Shank", 1000, 1, 25) P(4599, "Cured Ham Steak", 2000, 1, 35) P(8952, "Roasted Quail", 4000, 1, 45)
P(2512, "Rough Arrow", 10, 200, 1) P(2515, "Sharp Arrow", 50, 200, 10) P(3030, "Razor Arrow", 300, 200, 25) P(11285, "Jagged Arrow", 1000, 200, 40)
P(2516, "Light Shot", 10, 200, 1) P(2519, "Heavy Shot", 50, 200, 10) P(3033, "Solid Shot", 300, 200, 25)
P(17020, "Arcane Powder", 1000) P(17031, "Rune of Teleportation", 1000) P(17032, "Rune of Portals", 2000) P(17030, "Ankh", 2000)
P(17028, "Holy Candle", 700) P(17029, "Sacred Candle", 1000) P(5140, "Flash Powder", 25) P(17033, "Symbol of Divinity", 2000)
P(17034, "Maple Seed", 200) P(17035, "Stranglethorn Seed", 400) P(17036, "Ashwood Seed", 800) P(17037, "Hornbeam Seed", 1400)
P(17038, "Ironwood Seed", 2000) P(17021, "Wild Berries", 700) P(17026, "Wild Thornroot", 1000)
