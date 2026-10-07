The original request is archived below. The user's October 5, 2026 correction supersedes its manual inheritance choice: choose only the body and recipient, then roll one unknown actual ability with common/uncommon/rare weights 4:2:1. The approved balance follow-up adds varying card costs, independently decaying status applications, visible Resolve after stun, varied locked offensive targets, priest offense, and advanced branches for each first evolution. The approved next prototype adds three dungeon traits, a choice after the first raid and the F champion, visible reward milestones, and Captain Torren's announced every-third-round volley. These choices are intended to test build anticipation and replay interest; engagement has not been established by simulation. Healing remains repeatable. The current implementation shows permanent Armor separately from temporary Block; devouring transfers only an ability. Current rules and validation are documented in README.md and docs/testing.md.

Build a playable 2D dungeon-defense roguelite deckbuilder called **Goblin Grimoire** (working title). Implement it, run it, and verify the complete gameplay loop. Do not stop at a design document, scaffolding, or disconnected screens.

Inspect the repository and its instructions first. Preserve an existing engine and working project. For an empty repository, use Godot 4.x with GDScript and the available compatible engine version. Make reasonable implementation choices and continue without asking about routine details. Document assumptions and editable balance values.

## 1. Core concept and first-version scope

The player controls a dungeon. Every run starts at dungeon rank F with three named, lowly goblins. Adventurer parties invade to rob the treasure and destroy the dungeon. Defeated adventurers can be consumed by a chosen monster to inherit an actual ability they possessed. Combinations of absorbed abilities unlock branching evolutions into creatures such as Green Ogres, Red Ogres, and Basilisks. Those creatures can evolve again.

The central loop is: inspect an incoming party, select monster abilities, fight using cards, feed defeated adventurers to monsters, discover evolutions, recover some health, and face a stronger raid.

Keep the first version focused:

- Use one defensive combat chamber with three monsters against an adventurer party. Multi-room navigation and dungeon construction are future extensions.
- Player attacks and special actions come from cards; there are no automatic friendly attacks.
- Build a complete F-and-E-rank campaign: two regular raids and one champion raid per rank. Defeating the E champion wins the prototype and records promotion to D.
- Make rank definitions extensible to F, E, D, C, B, A, and S, without pretending the unimplemented ranks are playable.
- Include enough content to discover several first evolutions and at least one advanced evolution during this campaign.
- No equipment inventory, equipping items, selling, shops, crafting economy, or material collection in this version. Focus on absorbed abilities.
- Individual knockouts are temporary if the remaining monsters win. Losing the whole team destroys the dungeon and ends the run immediately.
- Healing is repeatable. Do not add Exhaust, once-per-raid healing, anti-stall timers, escalating punishment for healing, or diminishing healing returns.

## 2. Monsters and deck construction

Start with three distinct named goblin instances. Give each its own health, current form, consumed-ability history, learned abilities, selected combat cards, and feeding count.

Starting balance defaults:

- Three goblins with 20 maximum HP each.
- Three energy and a five-card hand each player turn.
- Twelve-card starting deck: three cards contributed by each monster plus three shared dungeon cards.

Each monster contributes its current form’s signature card and two selected learned/basic ability cards. Starting goblins have neutral basic cards so the initial deck functions immediately. Basic starting skills and native species skills do not satisfy consumption-based evolution requirements.

Absorbing an ability adds it to that monster’s available skill collection. Let the player select it for the next raid immediately. Do not automatically add every learned ability to the active deck. Learned skills persist through evolution; omit a separate learned-skill cap and replacement system for this prototype.

Card instances must retain their owning monster ID even when several goblins know the same ability. Shared dungeon cards have no monster owner.

If a monster is knocked out, temporarily remove its owned cards from the current combat hand and draw/discard circulation. Its learned abilities and selected deck configuration remain intact and are restored for the next raid. Avoid empty-deck or draw-loop softlocks.

## 3. Turn-based combat

Show enemy intentions before the player acts. Lock those intentions for the turn so selecting cards cannot reroll enemy decisions.

The player draws, gains energy, selects a card, selects a legal target, and sees its cost and projected direct effect. Resolve played cards immediately and place them in the discard pile. On End Turn, discard unused cards, resolve surviving adventurers’ announced actions and appropriate status effects, and begin the next turn if combat continues.

Define and consistently apply timing for block expiration, poison, burning, healing over time, stun, and death. Defeated actors cannot complete pending actions. Use bounded, deterministic effect resolution.

Targeting is relative to the acting faction. An adventurer’s Mend heals adventurer allies; the inherited version heals monster allies. The same underlying ability definitions should support both uses where practical.

