-- bosses, dungeons 1-15 (research 2026-11-26): Warcraft Tavern and Method.gg
-- Forever guides. Both say the old dungeons only changed loot, and their
-- boss text reads like Classic, so the old dungeons are kind "classic"; the
-- new ones (Hall of Thanes, Ruins of Lordaeron, Excavation Site, Dalaran)
-- are "forever". "(type not stated)" = the guide names the effect, not its type.
local WT = "https://www.warcrafttavern.com/forever/guides/"
local M = "https://www.method.gg/wow-forever/dungeons/"
local function B(name, tags, extra)
  local b = { name = name, tags = tags or {} }
  for k, v in pairs(extra or {}) do b[k] = v end
  return b
end
local function D(kind, src, list) return { kind = kind, source = src, list = list } end

F.bosses["The Hall of Thanes"] = D("forever", WT .. "hall-of-thanes/", {
  B("Faldrim Anvilmar", { interrupt = "Mind Blast", dispel_curse = "Anvilmar's Curse slows attacks and casts" }, { npc = 261306 }),
  B("Magmatus", { fire_res = "fire nova on melee", adds = "Dark Iron Summoner, kill first", interrupt = "the Summoner's casts" }, { npc = 261316 }),
  B("Plunder", {}, { npc = 261311 }),
  B("Durgen Dirgehammer", { fear = "8-second group fear (Tremor Totem helps)", adds = "two Lesser Stone Golems" }, { npc = 261319 }),
})
F.bosses["Ruins of Lordaeron"] = D("forever", M .. "ruins-of-lordaeron", {
  B("Witherfang", { dispel_poison = "Leech Poison on the tank", adds = "Broodlings" }),
  B("The Baron", { spread = "melee-range damage: ranged spread out" }),
  B("Viktor the Vile", { adds = "five waves first", dispel_poison = "Leech Poison" }, { optional = true }),
  B("The Abandoned", { interrupt = "Life Drain on the tank", adds = "three waves", frost_res = "Frost Nova and Chilled" }, { optional = true }),
  B("Bjork", {}),
  B("Rath'mael", { interrupt = "Flamestrike on the tank", fire_res = "Flamestrike" }),
})
F.bosses["Wailing Caverns"] = D("classic", M .. "wailing-caverns", {
  B("Lady Anacondra", { interrupt = "Sleep and Lightning Bolt", interrupt_heal = "Healing Touch" }),
  B("Kresh", {}),
  B("Lord Cobrahn", { interrupt = "Druid's Slumber and Lightning Bolt", interrupt_heal = "Healing Touch", adds = "Deviate Pythons", dispel_poison = "poison in serpent form" }),
  B("Lord Pythas", { interrupt = "Sleep and Lightning Bolt", interrupt_heal = "Healing Touch", adds = "Druid of the Fang, Deviate Shambler" }),
  B("Skum", { spread = "Chained Bolt jumps between players", interrupt = "Chained Bolt" }),
  B("Lord Serpentis", { interrupt = "Sleep and Lightning Bolt", interrupt_heal = "Healing Touch", adds = "Druids of the Fang" }),
  B("Verdan the Everliving", {}),
  B("Mutanus the Devourer", { fear = "Terrify", interrupt = "Naralex's Nightmare", adds = "waves during the escort" }),
})
F.bosses["Ragefire Chasm"] = D("classic", M .. "ragefire-chasm", {
  B("Oggleflint", { adds = "troggs" }),
  B("Taragaman the Hungerer", { fire_res = "Fire Nova on melee" }),
  B("Jergosh the Invoker", { interrupt = "Immolate", dispel_curse = "Curse of Weakness", adds = "two adds" }),
  B("Bazzalan", { dispel_poison = "poison on the tank", adds = "two adds" }),
})
F.bosses["The Deadmines"] = D("classic", M .. "the-deadmines", {
  B("Rhahk'Zor", { cc = "polymorph one of his two Watchmen", adds = "two Watchmen" }),
  B("Sneed's Shredder", { fear = "Terrify" }),
  B("Gilnid", { adds = "goblin workers" }),
  B("Mr. Smite", { adds = "two stealthed Blackguards" }),
  B("Cookie", { interrupt_heal = "Cookie's Cooking heals him" }),
  B("Captain Greenskin", { adds = "Squallshaper, Pirate and Companion", dispel_poison = "Poisoned Harpoon on the tank" }),
  B("Edwin VanCleef", { adds = "two at the pull, two more at 50% (a stun stops the second call)" }),
})
F.bosses["Shadowfang Keep"] = D("classic", M .. "shadowfang-keep", {
  B("Rethilgore", { adds = "worgs" }),
  B("Razorclaw the Butcher", {}),
  B("Baron Silverlaine", { dispel_curse = "Veil of Shadow cuts healing", interrupt = "Veil of Shadow" }),
  B("Commander Springvale", { interrupt_heal = "Holy Light inside Divine Shield", adds = "Wailing Guardsman silences, kill first" }),
  B("Odo the Blindwatcher", { enrage = "Howling Rage grows as he loses health", adds = "Vile Bats" }),
  B("Fenrus the Devourer", { dispel_poison = "Toxic Saliva" }),
  B("Wolf Master Nandos", { adds = "wolf guards, then summoned wolves" }),
  B("Archmage Arugal", { shadow_res = "heavy Void Bolt on the tank", cc = "the player Arugal's Curse takes over" }),
})
F.bosses["Blackfathom Deeps"] = D("classic", M .. "blackfathom-deeps", {
  B("Ghamoo-ra", {}),
  B("Lady Sarevess", { interrupt = "Forked Lightning", adds = "two naga", cc = "polymorph a naga" }),
  B("Gelihast", { adds = "murlocs" }),
  B("Old Serra'kis", {}, { conflict = "one guide says he heals himself, another says no abilities" }),
  B("Twilight Lord Kelris", { dispel_magic = "Sleep", shadow_res = "Mind Blast on the tank" }),
  B("Aku'mai", { enrage = "Frenzied Rage", nature_res = "Poison Cloud", adds = "brazier waves before the boss" }),
})
F.bosses["The Stockade"] = D("classic", M .. "the-stockade", {
  B("Targorr the Dread", { enrage = "at 20%", adds = "prisoners" }),
  B("Dextren Ward", { fear = "Intimidating Shout (Tremor Totem helps)" }),
  B("Kam Deepfury", {}),
  B("Hamhock", { interrupt = "Chain Lightning", purge = "Bloodlust on him and nearby adds" }),
  B("Bazil Thredd", { adds = "clear the room first" }),
})
F.bosses["Excavation Site: Wetlands"] = D("forever", M .. "excavation-site-wetlands", {
  B("Saltspine", {}),
  B("Shadetooth", { fear = "Terrifying Roar can run players into packs", enrage = "at 20%", adds = "two Thicket Hunters",
    dispel_disease = "Infected Wound from the Hunters" }),
  B("Relic Guardian", {}),
})
F.bosses["City of Dalaran"] = D("forever", M .. "city-of-dalaran", {
  B("Atrexis the Grave Knight", { purge = "Unholy Frenzy", adds = "Raise Dead skeletons" }),
  B("Arcane Anomaly", {}),
  B("Arcanic Enigma", { adds = "two Mana Phantoms, then Manalings", interrupt = "the Phantoms' Mana Burn", dispel_magic = "Manamorph polymorph (type not stated)" }),
  B("Unstable Sentinel", { spread = "Malfunction pulses within 25 yards" }),
  B("Fel Ancient", {}),
  B("Mana Devourer", {}),
  B("Shade of the Archmage", { spread = "Bounding Mana bounces: ranged spread" }),
}, nil)
F.bosses["City of Dalaran"].orderUnconfirmed = true
F.bosses["Gnomeregan"] = D("classic", M .. "gnomeregan", {
  B("Grubbis", { adds = "Chomper" }),
  B("Viscous Fallout", { nature_res = "nature melee hits armor doesn't reduce" }),
  B("Electrocutioner 6000", { spread = "Chain Bolt", nature_res = "Megavolt and Chain Bolt" }),
  B("Crowd Pummeler 9-60", {}),
  B("Mekgineer Thermaplugg", { adds = "Walking Bombs: press the pillar buttons" }),
})
F.bosses["Razorfen Kraul"] = D("classic", M .. "razorfen-kraul", {
  B("Roogug", { adds = "Earth and Stone Rumblers", cc = "polymorph adds" }),
  B("Death Speaker Jargba", { dispel_magic = "Dominate Mind", cc = "the mind-controlled player", adds = "Groundshaker first",
    interrupt = "the Acolyte's Mana Burn", shadow_res = "Shadow Bolt" }),
  B("Aggem Thorncurse", { adds = "boar spirits", interrupt_heal = "Chain Heal" }),
  B("Overlord Ramtusk", { adds = "two Spearhides" }),
  B("Agathelos the Raging", { enrage = "at low health" }),
  B("Charlga Razorflank", { interrupt_heal = "Renew on herself", spread = "Chain Bolt hits three players" }),
})
F.bosses["Scarlet Monastery"] = D("classic", M .. "scarlet-monastery-graveyard", {
  B("Interrogator Vishas", { adds = "a Scryer", interrupt = "the Scryer's Shadow Bolt", dispel_magic = "the Scryer's Sleep" }),
  B("Bloodmage Thalnos", { fire_res = "Flame Spike and Fire Nova" }, { conflict = "guides disagree whether his Shadow Bolt can be interrupted" }),
  B("Houndmaster Loksey", { purge = "Bloodlust on him and the hounds", adds = "three hounds", cc = "the hounds" }, { source = M .. "scarlet-monastery-library" }),
  B("Arcanist Doan", { spread = "Detonation: spread to the edges or break line of sight" }, { source = M .. "scarlet-monastery-library" }),
  B("Herod", { spread = "Cleave and Whirlwind", adds = "Trainees rush in after he dies" }, { source = M .. "scarlet-monastery-armory" }),
  B("High Inquisitor Fairbanks", { interrupt_heal = "Heal", dispel_curse = "Curse of Blood" }, { source = M .. "scarlet-monastery-cathedral" }),
  B("Scarlet Commander Mograine", {}, { source = M .. "scarlet-monastery-cathedral" }),
  B("High Inquisitor Whitemane", { interrupt_heal = "she revives and heals Mograine: kill her first" }, { source = M .. "scarlet-monastery-cathedral" }),
})
F.bosses["Razorfen Downs"] = D("classic", M .. "razorfen-downs", {
  B("Tuten'kash", { dispel_poison = "Virulent Poison", dispel_curse = "Curse of Tuten'kash", adds = "spider waves from the gong" }),
  B("Mordresh Fire Eye", { interrupt = "Fireball", fire_res = "Fire Nova on melee", adds = "skeletons" }),
  B("Glutton", { enrage = "at 30%" }),
  B("Amnennar the Coldbringer", { frost_res = "Frostbolt and Frost Nova", adds = "Frost Spectres, twice" }),
})
F.bosses["Uldaman"] = D("classic", M .. "uldaman", {
  B("Revelosh", { interrupt = "Chain Lightning", spread = "healers spread", adds = "Rockchewers", cc = "polymorph an add" }),
  B("Ironaya", {}),
  B("Obsidian Sentinel", { adds = "Obsidian Shards at 66% and 33%" }),
  B("Ancient Stone Keeper", {}),
  B("Galgann Firehammer", { dispel_magic = "Amplify Flames", fire_res = "Fire Nova, Flame Lash, Flame Shock", adds = "two Geologists", cc = "the adds" }),
  B("Grimlok", { purge = "Bloodlust on all enemies", cc = "adds", adds = "Geomancer, Brawler and a Basilisk", dispel_magic = "the Basilisk's Crystalline Slumber" }),
  B("Archaedas", { adds = "Earthen Guardians and Vault Warders" }),
})
