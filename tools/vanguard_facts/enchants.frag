-- enchant ids as they appear in item links, with WoW FOREVER values (Wowhead
-- Forever spell pages, 2026-11-26). Forever changed several Classic enchants:
-- chest Health became Stamina, Mana became Intellect, many amounts went up,
-- and some moved to ids above 8000. Never reuse a Classic table.
local W = "https://www.wowhead.com/forever/spell="
local STR, AGI, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local function E(id, name, spell, stats) F.enchants[id] = { name = name, stats = stats, source = W .. spell } end
local function X(id, name, spell, detail, proc) F.enchants[id] = { name = name, proc = true, detail = detail, kind = proc and "proc" or "other", source = W .. spell } end
local function all(n) return { [STR] = n, [AGI] = n, [STA] = n, [INT] = n, [SPI] = n } end
local function res(n) return { RESISTANCE2_NAME = n, RESISTANCE3_NAME = n, RESISTANCE4_NAME = n, RESISTANCE5_NAME = n, RESISTANCE6_NAME = n } end
E(847, "Chest: Minor Stats", 13626, all(1)) E(866, "Chest: Lesser Stats", 13700, all(2)) E(928, "Chest: Stats", 13941, all(3)) E(1891, "Chest: Greater Stats", 20025, all(4))
E(41, "Chest: Inferior Stamina", 7420, { [STA] = 2 }) E(242, "Chest: Lesser Stamina", 7748, { [STA] = 3 }) E(254, "Stamina +4 (chest, bracer or boots)", 7857, { [STA] = 4 })
E(850, "Chest: Greater Stamina", 13640, { [STA] = 6 }) E(908, "Chest: Superior Stamina", 13858, { [STA] = 8 }) E(1892, "Chest: Major Stamina", 20026, { [STA] = 10 })
E(24, "Chest: Minor Intellect", 7443, { [INT] = 2 }) E(246, "Chest: Lesser Intellect", 7776, { [INT] = 3 }) E(843, "Chest: Intellect", 13607, { [INT] = 4 })
E(857, "Chest: Greater Intellect", 13663, { [INT] = 6 }) E(1893, "Chest: Major Intellect", 20028, { [INT] = 10 })
E(66, "Minor Stamina +3 (bracer, boots or shield)", 7457, { [STA] = 3 }) E(248, "Bracer: Minor Strength", 7782, { [STR] = 3 })
E(247, "Minor Agility +3 (bracer or boots)", 7779, { [AGI] = 3 }) E(243, "Bracer: Minor Spirit", 7766, { [SPI] = 3 })
E(823, "Bracer: Lesser Strength", 13536, { [STR] = 4 }) E(8203, "Bracer: Lesser Spirit", 7859, { [SPI] = 4 }) E(8734, "Bracer: Lesser Intellect", 13622, { [INT] = 3 })
E(856, "Bracer: Strength", 13661, { [STR] = 5 }) E(852, "Stamina +5 (bracer, boots or shield)", 13648, { [STA] = 5 }) E(851, "Spirit +5", 13642, { [SPI] = 5 })
E(905, "Bracer: Intellect", 13822, { [INT] = 5 }) E(927, "Strength +7 (bracer or gloves)", 13939, { [STR] = 7 }) E(929, "Stamina +7", 13945, { [STA] = 7 })
E(907, "Bracer: Greater Spirit", 13846, { [SPI] = 7 }) E(1883, "Bracer: Greater Intellect", 20008, { [INT] = 7 }) E(1885, "Bracer: Superior Strength", 20010, { [STR] = 9 })
E(1886, "Stamina +9 (bracer or shield)", 20011, { [STA] = 9 }) E(1884, "Bracer: Superior Spirit", 20009, { [SPI] = 9 })
E(2566, "Bracer: Healing Power", 23802, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 24 })
E(783, "Cloak: Minor Protection", 7771, { RESISTANCE0_NAME = 10 }) E(744, "Cloak: Lesser Protection", 13421, { RESISTANCE0_NAME = 20 })
E(848, "Cloak: Defense", 13635, { RESISTANCE0_NAME = 30 }) E(884, "Cloak: Greater Defense", 13746, { RESISTANCE0_NAME = 60 })
E(1889, "Cloak: Superior Defense", 20015, { RESISTANCE0_NAME = 70 }) E(849, "Cloak: Lesser Agility", 13882, { [AGI] = 3 })
E(65, "Cloak: Minor Resistance", 7454, res(2)) E(903, "Cloak: Resistance", 13794, res(3)) E(1888, "Cloak: Greater Resistance", 20014, res(5))
E(256, "Cloak: Lesser Fire Resistance", 7861, { RESISTANCE2_NAME = 10 }) E(2463, "Cloak: Fire Resistance", 13657, { RESISTANCE2_NAME = 12 })
E(804, "Cloak: Lesser Shadow Resistance", 13522, { RESISTANCE5_NAME = 10 })
E(8204, "Boots: Lesser Agility", 13637, { [AGI] = 4 }) E(904, "Boots: Agility", 13935, { [AGI] = 5 }) E(1887, "Agility +7 (boots or gloves)", 20023, { [AGI] = 7 })
E(8206, "Gloves: Greater Agility", 20012, { [AGI] = 10 }) E(8207, "Gloves: Greater Strength", 20013, { [STR] = 10 })
E(2564, "Agility +15 (gloves or weapon)", 25080, { [AGI] = 15 }) E(2563, "Weapon: Strength", 23799, { [STR] = 15 })
E(2504, "Weapon: Spell Power", 22749, { ITEM_MOD_SPELL_POWER_SHORT = 30 }) E(2505, "Weapon: Healing Power", 22750, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 55 })
E(2568, "Weapon: Mighty Intellect", 23804, { [INT] = 22 }) E(2567, "Weapon: Mighty Spirit", 23803, { [SPI] = 22 })
E(723, "2H Weapon: Lesser Intellect", 7793, { [INT] = 5 }) E(2646, "2H Weapon: Agility", 27837, { [AGI] = 25 })
E(1904, "2H Weapon: Major Intellect", 20036, { [INT] = 9 }) E(1903, "2H Weapon: Major Spirit", 20035, { [SPI] = 9 })
E(255, "Shield: Lesser Spirit", 13485, { [SPI] = 3 }) E(1890, "Shield: Superior Spirit", 20016, { [SPI] = 9 })
X(2565, "Bracer: Mana Regeneration", 23801, "4 mana every 5 seconds") X(2617, "Gloves: Healing Power", 25079, "+35 healing, +12 spell damage")
X(911, "Boots: Minor Speed", 13890, "run speed") X(1900, "Weapon: Crusader", 20034, nil, true) X(803, "Weapon: Fiery Weapon", 13898, nil, true)
X(1898, "Weapon: Lifestealing", 20032, nil, true) X(1894, "Weapon: Icy Chill", 20029, nil, true) X(912, "Weapon: Demonslaying", 13915, nil, true)
X(250, "Weapon: Minor Striking", 7788, "+1 weapon damage") X(241, "Weapon: Lesser Striking", 13503, "+2 weapon damage") X(943, "Weapon: Striking", 13693, "+3 weapon damage")
X(805, "+4 weapon damage", 13943, "+4 weapon damage") X(1897, "+5 weapon damage", 20031, "+5 weapon damage") X(8205, "2H Weapon: Impact", 13695, "+6 weapon damage")
X(963, "2H Weapon: Greater Impact", 13937, "+7 weapon damage") X(1896, "2H Weapon: Superior Impact", 20030, "+9 weapon damage")