Use readable party positions and targeting rules such as frontline, lowest-health ally, or selected target. Preview intended targets. Support attacks, block, direct healing, regeneration, damage-over-time effects, and a simple control effect.

Healing cards cycle through the normal discard and reshuffle process and can be used repeatedly in the same raid. Regeneration can be reapplied according to its clearly stated stacking/refresh rule. Never impose a hidden usage limit. Let players choose recovery turns rather than automatically attacking.

Win when every adventurer is defeated. If all monsters are knocked out, immediately end the run in defeat. There is no separate dungeon health pool or retry. Failed raids provide no feeding rewards or recovery. Successful raids advance progression.

## 4. Health and recovery

Monster health persists between raids. There is no full heal just for starting another battle.

After each successful raid and its reward/feeding phase, restore ceil(25% of maximum HP) to every monster, capped at maximum HP. A knocked-out monster starts this recovery at zero and returns with that same amount. Retain its form and learned abilities. A full party wipe ends the run before feeding or recovery.

Example: a 20-HP goblin finishing at 6 HP recovers to 11; a knocked-out one recovers to 5.

Apply recovery exactly once per won raid, including after loading a save. Clear temporary battle statuses before the next raid.

When evolution changes maximum HP, preserve current health percentage, rounded consistently; do not fully heal the monster. A knocked-out monster remains at zero until normal post-raid recovery.

Keep recovery percentage, healing amounts, costs, and enemy scaling in editable balance data.

## 5. Adventurers, feeding, and randomized abilities

Generate coherent adventurers from class templates plus randomized abilities. Use a seeded RNG and record the run seed.

Include warrior, defender, rogue, mage, priest, and controller-style adventurers. Their actual combat abilities must match the abilities offered when consumed. Use class-specific pools with some variation rather than arbitrary combinations.

After a successful raid, show each defeated adventurer and its transferable abilities. For each body:

- Choose one recipient monster.
- Preview the actual unknown transferable abilities and their weighted odds (common 4, uncommon 2, rare 1).
- Confirm consumption once.
- Roll one unknown ability randomly, add it to the recipient and immediately evaluate evolution eligibility. The player cannot choose the inherited ability.

One body can be consumed once, by one monster, for one ability. The recipient is independent of who landed the killing blow. Allow feeding any roster monster, including one knocked out during the raid. Do not permit duplicate reward claims.

Make reward abilities selectable and useful even when they cause no evolution. Prevent duplicate copies of the same known ability from falsely satisfying distinct-ability requirements. If all offered abilities are already known to the chosen monster, allow choosing another recipient or skipping that body.

Use controlled introductory encounter generation so the first few victories provide several plausible evolution combinations. The tutorial must not reveal recipes or prescribe which monster to feed.

## 6. Hidden evolution system

Store evolution requirements in data, not giant UI conditionals. Each recipe specifies source form, absorbed affinity requirements, minimum feeding count, and resulting form.

Illustrative first recipes:

- Goblin + Might + Guard → Green Ogre.
- Goblin + Might + Flame → Red Ogre.
- Goblin + Venom + Control → Basilisk.
- Goblin + Trickery + Mystic → Shadow Stalker.

Examples of transferable abilities and affinities:

- Heavy Blow: Might.
- Shield Wall: Guard.
- Firebolt: Flame.
- Poisoned Blade: Venom.
- Snare: Control.
- Smoke Step: Trickery.
- Arcane Bolt: Mystic.
- Mend and Regrowth: Vitality.

Several abilities may provide the same affinity. Count affinities from abilities actually consumed by that individual, whether currently selected for its deck or not. Do not count starter abilities or an ability twice. Require at least two feedings for a first evolution.

Implement at least two later branches, such as Red Ogre + Mystic → Oni and Basilisk + Flame → Ember Basilisk, with an appropriate later feeding threshold such as four total feedings.

Evaluate after feeding. Reveal currently eligible transformations at that point; allow choosing among them or declining. A declined, already-earned transformation remains available through an Evolve action during preparation. Do not display unmet requirements, nearby possibilities, future branches, locked silhouettes, or undiscovered evolution names anywhere in normal gameplay.

Evolution changes appearance, base attributes, innate passive, signature-card options, and later lineage possibilities. It preserves the monster’s identity and all learned abilities. Each form must offer a mechanically meaningful difference, not only larger stats. For example:

- Green Ogre protects allies and benefits from blocking.
- Red Ogre spreads burning through cleaving attacks.
- Basilisk combines poison and control.
- Shadow Stalker uses evasion and ambushes.

Only record an evolution as discovered when the player actually performs it. Resolve at most one transformation per feeding action to avoid unexpected automatic chains.

