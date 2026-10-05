# Goblin Grimoire

A playable 2D dungeon-defense roguelite deckbuilder built in **Godot 4.7 / GDScript**.

**[Play in your browser](https://joeypshell.github.io/goblin-grimoire/)**

The browser game has responsive phone layouts, including iPhone portrait and landscape. Tap a card, then a highlighted target; swipe the hand to reach more cards. Scroll preparation, feeding, and the grimoire with your finger. Combat keeps **End your turn** within reach, and portrait faction tabs show both teams' health. Skill menus use large touch targets and show selected ability descriptions. Rotating preserves the battle and selected card.

Combat shows **YOUR TURN**, each card's acting monster, numeric invader intentions and their targets. Selecting a card keeps those intentions visible and adds its projected effect. Ending your turn visibly walks through monster effects, each invader's action, invader effects, and your fresh hand. Actual HP, block and status changes appear alongside each action. **Skip animation** jumps to the committed result. Preparation, feeding and recovery each explain the next step.

Cards now have painterly goblin illustrations for attack, guard, and healing categories, with their owner, energy cost, and numerical effect visible on the face. Desktop combat stages full-body creatures in the chamber with idle motion, attack lunges, and hit/heal/shield reactions. Playing a card shows a small cosmetic discard flight after its immediate result. The phone hand remains horizontally scrollable; tap a selected card again for its full description. Turn on **Reduce motion** in **Log & rules** to remove cosmetic movement and card fades. See [the art direction and original generation prompts](docs/art-direction.md).

Or download the standalone Windows build from [Releases](https://github.com/joeypshell/goblin-grimoire/releases/latest), extract it, and launch `GoblinGrimoire.exe`.

Defend one chamber with Grub, Nix, and Moss. Read the invading party's intentions, play cards, and consume the abilities of defeated adventurers. Each goblin keeps its own identity, skills, and health. Discover transformations by feeding them; the grimoire records only transformations you actually perform.

## Launch

Open `project.godot` in Godot 4.7 and press **F5** to play, or run:

```sh
godot --path .
```

The browser build requires WebGL 2.0. It uses the Compatibility renderer and a single-threaded export, following [Godot's web export guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html). The web shell follows the visible browser height, excludes iPhone safe areas, and retains readable control sizes on high-density screens. Use a current Safari on iPhone. Saves use Godot's `user://` storage; browser saves belong to the browser profile and site. Native saves live in the platform's Godot application data directory.

## Controls and loop

- Click **New Run** or **Continue**. Inspect the incoming party and choose two available skills per monster.
- Click **Defend the dungeon**, then select a card and a highlighted legal target. Cards resolve immediately. Owned cards require a living owner.
- Click **End your turn** (or press Space) to watch the announced invader actions resolve. You have three energy and draw five cards each turn. Friendly monsters only act through cards. Cards pause during the enemy sequence; **Skip animation** finishes its presentation.
- After victory, choose a body and a recipient, then **Devour & inherit**. One of that adventurer's unknown abilities is rolled randomly, with common abilities more likely. Possible results and their chances are shown before devouring; the saved result appears afterward. You can skip a body. Learned abilities can be selected for the next raid.
- An **Evolve** action appears only for transformations a monster has earned. You can accept it or return to it during preparation.
- Finish feeding to recover 25% of each monster's maximum HP. Clear two raids and a champion at F, then E. Defeating the E champion wins and records promotion to D.
- **Save & title** and **Continue** preserve the current battle or reward phase. **New Run** preserves permanent discoveries.
- **Log & rules** shows the combat record and a saved **Reduce motion** preference. The browser's motion preference supplies the initial setting when no choice has been saved.

No equipment or shops. D through S are data definitions for future campaigns; this version plays F and E only.

## Balance and rules

Edit `scripts/game_data.gd`: `BALANCE` contains energy, hand size, core HP, 25-HP breach damage, recovery, and status tuning. `ABILITIES` defines costs, targets, affinities, rarity, and effects; `INHERITANCE_WEIGHTS` uses common 4, uncommon 2, rare 1. Weights are normalized across the actual corpse's abilities that the recipient does not already know. A lone eligible ability has a 100% chance. `FORMS` defines HP, signatures, passives, and portrait colors. `CLASSES` and `ENCOUNTERS` control coherent seeded parties and difficulty, including permanent armor (warrior 1, defender 2, other classes 0). `RECIPES` stores hidden progression; **reading that developer data reveals discoveries**.

The initial deck has 12 cards: each monster's signature and two selected skills, plus three shared dungeon cards. Friendly knockouts remove every card belonging to that monster for the current battle. Cards cycle through discard and reshuffle; healing has no use cap or exhaustion. Duplicate known abilities cannot be consumed again. Only uniquely consumed abilities count toward a recipe.

Armor reduces each direct hit before temporary Block and is not spent. Block absorbs the remaining damage and expires at the start of its faction's next turn. Poison and burning bypass both Armor and Block and tick at the end of the affected faction's turn; regeneration heals then. Their strength decays by one each tick. Reapplying them adds strength without a hidden limit. Enemy stun skips the next announced action; monster stun prevents owned cards for one player turn per charge. Shared dungeon cards remain available. Evasion prevents the next damaging hit. Armor is visible during preparation, combat and feeding; devouring transfers only an ability. Prior saved actors with no armor field retain armor 0. Knocked-out actors cannot act or receive healing. Evolution preserves health percentage, rounded to nearest HP (a living monster keeps at least 1 HP). Recovery rounds up and revives knocked-out monsters. A breach ends that raid, deducts core HP once, and grants recovery without rewards; a surviving core permits a retry of the same party.

Seeded encounter variations are recorded with the run. Intentions are locked at turn start. If an announced target is knocked out, an enemy redirects to the first living valid target; this rule is shown in combat.

## Architecture and verification

`game_data.gd` is balance/content; `battle.gd` is simulation; `run_state.gd` owns progression, separate run/profile saves, exactly-once rewards and recovery. `main.gd` and focused `ui_*.gd` modules render the interface. `battle_replay.gd` captures the existing turn simulation on an isolated clone; `turn_presentation.gd` presents its immutable snapshots after committing and saving the real turn once. Skipping or reloading cannot apply the actions again. Painterly card illustrations are bundled in `assets/cards/`; original vector creature and chamber art remains part of the prototype. `ui_card.gd`, `ui_battlefield.gd`, `battle_creature.gd`, and `card_fx.gd` handle cosmetic rendering without changing battle or RNG state.

The project bundles Noto Sans and Noto Sans Symbols 2 from [Google Fonts](https://github.com/google/fonts), under their included SIL Open Font Licenses in `assets/fonts/`, so native and browser text match.

Run the checks in a separate test profile:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/mobile_smoke.gd
godot --headless --path . --script tests/flow_smoke.gd
godot --headless --path . --script tests/art_smoke.gd
```

Run `godot --path . --script tests/mobile_smoke.gd` with a graphics display for native screenshots and real Godot touch-event checks. Run `godot --path . --script tests/art_smoke.gd` to capture illustrated card and battlefield views and check cosmetic state, reduced motion, and save continuation. The headless variants check layout and UI actions without rendering PNGs. See [docs/testing.md](docs/testing.md) for checks actually performed, including the limits of iPhone verification. Tests do not erase player saves. The empty-profile reset is a debug API, absent from the game interface.

Export with Godot's matching export templates installed:

```sh
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --export-release Windows build/windows/GoblinGrimoire.exe
```

Serve the web export through HTTP/HTTPS rather than opening its HTML as a local file. The GitHub Actions workflow verifies gameplay, exports the game, and publishes GitHub Pages on each push to `main`. Source and exports remain separate.
