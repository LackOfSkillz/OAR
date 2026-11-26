-- bosses, dungeons 16-29 (research 2026-11-26). Warcraft Tavern's Forever
-- guides; its pages for Classic dungeons say they're based on Classic (not
-- testable in the beta), so those are kind "classic". "(guess)" = the tag is
-- our reading of the ability, not stated by the guide.
local WT = "https://www.warcrafttavern.com/forever/guides/"
local function B(name, tags, extra)
  local b = { name = name, tags = tags or {} }
  for k, v in pairs(extra or {}) do b[k] = v end
  return b
end
local function D(kind, src, list) return { kind = kind, source = src, list = list } end

F.bosses["Zul'Farrak"] = D("classic", WT .. "zulfarrak/", {
  B("Antu'sul", { interrupt_heal = "two healing casts", adds = "basilisks and totems" }),
  B("Theka the Martyr", { dispel_disease = "Fevered Plague (type is our guess)" }),
  B("Witch Doctor Zum'rah", { interrupt = "Shadow Bolt", interrupt_heal = "heavy healing", adds = "zombies and totems" }),
  B("Shadowpriest Sezz'ziz", { interrupt_heal = "heals himself and Nekrum", fear = "Psychic Scream", adds = "Nekrum" }),
  B("Sergeant Bly", { adds = "four-member party; the healer dies first" }),
  B("Hydromancer Velratha", { interrupt = "heavy caster", adds = "totems", cc = "pulled trash" }),
  B("Gahz'rilla", {}),
  B("Chief Ukorz Sandscalp", { adds = "Ruuzlu" }),
})
F.bosses["Maraudon"] = D("classic", WT .. "maraudon/", {
  B("Tinkerer Gizlock", {}),
  B("Lord Vyletongue", { adds = "two elites", cc = "control the adds" }),
  B("Noxxion", { adds = "splits into copies" }),
  B("Razorlash", {}),
  B("Celebras the Cursed", { interrupt = "Twisted Tranquility", adds = "re-summoned" }),
  B("Landslide", { adds = "Shardlings" }),
  B("Rotgrip", {}),
  B("Princess Theradras", { fear = "Repulsive Gaze (Fear Ward or Tremor Totem help)" }),
})
F.bosses["The Temple of Atal'Hakkar"] = D("classic", WT .. "sunken-temple/", {
  B("Atal'alarion", {}),
  B("Spawn of Hakkar", {}),
  B("Jammal'an the Prophet", { dispel_magic = "Shadow Word: Pain", dispel_curse = "Curse of Weakness", spread = "Flamestrike and Hex", adds = "Ogom dies first" }),
  B("Shade of Eranikus", { tank_swap_or_offtank = "Deep Slumber sleeps the top-threat player" }),
  B("Avatar of Hakkar", { dispel_magic = "Shadow Word: Pain", dispel_curse = "Curse of Tongues", cc = "a mind-controlled player", adds = "Bloodkeepers" }),
})
F.bosses["Blackrock Depths"] = D("classic", WT .. "blackrock-depths/", {
  B("High Interrogator Gerstahn", { interrupt = "Mana Burn", fear = "Psychic Scream", dispel_magic = "Shadow Word: Pain" }),
  B("Lord Roccor", {}),
  B("Houndmaster Grebmar", { adds = "wolves", purge = "Bloodlust (our guess)" }),
  B("Hedrum the Creeper", { dispel_poison = "Baneful Poison", dispel_magic = "Web Explosion" }),
  B("Anub'shiah", { dispel_curse = "Curse of Tongues" }),
  B("Ok'thor the Breaker", { dispel_magic = "Polymorph" }),
  B("Eviscerator", { shadow_res = "Shadow Bolt Volley" }),
  B("Theldren", { adds = "four gladiators", cc = "four gladiators" }),
  B("Pyromancer Loregrain", { fire_res = "fire damage and a Scorching Totem", adds = "the totem" }),
  B("Warder Stilgiss", { interrupt = "Frostbolt", dispel_magic = "Frost Nova", adds = "Verek" }),
  B("Watchman Doomgrip", { adds = "three stone guardians" }),
  B("Fineous Darkvire", { interrupt_heal = "Holy Light" }),
  B("Lord Incendius", { dispel_curse = "stacking Curse of the Elemental Lord", fire_res = "fire damage" }),
  B("Bael'Gar", { adds = "spawned mid-fight", fire_res = "Magma Splash" }),
  B("General Angerforge", { adds = "summoned at low health" }),
  B("Golem Lord Argelmach", { adds = "two constructs" }),
  B("Hurley Blackbreath", { adds = "four adds", cc = "four adds" }),
  B("Plugger Spazzring", { dispel_magic = "Immolate", dispel_curse = "Curse of Tongues" }, { npc = 9499, source = "https://forever.warcraftdb.com" }),
  B("Phalanx", {}),
  B("Ambassador Flamelash", { adds = "corner spawns buff him", fire_res = "fire damage" }),
  B("Doom'rel", { interrupt = "the Seven include casters", adds = "the Seven; Doom'rel's demons can be banished" }),
  B("Magmus", { fire_res = "fire sweeps the room" }),
  B("Emperor Dagran Thaurissan", { interrupt_heal = "Princess Moira heals him", tank_swap_or_offtank = "off-tank Moira" }),
})
F.bosses["Dire Maul"] = D("classic", WT .. "dire-maul-east/", {
  B("Pusillin", { adds = "four imps", interrupt = "Fireball and Blast Wave" }),
  B("Lethtendris", { interrupt = "Void Bolt and Shadow Bolt Volley", dispel_magic = "Immolate", dispel_curse = "Tongues and Thorns",
    adds = "Pimgib, kill first", shadow_res = "Shadow Bolt Volley" }),
  B("Hydrospawn", { adds = "Hydrolings" }),
  B("Zevrim Thornhoof", { dispel_magic = "Intense Pain (type is our guess)" }),
  B("Alzzin the Wildshaper", { adds = "join at 35%" }),
  B("Tendris Warpwood", { adds = "Wandering Ancients" }, { source = WT .. "dire-maul-west/" }),
  B("Magister Kalendris", { interrupt = "Mind Blast and Mind Flay", dispel_magic = "Shadow Word: Pain", cc = "a mind-controlled player", shadow_res = "shadow damage" }, { source = WT .. "dire-maul-west/" }),
  B("Illyanna Ravenoak", { adds = "Ferra the bear", cc = "Hibernate Ferra" }, { source = WT .. "dire-maul-west/" }),
  B("Immol'thar", { adds = "Eyes", enrage = "at 50%" }, { source = WT .. "dire-maul-west/" }),
  B("Prince Tortheldrin", {}, { source = WT .. "dire-maul-west/" }),
  B("Guard Mol'dar", { enrage = "enrages" }, { source = WT .. "dire-maul-north/" }),
  B("Stomper Kreeg", { enrage = "enrages" }, { npc = 14322, source = WT .. "dire-maul-north/" }),
  B("Guard Fengus", { enrage = "enrages" }, { source = WT .. "dire-maul-north/" }),
  B("Guard Slip'kik", { enrage = "enrages" }, { source = WT .. "dire-maul-north/" }),
  B("Captain Kromcrush", { adds = "Gordok Reavers at 50%", cc = "the Reavers", fear = "Intimidating Shout" }, { npc = 14325, source = WT .. "dire-maul-north/" }),
  B("King Gordok", { interrupt_heal = "Cho'Rush's Healing Wave", interrupt = "Mind Blast", fear = "Psychic Scream" }, { source = WT .. "dire-maul-north/" }),
})
F.bosses["Blackrock Spire"] = D("classic", WT .. "lower-blackrock-spire/", {
  B("Highlord Omokk", { adds = "two adds", cc = "two adds", enrage = "enrages" }),
  B("Shadow Hunter Vosh'gajin", { dispel_curse = "Curse of Blood", adds = "two Shadow Priests", cc = "two Shadow Priests" }),
  B("War Master Voone", {}),
  B("Mother Smolderweb", { dispel_poison = "Mother's Milk", adds = "spiderlings" }),
  B("Urok Doomhowl", { adds = "ogre waves", fear = "Intimidating Roar" }),
  B("Quartermaster Zigris", { spread = "Stun Bomb" }),
  B("Halycon", { adds = "pups" }),
  B("Gizrul the Slavener", { enrage = "enrages" }),
  B("Overlord Wyrmthalak", { adds = "at 50%", cc = "the adds" }),
  B("Pyroguard Emberseer", { adds = "Incarcerators", fire_res = "Fire Nova" }, { source = WT .. "upper-blackrock-spire/" }),
  B("Solakar Flamewreath", { adds = "waves" }, { source = WT .. "upper-blackrock-spire/" }),
  B("Goraluk Anvilcrack", { tank_swap_or_offtank = "Backhand stuns the main tank" }, { source = WT .. "upper-blackrock-spire/" }),
  B("Warchief Rend Blackhand", { tank_swap_or_offtank = "one tank each for Rend and Gyth", adds = "drake waves" }, { source = WT .. "upper-blackrock-spire/" }),
  B("The Beast", { fear = "fears", fire_res = "Flamebreak" }, { source = WT .. "upper-blackrock-spire/" }),
  B("General Drakkisath", { tank_swap_or_offtank = "Conflagration", adds = "two Chromatic guards", fire_res = "Flame Breath" }, { source = WT .. "upper-blackrock-spire/" }),
})
F.bosses["Scholomance"] = D("classic", WT .. "scholomance/", {
  B("Kirtonos the Herald", { dispel_curse = "curses in human form" }),
  B("Jandice Barov", { dispel_disease = "Dark Plague", dispel_curse = "Curse of Blood", adds = "illusions" }),
  B("Rattlegore", { adds = "one add and nearby trash" }),
  B("Marduk Blackpool", { shadow_res = "Shadow Bolt Volley and Defiling Aura" }),
  B("Vectus", { spread = "Flamestrike", fire_res = "fire damage" }),
  B("Ras Frostwhisper", { interrupt = "casts", fear = "fears", frost_res = "Chill Nova" }),
  B("Lady Illucia Barov", { interrupt = "casts", cc = "a mind-controlled player" }),
  B("Lord Alexei Barov", { dispel_curse = "Veil of Shadow", adds = "two adds", cc = "Shackle Undead", shadow_res = "Unholy Aura (our guess)" }),
  B("The Ravenian", {}),
  B("Lorekeeper Polkelt", { adds = "exploding zombies", spread = "explosions" }),
  B("Doctor Theolen Krastinov", { enrage = "at 50%" }),
  B("Instructor Malicia", { interrupt = "heavy caster", adds = "adds" }),
  B("Darkmaster Gandling", { adds = "teleported players fight chamber mobs" }),
})
F.bosses["Stratholme"] = D("classic", WT .. "stratholme-living/", {
  B("The Unforgiven", { adds = "adds" }),
  B("Postmaster Malown", { adds = "Undead Postmen", cc = "only Turn or Shackle Undead work", fear = "fears", dispel_curse = "Wailing Dead" }),
  B("Timmy the Cruel", { enrage = "enrages" }),
  B("Cannon Master Willey", { adds = "adds", cc = "adds" }),
  B("Archivist Galford", { spread = "Burning Winds", fire_res = "Burning Winds" }),
  B("Balnazzar", { dispel_magic = "Deep Sleep (type is our guess)", fear = "Psychic Scream", spread = "spread" }),
  B("Nerub'enkan", { adds = "scarabs" }, { source = WT .. "stratholme-undead/" }),
  B("Baroness Anastari", { cc = "a possessed player", dispel_curse = "Banshee Curse" }, { source = WT .. "stratholme-undead/" }),
  B("Maleki the Pallid", { interrupt = "Drain Life and Frostbolt", tank_swap_or_offtank = "Ice Tomb freezes the tank", frost_res = "frost damage (our guess)" }, { source = WT .. "stratholme-undead/" }),
  B("Magistrate Barthilas", {}, { source = WT .. "stratholme-undead/" }),
  B("Ramstein the Gorger", { tank_swap_or_offtank = "Knockout: he jumps to the second on threat" }, { source = WT .. "stratholme-undead/" }),
  B("Baron Rivendare", { adds = "skeletons", shadow_res = "Unholy Aura (our guess)" }, { source = WT .. "stratholme-undead/" }),
})
F.bosses["The Drowned City"] = D("forever", "https://www.method.gg/wow-forever/dungeons/the-drowned-city", {
  B("Zul'Alai", { dispel_magic = "Rotted Strike slow" }),
  B("Var'Taka", { adds = "two Brinescale Priestesses", cc = "the priestesses", interrupt_heal = "the priestesses heal the boss" }),
  B("Captain Dreadrise", { interrupt = "Waterbolt Volley", adds = "kill the Abyssal Bubble" }),
  B("Deathless Marrow", { adds = "endless naga waves", cc = "naga waves" }),
  B("Primeval Elemental", { interrupt = "Waterbolt" }, { source = WT .. "the-drowned-city/" }),
  B("Min'loth the Serpent", { dispel_poison = "Poison Bolt Volley in phase 2", fear = "fears" }),
})
F.bosses["Krol'dok Stronghold"] = D("forever", WT .. "kroldok-stronghold/", {
  B("Slavecrusher Grox", { adds = "prisoners join" }),
  B("Twilight Commander Zarmok", {}),
  B("War Handler Ashka", { adds = "wolves Snarlfang and Terrorhowl, kill first" }),
  B("Nar'gurk", { adds = "warlock and curseweaver adds", cc = "charmed players and the adds", dispel_magic = "the adds' magic damage over time" }),
  B("Bossman Toof", { adds = "Brutes and Shamans" }),
  B("Overlord Mugg", { adds = "two Centurions", cc = "the Centurions", spread = "jump damage" }),
})
F.bosses["Alcaz Prison"] = D("forever", WT .. "alcaz-island-prison/", {
  B("Tidemistress Ca'zass", { interrupt = "casts", adds = "two Enchantresses", dispel_magic = "Polymorph (our guess)", frost_res = "Frostbolt Volley and Blizzard (our guess)" }),
  B("Overseer Wrex", {}),
  B("Katerina the Cleaner", { adds = "two Chaplain Priests, kill first" }),
  B("Zarla Ober", { fire_res = "Fireball, Flamestrike and fire breath", fear = "in the dragon phase", adds = "the room pack" }),
  B("The Questioner", { interrupt = "Drain Life", adds = "adds" }),
})
F.bosses["Blackmaw Hold"] = D("forever", WT .. "blackmaw-hold/", {
  B("Withermaw", { adds = "Flesh Maggots", fear = "fears", dispel_disease = "disease" }),
  B("Bonesnout the Unbroken", { adds = "four Ritualists give him damage resistance" }),
  B("Impaan the Imprisoner", { adds = "imps" }),
  B("Unbound Spirit", { adds = "totems and spirit beasts" }),
  B("Elder Shaman Bloodmane", { interrupt = "Chain Lightning", adds = "Devotees and two Feral Spirits", nature_res = "nature damage" }),
  B("Blackmaw Behemoth", { interrupt = "Bestial Roar and Thunder Roar", adds = "Clawbert first: his heal can't be interrupted", nature_res = "nature damage" }),
  B("Varrox Bleakhoof", { spread = "Crimson Wrest and its void zone" }),
})
F.bosses["Shaper's Terrace"] = D("forever", WT .. "shapers-terrace/", {
  B("Cinder", { fire_res = "fire damage" }),
  B("Titanosaur", { fear = "fears" }),
  B("Snowtalon", { frost_res = "Frost Nova and Cone of Cold" }),
  B("Tor'Rel", { fire_res = "one raptor of each element", frost_res = "one raptor of each element", adds = "Ravasaur Stalkers at low health" }),
  B("Vitrix", {}, { unknown = true }),
  B("Direhorn Matriarch", {}),
  B("Thunderhoof", { interrupt = "lightning casts", nature_res = "nature damage" }),
  B("Venomridge", { dispel_poison = "party-wide poison", nature_res = "nature damage" }),
  B("Bolt", { spread = "instant Chain Lightning", nature_res = "nature damage" }),
  B("Nanaya", { frost_res = "Blizzard phases", nature_res = "Chain Lightning phases (our guess)" }),
})
