# Card art and battlefield visual slice

This slice adds illustrated card faces and a staged, animated battlefield to the playable prototype. It changes presentation, not card costs, targeting, damage, enemy intentions, progression, or random-number use.

The art direction combines moss-green goblins, expressive golden eyes, rough brown clothing, dark mossy stone, warm ochre light, parchment highlights, and charcoal shadows. The three card illustrations share a hand-painted 2D fantasy style, clean silhouettes, visible actions, and a charming tone. The artwork contains no text or UI; Godot draws the owner, ability name, energy cost, numerical effect, selection state, and unavailable reason separately so they remain legible at different sizes.

## Saved illustrations

| Original asset | Dimensions | Category and use |
| --- | --- | --- |
| [`attack-v1.png`](../assets/cards/attack-v1.png) | 1254 × 1254 PNG | Dagger attack; reused for damaging abilities, including the starter Strike cards. |
| [`guard-v1.png`](../assets/cards/guard-v1.png) | 1254 × 1254 PNG | Wooden shield and protective arc; reused for blocking abilities, including starter Guard cards. |
| [`vitality-v1.png`](../assets/cards/vitality-v1.png) | 1254 × 1254 PNG | Restorative green wisp; reused for healing and regeneration, including starter Patch Up cards. |

These are three **category illustrations**, not unique illustrations for every card, monster, or ability. The category is chosen from the actual ability effects. Affinity colors add a small vector accent so related illustrations can serve different abilities. A card's visible owner and ability name carry its specific identity.

The images were generated with the built-in **imagegen** tool, without an image-generation CLI. The original generated PNGs are preserved at the paths above. The renderer crops them at runtime for each card layout; it does not crop, resize, paint over, or replace the source files. Godot's imported textures and exported builds are derived copies.

## Generation prompts

Each prompt below combines the original use-case/type prefix, subject, and shared style instruction. The corresponding source image is named immediately above its prompt.

### `assets/cards/attack-v1.png`

```text
Use case: stylized-concept. Asset type: square illustration for an attack card in the original 2D fantasy dungeon deckbuilder Goblin Grimoire. Create one finished hand-painted game illustration: a scrappy small moss-green goblin with pointed ears and expressive golden eyes, rough brown tunic, lunging with a short chipped dagger, bright amber arc of motion and a few sparks. Crop to an energetic waist-up close action pose, face and dagger clearly legible, subject fills frame and stays in the central 80 percent so a wide card crop still reads. Dark moss stone dungeon backdrop with soft atmospheric shadows. Restrained moss greens, warm ochre, parchment highlights, charcoal shadows. Bold clean silhouettes, rich painterly texture, polished independent fantasy card-game aesthetic, charming rather than grotesque, coherent hand-drawn 2D style. No typography, no words, no numbers, no border, no card UI, no watermark, no gore, no photographic or 3D rendering. One square illustration.
```

### `assets/cards/guard-v1.png`

```text
Use case: stylized-concept. Asset type: square illustration for an guard(block) card in the original 2D fantasy dungeon deckbuilder Goblin Grimoire. Create one finished hand-painted game illustration: a scrappy small moss-green goblin with pointed ears, expressive golden eyes and rough brown tunic, planting a battered round wooden shield in front of itself, luminous warm-gold protective arc embracing the shield. Energetic waist-up defensive pose, goblin face peeking over shield, subject fills frame and stays in central 80 percent so a wide card crop still reads. Dark moss stone dungeon backdrop with soft atmospheric shadows. Restrained moss greens, warm ochre, parchment highlights, charcoal shadows. Bold clean silhouettes, rich painterly texture, polished independent fantasy card-game aesthetic, charming rather than grotesque, coherent hand-drawn 2D style. No typography, no words, no numbers, no border, no card UI, no watermark, no gore, no photographic or 3D rendering. One square illustration.
```

### `assets/cards/vitality-v1.png`

```text
Use case: stylized-concept. Asset type: square illustration for an healing card in the original 2D fantasy dungeon deckbuilder Goblin Grimoire. Create one finished hand-painted game illustration: a scrappy small moss-green goblin with pointed ears, expressive golden eyes and rough brown tunic, tenderly holding a glowing jade-green restorative wisp between both hands, small swirling leaves and golden motes illuminating its relieved face. Waist-up intimate magical pose, hands and face clearly readable, subject fills frame and stays in central 80 percent so a wide card crop still reads. Dark moss stone dungeon backdrop with soft atmospheric shadows. Restrained moss greens, warm ochre, parchment highlights, charcoal shadows. Bold clean silhouettes, rich painterly texture, polished independent fantasy card-game aesthetic, charming rather than grotesque, coherent hand-drawn 2D style. No typography, no words, no numbers, no border, no card UI, no watermark, no gore, no photographic or 3D rendering. One square illustration.
```

## Presentation and motion

Desktop combat places full-body vector creatures in the chamber, with names, HP, block, numerical intentions, and target highlights around them. Subtle idle breathing, attack lunges, hit reactions, and heal/shield/status pulses support the existing action sequence. The selected card retains its effect text, and playing it can show a small cosmetic flight toward the discard counter. The real card result commits immediately; these effects never delay or replay its mechanics.

The desktop hand uses centered, fixed-width faces. Portrait phones retain a horizontally scrollable hand, compact actor panels, and target guidance. Short landscape layouts use a small art strip to preserve space for actions. Tapping a selected card again opens its full description. Card children ignore mouse input so the whole face remains the same selection target. Illustrations have a vector fallback if a texture is unavailable.

**Reduce motion**, available through combat's **Log & rules**, removes cosmetic movement and card fades while retaining action messages, health/status changes, selection, and turn controls. The browser preference supplies the initial setting when there is no saved preference; an explicit choice is saved separately from the run. **Skip animation** still advances a committed enemy turn to its final screen.

The creature portraits, bodies, weapons, and chamber remain original procedural vector **prototype art**. They establish readable faction, form, and action silhouettes but do not yet match the detail or finish of the painterly card images. Future passes can add unique ability illustrations, stronger visual identity for each owner, and authored creature animation. Those additions should preserve numeric intentions, touch targets, reduced motion, and the separation between cosmetic effects and simulation.

## Implementation and review

`scripts/ui_card.gd` renders the illustrated faces and exposes a null-safe `texture_for(ability_id)` helper. `scripts/card_fx.gd` handles cosmetic played-card flight. `scripts/ui_battlefield.gd` and `scripts/battle_creature.gd` render the staged creatures and reactions. No generated illustration exposes an undiscovered transformation or recipe.

Run the slice's checks using:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/art_smoke.gd
godot --path . --script tests/art_smoke.gd
```

The graphical run captures production card and battlefield views for pixel review. The suite checks visible owner/cost/effect labels, selection and disabled faces, texture loading, layout, unchanged combat/RNG state during cosmetic effects, reduced motion, and continuing a saved run. See [testing.md](testing.md) for completed verification and its platform limits.
