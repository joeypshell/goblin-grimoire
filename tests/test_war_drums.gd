extends RefCounted

const Combat = preload("res://scripts/battle.gd")
const Traits = preload("res://scripts/battle_traits.gd")
const Forms = preload("res://scripts/battle_forms.gd")
const Replay = preload("res://scripts/battle_replay.gd")

func run(t) -> void:
	t.group("War Drums legal protection, independent rewards, snapshots and replay")
	test_targeting(t)
	test_once_per_turn(t)
	test_area_protection(t)
	test_combined_rewards(t)
	test_preview_and_replay(t)
	test_snapshots(t)
	test_continue(t)

func fixture(t, traits: Array = ["war_drums"], people: Array = []):
	var random := RandomNumberGenerator.new()
	random.seed = 64812
	var battle = Combat.new()
	battle.setup(t.roster() if people.is_empty() else people, [t.enemy()], random, traits)
	battle.draw_pile = [t.card("strike", "m1", "drum_draw_a"), t.card("guard", "m2", "drum_draw_b"), t.card("strike", "m2", "drum_draw_c"), t.card("guard", "m1", "drum_draw_d")]
	battle.discard = []
	return battle

func count(battle) -> int:
	return int(battle.trait_state["trigger_counts"]["war_drums"])

func play(t, battle, ability: String, target: String, owner: String = "m0") -> void:
	battle.hand = [t.card(ability, owner)]
	t.check(battle.play_card(0, target), "Actual card resolves the War Drums fixture: " + ability)

func test_targeting(t) -> void:
	for exclusion in ["self", "shared", "shield_bash", "smoke_step", "dead_ally", "dead_owner", "invalid", "stunned_owner", "unaffordable", "no_trait"]:
		var battle = fixture(t, [] if exclusion == "no_trait" else ["war_drums"])
		var ability: String = "rally" if exclusion == "shared" else "shield_bash" if exclusion == "shield_bash" else "smoke_step" if exclusion == "smoke_step" else "guard"
		var target: String = "e0" if exclusion in ["invalid", "shield_bash"] else "m0" if exclusion in ["self", "smoke_step", "shared"] else "m1"
		if exclusion == "dead_ally": battle.monsters[1]["hp"] = 0
		if exclusion == "dead_owner": battle.monsters[0]["hp"] = 0
		if exclusion == "stunned_owner": battle._status(battle.monsters[0], "stun", 1)
		if exclusion == "unaffordable": battle.energy = 0
		battle.hand = [t.card(ability, "" if exclusion == "shared" else "m0")]
		var before: Dictionary = battle.to_dict()
		var accepted: bool = battle.play_card(0, target)
		var rejected: bool = exclusion in ["dead_ally", "dead_owner", "invalid", "stunned_owner", "unaffordable"]
		t.check(accepted != rejected and count(battle) == 0 and not battle.trait_state["war_drums_triggered"] and battle.draw_pile.size() == 4, "Only an affordable owned card protecting another living monster can reward War Drums: " + exclusion)
		if rejected: t.check(t.same_saved_value(before, battle.to_dict()), "Rejected protection preserves complete combat state and RNG: " + exclusion)
	var battle = fixture(t)
	var random_before: int = battle.rng.state
	var energy_before: int = battle.energy
	play(t, battle, "guard", "m1")
	t.check(battle.monsters[1]["block"] == 7 and battle.energy == energy_before and battle.hand.size() == 1 and count(battle) == 1 and battle.rng.state == random_before, "Guard another monster spends one energy, refunds one, draws one, and consumes no RNG without a shuffle")

