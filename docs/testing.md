# Verification

Run the simulation and persistence suite with Godot 4.7:

```sh
godot --headless --path . --script tests/test_runner.gd
```

The latest verified run passed **451 assertions in seven groups**. A bounded tactical driver completed the six real F/E campaign raids with seed `730204`, using **81 card plays across 28 ended turns** through the ordinary `RunState.play_card` and `end_turn` APIs. It consumed actual generated adventurer bodies, performed Red Ogre → Oni and another first evolution, defeated both champions, and recorded promotion to D. Combat, card draws, costs, enemy HP, and enemy intentions remain at production values. The driver scores candidate moves on cloned battles, then plays its chosen move on the actual run; it does not modify health or give rewards during that campaign.

The same suite separately uses explicit fixtures for rare situations: healing the same reshuffled Mend repeatedly, invalid targeting and insufficient energy, owner-specific knockouts and removal from every pile, empty decks, faction-relative healing, block expiration, poison/burning before regeneration, additive regeneration and decay, stun in both factions, locked intentions and dead-target rotation, all six evolved innate passives, feeding/evolving a knocked-out recipient, declined eligible branches, one transformation per feeding decision, restoration of the owner's cards in the next raid, four breaches ending the run, and recovery exactly once.

Save checks include continuing an active battle with its hand, piles, energy, turn, statuses, intentions and RNG state intact; a partly consumed feeding screen with unchanged bodies and claim flags; and both victorious and breached results without duplicated recovery. New profiles have no discoveries; eligibility alone reveals no grimoire entry; performed evolutions persist across a new run. JSON numeric comparisons normalize the format's float decoding while still comparing every saved field.

Tests use freshly named `user://verification/` subdirectories. They do not reset or write the normal player's run or grimoire.

## Turn flow and action clarity

```sh
godot --headless --path . --script tests/flow_smoke.gd
godot --path . --script tests/flow_smoke.gd
```

The final flow run passes **1,583 headless assertions** and **1,607 native assertions**, with **24 native screenshots**, zero issues, and no engine/script errors. The suite compares the isolated replay with the ordinary battle simulation, including RNG state and every combat field. Fixtures exercise monster effects before invaders, invader effects after actions, stunned and defeated actors, knockout retargeting, empty decks, and terminal victory/breach snapshots. It verifies that ending a turn commits and saves exactly once before playback; repeated End turn, Space and stale card/target callbacks cannot resolve it again. Reload during playback restores the committed result, while Skip cancels only presentation. Resizing preserves the live result and the visible action sequence. Breach frames show knockout before exactly-once recovery, and victory transitions to actual feeding rewards.

Read-only intent and card queries cover numeric damage, block absorption, evasion, capped healing, enemy support recipients, shared/owned cards, and unavailable reasons without consuming RNG or mutating combat. Native captures show the player turn, faction effects, precise acting invader/recipient, actual HP/block changes, drawing, and the next player turn at desktop and portrait phone dimensions. The CI runs the headless flow suite on each push alongside gameplay and responsive layout checks.

Pixel review confirms all three default desktop monster panels are visible, and narrow `375×667` phone guidance shows the owner, action, cost, target instruction and numeric effect without internal scrolling. Invader intentions remain visible beneath selected-card previews. Long actor descriptions and temporary action callouts fit their panels or clipped scroll regions. Turn captures are saved in ignored `tests/artifacts/flow/`.

The final browser build was played at `390×844` and `844×390`, both at a 3× device-pixel ratio. Checks covered readable numeric intentions, card-owner and healing-target guidance, immediate card results, the visible handoff, rotation with a selected card followed by playing it, and reload during the enemy sequence. Continue restored the committed next round with its knockout, remaining HP, hand, energy and new intentions. The browser reported no warnings or errors. Missing arrow glyphs discovered during browser inspection were replaced with readable words.

For native presentation verification, run without `--headless`:

```sh
godot --path . --script tests/visual_smoke.gd
```

