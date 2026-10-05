# Verification

## v0.6.0 dungeon builds and champion payoff

The gameplay suite passed **3,217 checks across 13 groups**, with zero failures. New coverage exercises earned choices after the first raid and F champion, rejection before an earned reward, no duplicate traits, exactly-once recovery and choice saves, pending-choice reload, two missed legacy milestones at a safe boundary, and no RNG consumption from reward queries or selection. Tests use isolated verification profiles; the normal native run and grimoire hashes remain unchanged.

Combat regressions cover direct and status-tick poisoned deaths, independent fresh poison layers, enemy-array order independence, no same-tick spread chain, once-only corpse marking, and no activation report when no recipients survive. Shield retaliation checks Armor/Evasion/status exclusions, lethal defenders, once per recipient per announced attack, defended retaliation, area attacks and a poisoned KO caused by retaliation. Pack checks distinct owners, shared-card exclusion, failed plays, once-per-turn activation, saved two-owner progress, draw/shuffle and exact replay state. Captain tests cover scheduled rounds, ordinary actions between volleys, locked previews, Stun cancellation, Resolve, defeat cancellation, and the transferable ability's relative targeting.

Five bounded campaigns used production cards, party generation, weighted inheritance and ordinary trait-selection APIs:

| Seed / feeding policy | Traits | Result | Ended turns / card plays |
| --- | --- | --- | ---: |
| 730204 / discovery driver | Venom Nest + Spiteful Shields | Victory | 33 / 96 |
| 101 / concentrated | Venom Nest + Spiteful Shields | Victory | 38 / 110 |
| 101 / spread | Pack Instinct + Venom Nest | Defeat at raid index 4 after four breaches | 53 / 151 |
| 730205 / concentrated | Venom Nest + Spiteful Shields | Victory | 35 / 97 |
| 730205 / spread | Pack Instinct + Venom Nest | Victory | 47 / 142 |

These demonstrate reachable victories and normal failure/retry behavior, not human win rates or trait rankings. Feeding policies and combat decisions consume the shared RNG differently; their later encounters are not matched comparisons. The driver knows developer recipes and is not tuned to each trait. Whether players find the builds more engaging remains a human playtest question.

Final UI checks passed **15,916 headless / 16,124 native mobile assertions across 180 views**, including 28 native touch assertions; **2,415 native flow assertions with 24 sequence captures**; **8,397 art assertions in each mode across 74 views**; and **2,749 trait assertions in each mode across 56 views**. The dedicated trait suite covers first/second choices, scrolling to the lower choice actions, learned but unequipped poison guidance, the visible champion numbers and counterplay, cancelling its announced volley, saved Pack progress and named compound activations at 1280×720, 390×844, 375×667 and 844×320. Native pixel review caught Captain caption overflow and compact callouts obscuring names; the final captions retain numeric intentions, the existing wide counter carries champion guidance, and mobile actor flashes plus written numeric feedback keep names and HP visible. Desktop floating feedback fits only inside creature art. No minimum-size feedback loop was introduced.

The exported browser build completed a real first raid through card/target controls, consumed all three actual bodies, and reached the first trait reward. At emulated **390×844 / DPR 3** (canvas **1170×2532**), reload/Continue preserved the pending options and learned-but-unequipped Poisoned Blade guidance. Scrolling reached all three choices. Selecting the third option awarded Pack Instinct, showed the champion milestone and capped recovery, and another reload preserved the selected trait without reopening the reward or applying recovery twice. Browser warnings and errors were empty. Windows version metadata reads 0.6.0 and the exported game's headless startup exits cleanly. Physical iPhone Safari is unavailable; these are emulated browser and native Godot touch checks.

## v0.5.0 balance pass

The gameplay and persistence suite passed **3,162 checks across 11 groups**, with zero failures. Five actual six-raid campaigns completed through ordinary play, feeding, evolution, recovery and save APIs, with no breaches:

| Seed / feeding policy | Ended turns | Card plays |
| --- | ---: | ---: |
| 730204 / discovery driver | 37 | 106 |
| 101 / concentrated | 43 | 122 |
| 101 / spread | 53 | 158 |
| 730205 / concentrated | 41 | 119 |
| 730205 / spread | 45 | 132 |