func test_once_per_turn(t) -> void:
	var battle = fixture(t)
	play(t, battle, "guard", "m1")
	var pile_before: int = battle.draw_pile.size()
	var energy_before: int = battle.energy
	play(t, battle, "guard", "m0", "m2")
	t.check(battle.energy == energy_before - 1 and battle.hand.is_empty() and battle.draw_pile.size() == pile_before and count(battle) == 1, "A different monster's protection cannot repeat the run-wide reward in the same turn")
	battle.end_turn()
	t.check(not battle.trait_state["war_drums_triggered"] and count(battle) == 1, "Beginning the next player turn resets eligibility while retaining the activation total")
	battle.draw_pile = [t.card("strike", "m1", "next_turn_draw")]
	energy_before = battle.energy
	play(t, battle, "guard", "m2", "m1")
	t.check(count(battle) == 2 and battle.energy == energy_before and battle.hand.size() == 1, "The next player turn can independently earn another protection reward")
	var empty = fixture(t)
	empty.draw_pile.clear()
	play(t, empty, "guard", "m1")
	var snapshot: Dictionary = empty.to_dict()
	Traits.played(empty, t.card("guard"), {"protect": true})
	t.check(count(empty) == 1 and t.same_saved_value(snapshot, empty.to_dict()), "A draw that requires a reshuffle still records one activation and cannot replay the reward")

func test_area_protection(t) -> void:
	var people: Array = t.roster()
	people[0]["form"] = "green_ogre"
	var battle = fixture(t, ["war_drums"], people)
	play(t, battle, "ogre_aegis", "m0")
	t.check(battle.monsters.all(func(actor): return actor["block"] == 10) and battle.energy == 2 and battle.hand.size() == 1 and count(battle) == 1 and battle.form_state["m0"]["ready"], "Owned area protection gives all targets Block, stores one Bulwark charge and awards War Drums exactly once")
	people = t.roster()
	people[1]["hp"] = 0
	people[2]["hp"] = 0
	var alone = fixture(t, ["war_drums"], people)
	play(t, alone, "shield_wall", "m0")
	t.check(count(alone) == 0 and alone.hand.is_empty(), "Owned area protection of the sole surviving owner counts as self-only Block")

func test_combined_rewards(t) -> void:
	var people: Array = t.roster()
	people[2]["form"] = "green_ogre"
	var battle = fixture(t, ["war_drums", "pack_instinct"], people)
	battle.energy = 8
	play(t, battle, "strike", "e0", "m0")
	play(t, battle, "strike", "e0", "m1")
	var energy_before: int = battle.energy
	play(t, battle, "guard", "m0", "m2")
	t.check(battle.energy == energy_before + 1 and battle.hand.size() == 2 and battle.draw_pile.size() == 2, "One third-owner protection independently triggers War Drums and Pack Instinct, each granting one energy and card")
	t.check(count(battle) == 1 and battle.trait_state["trigger_counts"]["pack_instinct"] == 1 and battle.form_state["m2"]["ready"], "Combined rewards retain their own counters and also store the owner's Bulwark charge")
	energy_before = battle.energy
	play(t, battle, "guard", "m1", "m2")
	t.check(battle.energy == energy_before - 1 and battle.hand.is_empty() and count(battle) == 1 and battle.trait_state["trigger_counts"]["pack_instinct"] == 1 and Forms.damage_bonus(battle, battle.monsters[2]) == 10, "Further protection cannot repeat either trait or stack the form charge")