## 7. Grimoire and saving

The grimoire starts genuinely empty on a new profile. Show no undiscovered entries, silhouettes, recipe hints, or completion counters that enumerate hidden forms.

After an evolution is performed, permanently record the discovered form, its appearance, abilities, source form, and actual recipe requirements. It should help the player reproduce a discovery in a later run. Record only known information.

Keep permanent grimoire data separate from current-run data. New Run resets the team to three goblins, rank, and current progression while preserving discoveries. Provide a clearly separate debug-only reset for testing an empty profile.

Support New Run and Continue. Save the seed/RNG state, monster identities and health, learned and selected abilities, evolution state, rank/raid progress, and any partially completed reward phase. Save after feeding/evolution decisions and between raids. Reloading must not reroll rewards, allow reconsuming a body, or duplicate recovery.

## 8. Playable presentation

Create a coherent, readable game interface:

- Title screen with New Run, Continue when available, and Grimoire.
- Preparation screen for the three monsters and their selected abilities.
- Incoming-party preview.
- Combat with clear portraits, health, block/statuses, intentions, owned cards, costs, legal target feedback, energy, deck/discard counts, and End Turn.
- Feeding screen with actual defeated adventurers and their abilities.
- A satisfying evolution reveal.
- Raid results, promotion, victory, and defeat.
- Discovered-only grimoire entries.

Use a restrained fantasy dungeon style with distinct silhouettes and colors for each form. Simple original placeholder art is acceptable, but the interface must feel usable and deliberate. Add lightweight feedback for damage, healing, card play, feeding, and transformation. Keep text legible at 1280×720 and avoid overlapping or clipped controls. Provide background music with saved volume and mute settings, including mobile gesture-based playback.

## 9. Implementation and verification

Use data-driven definitions for abilities, affinities, forms, recipes, enemy classes, encounters, and ranks. Separate simulation, persistent state, and presentation. Use stable IDs and signals/events instead of tightly coupling every screen.

Keep scripts focused, preferably around 250–500 lines; refactor before any script approaches 1,000 lines. Follow repository-specific rules. Avoid building a generalized framework beyond what this game needs.

Build in working increments, but finish the integrated loop before stopping. Add meaningful automated or headless checks for:

- Legal card targeting, energy, drawing, discard, and reshuffling.
- Repeatable healing in the same raid.
- Knockouts, owner-card removal, immediate run defeat on a full wipe, and exactly-once victory recovery.
- Consuming actual generated enemy abilities once.
- Per-monster evolution eligibility and retention of abilities.
- Hidden/discovered grimoire behavior.
- Save/load without duplicate rewards or recovery.

Run the project and fix runtime errors. Verify a normal first raid, feeding, a first evolution, a later evolution, promotion, immediate run defeat, and restarting with retained discoveries. Verify living old saves preserve their exact combat and RNG, while old pending retry saves become defeats. Use a separate test profile or debug seed to exercise rare cases without revealing them to normal players.

## 10. Next design experiment

Use the first three raids as a short build test before adding content. Raid one introduces the team and earns a trait. Raid two offers contrasting threats and actual corpse abilities that can support the player's build. The first champion should test that build with a short, readable danger-and-payoff cycle.

Compare intent-aware plays with random legal plays using the same initial seeds and reward policy. Record first-act completions, turns, card plays and losses; later draws and inheritance can diverge with different decisions, so these are bounded diagnostics rather than human win rates. If random play clears as easily, increase tactical pressure in the existing fights without extending their health budgets.

The combat banner counts down to the champion's predictable Banner Volley. Charged attacks explicitly show their numerical attack bonus separately from actual HP damage. A short victory recap records earned Bulwark charges, trait activations and team HP before recovery; it survives Continue and does not fabricate missing history for older saves. Use only earned forms and known skills; keep undiscovered recipes hidden. The next human playtest should compare two earned traits through the first champion and ask whether protection, enemy intentions and possible meals changed decisions, and whether the recap makes those payoffs satisfying.

The approved v0.14 experiment narrows the first reward to two randomly selected existing traits, generated once from an independent seed stream and saved. Continue preserves the offers; the F champion still offers all unowned traits. Record offers alongside choices. Test whether different first offers change feeding, equipped skills and combat decisions before expanding traits or changing reward timing. Body inheritance remains weighted random, and current trait effects, the fixed deck and the six-raid campaign remain in place.

Deliver the runnable project, a concise README with launch instructions and controls, and a short description of balance/data locations and what you actually tested. If the environment cannot launch Godot, complete the available validation and state that limitation accurately.
