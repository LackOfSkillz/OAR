# Phase 5: Professions, auctions and fishing

**Goal:** one place that knows every character's bags, bank and recipes, plans crafting and Merchant's Favor crates around what you already own, gets prices from Auctionator/TSM (or a light scan of its own), makes posting and buying faster without automating it, and turns fishing into one key from cast to cooking pot.

**Gate G5:** shopping list for a chosen craft shows the right missing materials across two characters; a Favor crate shows how to fill it from bags/bank/alts; prices appear in tooltips from the installed auction addon; a 15-minute fishing session logs every catch; every buy, post, craft and cast is Gary's click.

Rule for the whole phase (from the blueprint): crafting needs the profession window open, and every buy, post and craft is one click by Gary. Nothing runs from a timer or event.

Modules: `Inventory`, `Professions`, `CraftQueue`, `Favor`, `Prices`, `AuctionatorBridge`/`TSMBridge`, `AuctionHelper`, `Ledger`, `Merchant`, `Mailbox`, `Fishing`, `Gathering`.

---

### P5-01 · Inventory across characters · Claude · deps: P1-04
1. Module `Inventory` (all classes): bags on `BAG_UPDATE_DELAYED` (throttled), bank on `BANKFRAME_OPENED`/`PLAYERBANKSLOTS_CHANGED`, equipped items, mailbox attachments seen on `MAIL_INBOX_UPDATE`, money. Store `ns.db.global.inventory[charKey] = { bags = {[itemID]=count}, bank = {...}, mail = {...}, money, at }`.
2. Tooltip line on items: "You have 12 (Torrant 8 bags, Lumen 4 bank)". Shift shows the full breakdown.
3. Specs for counting and merging.

**Done when:** tooltip on Light Leather shows counts from two characters after Gary opened the bank on each once.

### P5-02 · Profession scanner · Claude · deps: P0-08
1. On `TRADE_SKILL_SHOW` / `CRAFT_SHOW` (Classic enchanting) and their update events, record per character: profession, skill/max, known recipes with reagents (Classic `GetTradeSkillInfo`/`GetTradeSkillReagentInfo` or modern `C_TradeSkillUI` per probe), and whether the next rank is trainable now (Forever lets you train the next rank as soon as you have the skill).
2. Store per character; fill the `recipe` data kind from what is seen (so the pack grows from play).
3. Rank-ready alert: once per rank, "Torrant can train Journeyman Leatherworking" (also feeds the P8 errand list).

**Done when:** opening Leatherworking and First Aid on Torrant records recipes; log shows counts.

### P5-03 · Craft queue and shopping list · Claude · deps: P5-01, P5-02
1. Queue crafts (recipe × count) from the profession window or the hub. Missing materials = needed − (bags + bank + alts, alt items shown separately because they need mail).
2. Shopping list opens at the AH (and at vendors that sell any of it), one row per item with count and best known price. Each purchase is Gary's click.
3. Specs: reagent math with partial stocks and alts.

**Done when:** queue 5 crafts, list matches a hand count; buying at the AH ticks items off.

### P5-04 · Skill-up planner · Claude · deps: P5-02, P5-06
1. For the current skill, rank recipes by cost per expected skill point (orange 1.0, yellow ~0.5 to 0.75 by distance to green, green ~0.25; label these as estimates) using prices and what you already own.
2. "Cheapest route to N": greedy plan using owned materials first.

**Done when:** plan shows for Gary's profession; numbers sanity-checked by Gary.

### P5-05 · Prices · Claude · deps: P0-08
1. `ns.Prices:Get(itemID)` with sources in order: Auctionator API (`Auctionator.API.v1.GetAuctionPriceByItemID(callerID, itemID)`), TSM (`TSM_API.GetCustomPriceValue("DBMarket", "i:" .. itemID)`), our own history, vendor price (`ItemInfo().sellPrice`). Bridges are modules with `requires`; each checks the API exists inside pcall.
2. Own history only when neither addon exists: record prices from AH search results Gary views (`AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` / Classic `AUCTION_ITEM_LIST_UPDATE`), keep min buyout per day for 14 days.
3. Tooltip line: AH value and vendor value, with a warning when AH value is below vendor value (Forever cut many crafted vendor prices, so vendor is not a safe floor).

**Done when:** tooltips show prices from whichever source exists on Gary's setup; the log names the source.