These runs use production HP, card costs, enemy targeting and weighted random inheritance. They include actual routes to both newly added advanced branches, with Nightstalker and Ancient Ogre reached in seed 101 campaigns. They demonstrate campaign reachability, not a human win rate or an optimal strategy ranking: the driver knows developer recipes, and its actions consume shared RNG, so later encounters and rewards can differ between feeding policies. The tactical driver now values removing enemy Block/Evasion and respects varying energy costs; older pacing measurements included its former reluctance to attack defended foes.

Regressions cover nonstacking Stun in both factions, a skipped action atomically granting Resolve, immunity through the next normal action/turn and then expiry, independent Poison/Burn/Regeneration applications, lethal status damage before healing, cleanse removing both display totals and layers, two-energy actions, and each advanced signature and passive. Seeded offensive targets reach all living monsters, preserve announced actions through queries and reload, and retain deterministic KO redirection. Generated priests always have and use offense; continuing an older heal-only priest party supplies Arcane Bolt without changing its already locked intent or RNG. Legacy aggregate-only statuses migrate as one application; layered saves continue identically through actions, decay, targeting and shuffle. All profiles are explicitly isolated under `user://verification/`.

Final UI checks passed **15,097 headless / 15,287 native mobile assertions across 162 views**, including 28 native touch checks; **2,390 headless / 2,414 native flow assertions**, with 24 rendered sequence captures; and **8,397 art assertions in each mode across 74 views**. Every UI harness injects its isolated bootstrap profile before scene startup, so even profile and motion-preference reads avoid the player's normal directory. Catalog fixtures separately check Resolve warnings, full-HP Mend cleansing, new signatures and owner Evasion, long card-detail scrolling, and consumed-affinity history. Native pixel review at 375×667, 390×844, 844×320 and 1920×1080 confirms the changed copy, cards and new creature forms; all final logs contain zero script/engine errors or warnings.

The browser build was checked at 1280×720 and emulated 390×844 with a 1170×2532 canvas: an actual Strike spent one energy and dealt its predicted six damage, and reload/Continue preserved that result and the locked targets. Mobile Log & rules fit and scrolled; browser warnings/errors were empty. Windows version metadata and headless startup were verified. Physical iPhone Safari remains unavailable; browser emulation and native Godot touch tests do not establish its hardware performance.

Legacy saves with multiple stun charges normalize to one displayed skipped turn, then grant Resolve and restore owned-card play. Both normalization and status consumption preserve the locked intentions and RNG.

## Previous release: v0.4.0

Run the simulation and persistence suite with Godot 4.7:

```sh
godot --headless --path . --script tests/test_runner.gd
```

The v0.4.0 gameplay run passed **1,584 assertions in nine groups**. A bounded tactical driver completed the six real F/E campaign raids with seed `730204`, using **107 card plays across 47 ended turns** through the ordinary `RunState.play_card` and `end_turn` APIs. It consumed actual generated adventurer bodies, accepted each random inherited skill once, performed Basilisk → Ember Basilisk and another first evolution, defeated both champions, and recorded promotion to D. Combat, card draws, costs, enemy HP, armor, and enemy intentions remain at production values. The driver scores candidate moves on cloned battles, then plays its chosen move on the actual run; it does not modify health or give rewards during that campaign. It chooses recipients and may decline an earned evolution, just as a player can; it cannot choose the inherited skill.

Random inheritance tests cover actual defeated bodies, invalid recipients/indices/phases, duplicate/unknown ability filtering, empty eligible pools, read-only previews, exactly-once consumption/save, and continuation with the exact result and post-roll RNG. Two separate fixed-seed sets of 512 fixture bodies reproduce identical outcomes, with common/uncommon/rare results near the declared 4:2:1 weights. These probability fixtures are separate from the real campaign. Armor tests cover repeated direct hits, Armor before spent Block, full prevention without healing, evasion, poison/burn bypass, turn persistence, class values, old saves without an armor field, combat save restoration, and no armor transfer on devouring.

