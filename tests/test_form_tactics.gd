extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const Tactics = preload("res://scripts/invader_tactics.gd")

func run(t) -> void:
	t.group("form setup/payoff, once-per-turn boundaries, snapshots and deliberate invader pressure")
	test_bulwark(t)
	test_fire_chain(t)
	test_venom_trap(t)
	test_ambush_chain(t)
	test_snapshots(t)
	test_trait_combination(t)
	test_tactical_cards(t)
	test_invaders(t)
	test_marshal(t)

func formed(t, form: String, size: int = 3):
	var people: Array = t.roster()
	people[0]["form"] = form
	people[0]["hp"] = Data.FORMS[form]["max_hp"]
	people[0]["max_hp"] = Data.FORMS[form]["max_hp"]
	var party: Array = []
	for index in range(size): party.append(t.enemy("e%d" % index))
	var battle = t.fixture(people, party)
	battle.energy = 20
	return battle

func fixed_draw(battle, t) -> void:
	battle.draw_pile = [t.card("guard", "m1", "draw_a"), t.card("strike", "m1", "draw_b"), t.card("patch_up", "m2", "draw_c"), t.card("guard", "m2", "draw_d")]

func play(t, battle, ability: String, target: String, owner: String = "m0") -> bool:
	battle.hand = [t.card(ability, owner, "edge_" + ability)]
	var accepted: bool = battle.play_card(0, target)
	t.check(accepted, "Production card accepts the explicit tactical fixture: " + ability)
	return accepted

func read_only_preview(t, battle, card: Dictionary, target: String, fragment: String = "") -> void:
	var before: Dictionary = battle.to_dict()
	var action_log: Array = battle.action_log.duplicate()
	for repeat in range(4):
		var text: String = battle.preview(card, target)
		t.check(not text.is_empty() and (fragment == "" or text.contains(fragment)), "Preview describes the actual tactical effect: " + fragment)
	t.check(t.same_saved_value(before, battle.to_dict()) and action_log == battle.action_log, "Repeated tactical previews preserve every battle field, pending combo, logs and RNG")

func test_bulwark(t) -> void:
	for form in ["green_ogre", "ancient_ogre"]:
		var bonus: int = 6 if form == "green_ogre" else 8
		var battle = formed(t, form)
		t.check(t.all_cards(battle).size() == 12, "A transformation keeps the original twelve-card deck: " + form)
		play(t, battle, "guard", "m0")
		play(t, battle, "strike", "e0")
		t.check(battle.enemies[0]["hp"] == 494, "Blocking only yourself cannot prepare Bulwark: " + form)
		play(t, battle, "rally", "m0", "")
		play(t, battle, "strike", "e0")
		t.check(battle.enemies[0]["hp"] == 488, "A shared dungeon card cannot prepare another monster's Bulwark")
		var random_before: int = battle.rng.state
		play(t, battle, "guard", "m1")
		read_only_preview(t, battle, t.card("strike"), "e0", "+%d damage" % bonus)
		battle.hand = [t.card("strike")]
		battle.energy = 0
		var rejected: Dictionary = battle.to_dict()
		t.check(not battle.play_card(0, "e0") and t.same_saved_value(rejected, battle.to_dict()), "Rejected attack cannot consume the readied Bulwark payoff")
		battle.energy = 20
		play(t, battle, "strike", "e0")
		t.check(battle.enemies[0]["hp"] == 488 - 6 - bonus and battle.rng.state == random_before, "Protecting another ally grants the specified next attack bonus without RNG: " + form)
		play(t, battle, "guard", "m2")
		var hp_before: int = battle.enemies[0]["hp"]
		play(t, battle, "strike", "e0")
		t.check(battle.enemies[0]["hp"] == hp_before - 6, "Repeated protection cannot earn a second Bulwark attack in the same turn")
		battle.end_turn()
		# Guard-only invaders put up Block during their turn. Remove that unrelated
		# fixture defense so this assertion isolates the new turn's form payoff.
		for enemy in battle.enemies: enemy["block"] = 0
		battle.energy = 10
		play(t, battle, "guard", "m1")
		hp_before = battle.enemies[0]["hp"]
		play(t, battle, "strike", "e0")
		t.check(battle.enemies[0]["hp"] == hp_before - 6 - bonus, "Fresh player turn permits a new protection-then-attack sequence")
		var area = formed(t, form)
		play(t, area, "guard", "m1")
		play(t, area, "ember_burst", "e0")
		t.check(area.enemies.all(func(actor): return actor["hp"] == 497 - bonus), "Readied area card boosts every recipient before consuming Bulwark once")
		play(t, area, "strike", "e0")
		t.check(area.enemies[0]["hp"] == 491 - bonus, "Area payoff is consumed after the entire card, rather than left ready")

