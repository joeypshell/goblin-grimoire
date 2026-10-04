# Verification

Run the simulation and persistence suite with Godot 4.7:

```sh
godot --headless --path . --script tests/test_runner.gd
```

The latest verified run passed **451 assertions in seven groups**. A bounded tactical driver completed the six real F/E campaign raids with seed `730204`, using **81 card plays across 28 ended turns** through the ordinary `RunState.play_card` and `end_turn` APIs. It consumed actual generated adventurer bodies, performed Red Ogre → Oni and another first evolution, defeated both champions, and recorded promotion to D. Combat, card draws, costs, enemy HP, and enemy intentions remain at production values. The driver scores candidate moves on cloned battles, then plays its chosen move on the actual run; it does not modify health or give rewards during that campaign.

The same suite separately uses explicit fixtures for rare situations: healing the same reshuffled Mend repeatedly, invalid targeting and insufficient energy, owner-specific knockouts and removal from every pile, empty decks, faction-relative healing, block expiration, poison/burning before regeneration, additive regeneration and decay, stun in both factions, locked intentions and dead-target rotation, all six evolved innate passives, feeding/evolving a knocked-out recipient, declined eligible branches, one transformation per feeding decision, restoration of the owner's cards in the next raid, four breaches ending the run, and recovery exactly once.

Save checks include continuing an active battle with its hand, piles, energy, turn, statuses, intentions and RNG state intact; a partly consumed feeding screen with unchanged bodies and claim flags; and both victorious and breached results without duplicated recovery. New profiles have no discoveries; eligibility alone reveals no grimoire entry; performed evolutions persist across a new run. JSON numeric comparisons normalize the format's float decoding while still comparing every saved field.

Tests use freshly named `user://verification/` subdirectories. They do not reset or write the normal player's run or grimoire.

For native presentation verification, run without `--headless`:

```sh
godot --path . --script tests/visual_smoke.gd
```

This creates **15 screenshots at 1280×720** in the ignored `tests/artifacts/` directory and checks visible buttons and labels against viewport bounds and actor-panel containment. It also checks that no undiscovered form name appears in the initial screens and that a discovered recipe and signature render in the grimoire. The latest run passed with **zero layout/content issues** and no script errors on Godot 4.7 Compatibility/OpenGL. Screens cover title, empty grimoire, preparation, combat, targeting, feeding, evolution reveal, discovered grimoire, raid result, promotion, defeat, evolved combat, a selected area attack, Regrowth targeting, and shared Dungeon Rally targeting. These screenshots render the actual scenes; later-screen UI fixtures complement the mechanically played campaign.

The native checks detected and led to fixes for a discovered-recipe type mismatch, actor status text outside its panel, repeated multi-target previews overflowing rows, and a clipped combat footer. Both native screenshots and simulation checks were rerun after those fixes. Automated checks exit nonzero on failed assertions. Inspect the engine console as well for unexpected script errors when changing presentation code.