The final v0.4.0 UI checks pass **14,373 headless / 14,554 native mobile assertions across 153 views**, including 28 native touch checks; **2,366 headless / 2,390 native flow assertions with 24 screenshots**; and **5,668 art assertions in each mode across 49 views**. Each combat actor's Armor and Block labels are checked for their actual independent values, visibility and containment. Feeding checks operate the real Devour control on an actual mage-corpse skill pool, verify read-only weighted odds without RNG changes, and capture the immediate saved receipt at every size. Pixel review at 375×667, 390×844, 1280×720 and 844×320 confirms readable odds, the Devour action, and the recipient/skill/source result. All final logs are free of engine/script errors and warnings.

The exported browser build was checked at 1280×720 and emulated phone 390×844 with a 1170×2532 backing canvas. A real Goblin Stab preview showed 4 HP loss against Armor 1; playing it removed exactly 4 HP, spent one energy, and left armor intact. Reload/Continue on the phone retained that result and both independent defense values. Browser warnings/errors were empty. The v0.4.0 Windows export's version metadata and headless launch also passed. A physical iPhone/Safari device remains unavailable; emulation and native touch coverage do not replace that hardware check.

The same suite separately uses explicit fixtures for rare situations: healing the same reshuffled Mend repeatedly, invalid targeting and insufficient energy, owner-specific knockouts and removal from every pile, empty decks, faction-relative healing, block expiration, poison/burning before regeneration, additive regeneration and decay, stun in both factions, locked intentions and dead-target rotation, all six evolved innate passives, feeding/evolving a knocked-out recipient, declined eligible branches, one transformation per feeding decision, restoration of the owner's cards in the next raid, four breaches ending the run, and recovery exactly once.

Save checks include continuing an active battle with its hand, piles, energy, turn, statuses, intentions and RNG state intact; a partly consumed feeding screen with unchanged bodies and claim flags; and both victorious and breached results without duplicated recovery. New profiles have no discoveries; eligibility alone reveals no grimoire entry; performed evolutions persist across a new run. JSON numeric comparisons normalize the format's float decoding while still comparing every saved field.

Tests use freshly named `user://verification/` subdirectories. They do not reset or write the normal player's run or grimoire.

## Turn flow and action clarity

```sh
godot --headless --path . --script tests/flow_smoke.gd
godot --path . --script tests/flow_smoke.gd
```

The final v0.3.1 flow run passes **1,983 headless assertions** and **2,007 native assertions**, with **24 native screenshots**, zero issues, and no engine/script errors. The suite compares the isolated replay with the ordinary battle simulation, including RNG state and every combat field. Fixtures exercise monster effects before invaders, invader effects after actions, stunned and defeated actors, knockout retargeting, empty decks, and terminal victory/breach snapshots. It verifies that ending a turn commits and saves exactly once before playback; repeated End turn, Space and stale card/target callbacks cannot resolve it again. Reload during playback restores the committed result, while Skip cancels only presentation. Resizing preserves the live result and the visible action sequence. Breach frames show knockout before exactly-once recovery, and victory transitions to actual feeding rewards.

Read-only intent and card queries cover numeric damage, block absorption, evasion, capped healing, enemy support recipients, shared/owned cards, and unavailable reasons without consuming RNG or mutating combat. Native captures show the player turn, faction effects, precise acting invader/recipient, actual HP/block changes, drawing, and the next player turn at desktop and portrait phone dimensions. The CI runs the headless flow suite on each push alongside gameplay and responsive layout checks.

Pixel review confirms all three default desktop monsters are visible on the battlefield, and narrow `375×667` phone guidance shows the owner, action, cost, target instruction and numeric effect without internal scrolling. Invader intentions remain visible alongside selected-card previews. Long actor descriptions and temporary action callouts fit their panels or clipped scroll regions. Turn captures are saved in ignored `tests/artifacts/flow/`.

The final browser build was played at `390×844` and `844×390`, both at a 3× device-pixel ratio. Checks covered readable numeric intentions, card-owner and healing-target guidance, immediate card results, the visible handoff, rotation with a selected card followed by playing it, and reload during the enemy sequence. Continue restored the committed next round with its knockout, remaining HP, hand, energy and new intentions. The browser reported no warnings or errors. Missing arrow glyphs discovered during browser inspection were replaced with readable words.