func test_preview_and_replay(t) -> void:
	var battle = fixture(t)
	var card: Dictionary = t.card("guard")
	var before: Dictionary = battle.to_dict()
	var logs: Array = battle.action_log.duplicate()
	for repeat in range(5):
		t.check(battle.preview(card, "m1").contains("War Drums") and not battle.preview(card, "m0").contains("War Drums"), "Target preview advertises the energy/draw reward only for protecting another monster")
		t.check(Traits.card_preview(battle, card, Forms.prepare(battle, card, "m1")).contains("1 energy") and Traits.card_preview(battle, card, Forms.prepare(battle, card, "e0")) == "", "Trait preview requires the actual valid protection context")
	t.check(t.same_saved_value(before, battle.to_dict()) and logs == battle.action_log, "Repeated previews preserve trigger eligibility, counters, logs, complete state and RNG")
	play(t, battle, "guard", "m1")
	t.check(not battle.preview(card, "m2").contains("War Drums"), "Used War Drums disappears from further protection forecasts this turn")
	before = battle.to_dict()
	var replay = Replay.make(battle)
	t.check(t.same_saved_value(before, battle.to_dict()), "Capturing next-turn playback cannot mutate live War Drums state or RNG")
	battle.end_turn()
	t.check(t.same_saved_value(battle.to_dict(), replay.to_dict()) and not battle.trait_state["war_drums_triggered"] and count(battle) == 1, "Replayed and direct invader turns reset eligibility identically without replaying the protection reward")
	var legacy = fixture(t)
	legacy.trait_state.erase("war_drums_triggered")
	legacy.trait_state["trigger_counts"].erase("war_drums")
	before = legacy.to_dict()
	t.check(legacy.preview(card, "m1").contains("War Drums") and t.same_saved_value(before, legacy.to_dict()), "Read-only preview handles missing legacy trait fields without backfilling or advancing RNG")

func test_snapshots(t) -> void:
	var battle = fixture(t)
	play(t, battle, "guard", "m1")
	var snapshot: Dictionary = battle.to_dict()
	var restored = Combat.new()
	restored.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(t.same_saved_value(snapshot, restored.to_dict()) and restored.trait_state["war_drums_triggered"], "Saved reward eligibility and its activation count restore exactly")
	var energy_before: int = restored.energy
	play(t, battle, "guard", "m2")
	play(t, restored, "guard", "m2")
	t.check(restored.energy == energy_before - 1 and restored.hand.is_empty() and count(restored) == 1 and t.same_saved_value(battle.to_dict(), restored.to_dict()), "Continue cannot grant energy or draw again from a previously completed protection reward")
	var old: Dictionary = snapshot.duplicate(true)
	old["trait_state"].erase("war_drums_triggered")
	old["trait_state"]["trigger_counts"].erase("war_drums")
	var legacy = Combat.new()
	legacy.restore(old, old["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(not legacy.trait_state["war_drums_triggered"] and count(legacy) == 0 and legacy.hand == old["hand"] and legacy.intents == old["intents"] and str(legacy.rng.state) == old["rng_state"], "Legacy restore backfills missing War Drums state while preserving the actual hand, locked intentions and RNG")
	var missing: Dictionary = snapshot.duplicate(true)
	missing.erase("trait_state")
	legacy.restore(missing, missing["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(legacy.trait_state == Traits.fresh_state() and legacy.hand == missing["hand"] and str(legacy.rng.state) == missing["rng_state"], "Entirely missing legacy trait state receives fresh defaults without drawing or rerolling")

func test_continue(t) -> void:
	var game = t.state_at("war_drums_continue")
	game.new_run(61426)
	game.run["traits"] = ["war_drums"]
	game.start_raid()
	var owners: Array = game.run["monsters"].map(func(actor): return actor["id"])
	game.battle.hand = [t.card("guard", owners[0], "saved_drums")]
	t.check(game.play_card(0, owners[1]) and count(game.battle) == 1, "Real RunState card action grants and saves the protection reward")
	var snapshot: Dictionary = game.battle.to_dict()
	var resumed = t.state_at("war_drums_continue")
	t.check(resumed.load_game() and t.same_saved_value(snapshot, resumed.battle.to_dict()), "Real Continue preserves War Drums eligibility and count in the complete battle snapshot")
	game.battle.hand = [t.card("guard", owners[2], "next_saved_guard")]
	resumed.battle.hand = game.battle.hand.duplicate(true)
	t.check(game.play_card(0, owners[0]) and resumed.play_card(0, owners[0]) and count(resumed.battle) == 1 and t.same_saved_value(game.battle.to_dict(), resumed.battle.to_dict()), "A later protection after real Continue cannot repeat the used reward")