func test_fire_chain(t) -> void:
	for form in ["red_ogre", "oni"]:
		var battle = formed(t, form)
		var starting_energy: int = battle.energy
		play(t, battle, "firebolt", "e0")
		t.check(battle.enemies[1]["statuses"].get("burn", 0) == 0 and battle.energy == starting_energy - 1, "A card's newly applied Burn cannot satisfy its own fire-chain setup: " + form)
		read_only_preview(t, battle, t.card("strike"), "e0", "spreads 2 Burn")
		var random_before: int = battle.rng.state
		var energy_before: int = battle.energy
		play(t, battle, "strike", "e0")
		t.check(battle.enemies[1]["status_layers"]["burn"] == [2] and battle.enemies[2]["status_layers"]["burn"] == [2], "Attacking a pre-burning foe spreads a fresh independent Burn application to other invaders")
		t.check(battle.energy == energy_before - (0 if form == "oni" else 1) and battle.rng.state == random_before, "Oni refunds one energy; first fire-chain spread consumes no RNG")
		energy_before = battle.energy
		play(t, battle, "strike", "e1")
		t.check(battle.enemies[2]["status_layers"]["burn"] == [2] and battle.energy == energy_before - 1, "Another burning target cannot repeat fire-chain spread or refund in the same turn")
		var finishing = formed(t, form)
		finishing.enemies[0]["hp"] = 1
		finishing._status(finishing.enemies[0], "burn", 1)
		play(t, finishing, "strike", "e0")
		t.check(finishing.enemies[0]["hp"] == 0 and finishing.enemies[1]["statuses"].get("burn", 0) == 2, "Finishing a pre-burning target retains the setup for the post-card spread")

func test_venom_trap(t) -> void:
	for form in ["basilisk", "ember_basilisk"]:
		var amount: int = 1 if form == "basilisk" else 2
		for exclusion in ["no_poison", "resolve", "already_stunned", "lethal"]:
			var negative = formed(t, form)
			fixed_draw(negative, t)
			if exclusion != "no_poison": negative._status(negative.enemies[0], "poison", 1)
			if exclusion == "resolve": negative.enemies[0]["statuses"]["resolve"] = 1
			if exclusion == "already_stunned": negative._status(negative.enemies[0], "stun", 1)
			if exclusion == "lethal": negative.enemies[0]["hp"] = 1
			if exclusion == "lethal":
				var before: Dictionary = negative.to_dict()
				var text: String = negative.preview(t.card("snare"), "e0").to_lower()
				t.check(not text.contains("+1 stun") and not text.contains("draws") and t.same_saved_value(before, negative.to_dict()), "Lethal poisoned Snare preview omits the impossible stun/draw and preserves state")
			play(t, negative, "snare", "e0")
			t.check(negative.hand.is_empty() and negative.draw_pile.size() == 4, "Venom trap cannot draw for an unsuccessful pre-poisoned stun: " + exclusion)
			negative._status(negative.enemies[1], "poison", 1)
			play(t, negative, "snare", "e1")
			t.check(negative.hand.size() == amount and negative.draw_pile.size() == 4 - amount, "A non-triggering control action does not consume the later valid venom-trap draw")
		var gaze = formed(t, form)
		fixed_draw(gaze, t)
		play(t, gaze, "petrifying_gaze", "e0")
		t.check(gaze.hand.is_empty(), "Poison and stun from the same card cannot invent a pre-existing venom setup")
		var battle = formed(t, form)
		fixed_draw(battle, t)
		battle._status(battle.enemies[0], "poison", 1)
		read_only_preview(t, battle, t.card("snare"), "e0", "draws %d card" % amount)
		var random_before: int = battle.rng.state
		play(t, battle, "snare", "e0")
		t.check(battle.hand.size() == amount and battle.rng.state == random_before, "Successful pre-poisoned stun draws the form's exact reward without an unnecessary shuffle")
		battle._status(battle.enemies[1], "poison", 1)
		var remaining: int = battle.draw_pile.size()
		play(t, battle, "snare", "e1")
		t.check(battle.hand.is_empty() and battle.draw_pile.size() == remaining, "A second successfully stunned poisoned foe cannot repeat the draw in one turn")

