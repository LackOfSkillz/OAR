# Macro tricks for Outrider one-button keys (WoW Forever, retail-engine client)

Research date 2026-11-22. Labels: **[retail-doc]** means documented for the modern retail client, so it probably applies to Forever but has not been measured on it. **[Forever-src]** means a Forever-specific web source says so. **[UNCONFIRMED]** means a community report or older client only. Nothing here was tested on Gary's client. Your own measurements (one attempt per press; only "not ready" falls through; `,null` wraps; Auto Shot restart) take precedence over any source.

Main sources:
- MC = https://warcraft.wiki.gg/wiki/Macro_conditionals
- CS = https://warcraft.wiki.gg/wiki/MACRO_castsequence
- MM = https://warcraft.wiki.gg/wiki/Making_a_macro
- RB = https://rankedboost.com/world-of-warcraft/forever/macros/ (Forever list. Its content looks auto-generated in places: a Forever shaman page mentions Riptide. Use it only for "this command exists".)

## 1. Conditionals on the modern client (MC)

**Target selectors:**
- `@unit` (player, target, focus, mouseover, targettarget, pet, pettarget, partyN, ...)
- `@cursor` (ground under the cursor, 7.1+)
- `@none` (forces the targeting cursor, no auto self-cast)
- `target=` is an alias for `@`

**Unit tests (apply to the @ unit, default target):** `exists`, `help`, `harm`, `dead`, `party`, `raid`, `unithasvehicleui`.

