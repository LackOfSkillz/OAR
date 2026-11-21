-- Data/Talents.lua
-- Levelling talent builds, one talent per point from level 10, copied from the
-- WoW Forever guide at wowhandbook.com (client 1.60.1, read 2026-11-16).
-- verified = false until Gary has spent the points in game and the names
-- matched the client's tree (the Talents module logs any name it lacks).
-- order = { { "Talent name", points }, ... } in the order the guide spends them.
-- fromLevel / toLevel: a build for part of the way (the mage guide resets
-- its talents at 40 and goes Frost); respec = what to tell the player.

local _, ns = ...
local WH = "wowhandbook.com/classes/%s/talents (read 2026-11-16)"

ns.Data:Register("talentbuild", "forever-levelling", {
  { id = "hunter-bm", class = "HUNTER", rank = 1, name = "Beast Mastery (levelling)",
    source = WH:format("hunter"), verified = false,
    note = "Your pet tanks, you shoot. 35 Beast Mastery / 16 Marksmanship, no respec.",
    order = {
      { "Endurance Training", 5 },            -- 10-14
      { "Improved Aspect of the Monkey", 3 }, -- 15-17
      { "Improved Revive Pet", 2 },           -- 18-19
      { "Bestial Swiftness", 1 },             -- 20
      { "Pathfinding", 2 },                   -- 21-22
      { "Unleashed Fury", 2 },                -- 23-24
      { "Summon Hawk", 1 },                   -- 25
      { "Unleashed Fury", 3 },                -- 26-28
      { "Improved Mend Pet", 1 },             -- 29
      { "Ferocity", 5 },                      -- 30-34
      { "Intimidation", 1 },                  -- 35
      { "Spirit Bond", 2 },                   -- 36-37
      { "Bestial Discipline", 2 },            -- 38-39
      { "Frenzy", 4 },                        -- 40-43
      { "Bestial Wrath", 1 },                 -- 44
      { "Lethal Attacks", 5 },                -- 45-49
      { "Careful Aim", 5 },                   -- 50-54
      { "Rapid Killing", 2 },                 -- 55-56
      { "Improved Stings", 3 },               -- 57-59
      { "Trueshot Aura", 1 },                 -- 60
    } },

  { id = "priest-shadow", class = "PRIEST", rank = 1, name = "Shadow (levelling)",
    source = WH:format("priest"), verified = false,
    note = "Shadow damage with Spirit Tap mana; 17 Discipline / 3 Holy / 31 Shadow, no respec.",
    order = {
      { "Wand Specialization", 2 },           -- 10-11
      { "Spirit Tap", 5 },                    -- 12-16
      { "Improved Shadow Word: Pain", 2 },    -- 17-18
      { "Shadow Focus", 3 },                  -- 19-21
      { "Shadow Reach", 2 },                  -- 22-23
      { "Mind Flay", 1 },                     -- 24
      { "Improved Mind Flay", 2 },            -- 25-26
      { "Vampiric Embrace", 1 },              -- 27
      { "Shadow Weaving", 3 },                -- 28-30
      { "Shadow Focus", 1 },                  -- 31
      { "Silence", 1 },                       -- 32
      { "Devouring Contagion", 2 },           -- 33-34
      { "Shadow Focus", 1 },                  -- 35
      { "Improved Mind Blast", 1 },           -- 36
      { "Darkness", 5 },                      -- 37-41
      { "Shadowform", 1 },                    -- 42
      { "Twin Disciplines", 5 },              -- 43-47
      { "Mental Strength", 3 },               -- 48-50
      { "Improved Power Word: Shield", 3 },   -- 51-53
      { "Meditation", 3 },                    -- 54-56
      { "Twilight Focus", 3 },                -- 57-59
      { "Soul Warding", 1 },                  -- 60
    } },

  { id = "mage-arcane", class = "MAGE", rank = 1, name = "Arcane (levelling 10-39)", toLevel = 39,
    source = WH:format("mage") .. ", Arcane to Frost Leveling", verified = false,
    note = "Arcane to 39; at 40 the guide resets your talents and goes Frost.",
    respec = "Level 40: reset your talents at the mage trainer; Outrider then follows the Frost build.",
    order = {
      { "Wand Specialization", 2 },           -- 10-11
      { "Improved Channeling", 3 },           -- 12-14
      { "Missile Barrage", 2 },               -- 15-16
      { "Arcane Subtlety", 2 },               -- 17-18
      { "Improved Channeling", 1 },           -- 19
      { "Arcane Blast", 1 },                  -- 20
      { "Improved Channeling", 1 },           -- 21
      { "Arcane Concentration", 3 },          -- 22-24
      { "Arcane Wrath", 1 },                  -- 25
      { "Arcane Concentration", 2 },          -- 26-27
      { "Arcane Meditation", 3 },             -- 28-30
      { "Precision", 2 },                     -- 31-32 (Frost)
      { "Presence of Mind", 1 },              -- 33
      { "Arcane Mind", 3 },                   -- 34-36
      { "Arcane Instability", 3 },            -- 37-39
    } },

  { id = "mage-frost", class = "MAGE", rank = 2, name = "Frost (levelling 40-60)", fromLevel = 40,
    source = WH:format("mage") .. ", Arcane to Frost Leveling", verified = false,
    note = "After the reset at 40: 31 points in Frost at once (the guide lists them, not their order), then back into Arcane.",
    order = {
      { "Improved Frostbolt", 5 }, { "Precision", 2 }, { "Ice Shards", 5 }, { "Frost Channeling", 3 },
      { "Ice Lance", 1 }, { "Ice Block", 1 }, { "Shatter", 3 }, { "Improved Cone of Cold", 3 },
      { "Cold Snap", 1 }, { "Fingers of Frost", 2 }, { "Winter's Chill", 4 }, { "Ice Barrier", 1 }, -- 40 (31 points)
      { "Winter's Chill", 1 },                -- 41
      { "Improved Blizzard", 1 },             -- 42
      { "Improved Channeling", 5 },           -- 43-47
      { "Missile Barrage", 2 },               -- 48-49
      { "Arcane Subtlety", 2 },               -- 50-51
      { "Arcane Concentration", 1 },          -- 52
      { "Arcane Blast", 1 },                  -- 53
      { "Arcane Concentration", 4 },          -- 54-57
      { "Arcane Meditation", 3 },             -- 58-60
    } },
})