func test_ambush_chain(t) -> void:
	for form in ["shadow_stalker", "nightstalker"]:
		var draw_count: int = 1 if form == "nightstalker" else 0
		var correct = formed(t, form)
		var reversed = formed(t, form)
		fixed_draw(correct, t)
		fixed_draw(reversed, t)
		correct.energy = 3
		reversed.energy = 3
		play(t, correct, "poisoned_blade", "e0", "m1")
		read_only_preview(t, correct, t.card("strike"), "e0", "returns 1 energy")
		play(t, correct, "strike", "e0")
		play(t, reversed, "strike", "e0")
		play(t, reversed, "poisoned_blade", "e0", "m1")
		t.check(correct.energy == 2 and reversed.energy == 1 and correct.hand.size() == draw_count, "Applying an ally's status before the stalker's attack yields a real order-dependent energy/draw payoff")
		var energy_before: int = correct.energy
		var pile_before: int = correct.draw_pile.size()
		play(t, correct, "strike", "e0")
		t.check(correct.energy == energy_before - 1 and correct.hand.is_empty() and correct.draw_pile.size() == pile_before, "Further attacks cannot repeat the stalker's refund or draw")
		var fresh = formed(t, form)
		fixed_draw(fresh, t)
		energy_before = fresh.energy
		play(t, fresh, "firebolt", "e0")
		t.check(fresh.energy == energy_before - 1 and fresh.hand.is_empty(), "New affliction from the stalker's own current card cannot satisfy its pre-action setup")

func test_snapshots(t) -> void:
	for form in ["green_ogre", "ancient_ogre", "red_ogre", "oni", "basilisk", "ember_basilisk", "shadow_stalker", "nightstalker"]:
		var battle = formed(t, form)
		fixed_draw(battle, t)
		var ability: String = "strike"
		if form in ["green_ogre", "ancient_ogre"]: play(t, battle, "guard", "m1")
		elif form in ["red_ogre", "oni"]: battle._status(battle.enemies[0], "burn", 1)
		else: battle._status(battle.enemies[0], "poison", 1)
		if form in ["basilisk", "ember_basilisk"]: ability = "snare"
		battle.hand = [t.card(ability)]
		var snapshot: Dictionary = battle.to_dict()
		t.check(snapshot.has("form_state"), "Snapshots carry the form's pending/used turn state: " + form)
		var restored = Combat.new()
		restored.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
		t.check(t.same_saved_value(snapshot, restored.to_dict()), "Restoring a pending tactical snapshot preserves hand, statuses, form state, intentions and RNG")
		t.check(battle.play_card(0, "e0") and restored.play_card(0, "e0") and t.same_saved_value(battle.to_dict(), restored.to_dict()), "Saved and uninterrupted tactical payoff produce identical complete results")
		var used: Dictionary = battle.to_dict()
		var resumed = Combat.new()
		resumed.restore(used, used["monster_combat"].duplicate(true), RandomNumberGenerator.new())
		t.check(t.same_saved_value(used, resumed.to_dict()), "Reloading an already used form payoff cannot replay an energy/card/status reward")
		if form in ["green_ogre", "ancient_ogre"]:
			play(t, battle, "guard", "m1")
			play(t, resumed, "guard", "m1")
		var repeat_target: String = "e1" if form in ["basilisk", "ember_basilisk"] else "e0"
		if repeat_target == "e1":
			battle._status(battle.enemies[1], "poison", 1)
			resumed._status(resumed.enemies[1], "poison", 1)
		var energy_before: int = resumed.energy
		var pile_before: int = resumed.draw_pile.size()
		play(t, battle, ability, repeat_target)
		play(t, resumed, ability, repeat_target)
		t.check(resumed.energy == energy_before - 1 and resumed.hand.is_empty() and resumed.draw_pile.size() == pile_before and t.same_saved_value(battle.to_dict(), resumed.to_dict()), "Used tactical payoff cannot refund or draw again after Continue")
		battle.end_turn()
		resumed.end_turn()
		t.check(t.same_saved_value(battle.to_dict(), resumed.to_dict()), "Form state resets at the same next-turn boundary after reload")
		var old: Dictionary = snapshot.duplicate(true)
		old.erase("form_state")
		var legacy = Combat.new()
		legacy.restore(old, old["monster_combat"].duplicate(true), RandomNumberGenerator.new())
		t.check(legacy.hand == old["hand"] and legacy.intents == old["intents"] and str(legacy.rng.state) == old["rng_state"], "Legacy snapshot without form state gains defaults without rerolling its hand or locked intentions")
	var game = t.state_at("form_pending_continue")
	game.new_run(6451)
	game.run["monsters"][0]["form"] = "green_ogre"
	game.run["monsters"][0]["max_hp"] = Data.FORMS["green_ogre"]["max_hp"]
	game.start_raid()
	var owner: String = game.run["monsters"][0]["id"]
	game.battle.hand = [t.card("guard", owner, "saved_guard"), t.card("strike", owner, "saved_attack")]
	t.check(game.play_card(0, game.run["monsters"][1]["id"]), "Authoritative run action saves a pending protection combo")
	var before: Dictionary = game.battle.to_dict()
	var continued = t.state_at("form_pending_continue")
	t.check(continued.load_game() and t.same_saved_value(before, continued.battle.to_dict()), "Real Continue preserves the pending form combo along with its recorded action")
	var target: String = game.battle.enemies[0]["id"]
	t.check(game.play_card(0, target) and continued.play_card(0, target) and t.same_saved_value(game.battle.to_dict(), continued.battle.to_dict()), "Real saved run and uninterrupted run resolve the same readied form attack exactly once")

