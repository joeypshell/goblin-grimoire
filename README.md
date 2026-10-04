# Goblin Grimoire

A playable 2D dungeon-defense roguelite deckbuilder built in **Godot 4.7 / GDScript**.

**[Play in your browser](https://joeypshell.github.io/goblin-grimoire/)**

Or download the standalone Windows build from [Releases](https://github.com/joeypshell/goblin-grimoire/releases/latest), extract it, and launch `GoblinGrimoire.exe`.

Defend one chamber with Grub, Nix, and Moss. Read the invading party's intentions, play cards, and consume the abilities of defeated adventurers. Each goblin keeps its own identity, skills, and health. Discover transformations by feeding them; the grimoire records only transformations you actually perform.

## Launch

Open `project.godot` in Godot 4.7 and press **F5** to play, or run:

```sh
godot --path .
```

The browser build requires WebGL 2.0. It uses the Compatibility renderer and a single-threaded export, following [Godot's web export guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html). Saves use Godot's `user://` storage; browser saves belong to the browser profile and site. Native saves live in the platform's Godot application data directory.

## Controls and loop

- Click **New Run** or **Continue**. Inspect the incoming party and choose two available skills per monster.
- Click **Defend the dungeon**, then select a card and a highlighted legal target. Cards resolve immediately. Owned cards require a living owner.
- Click **End Turn** to resolve the announced enemy actions. You have three energy and draw five cards each turn. Friendly monsters only act through cards.
- After victory, choose a body, a monster, and one actual adventurer ability to consume, or skip that body. Learned abilities can be selected for the next raid.
- An **Evolve** action appears only for transformations a monster has earned. You can accept it or return to it during preparation.
- Finish feeding to recover 25% of each monster's maximum HP. Clear two raids and a champion at F, then E. Defeating the E champion wins and records promotion to D.
- **Save & title** and **Continue** preserve the current battle or reward phase. **New Run** preserves permanent discoveries.

No equipment or shops. D through S are data definitions for future campaigns; this version plays F and E only.

## Balance and rules

Edit `scripts/game_data.gd`: `BALANCE` contains energy, hand size, core HP, 25-HP breach damage, recovery, and status tuning. `ABILITIES` defines costs, targets, affinities, and effects; `FORMS` defines HP, signatures, passives, and portrait colors. `CLASSES` and `ENCOUNTERS` control coherent seeded parties and difficulty. `RECIPES` stores hidden progression; **reading that developer data reveals discoveries**.

The initial deck has 12 cards: each monster's signature and two selected skills, plus three shared dungeon cards. Friendly knockouts remove every card belonging to that monster for the current battle. Cards cycle through discard and reshuffle; healing has no use cap or exhaustion. Duplicate known abilities cannot be consumed again. Only uniquely consumed abilities count toward a recipe.

Block expires at the start of its faction's next turn. Poison and burning bypass block and tick at the end of the affected faction's turn; regeneration heals then. Their strength decays by one each tick. Reapplying them adds strength without a hidden limit. Enemy stun skips the next announced action; monster stun prevents owned cards for one player turn per charge. Shared dungeon cards remain available. Evasion prevents the next damaging hit. Knocked-out actors cannot act or receive healing. Evolution preserves health percentage, rounded to nearest HP (a living monster keeps at least 1 HP). Recovery rounds up and revives knocked-out monsters. A breach ends that raid, deducts core HP once, and grants recovery without rewards; a surviving core permits a retry of the same party.

Seeded encounter variations are recorded with the run. Intentions are locked at turn start. If an announced target is knocked out, an enemy redirects to the first living valid target; this rule is shown in combat.

## Architecture and verification

`game_data.gd` is balance/content; `battle.gd` is simulation; `run_state.gd` owns progression, separate run/profile saves, exactly-once rewards and recovery. `main.gd` and focused `ui_*.gd` modules render the interface. Original vector portraits and chamber art require no asset downloads.

The project bundles Noto Sans and Noto Sans Symbols 2 from [Google Fonts](https://github.com/google/fonts), under their included SIL Open Font Licenses in `assets/fonts/`, so native and browser text match.

Run the checks in a separate test profile:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/test_runner.gd
```

See [docs/testing.md](docs/testing.md) for the checks actually performed. CI repeats headless verification on main and pull requests. Tests do not erase player saves. The empty-profile reset is a debug API, absent from the game interface.

Export with Godot's matching export templates installed:

```sh
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --export-release Windows build/windows/GoblinGrimoire.exe
```

Serve the web export through HTTP/HTTPS rather than opening its HTML as a local file. The GitHub Actions workflow verifies gameplay, exports the game, and publishes GitHub Pages on each push to `main`. Source and exports remain separate.