## Illustrated cards, battlefield and motion

```sh
godot --headless --path . --script tests/art_smoke.gd
godot --path . --script tests/art_smoke.gd
```

The final v0.3.1 art suite passes **4,480 assertions in each mode**, with **49 headless layouts or native screenshots** and zero issues. Sizes are `1280×720`, `1920×1080`, `1920×900`, tablet `1024×768`, smaller landscape window `1050×640`, phones `390×844` and `375×667`, and short landscape `844×320`. Captures are in ignored `tests/artifacts/art/<width>x<height>/`. The short-landscape hand is explicitly scrolled into view for review of its art strip, numeric effects and disabled badges. Linux CI caught an initial container allocation feedback loop that could enlarge the stage minimum before card faces finished layout. The corrected holder keeps a fixed 140-pixel minimum and sizes its stage within allocated space. A regression resizes 1280×720 to 1920×1080 and back, verifies stable minimum and geometry after deferred card layout, checks fully visible cards and the end-turn action, and preserves combat and RNG.

Checks verify real loaded card textures, visible owner/cost/title/numeric-effect labels, label containment in every card, selected and disabled faces, and normal availability rules. A real card from the ordinary seeded raid is selected and played through its actual target control: the result commits immediately and matches the ordinary simulation exactly, including every combat field and RNG. Hover preserves the card's target rectangle; hover, idle and action animations preserve combat and RNG. Explicit catalog fixtures cover long multi-effect cards, selected Regrowth with stacked statuses, area targets, and all six evolved creature forms; these fixtures do not earn discoveries or substitute for the real-card campaign.

Desktop and tablet checks cover all six full-body creatures and readable numerical intentions, every unit label staying within its control and viewport, and a minimum creature drawing-control height of 60 logical pixels even with selection/status rows. Native pixel review covers baseline and selected lineups, larger displays, narrow portrait cards, and the short-landscape hand. It detected a Basilisk coil overlapping its form/status caption; the drawing extent was corrected and both lineage captures were reviewed again. Reduced motion keeps idle, lunge and hit-reaction drawing transforms still; enabling motion produces an actual lunge. The production preference is saved and reloaded from an isolated profile, while the separately saved battle and RNG remain unchanged. Reload during presentation and Skip retain the already committed result. All final suite runs exit zero, and their logs contain no engine/script warnings or errors.

The v0.3 web export was played at desktop `1280×720`, phone `390×844` with canvas `1170×2532`, and rotated `844×390` with canvas `2532×1170` (3× device-pixel ratio). Illustrated card owners, costs and numerical effects remained readable. Strike dealt 6 HP immediately, spending one energy and adding one discard. Reload/Continue preserved the battle; selecting Goblin Stab, rotating and playing it dealt 5 HP with another energy/discard update. Ending a turn displayed the faction handoff, and reload during playback restored round two with its remaining HP, fresh hand, energy and intentions. Patch Up healed from 5 to 11 HP and spent one energy. Short landscape scrolling revealed the hand while retaining the fixed footer. The browser reported no warnings or errors.

## Earlier native presentation baseline

For the earlier 15-screen presentation harness, run without `--headless`:

```sh
godot --path . --script tests/visual_smoke.gd
```

This creates **15 screenshots at 1280×720** in the ignored `tests/artifacts/` directory and checks visible buttons and labels against viewport bounds and actor-panel containment. It also checks that no undiscovered form name appears in the initial screens and that a discovered recipe and signature render in the grimoire. Its prior v0.2 run passed with **zero layout/content issues** and no script errors on Godot 4.7 Compatibility/OpenGL; this harness was not rerun for the v0.3 art slice. Current v0.3 evidence comes from the flow, mobile and art suites above. Screens cover title, empty grimoire, preparation, combat, targeting, feeding, evolution reveal, discovered grimoire, raid result, promotion, defeat, evolved combat, a selected area attack, Regrowth targeting, and shared Dungeon Rally targeting. These screenshots render the actual scenes; later-screen UI fixtures complement the mechanically played campaign.