func test_trait_combination(t) -> void:
	var people: Array = t.roster()
	people[2]["form"] = "nightstalker"
	var random := RandomNumberGenerator.new()
	random.seed = 9153
	var battle = Combat.new()
	battle.setup(people, [t.enemy()], random, ["pack_instinct"])
	fixed_draw(battle, t)
	battle._status(battle.enemies[0], "poison", 1)
	battle.hand = [t.card("strike", "m0", "first"), t.card("guard", "m1", "second"), t.card("quick_jab", "m2", "third")]
	t.check(battle.play_card(0, "e0") and battle.play_card(0, "m1"), "Two ordinary owner actions prepare an actual Pack Instinct combination")
	read_only_preview(t, battle, battle.hand[0], "e0", "returns 1 energy")
	t.check(battle.play_card(0, "e0") and battle.energy == 3 and battle.hand.size() == 2 and battle.draw_pile.size() == 2, "Third owner's zero-cost Nightstalker combo and Pack Instinct each award their own exact energy/card reward")
	play(t, battle, "quick_jab", "e0", "m2")
	t.check(battle.energy == 3 and battle.hand.is_empty() and battle.draw_pile.size() == 2, "Further zero-cost actions cannot recursively repeat either completed combo")

func test_tactical_cards(t) -> void:
	var battle = t.fixture()
	battle.energy = 0
	play(t, battle, "quick_jab", "e0")
	t.check(battle.energy == 0 and battle.enemies[0]["hp"] == 497 and battle.hand.is_empty(), "Quick Jab is a low-damage zero-energy action, with no free draw")
	battle = t.fixture()
	battle.enemies[0]["armor"] = 2
	battle.enemies[0]["block"] = 50
	read_only_preview(t, battle, t.card("shatter_guard"), "e0", "5 HP")
	play(t, battle, "shatter_guard", "e0")
	t.check(battle.enemies[0]["block"] == 0 and battle.enemies[0]["hp"] == 495, "Shatter Guard removes Block before its seven-damage hit while respecting permanent Armor")
	for form in ["green_ogre", "ancient_ogre"]:
		var shield = formed(t, form)
		var block: int = 6 if form == "green_ogre" else 7
		read_only_preview(t, shield, t.card("shield_bash"), "e0", "+%d block" % block)
		play(t, shield, "shield_bash", "e0")
		play(t, shield, "strike", "e0")
		t.check(shield.enemies[0]["hp"] == 489 and shield.monsters[0]["block"] == block, "Shield Bash previews passive-adjusted self Block and cannot falsely satisfy protecting another ally")