This creates **15 screenshots at 1280×720** in the ignored `tests/artifacts/` directory and checks visible buttons and labels against viewport bounds and actor-panel containment. It also checks that no undiscovered form name appears in the initial screens and that a discovered recipe and signature render in the grimoire. The latest run passed with **zero layout/content issues** and no script errors on Godot 4.7 Compatibility/OpenGL. Screens cover title, empty grimoire, preparation, combat, targeting, feeding, evolution reveal, discovered grimoire, raid result, promotion, defeat, evolved combat, a selected area attack, Regrowth targeting, and shared Dungeon Rally targeting. These screenshots render the actual scenes; later-screen UI fixtures complement the mechanically played campaign.

The native checks detected and led to fixes for a discovered-recipe type mismatch, actor status text outside its panel, repeated multi-target previews overflowing rows, and a clipped combat footer. Both native screenshots and simulation checks were rerun after those fixes. Automated checks exit nonzero on failed assertions. Inspect the engine console as well for unexpected script errors when changing presentation code.

The exported game was also played through browser UI controls: New Run, incoming preview, card selection and legal targets, direct damage/energy/discard updates, repeated healing, area block, poison, evasion, stun, and Space to end turns. The first raid was won with 15 cards over five player turns. An active battle survived Save & title and a browser reload with its existing hand, HP, energy, and locked intentions. The browser playtest consumed all three actual bodies, performed a first evolution, displayed its discovered recipe, selected a newly learned skill, applied recovery, and returned to preparation for the next raid. The browser console reported no warnings or errors. Bundled fonts replaced system fonts to keep browser glyphs and layout consistent with the final native screenshot checks.

## Mobile layout and touch verification

```sh
godot --path . --script tests/mobile_smoke.gd
godot --headless --path . --script tests/mobile_smoke.gd
godot --path . --script tests/mobile_smoke.gd -- --touch-only
```

The final native mobile run passed **8,183 assertions with zero issues**, producing **105 screenshots**: fifteen phases at each of `375×667`, `390×844`, `430×932`, `844×390`, `844×320`, `756×330`, and desktop `1280×720`. The two shorter landscape dimensions exercise reduced space from browser controls and safe-area margins. Captures use exact logical-size native Godot viewports and are saved in ignored `tests/artifacts/mobile/<width>x<height>/`; the harness creates `.gdignore` so captures are excluded from game imports and exports.

Checks cover every phase, targeted and area cards, long Regrowth text, actual damage/energy changes through the UI, enabled tap targets of at least 44 logical pixels in compact layouts, 44-pixel skill-menu rows, bounded popup dimensions, and feeding/continuation actions fully reachable through scrolling. Intentional scrollable content is distinguished from unintended horizontal or vertical clipping. Rotating preserves the selected card, complete battle state and RNG; rotating an open evolution reveal preserves the modal, run and discovery. The screenshots were visually inspected, including narrow portrait results/promotion, evolved area targeting, short landscape combat with a fixed End Turn button, and desktop results.

Native `Input.parse_input_event` tests inject real `InputEventScreenTouch` press/release and `InputEventScreenDrag` events into the game window with production input settings. The **28-assertion touch-only check passes**: New Run, Defend, card selection, legal enemy targeting, damage/energy, and End Turn; vertical preparation scrolling; horizontal hand scrolling to the final card; no accidental card selection on drag release; and selecting and playing the final card reached by that drag. These checks found and led to fixes for touch events consumed before reaching scroll containers and a landscape actor-height feedback loop. The final run was repeated after the fixes.

The headless version passes **8,050 layout/state assertions across 105 views**, skips PNG rendering and native touch injection, and exits nonzero on failure. It is suitable for CI; native touch checks require a graphical Godot run. Mobile browser rendering was also checked with device emulation at a 3× device-pixel ratio. A physical iPhone and Safari were unavailable, so these results establish native touch behavior and emulated mobile browser/layout coverage rather than a hardware Safari playtest.

The final web export was interacted with at `390×844` and `844×390` with a 3× device-pixel ratio (canvas backing sizes `1170×2532` and `2532×1170`). Browser checks covered New Run, preparation, targeted damage/energy/discard updates, the complete horizontal card hand, automatic friendly-target selection for healing, reload/Continue restoring the existing battle, rotation with a selected card and playing that card afterward, and ending a turn. `844×320` retained the fixed combat footer and scrollable battle body. The final browser console contained no warnings or errors. Browser pointer controls and emulated dimensions complement the separate native ScreenTouch/ScreenDrag checks; they do not substitute for an actual Safari device test.