**Player tests:**
- `advflyable`, `canexitvehicle`, `channeling[:spell]`, `combat`, `equipped:`/`worn:`, `flyable`, `flying`
- `form:n`/`stance:n`
- `group[:party|raid]`, `indoors`/`outdoors`
- `known:name|spellID` (added 10.0.2, also works with #showtooltip)
- `mounted`, `pet:name|family`, `petbattle`, `pvpcombat`, `resting`, `spec:n[/n2]`, `stealth`, `swimming`

**UI tests:**
- `actionbar:n`/`bar:n`, `bonusbar[:n]`
- `button:n`/`btn:` (mouse button or a virtual click)
- `cursor` (dragging something), `extrabar`, `mod[:key]`
- `overridebar`, `possessbar`, `shapeshift`, `vehicleui`, `house:*` (11.2.7)

**Removed:** `[talent:r/c]` was removed in 10.0.0 (MC).

**Negation:** `no` prefix (`noexists`, `nomod`, `noknown`). Comma means AND, `/` inside a condition means OR, `;` separates clauses, and the first clause that matches wins (MC).

**No aura, health, power or combo-point conditional exists** on the current list (MC). This matches your belief. Blizzard removed "smart" logic in 2.0: a failed spell that would trigger the GCD blocks the later lines (MM).

**Useful for us:**
- `[known:X]` **[retail-doc]**: one macro text works across levels and talent choices. Unlearned spells are skipped instead of failing the press. Biggest win. Check on Forever that `known` accepts the plain name with ranked spells. **[UNCONFIRMED on Forever]**
- `[@mouseover,help,nodead][@target,help,nodead][@player]` heal chain. If there is no mouseover, that clause is simply false and evaluation moves on (MC semantics). **[Forever-src]** RB lists @mouseover, @targettarget, help/harm, dead/nodead.
- `[@targettarget,help,nodead]` heals whoever your enemy target is hitting (RB shaman page).
- `[harm,nodead]` on Fight keys stops a press on a corpse or a friend.
- `[group]` / `[group:raid]` swaps solo and group lines (for example, no taunt solo).
- `[swimming]`, `[indoors]`, `[mounted]`, `[flying]`: travel and form keys.
- `[spec:n]`: only matters if Forever has spec slots or dual spec. **[UNCONFIRMED on Forever]**
- `[pet:Family]` gives hunter pet-family lines. `[btn:2]` gives right-click alternates on a clickable button.

## 2. Slash commands

| Command | Notes | Source |
|---|---|---|
| `/startattack [@unit]` | Targets the unit if needed and starts melee auto-attack. It does **not** restart a swing that is already running, so it is safe to spam. For hunters it is melee, not Auto Shot. | MM |
| `/stopattack` | Stops auto-attack. Useful before sap or polymorph lines. | MM |
| `/petattack [@target,harm]`, `/petfollow`, `/petstay`, `/petpassive` | Exist on Forever | RB |
| `/stopcasting` | Cancels the current cast. Since 2.3 it is not needed between an off-GCD spell and the next cast. Use it only on interrupt or panic keys, never on a spammed key (it would cancel your own cast). | MM |
| `/cleartarget [dead]` + `/targetenemy [noexists]` | Next-target-after-kill. See caveat 5f. | MM, RB |
| `/targetenemy [noharm][dead]` | Single-line version, no ordering issue | MC semantics |
| `/assist [@focus]`, `/focus`, `/targetlasttarget` | All valid | RB |
| `/use 13`, `/use 14` | Trinket slots. `/use <bag> <slot>` also works. A trinket on cooldown does nothing and the macro goes on. | MM; https://us.forums.blizzard.com/en/wow/t/trinket-spell-macro/429887 |
| `/cancelaura Name` | Removes a buff. Out of combat or in combat both fine for most buffs. | MM |
| `/cancelform` | Leaves the form. Druid recognition is instant since 2.3. | MM |
| `/dismount` | Exists | RB |
| `/castrandom a, b, c` | Picks one at random. Rarely useful in combat. | MM |
| `/stopmacro [cond]` | Ends the press. Use it with `[channeling]`, `[noexists]`, `[mounted]`. | MM |
| `/run` | Cannot cast, use, target or change bars. Fine for UI only. | MM |
| `/click Frame` | **Since 11.0.0, a macro cannot /click a button that runs another macro (macro chaining is blocked)**. Clicking a plain secure spell button is not clearly documented. Treat /click as "no extra actions per press". | https://us.forums.blizzard.com/en/wow/t/click-macros-1100/1910312 |
| `#showtooltip` / `#show` (with conditionals) | Sets the icon, tooltip and range/cooldown feedback. Without it the *first* spell in the macro drives the feedback. Lowercase only; use one of the two, not both. | MM |
| `!Spell` | Stops toggling off (Auto Shot, Shoot, Stealth, forms) since 2.3.2. | MM |

**castsequence `reset=`** (CS, MM):
- Options are `N` seconds, `target`, `combat`, `shift`/`ctrl`/`alt`, combined with `/`.
- **The N timer counts from the last press, so spamming faster than N never resets it.** Waiting about one GCD with `reset=1.5`-ish is the known trick to get "restart when I pause". See https://us.forums.blizzard.com/en/wow/t/castsequence-reset-macros-do-not-work-need-help/1341482
- The sequence advances only on a successful cast.
- A TWW-era bug broke `reset=` in macrotext and then in-game macros. It was reportedly fixed in March 2025 (https://us.forums.blizzard.com/en/wow/t/broke-castsequence-resetresets-macrotextin-game-macros-attention-blizzard/2079589). **Verify `reset=target` and `reset=combat` on Forever.**
- RB says sequences also reset on death **[Forever-src, unverified]**.

## 3. Off-GCD stacking

- **Yes.** An instant spell that does not trigger the GCD can be followed by another `/cast` line in the same press. `/stopcasting` between them stopped being needed in 2.3 (MM).
- This applies to off-GCD trinkets, for example `/use 13` then `/cast X` (https://us.forums.blizzard.com/en/wow/t/trinket-spell-macro/429887). A few trinkets are on the GCD and block the next line.
- It also applies to Nature's Swiftness. It is off the GCD (https://warcraft.wiki.gg/wiki/Nature%27s_Swiftness_(Classic_druid_talent)), and the Forever shaman page uses `/cast Nature's Swiftness` then `/cast [...] Healing Wave` (RB shaman: https://rankedboost.com/world-of-warcraft/forever/macros/shaman/restoration/).
- By the same rule, Inner Focus, Arcane Power, Presence of Mind, Bloodrage, Berserking and Blood Fury should work too. **[UNCONFIRMED per spell on Forever: check that each is off GCD in its tooltip or by testing.]**
- **Pitfall:** a trinket cannot be used during a cast. A press inside the spell-queue window can queue the spell without the trinket (https://us.forums.blizzard.com/en/wow/t/trinket-spell-macro/429887).
- **Pitfall:** when the off-GCD spell is on cooldown, its line "fails" with *not ready*. Your measurement says that falls through, which is good: the heal still goes.
- **Pitfall:** an off-GCD line that fails with another refusal (no target, wrong form) ends the press by your measurement. Guard it with conditions, for example `/cast [combat] Bloodrage`.

## 4. Spell queue window

- `SpellQueueWindow` defaults to 400 ms (Options > Combat > "Custom lag tolerance" in retail). A press up to that long before the current GCD or cast ends is queued and fires the moment it ends. Sources: https://maxroll.gg/wow/resources/spell-queue-window and https://us.forums.blizzard.com/en/wow/t/should-i-change-the-spell-queue-window-values/1610621
- Effect on spamming: steady spamming works well, because a press inside the last 400 ms is queued. A press earlier than that is rejected ("not ready"), which is harmless.
- **Danger for castsequence:** a press while casting does nothing (RB), so the sequence does not advance on it. Fine.
- A large window can delay a reactive press (interrupt) that queues behind a cast (same sources).
- Timed presses gain nothing over spam except avoiding the trinket-mid-cast issue above.
- Changing the CVar is Gary's call and a game setting, not addon code. Lowering it to ping+100 is common advice. **[community advice only]**

## 5. Pitfalls

- **a. Castsequence with cast-time spells interrupted by movement or pushback:** the step did not succeed, so the sequence does **not** advance and the next press retries it. CS: "doesn't advance until the current action is performed successfully". No source covers movement interrupts specifically. **[UNCONFIRMED edge case: whether a cast that *started* then got interrupted counts]**
- **b. Not enough mana in a castsequence:** that step stalls the sequence. Each press retries it, and the press ends (not "not ready"), so lines below it do not run (CS, MM: "a failed entry stalls the sequence"). Put mana-hungry sequences *below* cheap fallbacks, or accept the stall.
- **c. "Out of range" on the first line:** this is not a cooldown refusal, so by your measurement it ends the press. Guard range-limited lines with the target conditions you can test (`harm`, `exists`). Range cannot be tested by a conditional (MC has no range condition).
- **d. @mouseover with no mouseover:** the clause is false and evaluation moves to the next clause. Always end with `[@target]` or `[]` as the fallback (MC).
- **e. Auto self-cast:** a helpful `/cast` with no valid friendly target goes on you when the "Auto Self Cast" interface option is on. `@none` disables that (MC). The Alt self-cast key only applies to bare action-bar buttons. Inside macros `[mod:alt]` is read as a condition, but if Gary binds Alt+key separately, that binding wins over the macro's modifier (RB).
- **f. Conditions evaluated once per press (11.0+):** players report that from 11.0 conditionals are evaluated at the start of the press, so `/cast [noform] Cat Form` followed by `/cast [form:3] Shred` will not do both in one press (https://us.forums.blizzard.com/en/wow/t/evaluation-of-condition-change-mid-macro-no-longer-working/1905474). No blue post confirms it. **[UNCONFIRMED; test on Forever]** The same may apply to `/cleartarget [dead]` + `/targetenemy [noexists]`. Use the single-line `/targetenemy [noharm][dead]` instead.
- **g.** A reactive spell that is "not usable" (Overpower with no dodge) gives a refusal other than "not ready", so by your measurement it ends the press. That is why last place is right.

## 6. Class tricks (vanilla-style)

- **Warrior stance dance:** `/cast [stance:1] Overpower; Battle Stance`. One press swaps stance (off the GCD), the next press casts, because of pitfall 5f. Similarly `/cast [stance:3] Berserker Rage; Berserker Stance`. `stance:n` counts the stances you know, from the left (RB). Rage loss on swap is a game mechanic (Tactical Mastery). Charge or Intercept chosen by `[nocombat]`/`[combat]` (RB).
- **Hunter Auto Shot:**
  - `!` stops the toggle-off (MM).
  - Your measurement says re-sending restarts the shot. Community Classic notes say a re-press inside about 0.5 s of the swing end is what clips (https://us.forums.blizzard.com/en/wow/t/tbc-possible-working-revamped-hunter-macro/1203267) **[anecdotal]**.
  - So put `/cast !Auto Shot` only on a key that is not spammed (pull or start key), or guard it with `[nocombat]`.
  - Steady-Shot-style `reset=<weapon speed>` tricks depend on TBC Steady Shot, which Forever probably lacks.
  - `/petattack [@target,harm]` on the same press is free (not a spell).
- **Rogue:** `/cast [stealth] Cheap Shot; Sinister Strike` (RB). Same pattern for Ambush/Garrote.
- **Druid powershift:** `/cancelform` then `/cast !Cat Form` is the classic powershift. Because of 5f it may need `/cast [noform] !Cat Form; ...` across 2 presses. `!` stops the toggle back out. **[UNCONFIRMED on Forever]** Moonkin `/cancelform [form:5]` then a heal is on RB.
- **Mage:** `/stopcasting` then `/cast Counterspell` on a dedicated interrupt key (MM pattern). PoM or Arcane Power before a spell is off-GCD stacking (section 3).
- **Priest:** `/cast Inner Focus` then `/cast [@mouseover,help,nodead][] Greater Heal`. Inner Focus is off the GCD in Classic. **[confirm on Forever]**
- **Warlock:** `/cast [@pettarget,exists] Spell` for pet abilities, plus `/petattack`. Pet-bar spells are cast by name like normal `/cast`. **[UNCONFIRMED on Forever]**
- **Shaman totems:** `/castsequence reset=combat/target Searing Totem, Strength of Earth Totem, ...` Each totem goes on a successful drop, and it stalls on no mana (5b). Earth Shock interrupt on `@focus` (RB).
- **Paladin seal twisting:** it is ordinary key presses using game timing, so it is legal (no automation). Whether the Forever mechanic still allows the twist is **[UNCONFIRMED]**. No source found.

## 7. Recommended additions, ranked (all < 255 chars)

1. **`[known:]` guards on every optional line**, so one macro text survives levelling and talent changes.
   `/cast [known:Bestial Wrath,combat] Bestial Wrath`
   `/cast [harm,nodead] Raptor Strike`
2. **Off-GCD cooldowns stacked on the Fight key, guarded by `[combat]` and `[known:]`.** A cooldown that is not ready falls through, by your measurement.
   `/cast [combat,known:Berserking] Berserking`
   `/use [combat] 13`
   `/cast [harm,nodead] Mortal Strike`
3. **Heal target chain** (mouseover, friendly target, enemy's target, self) on every Heal key.
   `/cast [@mouseover,help,nodead][@target,help,nodead][@targettarget,help,nodead][@player] Flash Heal`
4. **Swiftness-style instant heal key:** `/cast Nature's Swiftness` then `/cast [@mouseover,help,nodead][@player] Healing Wave`. Inner Focus and Greater Heal work the same way.
5. **Corpse and friend guard plus next target** on Strike or Fight:
   `/targetenemy [noharm][dead]`
   `/startattack`
   `/cast [harm,nodead] Sinister Strike`
   The `/targetenemy` line is a separate non-spell command, so check that it does not end the press. **[test]**
6. **Pet follows the press** (hunter, warlock): `/petattack [@target,harm,nodead]` at the top of Fight. It is free and fires every press.
7. **Stance or form fallbacks** as the last clause: `/cast [stance:1] Overpower; [stance:2] Revenge; Battle Stance`, so a press in the wrong stance fixes the stance instead of failing.
8. **castsequence `reset=combat/target`** on DoT sequences, so a new target restarts the DoTs. Do not rely on `reset=N` while spamming.
9. **`/stopmacro [channeling]`** at the top of channel keys (you already do this). Add `[mounted]` too: `/stopmacro [channeling][mounted]`.

### What to measure on Forever first
1. `[known:]` with ranked spell names.
2. Whether a failed `/targetenemy` or `/use 13` (no trinket) ends the press.
3. Whether conditions re-evaluate mid-press (5f).
4. That `reset=target` and `reset=combat` work.
5. Inner Focus, Bloodrage and Berserking are off GCD and fall through.