func tactical_enemy(t, actor_class: String, abilities: Array) -> Dictionary:
	var actor: Dictionary = t.enemy("e0")
	actor["class_name"] = actor_class
	actor["form"] = actor_class
	actor["abilities"] = abilities
	actor["tactics"] = true
	return actor

func resilient(t) -> Array:
	var people: Array = t.roster()
	for index in range(people.size()):
		people[index]["hp"] = 900 + index * 50
		people[index]["max_hp"] = 1000
	return people

func test_invaders(t) -> void:
	var kits = {
		"warrior": ["heavy_blow", "strike", "shatter_guard"],
		"defender": ["shield_bash", "shield_wall", "heavy_blow", "shatter_guard"],
		"mage": ["firebolt", "arcane_bolt", "ember_burst"],
		"rogue": ["poisoned_blade", "smoke_step", "quick_jab", "strike"],
		"controller": ["snare", "arcane_bolt", "smoke_step"],
		"priest": ["arcane_bolt", "mend", "regrowth"]
	}
	var schedules = {
		"warrior": ["heavy_blow", "strike", "shatter_guard", "strike", "heavy_blow", "shatter_guard"],
		"defender": ["shield_bash", "shield_wall", "shatter_guard", "shield_bash", "shield_wall", "shatter_guard"],
		"mage": ["firebolt", "arcane_bolt", "ember_burst", "arcane_bolt", "firebolt", "ember_burst"],
		"rogue": ["poisoned_blade", "quick_jab", "smoke_step", "poisoned_blade", "quick_jab", "smoke_step"],
		"controller": ["snare", "arcane_bolt", "snare", "arcane_bolt", "snare", "arcane_bolt"],
		"priest": ["arcane_bolt", "arcane_bolt", "mend", "arcane_bolt", "arcane_bolt", "regrowth"]
	}
	for actor_class in kits:
		var enemy: Dictionary = tactical_enemy(t, actor_class, kits[actor_class])
		if actor_class == "priest": enemy["hp"] = 250
		var battle = t.fixture(resilient(t), [enemy])
		for round_number in range(6):
			t.check(battle.intents[0]["ability"] == schedules[actor_class][round_number], "Actual announced class cadence follows its readable attack/support rhythm: " + actor_class)
			t.check(enemy["abilities"].has(battle.intents[0]["ability"]), "Every scheduled intent comes from the invader's actual inheritable pool")
			var before: Dictionary = battle.to_dict()
			for repeat in range(3):
				Tactics.description(battle.enemies[0])
				Tactics.choose_ability(battle, battle.enemies[0], enemy["abilities"])
			t.check(t.same_saved_value(before, battle.to_dict()), "Inspecting schedule/copy consumes no RNG or rerolls the announced target")
			if round_number < 5: battle.end_turn()
		var initial = t.fixture(resilient(t), [enemy])
		if actor_class == "warrior": t.check(initial.intents[0]["target_id"] == "m2", "Warrior openly targets the highest current HP monster")
		if actor_class == "rogue": t.check(initial.intents[0]["target_id"] == "m0", "Rogue openly targets the lowest current HP monster")
	var healthy_priest = t.fixture(resilient(t), [tactical_enemy(t, "priest", kits["priest"])])
	for round_number in range(6):
		t.check(healthy_priest.intents[0]["ability"] == "arcane_bolt", "Healthy priest keeps pressure instead of wasting each third round on empty healing")
		if round_number < 5: healthy_priest.end_turn()
	var legacy_actions: Dictionary = {}
	for seed_value in range(16):
		var old: Dictionary = t.enemy("e0")
		old["abilities"] = ["guard", "strike"]
		var random := RandomNumberGenerator.new()
		random.seed = seed_value + 137
		var battle = Combat.new()
		battle.setup(resilient(t), [old], random)
		legacy_actions[battle.intents[0]["ability"]] = true
		t.check(Tactics.description(battle.enemies[0]) == "", "Unflagged legacy invaders do not advertise a newly imposed cadence")
		var current: Dictionary = old.duplicate(true)
		current["tactics"] = true
		var coherent = t.fixture(resilient(t), [current])
		t.check(coherent.intents[0]["ability"] == "strike" and coherent.intents[0]["target_id"] == "m2", "A flagged incomplete warrior kit still prefers its actual attack to idle defense")
	t.check(legacy_actions.has("guard") and legacy_actions.has("strike"), "Existing unflagged parties retain the prior varied ability selection")
	var seen: Dictionary = {}
	var guaranteed = {
		1: {"slot": 0, "skill": "shield_bash"},
		2: {"slot": 1, "skill": "ember_burst"},
		3: {"slot": 1, "skill": "shatter_guard"},
		4: {"slot": 0, "skill": "quick_jab"}
	}
	for seed_value in range(24):
		var random := RandomNumberGenerator.new()
		random.seed = seed_value + 7381
		for raid in range(6):
			var party: Array = Data.generate_party(raid, random)
			for enemy in party:
				t.check(enemy.get("tactics", false), "Newly generated actual invaders opt into readable tactics")
				if raid == 0:
					t.check(not enemy["abilities"].any(func(id): return id in ["shield_bash", "quick_jab", "ember_burst", "shatter_guard"]), "Introductory raid excludes every new pool skill for each tested seed")
				for ability in enemy["abilities"]:
					if ability in ["shield_bash", "quick_jab", "ember_burst", "shatter_guard"]:
						seen[ability] = true
						t.check(raid > 0, "Introductory raid retains its controlled original skill pools")
			if guaranteed.has(raid):
				var guarantee: Dictionary = guaranteed[raid]
				var recipient: Dictionary = party[guarantee["slot"]]
				var skill: String = guarantee["skill"]
				t.check(recipient["abilities"].has(skill), "Each seed guarantees the milestone's new skill in the actual invader kit: " + skill)
				var possible: Array = Data.inheritance_outcomes(recipient["abilities"], t.roster()[0]["learned"])
				t.check(possible.any(func(outcome): return outcome["ability"] == skill and outcome["chance"] > 0.0), "Guaranteed owned milestone skill is a real possible random inheritance: " + skill)
				var demonstration = t.fixture(resilient(t), [recipient])
				var announced: bool = false
				for round_number in range(3):
					announced = announced or demonstration.intents[0]["ability"] == skill
					if round_number < 2: demonstration.end_turn()
				t.check(announced, "The actual milestone invader announces its guaranteed skill within the first three rounds: " + skill)
	for ability in ["shield_bash", "quick_jab", "ember_burst", "shatter_guard"]:
		t.check(seen.has(ability), "Seeded later parties provide the new tactical card as a real transferable skill: " + ability)

