# Phase 8: Sharing and social

**Goal:** guildmates and party members running OAR share rare sightings (and, opt-in, their locations and gathering nodes), chat gets sorted so the important lines stand out, and a town errand list tells each character what to do while in a city.

**Gate G8:** with a second player (a friend or a second account) in the same guild, each sees the other's rare sightings within five seconds and as a pin; location sharing is off until switched on, and when on shows the other player on the world map; trial accounts don't break anything; chat triage and the errand list work for Torrant.

Limits (FOREVER_CONSTRAINTS C10, C11): addon messages go over GUILD, PARTY, RAID and WHISPER only (CHANNEL is disabled on Classic clients); trial and veteran accounts cannot send; exact positions are only known for party/raid members unless a player chooses to share theirs.

Modules/services: `ns.Comm` (core service), `RareShare`, `LocationShare`, `GatherShare`, `ChatTriage`, `Errands`, `Forecast`, `VersionCheck`.

---

### P8-01 · Comm layer · Claude · deps: P1-04
1. `Core/Comm.lua`: `C_ChatInfo.RegisterAddonMessagePrefix("OAR")`; `ns.Comm:Send(type, payload, channel, target)`, `ns.Comm:On(type, fn)`. Message format in DATA_SCHEMAS.md (versioned, base64 payload, chunked past 250 bytes, reassembled with a timeout).
2. Throttle: token bucket per channel (ChatThrottleLib if present, otherwise our own: about 800 bytes/s burst, lower sustained), priority for small messages.
3. Guard: `IsTrialAccount()` / `IsVeteranTrialAccount()` → receive only; log once.
4. Ignore messages from ourselves, unknown types, newer protocol versions, and senders not in our guild/party/raid for that channel.
5. Specs with a two-client mock (extend wowmock so two `Game`s exchange `CHAT_MSG_ADDON`).

**Done when:** specs pass, including chunking and throttling.

### P8-02 · Version check · Claude · deps: P8-01
1. On login and on joining a group, send `HELLO` (version, build) at most once per 10 minutes per channel. If a peer has a newer version, tell Gary once.
2. Hub Overview lists guildmates and party members with OAR and their versions.

**Done when:** two clients see each other in the list.

### P8-03 · Rare sightings sharing · Both · deps: P8-01, P2-07
1. Module `RareShare` (opt-in per character, guild and/or party): when RareScan sees a rare (alive or dead, deduped), send `RARE` with npcID, mapID, x, y, layer, time, state.
2. Receivers add it to Sightings with `how = "guild"` and `by`, show a toast "Guildie Lumen saw The Rake 2 min ago (your layer)" if it's on their watchlist, and a pin.
3. Layer matters: say whether the sighting is on the receiver's current layer.
4. Trust: only accept from guild/party members; drop sightings with impossible data (bad coords, future times).

**Done when:** Gary and a second player test it in game; under five seconds end to end.

### P8-04 · Location sharing (opt-in) · Both · deps: P8-01, P3-03
1. Module `LocationShare`, off by default, per character, guild only or friends via whisper: send own `LOC` (mapID, x, y, zone) every 30 s while moving, never in instances or battlegrounds, stops when switched off.
2. Show sharing guildmates on the world map with class color and name; party/raid members use Blizzard's own positions.
3. Clear privacy wording in the hub: who can see you, how often.

**Done when:** two players see each other on the map with sharing on, and not with it off.

### P8-05 · Gathering and fishing sharing · Claude · deps: P8-01, P5-13
1. Opt-in sharing of gathering nodes and fishing spots with the guild (low rate, deduped by position).

**Done when:** a node gathered by one player appears for the other.

### P8-06 · Town errand list · Claude · deps: P5-01, P5-02, P4-06, P2-11
1. Module `Errands`: on entering a capital or town, a small list for this character: train (new spell ranks or profession rank available), repair (durability), sell junk, buy ammo (hunter, below threshold), buy reagents (class reagents low), mail (alt handoffs from P6-08), AH shopping list items, bank items needed by queued crafts.
2. Each row has a **Waypoint** button to the right NPC (P3-07).

**Done when:** in Orgrimmar or Thunder Bluff, Torrant sees an accurate list.

### P8-07 · Chat triage · Claude · deps: P7-08
1. Route LFG and trade chatter into their own tab; highlight lines that match keywords (rare names, shopping list items, "LF" + Gary's role, Gary's name); mute repeated spam (same text from the same sender within 60 s).
2. Rules editable per character.

**Done when:** in a busy city chat, highlighted lines match Gary's keywords and spam repeats are collapsed.

### P8-08 · Forecasts · Claude · deps: P8-03, P5-08
1. Respawn forecasts from shared sightings (more observations, better ranges; show the number of observations).
2. Gold forecast from the ledger (gold per hour trend), clearly labeled as an estimate.

**Done when:** forecast panel shows ranges with observation counts.

### P8-09 · Gate G8 · Both · deps: all P8
Run the gate checks with a second player; tick G8.