### P5-06 · Merchant's Favor planner · Both · deps: P5-01, P5-05
Forever-specific: Waylaid Crates filled with one full stack of one bundle, turned in at Durotar Supply and Logistics (Horde) or the Azeroth Commerce Authority (Alliance); Favor is per character and buys recipes (30 to 360), some needing Friendly or Honored.
1. Probe and record how Favor appears in the API (currency? reputation? item?) the first time Gary visits the quartermaster; write it to PROBE_RESULTS.md. Build on whatever exists.
2. Per character: Favor balance, which crates can be filled right now from bags/bank/alts, cheapest way to fill each (own stock, buy materials, buy a filled crate), recipes to buy next with reputation needed.
3. Data pack `Data/Favor.lua` for crate contents and recipe costs, from cited sources, `verified = false` until seen.

**Done when:** Gary's Favor balance shows; one crate plan matches what he can actually fill.

### P5-07 · Auction helper · Claude · deps: P5-05
1. Posting suggestions in the sell tab: undercut rule set once (by copper or percent), floor = craft cost + AH cut + deposit, warning before posting under vendor value, crate-sized stacks suggested for raw materials. Each post is Gary's click on Blizzard's (or Auctionator's) post button; we only pre-fill price where the API allows it out of a click.
2. Undercut watch: on AH open, list Gary's auctions that were undercut (from owned auctions + latest prices), one click per repost.
3. Deposit sanity check: warn when deposit > likely profit.
4. If Auctionator or TSM is loaded, put our suggestions in our own small panel next to theirs instead of touching their frames.

**Done when:** Gary posts three items using the suggestions and sees the undercut list next visit.

### P5-08 · Ledger · Claude · deps: P5-05
1. Record sales, purchases, fees and expired auctions from mail and AH events; profit per profession, gold per hour per session.
2. Session loot value: items looted this session × current price.

**Done when:** after a selling session the ledger totals match Gary's gold change within fees.

### P5-09 · Merchant helper · Claude · deps: P5-05
1. At a vendor: **Sell junk** button (greys, plus items Gary marked junk) and **Repair** button (shows cost; guild repair if allowed). One click each. No auto-sell on open.
2. Vendor floor check before selling non-grey items (AH value higher? say so).
3. Record the vendor's item list for the gear advisor and the "sells ammo/food" POI tags.

**Done when:** Gary sells junk and repairs with two clicks; vendor list recorded.

### P5-10 · Mailbox collect · Claude · deps: P5-08
1. **Collect all** button at the mailbox: takes money and items one mail at a time on Gary's click, continues on the next click if the client throttles (no timers that take mail on their own), skips COD mail.
2. Ledger reads AH sale mails as they are opened.

**Done when:** Gary collects ten AH mails with a few clicks; COD mail untouched.

### P5-11 · Fishing: one key · Both · deps: P1-05
1. Module `Fishing`: when a fishing pole is equipped (or fishing mode is on), Gary's chosen key (or double right-click, setting) casts Fishing; when the bobber is out, the same key interacts with it. Implementation: secure override binding to a secure button set out of combat (`SetOverrideBindingClick`), bobber interaction via the client's interact-with-target/mouseover keybinding if Forever has the modern "Interact Key" (probe), otherwise clicking the bobber stays manual. Every cast and hook is a key press.
2. If the pole has no lure (`GetWeaponEnchantInfo`), the first press applies the best lure in bags instead of casting.
3. Loud splash: while fishing, raise SFX volume and lower music/ambience (CVars), restore after. Out of combat only.

**Done when:** Gary fishes with one key for 5 minutes; the sound restores afterwards. Note in DECISIONS how bobber interaction works on Forever.

### P5-12 · Fishing: gear, log, cooking · Claude · deps: P5-11, P5-01
1. Fishing outfit: save pole/hat/boots once; **Gear up** / **Gear down** buttons (out of combat, `EquipItemByName` on click).
2. Catch log: `LOOT_OPENED` while fishing records item, zone, subzone, time; per-spot observed odds; Forever's new fish as a collection.
3. Cook what you caught: recipes the catch feeds (from P5-02), skill-ups available, and the reminder that cooked food gives 5% kill experience in Forever.
4. Fish to gold: session catch valued with P5-05 prices.
5. Bait and Tackle reminders: camp items craftable from the fishing menu that Gary is missing.

**Done when:** after a session, the log lists catches by zone with counts and value.

### P5-13 · Gathering map · Claude · deps: P3-03
1. Record herb and mining nodes when gathered (loot source GUID of type GameObject gives the node type id; position = player position). Include Forever's new herbs.
2. Pins on map and minimap (P3 renderer), filters per node type, "scarce" flag for rare nodes.
3. Guild sharing later via P8.

**Done when:** gathered nodes show as pins in the right places.

### P5-14 · Gate G5 · Both · deps: all P5
Run the gate checks; tick G5.