func test_marshal(t) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 9162
	var marshal: Dictionary = Data.generate_party(5, random)[0]
	var battle = t.fixture(resilient(t), [marshal])
	t.check(marshal.get("champion", "") == "iron_marshal" and marshal["abilities"].has("breach_order"), "Final champion owns her actual inheritable block-breaking attack")
	battle.end_turn()
	t.check(battle.turn == 2 and battle.intents[0]["ability"] == "breach_order", "Marshal visibly announces whole-pack Block removal on round two")
	for monster in battle.monsters: monster["block"] = 40
	var hp_before: Array = battle.monsters.map(func(monster): return monster["hp"])
	battle.end_turn()
	t.check(battle.monsters.map(func(monster): return monster["hp"]) == hp_before.map(func(hp): return hp - 6), "The announced Breach Order removes forty Block before dealing six HP damage to each monster")
	var controlled = t.fixture(resilient(t), [marshal])
	controlled.end_turn()
	play(t, controlled, "snare_dungeon", controlled.enemies[0]["id"], "")
	hp_before = controlled.monsters.map(func(monster): return monster["hp"])
	controlled.end_turn()
	t.check(controlled.monsters.map(func(monster): return monster["hp"]) == hp_before and controlled.enemies[0]["statuses"].get("resolve", 0) == 1, "A real announced-action stun cancels the whole block-breaking champion action and grants Resolve")