-- Wowhead WoW Forever leveling guides (user guides by Drakanthos, client
-- 1.60.1, updated 2026-10-20; read in the browser 2026-11-21). Same rule:
-- verified = false until the points are spent and the names match the tree.
local WHF = "wowhead.com/forever guide by Drakanthos: %s (read 2026-11-21)"
ns.Data:Register("talentbuild", "wowhead-forever-levelling", {
  { id = "warrior-fury", class = "WARRIOR", rank = 1, name = "Fury (levelling, 16/35/0)",
    source = WHF:format("Fury Warrior Leveling and PvE"), verified = false,
    note = "Dual wield: Furious Precision fixes off-hand misses. Fury to 44, then 16 in Arms for Deep Wounds and rage. Train Dual Wield as soon as the trainer offers it; Berserker Stance from 30, Whirlwind from 36.",
    order = {
      { "Cruelty", 5 },                       -- 10-14
      { "Unbridled Wrath", 5 },               -- 15-19
      { "Furious Precision", 3 },             -- 20-22
      { "Piercing Howl", 1 },                 -- 23
      { "Booming Voice", 1 },                 -- 24
      { "Dual Wield Specialization", 5 },     -- 25-29
      { "Death Wish", 1 },                    -- 30
      { "Enrage", 5 },                        -- 31-35
      { "Flurry", 4 },                        -- 36-39
      { "Bloodthirst", 1 },                   -- 40
      { "Flurry", 1 },                        -- 41
      { "Raging Blows", 1 },                  -- 42
      { "Blood Craze", 2 },                   -- 43-44
      { "Improved Rend", 3 },                 -- 45-47 (Arms)
      { "Improved Heroic Strike", 2 },        -- 48-49
      { "Improved Tactical Mastery", 5 },     -- 50-54
      { "Anger Management", 1 },              -- 55
      { "Deep Wounds", 3 },                   -- 56-58
      { "Improved Overpower", 2 },            -- 59-60
    } },
  { id = "shaman-elemental", class = "SHAMAN", rank = 1, name = "Elemental (levelling, 31/20/0)",
    source = WHF:format("Elemental Shaman Leveling, Branch A"), verified = false,
    note = "Lightning Bolt does the work, Flame Shock sets up Lava Burst from 30, Elemental Mastery at 40. Hold the Lava Burst point until 30 if your points come early.",
    order = {
      { "Concussion", 5 },                    -- 10-14
      { "Call of Flame", 3 },                 -- 15-17
      { "Reverberation", 2 },                 -- 18-19
      { "Elemental Focus", 1 },               -- 20
      { "Elemental Alacrity", 3 },            -- 21-23
      { "Convection", 5 },                    -- 24-28
      { "Eye of the Storm", 1 },              -- 29
      { "Lava Burst", 1 },                    -- 30
      { "Lightning Overload", 3 },            -- 31-33
      { "Elemental Reach", 1 },               -- 34
      { "Elemental Fury", 5 },                -- 35-39
      { "Elemental Mastery", 1 },             -- 40
      { "Thundering Strikes", 5 },            -- 41-45 (Enhancement)
      { "Ancestral Knowledge", 5 },           -- 46-50
      { "Improved Ghost Wolf", 2 },           -- 51-52
      { "Shamanistic Focus", 1 },             -- 53
      { "Anticipation", 3 },                  -- 54-56
      { "Toughness", 4 },                     -- 57-60
    } },
  { id = "shaman-enhancement", class = "SHAMAN", rank = 2, name = "Enhancement (levelling, 17/34/0)",
    source = WHF:format("Enhancement Shaman Leveling, Branch A"), verified = false,
    note = "Mental Dexterity turns Intellect into attack power, Flurry and Windfury swing fast, Maelstrom Weapon makes Lightning Bolt instant. Stormstrike can't be trained before 40.",
    order = {
      { "Thundering Strikes", 5 },            -- 10-14
      { "Mental Dexterity", 3 },              -- 15-17
      { "Improved Ghost Wolf", 2 },           -- 18-19
      { "Shamanistic Focus", 1 },             -- 20
      { "Elemental Weapons", 3 },             -- 21-23
      { "Anticipation", 1 },                  -- 24
      { "Flurry", 5 },                        -- 25-29
      { "Mental Quickness", 2 },              -- 30-31
      { "Toughness", 3 },                     -- 32-34
      { "Maelstrom Weapon", 5 },              -- 35-39
      { "Stormstrike", 1 },                   -- 40
      { "Rage of the Farseer", 1 },           -- 41
      { "Improved Stormstrike", 2 },          -- 42-43
      { "Convection", 5 },                    -- 44-48 (Elemental)
      { "Elemental Devastation", 3 },         -- 49-51
      { "Reverberation", 5 },                 -- 52-56
      { "Call of Flame", 3 },                 -- 57-59
      { "Elemental Focus", 1 },               -- 60
    } },
  { id = "shaman-elemental-group", class = "SHAMAN", rank = 3, name = "Elemental (dungeons and raids, 38/13/0)",
    source = WHF:format("Elemental Shaman Leveling, Branch B (community build)"), verified = false,
    note = "The same core with Reverberation 5/5, Eye of the Storm 3/3, Elemental Reach 2/2 and Earthbound: the better pick once you group up.",
    order = {
      { "Convection", 5 },                    -- 10-14
      { "Concussion", 5 },                    -- 15-19
      { "Reverberation", 5 },                 -- 20-24
      { "Call of Flame", 3 },                 -- 25-27
      { "Elemental Focus", 1 },               -- 28
      { "Elemental Alacrity", 3 },            -- 29-31
      { "Eye of the Storm", 3 },              -- 32-34
      { "Earthbound", 1 },                    -- 35
      { "Elemental Reach", 2 },               -- 36-37
      { "Lightning Overload", 3 },            -- 38-40
      { "Lava Burst", 1 },                    -- 41
      { "Elemental Fury", 5 },                -- 42-46
      { "Elemental Mastery", 1 },             -- 47
      { "Thundering Strikes", 5 },            -- 48-52 (Enhancement)
      { "Ancestral Knowledge", 5 },           -- 53-57
      { "Improved Ghost Wolf", 2 },           -- 58-59
      { "Shamanistic Focus", 1 },             -- 60
    } },
})
