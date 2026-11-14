-- Data/Money.lua
-- Ways to earn gold before 60 on WoW Forever (Gary, 2026-11-14: "build a guide
-- that leads people to the best way to make money at their level and for
-- their profession"). Guide facts in our own words, no coordinates. Gold per
-- hour (copper) only where a guide reports one; those are beta or first-week
-- live reports, so everything is verified = false. MoneyGuide replaces a
-- guide's number with Gary's own measured gold per hour once he has done that
-- kind of earning for 15 minutes.
-- category: what loot measures it (skin, herb, ore, fish, cloth, mob, craft)
-- Sources (read 2026-11-14):
--   CC = conquestcapped.com/guides/wow-forever/wow-forever-gold-making/ (beta + live to Nov 13)
--   LP = leprestore.com/guides/world-of-warcraft-forever/wow-forever-gold-farming-guide/

local _, ns = ...
local CC, LP, BOTH = "conquestcapped.com", "leprestore.com", "conquestcapped.com, leprestore.com"
local G = 10000

ns.Data:Register("money", "forever-guides", {
  { id = "loot-everything", title = "Loot everything, vendor the grey items", minLevel = 1, maxLevel = 60,
    category = "mob", source = BOTH, verified = false,
    how = "Grey items go to any vendor. When a quest reward isn't an upgrade, take the one that sells for most." },
  { id = "skin-route", title = "Skin the beasts on your quest route", minLevel = 5, maxLevel = 30,
    profession = "Skinning", category = "skin", source = LP, verified = false,
    how = "Skin what you kill anyway. Sell leather at the auction house only when it beats the vendor after fees." },
  { id = "gather-route", title = "Pick herbs and ore between quests", minLevel = 5, maxLevel = 30,
    profession = { "Herbalism", "Mining" }, category = { "herb", "ore" }, source = BOTH, verified = false,
    gph = { 1.75 * G, 1.75 * G }, zones = { "Elwynn Forest" },
    how = "Detour only for nodes close to your route. Sell ore, not bars: bars often sold for less than the ore." },
  { id = "skin-loch-modan", title = "Skin crocolisks, bears and boars, east shore of Loch Modan", minLevel = 17, maxLevel = 22,
    profession = "Skinning", category = "skin", faction = "Alliance", source = CC, verified = false,
    gph = { 2 * G, 7.5 * G }, zones = { "Loch Modan" },
    how = "About 2g an hour normally, more when Pristine Leather drops (its price fell fast in the first week)." },
  { id = "grind-duskwood", title = "Grind spiders and wolves in Duskwood", minLevel = 20, maxLevel = 25,
    category = "mob", faction = "Alliance", source = CC, verified = false, gph = { 1.5 * G, 1.5 * G }, zones = { "Duskwood" },
    how = "No profession needed. Loot and vendor everything." },
  { id = "cloth-humanoids", title = "Kill humanoids for cloth", minLevel = 10, maxLevel = 60,
    category = "cloth", source = BOTH, verified = false,
    how = "Humanoids drop Wool, Silk and Mageweave cloth, coins and green items. Tailors buy cloth; test a small stack first." },
  { id = "mine-tin-silver", title = "Mine Tin and Silver where mobs are level 22-24", minLevel = 20, maxLevel = 30,
    profession = "Mining", category = "ore", source = CC, verified = false, gph = { 7 * G, 7 * G },
    how = "Tin Ore and Silver Ore. The guide doesn't name the zones." },
  { id = "fish-rare-catches", title = "Fish for rare catches (gems and green items)", minLevel = 20, maxLevel = 60,
    profession = "Fishing", category = "fish", source = CC, verified = false, gph = { 10 * G, 10 * G }, minSkill = 225,
    zones = { "Tanaris" },
    how = "Needs about 225 fishing. One player reported over 10g an hour with a +75 lure in Tanaris, where nobody else fished." },
  { id = "scarce-mats", title = "Scarce materials: Pyrite, Frilled Lichen, Pristine Leather", minLevel = 20, maxLevel = 60,
    profession = { "Mining", "Herbalism", "Skinning" }, category = { "ore", "herb", "skin" }, source = LP, verified = false,
    how = "Named as scarce in the beta (Pyrite from mining, Frilled Lichen from herbs, Pristine Leather from skinning). Prices unconfirmed." },
  { id = "zones-30-45", title = "Gather between quests in Stranglethorn, Desolace or Riverglades", minLevel = 30, maxLevel = 45,
    category = { "herb", "ore", "skin" }, source = LP, verified = false, zones = { "Stranglethorn Vale", "Desolace", "Riverglades" },
    how = "Collect nodes between objectives and skin beasts you must kill anyway. Riverglades is new on Forever." },
  { id = "zones-45-60", title = "Gather in Tanaris, Feralas, Un'Goro, Felwood and Winterspring", minLevel = 45, maxLevel = 60,
    category = { "herb", "ore", "skin", "cloth" }, source = LP, verified = false,
    zones = { "Tanaris", "Feralas", "Un'Goro Crater", "Felwood", "Winterspring" },
    how = "Ore, herbs, hides, cloth and enchanting materials all sell at this level." },
  { id = "alchemy-quest-items", title = "Brew items other players need for quests", minLevel = 30, maxLevel = 45,
    profession = "Alchemy", category = "craft", source = CC, verified = false,
    how = "Example: Frost Oil (Alchemy 200) for a Badlands quest had a good margin, then fell below the herb cost. Check prices first." },
  { id = "cook-well-fed", title = "Cook Well Fed food to sell", minLevel = 5, maxLevel = 60,
    profession = "Cooking", category = "craft", source = CC, verified = false,
    how = "Cooked fish sold for about 1 silver each in the beta. Cook what you catch or loot and sell the stack." },
  { id = "sell-to-players", title = "Sell materials other players need for supply crates", minLevel = 10, maxLevel = 60,
    category = { "herb", "ore", "skin", "cloth" }, source = LP, verified = false,
    how = "Forever's Waylaid Crates ask for gathered materials. The crates pay Merchant's Favor, so the gold comes from selling those materials to players filling them." },
})
