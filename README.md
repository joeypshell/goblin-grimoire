# Goblin Grimoire

A playable 2D dungeon-defense roguelite deckbuilder built in **Godot 4.7 / GDScript**.

**[Play in your browser](https://joeypshell.github.io/goblin-grimoire/)**

The browser game has responsive phone layouts, including iPhone portrait and landscape. Tap a card, then a highlighted target; swipe the hand to reach more cards. Scroll preparation, feeding, and the grimoire with your finger. Combat keeps **End your turn** within reach, and portrait faction tabs show both teams' health. Skill menus use large touch targets and show selected ability descriptions. Rotating preserves the battle and selected card.

Combat shows **YOUR TURN**, each card's acting monster, numeric invader intentions and their targets. Selecting a card keeps those intentions visible and adds its projected effect. Ending your turn visibly walks through monster effects, each invader's action, invader effects, and your fresh hand. Actual HP, block and status changes appear alongside each action. **Skip animation** jumps to the committed result. Preparation, feeding and recovery each explain the next step.

Cards now have painterly goblin illustrations for attack, guard, and healing categories, with their owner, energy cost, and numerical effect visible on the face. Desktop combat stages full-body creatures in the chamber with idle motion, attack lunges, and hit/heal/shield reactions. Playing a card shows a small cosmetic discard flight after its immediate result. The phone hand remains horizontally scrollable; tap a selected card again for its full description. Turn on **Reduce motion** in **Log & rules** to remove cosmetic movement and card fades. See [the art direction and original generation prompts](docs/art-direction.md).

Or download the standalone Windows build from [Releases](https://github.com/joeypshell/goblin-grimoire/releases/latest), extract it, and launch `GoblinGrimoire.exe`.

## v0.12 dungeon loss

**If all three monsters are knocked out, your dungeon is destroyed and the run ends immediately.** There is no separate Core HP pool, defeat recovery or raid retry. The defeat screen preserves the fallen team and offers a new run; grimoire discoveries remain.

An individual knockout still removes that monster's cards for the rest of the fight. Win with at least one survivor, then complete feeding to restore 25% of each monster's maximum HP, bringing knocked-out teammates back. Surviving damage carries forward.

Existing living battles, feeding and completed runs remain loadable. Old saves waiting to retry an already lost raid, including its preparation screen, become terminal defeats. Loading an old full-wipe combat also resolves defeat once. Historical playtest reports retain their original data.

## Unspent energy warning

Ending a turn with any unspent energy opens a warning showing how much remains. Choose **Keep playing** or **End turn anyway**. Opening or cancelling the warning preserves your selected card and battle; zero-energy turns proceed immediately. The End Turn button and Space use the same check. Escape cancels; Tab and Enter select an action from the keyboard.

## v0.11 music pass

The dungeon now has a continuous instrumental soundtrack. **Darkest Child** accompanies the title, preparation and feeding; its faster **var A** plays during raids. Both are by [Kevin MacLeod](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100784), used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Tracks are edited for looping, normalized to matching background levels and fade between contexts. Playing a card, ending a turn or opening a modal keeps the current music position.

Open **Sound settings** on the title or inside **Log & rules** to change music volume or mute it. Muting remembers the chosen volume; both choices are saved on this device independently of your run and motion/speed settings. Browser music starts after your first click, tap or key press, and pauses while the page is hidden. Native music pauses when the app goes into the background. Physical iPhone Safari playback/resume still needs a device check. See [soundtrack credits and preparation](assets/audio/LICENSE.txt).

Defend one chamber with Grub, Nix, and Moss. Read the invading party's intentions, play cards, and consume the abilities of defeated adventurers. Each goblin keeps its own identity, skills, and health. Discover transformations by feeding them; the grimoire records only transformations you actually perform.

After the first raid, choose a **dungeon trait** for the run: spread poison from defeated invaders with **Venom Nest**, turn absorbed attacks into retaliation with **Spiteful Shields**, coordinate all three monsters with **Pack Instinct**, or protect a teammate for extra energy and a draw with **War Drums**. The F champion earns a second, different trait. Preparation shows your next reward and the champion's threat, so you can equip skills and feed toward a plan.

## v0.10 first-act build experiment

Start a new run and play the first three raids to test the protection build. **War Drums** rewards the first owned card each turn that grants Block to another living monster with **1 energy and 1 card draw**. Guard works immediately; self-only and shared dungeon cards do not activate it. The interface shows whether the reward is ready or used, forecasts its payoff on legal targets, and reports its activation after playing.

**Green Ogre** now stores **+10 damage** when it protects another monster, and **Ancient Ogre** stores **+14**. The charge survives turns until the owner's next damaging card, so drawing the attack later no longer wastes the setup. One charge cannot stack; after spending it, the owner can recharge on the following turn. Stored and spent states remain visible and survive Continue. Other forms retain their existing tactics, and unmet transformations stay hidden.

Raid two offers contrasting puzzles at the existing health budgets. **The Iron Company** has a ward captain: a player attack that costs the captain HP without defeating them gives **4 Block** to the other living invader with the lowest HP percentage, after the whole card resolves. Defeating the captain, attacking allies first, or using damage over time changes the plan. **Runebound Pilgrims** has a priest announcing **Renewal Ritual** on rounds **2, 5, 8...** when another invader is wounded. Stun or defeat the priest to interrupt the **9-HP** heal. Its real corpse includes the rare, repeatable two-energy skill in its random inheritance pool, with later raids left to use it.

The campaign still has six raids. This experiment focuses its new encounter rules on the first act; it adds no separate mode or extra fights. Existing generated parties keep their rules and locked intentions. Future parties get the new rules. Healing remains repeatable, inheritance remains weighted randomly among actual unknown corpse abilities, and the deck retains twelve cards.

## v0.9 combat and transformation pass

Regular fights use smaller health budgets and deliberate role patterns. Warriors alternate heavy and light attacks, rogues pursue wounded monsters, and priests mostly attack with a heal opportunity every third round. Their actual next action and target remain locked and visible. The final champion announces **Breach Order** on rounds 2, 5, 8...: it removes Block before hitting the pack, so interrupting her or using Evade matters.

Transformations add a **once-per-turn combo** to their existing signature and passive. Green and Ancient Ogres protect another ally to ready a stronger attack. Red Ogres and Oni attack an already-burning foe to spread fire. Basilisks stun an already-poisoned foe to draw cards. Stalkers exploit an already-afflicted foe to recover energy. Later forms improve these payoffs. Combat shows whether the combo is available, readied or used, and target previews include the payoff. Only earned forms reveal their tactics.

Devoured skills show their cost and effect with explicit **Replace** buttons for the two equipped slots. New abilities include **Shield Bash**, **Quick Jab**, **Ember Burst**, **Shatter Guard** and the final champion's **Breach Order**, inherited only from bodies that possess them. New runs start with Strike and Guard equipped; Patch Up remains available. Core Pulse costs 2 energy and retains its repeatable team healing. Transformation health gains are smaller to put more emphasis on using the combo.

The standard parties introduce Shield Bash on raid 2, Ember Burst at the F champion, Shatter Guard on raid 4 and Quick Jab on raid 5. Those skills are actual possessions in the corpse pool; the recipient still inherits one random unknown skill. Optional alternate parties retain their different meal pools.

**Fast combat** is enabled by default and can be changed in **Log & rules** independently of Reduce motion. It shortens routine presentation while retaining each announced action and result. Existing generated parties and active locked intentions survive Continue; future parties use the new tuning. Start a new run to experience the full pass.

## v0.8 party choices

Before regular raids 2, 4 and 5, **choose which party to lure**. Two comparable parties offer different threats and possible meals. Their real HP, Armor and available affinities help you plan around the dungeon traits and skills you already have. Switch freely during preparation; **Defend the dungeon** locks the selected party through combat and Continue. The first raid and both champions keep their established parties. Devouring still rolls one random unknown ability with the same rarity weights.

The usual party is selected initially, so you can defend immediately. Both candidates are generated once and saved; inspecting or switching cannot reroll them. Existing saves retain an already generated incoming party, then receive choices at future eligible raids.

## v0.7 playtest reporting

**Playtest reports** on the title, results, and **Log & rules** opens collection status, an upload toggle, and a review-dashboard link. Reports record decks, card use, unused energy, raid outcomes, feeding, evolutions, and traits without player identity. Older saves are labelled **partial coverage**; unseen history is not reconstructed. Native builds also offer **Copy current report JSON**. Local storage retains up to ten reports; bounded timelines can trim older events while keeping cumulative recorded totals.

The [review dashboard](https://joeypshell.github.io/goblin-grimoire/dashboard/) provides reviewer sign-in/account creation, full-versus-partial coverage, per-raid results, decks, ordered action context, and JSON downloads. It connects to a separate Supabase Free backend with private reviewer access and confirmed-email requirements. Live database, ingestion, anonymous-access, native upload and mobile browser checks have passed. First-time reviewers choose their own password with **Create a reviewer account**, confirm their approved email, then return and sign in. See [the reporting verification](docs/testing.md#v070-playtest-reporting) and [reporting behavior and limits](docs/run-reports.md).

## Launch

Open `project.godot` in Godot 4.7 and press **F5** to play, or run:

```sh
godot --path .
```

The browser build requires WebGL 2.0. It uses the Compatibility renderer and a single-threaded export, following [Godot's web export guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html). The web shell follows the visible browser height, excludes iPhone safe areas, and retains readable control sizes on high-density screens. Use a current Safari on iPhone. Saves use Godot's `user://` storage; browser saves belong to the browser profile and site. Native saves live in the platform's Godot application data directory.

## Controls and loop

- Click **New Run** or **Continue**. Inspect the incoming party and choose two available skills per monster.
- On raids 2, 4 and 5, compare two incoming parties and choose who to lure. Your current selection is shown above preparation. Starting combat locks that party.
- Click **Defend the dungeon**, then select a card and a highlighted legal target. Cards resolve immediately. Owned cards require a living owner.
- Click **End your turn** (or press Space) to watch the announced invader actions resolve. You have three energy and draw five cards each turn. Friendly monsters only act through cards. Cards pause during the enemy sequence; **Skip animation** finishes its presentation.
- After victory, choose a body and a recipient, then **Devour & inherit**. One of that adventurer's unknown abilities is rolled randomly, with common abilities more likely. Possible results and their chances are shown before devouring; the saved result appears afterward. You can skip a body. Learned abilities can be selected for the next raid.
- An **Evolve** action appears only for transformations a monster has earned. You can accept it or return to it during preparation.
- Finish feeding to recover 25% of each monster's maximum HP. Clear two raids and a champion at F, then E. Defeating the E champion wins and records promotion to D.
- A knockout removes that monster's owned cards for the rest of the fight. A surviving victory brings teammates back through normal recovery. Losing all three monsters ends the run immediately; there are no raid retries.
- After raid one and the F champion, choose a run-wide trait before continuing. Traits have no duplicates and combine for the remaining raids. Continue preserves a pending choice. Older runs receive any missed trait choices at the next safe preparation or recovery boundary.
- **Save & title** and **Continue** preserve the current battle or reward phase. **New Run** preserves permanent discoveries.
- **Log & rules** shows the combat record and a saved **Reduce motion** preference. The browser's motion preference supplies the initial setting when no choice has been saved.

No equipment or shops. D through S are data definitions for future campaigns; this version plays F and E only.

## Balance and rules

Edit `scripts/game_data.gd`: `BALANCE` contains energy, hand size, victory recovery, and status tuning. `ABILITIES` defines costs, targets, affinities, rarity, and effects; `INHERITANCE_WEIGHTS` uses common 4, uncommon 2, rare 1. Weights are normalized across the actual corpse's abilities that the recipient does not already know. A lone eligible ability has a 100% chance. `FORMS` defines HP, signatures, passives, and portrait colors. `CLASSES` and `ENCOUNTERS` control coherent seeded parties and difficulty, including permanent armor (warrior 1, defender 2, other classes 0). `RECIPES` stores hidden progression; **reading that developer data reveals discoveries**.

`scripts/dungeon_traits.gd` defines trait choices, their two reward milestones and player-facing descriptions. Venom Nest spreads a fresh 2-strength poison application when an already poisoned invader dies, including poison-tick deaths. Spiteful Shields retaliates for 3 direct damage after an announced attack finishes, once per surviving monster whose Block absorbed that attack; Armor, Evasion and status damage alone do not trigger it. Pack Instinct counts three distinct monster card owners, excludes shared cards and grants one bonus energy and card draw per turn. Its progress survives saving mid-turn.

`scripts/raid_routes.gd` defines the three alternate class mixes and threat descriptions. They use the same health bonus and three-member size as that raid's original party. Their separate seeded generation leaves the usual party and gameplay RNG unchanged; cached options and the combat lock live in RunState. See [the party-choice verification](docs/testing.md#v080-party-choices).

Captain Torren, the F champion, announces **Banner Volley** every third round: 5 direct damage and 1 burning to every monster. His volley replaces his ordinary action. Defeat him or stun that announced action to cancel it, or prepare team Block and healing. Resolve still prevents consecutive stuns. Banner Volley is a rare Flame ability in his actual corpse pool and can be inherited by the same weighted random rule.

The initial deck has 12 cards: each monster's signature and two selected skills, plus three shared dungeon cards. Friendly knockouts remove every card belonging to that monster for the current battle. Cards cycle through discard and reshuffle; healing has no use cap or exhaustion. Duplicate known abilities cannot be consumed again. Only uniquely consumed abilities count toward a recipe. Preparation and feeding show each monster's consumed affinities; inheritance odds also show each possible skill's affinity. Every first evolution has an advanced branch, while unmet recipes stay hidden.

Armor reduces each direct hit before temporary Block and is not spent. Block absorbs the remaining damage and expires at the start of its faction's next turn. Poison and burning bypass Armor, Block and Evasion and tick at the end of the affected faction's turn; regeneration heals then. Each application decays by one independently, without a use cap: two Poison 3 applications tick for 6, 4, then 2 (12 total), rather than extending a single strength-6 tail. The same rule applies to burning and regeneration. Status labels show the sum due at the next tick. Mend restores 4 HP and removes all poison and burning; Patch Up restores 6 HP. Heavy Blow costs 2 energy for a single 12-damage hit; Shield Wall costs 2 energy for 8 Block per living ally. The evolved area signatures and Petrifying Gaze also cost 2 energy, making timing and energy choices matter.

Stun does not stack. It skips one announced enemy action or one monster's owned-card turn, then grants visible **Resolve** until that actor completes its next normal action or turn. Resolve prevents another stun, so control decks must also defend against intervening actions. Shared dungeon cards remain available during monster stun. Evasion prevents the next direct damaging hit. Armor is visible during preparation, combat and feeding; devouring transfers only an ability. Prior saved actors with no armor field retain armor 0. Knocked-out actors cannot act or receive healing. Evolution preserves health percentage, rounded to nearest HP (a living monster keeps at least 1 HP). After victory, recovery rounds up and revives knocked-out teammates. A full party wipe immediately ends the run, with no recovery or feeding rewards.

Seeded encounter variations are recorded with the run. Each single-target offensive intention chooses a seeded random living monster and stays locked throughout your turn; support healing still selects the lowest-health ally. If an announced target is knocked out, an enemy redirects to the first living valid target; this rule is shown in combat. Priests always possess Arcane Bolt as well as their healing skills, providing offensive pressure when left alive. Continuing an older active party adds that ability to its priests without changing the already announced action or RNG state. Older aggregate-only poison, burn and regeneration saves retain their existing strength as one application; subsequent applications use independent decay.

## Architecture and verification

`game_data.gd` is balance/content; `battle.gd` is simulation; `run_state.gd` owns progression, separate run/profile saves, exactly-once rewards and recovery. `main.gd` and focused `ui_*.gd` modules render the interface. `battle_replay.gd` captures the existing turn simulation on an isolated clone; `turn_presentation.gd` presents its immutable snapshots after committing and saving the real turn once. Skipping or reloading cannot apply the actions again. Painterly card illustrations are bundled in `assets/cards/`; original vector creature and chamber art remains part of the prototype. `ui_card.gd`, `ui_battlefield.gd`, `battle_creature.gd`, and `card_fx.gd` handle cosmetic rendering without changing battle or RNG state.

`run_reports.gd` records authoritative accepted actions in a separate bounded local journal; report queries do not consume gameplay RNG. `report_uploader.gd` tracks upload acknowledgments and retries separately from gameplay saves. The release candidate has its HTTPS ingestion endpoint and public dashboard configuration filled; reviewer access is enforced by database policies.

The project bundles Noto Sans and Noto Sans Symbols 2 from [Google Fonts](https://github.com/google/fonts), under their included SIL Open Font Licenses in `assets/fonts/`, so native and browser text match.

Run the checks in a separate test profile:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/mobile_smoke.gd
godot --headless --path . --script tests/flow_smoke.gd
godot --headless --path . --script tests/art_smoke.gd
godot --headless --path . --script tests/trait_smoke.gd
godot --headless --path . --script tests/party_routes_smoke.gd
godot --headless --path . --script tests/report_core_smoke.gd
godot --headless --path . --script tests/report_upload_smoke.gd
godot --headless --path . --script tests/report_ui_smoke.gd
# Node.js 24 is required for the TypeScript ingestion fixtures.
node tools/test_report_ingest.mjs
```

Run `godot --path . --script tests/mobile_smoke.gd` with a graphics display for native screenshots and real Godot touch-event checks. Run `godot --path . --script tests/art_smoke.gd` to capture illustrated card and battlefield views and check cosmetic state, reduced motion, and save continuation. The headless variants check layout and UI actions without rendering PNGs. See [docs/testing.md](docs/testing.md) for checks actually performed, including the limits of iPhone verification. Tests do not erase player saves. The empty-profile reset is a debug API, absent from the game interface.

Run `godot --path . --script tests/report_ui_smoke.gd` for report-modal screenshots. Ordinary upload tests use a self-contained loopback HTTP server; ingestion fixtures use a mocked backend. Explicitly gated live integration commands and their cleanup scope appear in [docs/testing.md](docs/testing.md#v070-playtest-reporting-connected-release-candidate).

Export with Godot's matching export templates installed:

```sh
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --export-release Windows build/windows/GoblinGrimoire.exe
```

Serve the web export through HTTP/HTTPS rather than opening its HTML as a local file. The GitHub Actions workflow verifies gameplay, exports the game, and publishes GitHub Pages on each push to `main`. Source and exports remain separate.
