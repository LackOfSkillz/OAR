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