The native checks detected and led to fixes for a discovered-recipe type mismatch, actor status text outside its panel, repeated multi-target previews overflowing rows, and a clipped combat footer. Both native screenshots and simulation checks were rerun after those fixes. Automated checks exit nonzero on failed assertions. Inspect the engine console as well for unexpected script errors when changing presentation code.

The earlier export was also played through browser UI controls: New Run, incoming preview, card selection and legal targets, direct damage/energy/discard updates, repeated healing, area block, poison, evasion, stun, and Space to end turns. The first raid was won with 15 cards over five player turns. An active battle survived Save & title and a browser reload with its existing hand, HP, energy, and locked intentions. The browser playtest consumed all three actual bodies, performed a first evolution, displayed its discovered recipe, selected a newly learned skill, applied recovery, and returned to preparation for the next raid. The browser console reported no warnings or errors. Bundled fonts replaced system fonts to keep browser glyphs and layout consistent with the native screenshot checks.

## Mobile layout and touch verification

```sh
godot --path . --script tests/mobile_smoke.gd
godot --headless --path . --script tests/mobile_smoke.gd
godot --path . --script tests/mobile_smoke.gd -- --touch-only
```

The final v0.3 native mobile run passed **11,857 assertions with zero issues**, producing **135 screenshots**: fifteen phases at each of `375×667`, `390×844`, `430×932`, `844×390`, `844×320`, `756×330`, and desktop `1280×720`, `1920×1080`, `1920×900`. The two shorter landscape dimensions exercise reduced space from browser controls and safe-area margins. Captures use exact logical-size native Godot viewports and are saved in ignored `tests/artifacts/mobile/<width>x<height>/`; the harness creates `.gdignore` so captures are excluded from game imports and exports.

Checks cover every phase, targeted and area cards, long Regrowth text, actual damage/energy changes through the UI, enabled tap targets of at least 44 logical pixels in compact layouts, 44-pixel skill-menu rows, bounded popup dimensions, and feeding/continuation actions fully reachable through scrolling. Intentional scrollable content is distinguished from unintended horizontal or vertical clipping. Rotating preserves the selected card, complete battle state and RNG; rotating an open evolution reveal preserves the modal, run and discovery. The screenshots were visually inspected, including narrow portrait results/promotion, evolved area targeting, short landscape combat with a fixed End Turn button, and desktop results.

Native `Input.parse_input_event` tests inject real `InputEventScreenTouch` press/release and `InputEventScreenDrag` events into the game window with production input settings. The **28 touch assertions pass as part of the final v0.3 native run**: New Run, Defend, illustrated card selection, legal enemy targeting, damage/energy, and End Turn; vertical preparation scrolling; horizontal hand scrolling to the final card using ordinary repeated finger gestures; no accidental card selection on drag release; and selecting and playing the final card reached by that drag. These checks found and led to fixes for touch events consumed before reaching scroll containers and a landscape actor-height feedback loop. The final run was repeated after the fixes.

The headless version passes **11,694 layout/state assertions across 135 views**, skips PNG rendering and native touch injection, and exits nonzero on failure. It is suitable for CI; native touch checks require a graphical Godot run. Mobile browser rendering was also checked with device emulation at a 3× device-pixel ratio. A physical iPhone and Safari were unavailable, so these results establish native touch behavior and emulated mobile browser/layout coverage rather than a hardware Safari playtest.

The previous responsive web export was interacted with at `390×844` and `844×390` with a 3× device-pixel ratio (canvas backing sizes `1170×2532` and `2532×1170`). Browser checks covered New Run, preparation, targeted damage/energy/discard updates, the complete horizontal card hand, automatic friendly-target selection for healing, reload/Continue restoring the existing battle, rotation with a selected card and playing that card afterward, and ending a turn. `844×320` retained the fixed combat footer and scrollable battle body. The browser console contained no warnings or errors. Browser pointer controls and emulated dimensions complement the separate native ScreenTouch/ScreenDrag checks; they do not substitute for an actual Safari device test. The current illustrated v0.3 browser evidence appears in the art section above.
