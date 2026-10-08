extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const Traits = preload("res://scripts/battle_traits.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Feedback = preload("res://scripts/combat_feedback.gd")
const Replay = preload("res://scripts/battle_replay.gd")
const SPELLS = ["soul_harvest", "renewal_wave", "plague_bloom", "ember_storm", "arcane_sweep", "shatter_wave", "hunters_mark", "sanctuary", "echo_rune", "battle_orders", "wild_growth", "cinder_seed"]

func run(t) -> void:
	t.group("shared spell roles, targeting, defense, healing, Echo and perk state")
	test_data_and_deck(t)
	test_area_defenses(t)
	test_healing(t)
	test_plague(t)
	test_soul_harvest(t)
	test_orders(t)
	test_mark(t)
	test_echo(t)
	test_perks(t)
	test_preview_snapshot_replay(t)

func fixture(t, active_traits: Array = [], party: Array = [], people: Array = []):
	var random := RandomNumberGenerator.new()
	random.seed = 516204
	var battle = Combat.new()
	battle.setup(t.roster() if people.is_empty() else people, [t.enemy()] if party.is_empty() else party, random, active_traits)
	battle.energy = 20
	battle.hand = []
	battle.draw_pile = []
	battle.discard = []
	for index in range(12): battle.draw_pile.append(t.card("strike", "m1", "spell_draw_%d" % index))
	return battle

func play(t, battle, ability: String, target: String, owner: String = "") -> void:
	battle.hand = [t.card(ability, owner)]
	t.check(battle.play_card(0, target), "Spell fixture accepts actual legal play: " + ability)

func rejected_unchanged(t, battle, ability: String, target: String, owner: String = "") -> void:
	battle.hand = [t.card(ability, owner)]
	var before: Dictionary = battle.to_dict()
	var action_before: Array = battle.action_log.duplicate()
	t.check(not battle.play_card(0, target), "Spell fixture rejects unavailable or invalid action: " + ability)
	t.check(t.same_saved_value(before, battle.to_dict()) and action_before == battle.action_log, "Rejected spell preserves complete state, RNG and action receipt: " + ability)

func triggers(battle, id: String) -> int:
	return int(battle.trait_state.get("trigger_counts", {}).get(id, 0))

func clone(battle):
	var result = Combat.new()
	result.restore(JSON.parse_string(JSON.stringify(battle.to_dict())), battle.monsters.duplicate(true), RandomNumberGenerator.new())
	return result

func test_data_and_deck(t) -> void:
	for id in SPELLS:
		var definition: Dictionary = Data.ABILITIES[id]
		t.check(definition.get("shared_only", false) and int(definition["cost"]) > 0 and definition.get("role", "") in ["heal", "area", "utility"], "Dungeon reward is a positive-cost shared spell with a tactical role: " + id)
		for template in Data.CLASSES.values(): t.check(not template["pool"].has(id), "Shared reward is absent from corpse class pools: " + id)
		var battle = fixture(t)
		rejected_unchanged(t, battle, id, "m0" if definition["target"] == "all_allies" else "e0", "m0")
		t.check(Copy.unavailable(battle, t.card(id)).length() > 0, "Unavailable shared spell is explained when owned: " + id)
	t.check(Data.inheritance_outcomes(SPELLS, []).is_empty(), "Unusual saved corpse pools cannot teach unusable owned shared spells")
	t.check(Data.inheritance_outcomes(SPELLS + ["strike"], []).size() == 1, "Shared-only filtering preserves normal weighted inheritance")
	var random := RandomNumberGenerator.new()
	random.seed = 21
	var custom = Combat.new()
	custom.setup(t.roster(), [t.enemy()], random, [], ["arcane_sweep", "wild_growth", "battle_orders"])
	var shared: Array = []
	for card in t.all_cards(custom):
		if card["owner"] == "": shared.append(card["ability"])
	t.check(t.all_cards(custom).size() == 12 and shared.size() == 3 and shared.has("arcane_sweep") and shared.has("wild_growth") and shared.has("battle_orders"), "Selected shared spells replace starter slots without changing twelve-card deck")
	var old = t.fixture()
	shared = []
	for card in t.all_cards(old):
		if card["owner"] == "": shared.append(card["ability"])
	t.check(shared.size() == 3 and shared.has("rally") and shared.has("core_pulse") and shared.has("snare_dungeon"), "Four-argument callers retain the original starter shared cards")

func test_area_defenses(t) -> void:
	var battle = fixture(t, [], [t.enemy("a"), t.enemy("b"), t.enemy("c")])
	battle.enemies[0]["armor"] = 1
	battle.enemies[1]["block"] = 3
	battle._status(battle.enemies[2], "evasion", 1)
	play(t, battle, "arcane_sweep", "a")
	t.check(battle.enemies[0]["hp"] == 498 and battle.enemies[1]["hp"] == 500 and battle.enemies[1]["block"] == 0 and battle.enemies[2]["hp"] == 500 and not battle.enemies[2]["statuses"].has("evasion"), "Arcane Sweep applies each foe's Armor, spent Block and Evade independently")
	battle = fixture(t, [], [t.enemy("a"), t.enemy("b"), t.enemy("c")])
	for foe in battle.enemies: foe["block"] = 50
	battle.enemies[0]["armor"] = 2
	battle._status(battle.enemies[1], "evasion", 1)
	play(t, battle, "shatter_wave", "a")
	t.check(battle.enemies[0]["hp"] == 498 and battle.enemies[1]["hp"] == 500 and battle.enemies[2]["hp"] == 496, "Shatter Wave clears Block before every hit while respecting Armor and Evade")
	for foe in battle.enemies: t.check(foe["block"] == 0, "Even an evaded Shatter Wave removes Block")
	battle = fixture(t, [], [t.enemy("a", "guard", 3), t.enemy("b"), t.enemy("c")])
	battle._status(battle.enemies[1], "evasion", 1)
	battle.enemies[2]["armor"] = 3
	play(t, battle, "ember_storm", "a")
	t.check(battle.enemies[0]["hp"] == 0 and battle.enemies[0]["statuses"].is_empty(), "AoE status rider cannot apply after its target is knocked out")
	t.check(battle.enemies[1]["hp"] == 500 and battle.enemies[1]["statuses"]["burn"] == 2 and battle.enemies[2]["statuses"]["burn"] == 2, "Ember Storm Burn applies to surviving foes even when its direct hit is prevented")
	battle = fixture(t)
	play(t, battle, "cinder_seed", "e0")
	t.check(battle.enemies[0]["hp"] == 498 and battle.enemies[0]["status_layers"]["burn"] == [2], "Cinder Seed provides one direct setup hit and independently decaying Burn")

func test_healing(t) -> void:
	var battle = fixture(t)
	rejected_unchanged(t, battle, "renewal_wave", "m0")
	t.check(Copy.unavailable(battle, t.card("renewal_wave", "")).contains("No missing HP"), "Party heal explains its no-op restriction")
	battle.monsters[0]["hp"] = 10
	battle.monsters[1]["hp"] = 0
	battle._status(battle.monsters[0], "poison", 3)
	battle._status(battle.monsters[2], "burn", 2)
	play(t, battle, "renewal_wave", "m0")
	t.check(battle.monsters[0]["hp"] == 15 and battle.monsters[1]["hp"] == 0 and battle.monsters[1]["statuses"].is_empty(), "Renewal Wave heals wounded living monsters without reviving KOs")
	t.check(not battle.monsters[0]["statuses"].has("poison") and not battle.monsters[2]["statuses"].has("burn"), "Renewal Wave cleanses wounded and full-HP living recipients")
	play(t, battle, "renewal_wave", "m0")
	t.check(battle.monsters[0]["hp"] == 20, "Renewal Wave remains repeatable while meaningful healing remains")
	rejected_unchanged(t, battle, "renewal_wave", "m0")
	battle = fixture(t)
	battle.monsters[0]["hp"] = 5
	battle.monsters[1]["hp"] = 0
	play(t, battle, "wild_growth", "m0")
	play(t, battle, "wild_growth", "m0")
	t.check(battle.monsters[0]["hp"] == 5 and battle.monsters[0]["status_layers"]["regen"] == [2, 2] and battle.monsters[1]["statuses"].is_empty(), "Wild Growth stacks separate delayed healing applications only on living monsters")
	battle.end_turn()
	t.check(battle.monsters[0]["hp"] == 9 and battle.monsters[0]["status_layers"]["regen"] == [1, 1] and battle.monsters[1]["hp"] == 0, "Stacked Regen heals and decays at player turn end without revival")
	battle = fixture(t)
	battle.monsters[0]["hp"] = 18
	battle.monsters[1]["hp"] = 0
	play(t, battle, "sanctuary", "m0")
	t.check(battle.monsters[0]["block"] == 6 and battle.monsters[0]["statuses"]["regen"] == 1 and battle.monsters[1]["block"] == 0, "Sanctuary gives living party protection and delayed regeneration")
	battle.end_turn()
	t.check(battle.monsters[0]["hp"] == 19 and battle.monsters[0]["block"] == 0 and not battle.monsters[0]["statuses"].has("regen"), "Sanctuary Regen ticks once; ordinary Block clears at the next player turn")

func test_plague(t) -> void:
	var battle = fixture(t, [], [t.enemy("a"), t.enemy("b"), t.enemy("c"), t.enemy("dead")])
	rejected_unchanged(t, battle, "plague_bloom", "a")
	t.check(Copy.unavailable(battle, t.card("plague_bloom", "")).contains("poisoned") and battle.preview(t.card("plague_bloom", ""), "a").contains("poisoned"), "Both card and target preview explain Poison setup requirement")
	battle._status(battle.enemies[0], "poison", 3)
	battle._status(battle.enemies[0], "poison", 2)
	battle._status(battle.enemies[1], "poison", 2)
	battle.enemies[3]["hp"] = 0
	t.check(battle.legal_targets(t.card("plague_bloom", "")) == ["a", "b"], "Plague Bloom highlights poisoned living sources only")
	rejected_unchanged(t, battle, "plague_bloom", "c")
	var rng_before: int = battle.rng.state
	play(t, battle, "plague_bloom", "a")
	t.check(battle.enemies[0]["status_layers"]["poison"] == [3, 2] and battle.enemies[1]["status_layers"]["poison"] == [2, 5] and battle.enemies[2]["status_layers"]["poison"] == [5] and battle.enemies[3]["statuses"].is_empty(), "Plague Bloom copies aggregate source strength as a fresh layer, preserves source layers and skips KOs")
	t.check(battle.rng.state == rng_before, "Poison spreading consumes no gameplay RNG")
	battle = fixture(t)
	battle._status(battle.enemies[0], "poison", 4)
	rejected_unchanged(t, battle, "plague_bloom", "e0")

func test_soul_harvest(t) -> void:
	var battle = fixture(t, ["blood_cauldron", "venom_nest"], [t.enemy("a", "guard", 4), t.enemy("b", "guard", 4), t.enemy("c")])
	battle.monsters[0]["hp"] = 10
	battle.monsters[1]["max_hp"] = 36
	battle.monsters[1]["hp"] = 25
	battle.monsters[2]["hp"] = 0
	battle._status(battle.enemies[0], "poison", 2)
	var before: Dictionary = battle.to_dict()
	var preview: String = battle.preview(t.card("soul_harvest", ""), "a")
	t.check(preview.contains("Rook heals 5") and preview.contains("Moss heals 5") and preview.contains("Blood Cauldron") and t.same_saved_value(before, battle.to_dict()), "Soul Harvest preview predicts each kill's wounded-percentage target without modifying combat")
	play(t, battle, "soul_harvest", "a")
	t.check(battle.monsters[0]["hp"] == 15 and battle.monsters[1]["hp"] == 30 and battle.monsters[2]["hp"] == 0, "Each direct Soul Harvest kill heals once and recalculates wounded HP percentage without resurrection")
	t.check(triggers(battle, "blood_cauldron") == 1 and battle.hand.size() == 1 and triggers(battle, "venom_nest") == 2, "Two actual kill heals trigger Blood Cauldron once while existing poisoned-death chains remain bounded")
	t.check(battle.enemies[2]["hp"] == 496, "Poison spread adds status rather than recursively creating Soul Harvest kills")
	battle = fixture(t, [], [t.enemy("a", "guard", 4)])
	battle.monsters[1]["max_hp"] = 36
	battle.monsters[1]["hp"] = 25
	play(t, battle, "soul_harvest", "a")
	t.check(battle.monsters[0]["hp"] == 20 and battle.monsters[1]["hp"] == 30, "Soul Harvest chooses a wounded ogre over a lower raw-HP healthy goblin")
	battle = fixture(t, [], [t.enemy("a", "guard", 4), t.enemy("b", "guard", 4)])
	battle.monsters[0]["hp"] = 10
	battle.enemies[0]["block"] = 4
	battle._status(battle.enemies[1], "evasion", 1)
	play(t, battle, "soul_harvest", "a")
	t.check(battle.monsters[0]["hp"] == 10 and battle.enemies[0]["hp"] == 4 and battle.enemies[1]["hp"] == 4, "Blocked and evaded non-kills never cause Soul Harvest healing")
	battle = fixture(t, [], [t.enemy("a", "guard", 4)])
	battle.monsters[0]["hp"] = 10
	battle.monsters[1]["hp"] = 10
	play(t, battle, "soul_harvest", "a")
	t.check(battle.monsters[0]["hp"] == 15 and battle.monsters[1]["hp"] == 10, "Equal HP-percentage healing targets break ties by stable roster order")

func test_orders(t) -> void:
	var battle = fixture(t)
	var rng_before: int = battle.rng.state
	play(t, battle, "battle_orders", "m0")
	t.check(battle.hand.size() == 2 and battle.draw_pile.size() == 10 and battle.energy == 19 and battle.rng.state == rng_before, "Battle Orders draws two once rather than twice per party member")
	battle = fixture(t)
	battle.monsters[1]["hp"] = 0
	battle.monsters[2]["hp"] = 0
	for card in battle.draw_pile: card["owner"] = "m0"
	play(t, battle, "battle_orders", "m0")
	t.check(battle.hand.size() == 2, "Battle Orders draw count is independent of living party size")
	battle = fixture(t)
	battle.draw_pile = []
	battle.discard = []
	battle.energy = 3
	for _index in range(3):
		play(t, battle, "battle_orders", "m0")
		t.check(battle.hand.size() == 1 and battle.hand[0]["ability"] == "battle_orders", "Orders can cycle its own card without inventing extra cards")
	rejected_unchanged(t, battle, "battle_orders", "m0")
	t.check(battle.energy == 0, "Positive draw-card cost bounds a one-card redraw loop to available energy")

func test_mark(t) -> void:
	var battle = fixture(t)
	play(t, battle, "hunters_mark", "e0")
	t.check(battle.enemies[0]["hp"] == 497 and battle.enemies[0]["statuses"]["marked"] == 4 and Copy.status(battle.enemies[0]).contains("next owned hit +4"), "Hunter's Mark is a visible stored next-owned-hit debuff")
	play(t, battle, "hunters_mark", "e0")
	t.check(battle.enemies[0]["statuses"]["marked"] == 4, "Hunter's Mark reapplication cannot stack its bonus")
	play(t, battle, "arcane_sweep", "e0")
	t.check(battle.enemies[0]["hp"] == 491 and battle.enemies[0]["statuses"]["marked"] == 4, "Shared direct attacks neither benefit from nor consume the owned-hit mark")
	play(t, battle, "wild_growth", "m0")
	t.check(battle.enemies[0]["statuses"]["marked"] == 4, "Support spells do not consume Hunter's Mark")
	var before: Dictionary = battle.to_dict()
	play(t, battle, "strike", "e0", "m0")
	t.check(battle.enemies[0]["hp"] == 481 and not battle.enemies[0]["statuses"].has("marked") and Feedback.describe(before, battle.to_dict()).contains("Hunter's Mark spent"), "Owned direct hit adds four damage and visibly spends Hunter's Mark once")
	for defense in ["armor", "block", "evade"]:
		battle = fixture(t)
		battle._status(battle.enemies[0], "marked", 4)
		if defense == "armor": battle.enemies[0]["armor"] = 30
		if defense == "block": battle.enemies[0]["block"] = 30
		if defense == "evade": battle._status(battle.enemies[0], "evasion", 1)
		play(t, battle, "strike", "e0", "m0")
		t.check(battle.enemies[0]["hp"] == 500 and not battle.enemies[0]["statuses"].has("marked"), "Accepted owned hit spends mark even when prevented by " + defense)
	battle = fixture(t)
	battle._status(battle.enemies[0], "marked", 4)
	battle._status(battle.enemies[0], "poison", 2)
	battle.end_turn()
	t.check(battle.enemies[0]["hp"] == 498 and battle.enemies[0]["statuses"]["marked"] == 4, "Damage over time and invader actions do not use a monster-owned-hit debuff")

func test_echo(t) -> void:
	var battle = fixture(t, ["pack_instinct", "war_drums"])
	var before: Dictionary = battle.to_dict()
	play(t, battle, "echo_rune", "m0")
	t.check(battle.dungeon_state["echo_ready"] and battle.energy == 18 and Copy.dungeon_status(battle).contains("ECHO ARMED") and Feedback.describe(before, battle.to_dict()).contains("Echo armed"), "Echo has a visible saved one-charge state and costs two energy")
	rejected_unchanged(t, battle, "echo_rune", "m0")
	t.check(battle.preview(t.card("echo_rune", ""), "m0").contains("already armed"), "Echo rearm restriction is explained in target preview")
	play(t, battle, "guard", "m1", "m0")
	play(t, battle, "arcane_sweep", "e0")
	t.check(battle.dungeon_state["echo_ready"], "Owned support and shared attacks keep the stored Echo charge")
	battle.end_turn()
	t.check(battle.dungeon_state["echo_ready"], "Echo charge persists through ordinary end-turn resolution")
	battle.energy = 20
	battle.enemies[0]["armor"] = 1
	battle.enemies[0]["block"] = 3
	battle._status(battle.enemies[0], "evasion", 1)
	battle._status(battle.enemies[0], "marked", 4)
	var hp_before: int = battle.enemies[0]["hp"]
	before = battle.to_dict()
	play(t, battle, "firebolt", "e0", "m0")
	t.check(battle.enemies[0]["hp"] == hp_before - 1 and battle.enemies[0]["block"] == 0 and not battle.enemies[0]["statuses"].has("marked"), "Echo second hit has its own Armor/Block check after first hit spends Evade and Hunter's Mark")
	t.check(battle.enemies[0]["status_layers"]["burn"] == [2] and not battle.dungeon_state["echo_ready"], "Echo repeats direct hits while Burn rider applies once and charge is consumed")
	t.check(int(battle.recap_state["cards_played"]) == int(before["recap_state"]["cards_played"]) + 1 and battle.trait_state["owners"] == ["m0"] and Feedback.describe(before, battle.to_dict()).contains("ECHO:"), "Echo records one played card and one owner action with a visible repeat receipt")
	var people: Array = t.roster()
	people[0]["form"] = "green_ogre"
	people[0]["max_hp"] = 28
	people[0]["hp"] = 28
	battle = fixture(t, [], [t.enemy("a"), t.enemy("b")], people)
	play(t, battle, "guard", "m1", "m0")
	play(t, battle, "echo_rune", "m0")
	play(t, battle, "ember_burst", "a", "m0")
	t.check(battle.enemies[0]["hp"] == 474 and battle.enemies[1]["hp"] == 474 and battle.enemies[0]["status_layers"]["burn"] == [1], "Echo repeats both AoE direct hits with one prepared Bulwark bonus and one status rider per foe")
	t.check(battle.recap_state["bulwark"]["m0"]["activations"] == 1 and battle.recap_state["bulwark"]["m0"]["bonus_total"] == 10 and not battle.form_state["m0"]["ready"], "Repeated Bulwark hits spend and count one charge rather than firing form counters twice")
	people = t.roster()
	people[0]["form"] = "oni"
	people[0]["max_hp"] = 34
	people[0]["hp"] = 34
	battle = fixture(t, [], [t.enemy("a"), t.enemy("b")], people)
	battle._status(battle.enemies[0], "burn", 1)
	play(t, battle, "echo_rune", "m0")
	var energy_before: int = battle.energy
	play(t, battle, "firebolt", "a", "m0")
	t.check(battle.enemies[0]["hp"] == 486 and battle.enemies[0]["status_layers"]["burn"] == [1, 2] and battle.enemies[1]["status_layers"]["burn"] == [2] and battle.energy == energy_before, "Echo repeats Oni damage but Fire chain spreads and refunds energy only once")
	battle = fixture(t, [], [t.enemy("e0", "guard", 6)])
	play(t, battle, "echo_rune", "m0")
	play(t, battle, "strike", "e0", "m0")
	t.check(battle.outcome == "won" and not battle.dungeon_state["echo_ready"] and battle.recap_state["cards_played"] == 2, "First-hit lethal attack consumes Echo without attacking or resurrecting an already-dead target")
	battle = fixture(t)
	play(t, battle, "echo_rune", "m0")
	battle.monsters[0]["hp"] = 0
	rejected_unchanged(t, battle, "strike", "e0", "m0")
	t.check(battle.dungeon_state["echo_ready"], "Rejected attack from a KO owner cannot consume Echo")
	battle = fixture(t)
	play(t, battle, "echo_rune", "m0")
	battle.enemies[0]["armor"] = 50
	play(t, battle, "strike", "e0", "m0")
	t.check(battle.enemies[0]["hp"] == 500 and not battle.dungeon_state["echo_ready"], "Two fully prevented accepted hits still consume the one Echo charge")
	people = t.roster()
	people[0]["form"] = "basilisk"
	people[0]["max_hp"] = 24
	people[0]["hp"] = 24
	battle = fixture(t, [], [t.enemy("a", "guard", 5), t.enemy("b")], people)
	battle._status(battle.enemies[0], "poison", 2)
	play(t, battle, "echo_rune", "m0")
	t.check(not battle.preview(t.card("snare", "m0"), "a").contains("Venom trap"), "Venom trap forecast does not promise a draw when Echo kills before the Stun rider")
	play(t, battle, "snare", "a", "m0")
	t.check(battle.enemies[0]["hp"] == 0 and battle.enemies[0]["statuses"].is_empty() and battle.hand.is_empty() and not battle.form_state["m0"]["used"], "Echo lethal Snare cannot stun a KO or double-trigger a Basilisk tactic")
	battle = fixture(t)
	battle.draw_pile = [t.card("guard", "m0")]
	battle.discard = []
	rejected_unchanged(t, battle, "echo_rune", "m0")
	t.check(Copy.unavailable(battle, t.card("echo_rune", "")).contains("No living owned attack"), "Echo cannot spend energy on a charge with no usable owned attack in the deck")

func test_perks(t) -> void:
	var battle = fixture(t, ["blood_cauldron"])
	play(t, battle, "patch_up", "m0", "m0")
	t.check(triggers(battle, "blood_cauldron") == 0, "Zero-HP healing never consumes Blood Cauldron eligibility")
	battle.monsters[0]["hp"] = 10
	play(t, battle, "wild_growth", "m0")
	t.check(triggers(battle, "blood_cauldron") == 0, "Adding delayed Regen does not count as a healing card")
	play(t, battle, "renewal_wave", "m0")
	t.check(triggers(battle, "blood_cauldron") == 1 and battle.hand.size() == 1, "First actual party healing draws exactly one Blood Cauldron card")
	play(t, battle, "patch_up", "m0", "m1")
	t.check(triggers(battle, "blood_cauldron") == 1 and battle.hand.is_empty(), "Repeated actual healing by another owner cannot repeat Blood Cauldron that turn")
	battle.end_turn()
	t.check(triggers(battle, "blood_cauldron") == 1 and not battle.trait_state["blood_cauldron_triggered"], "End-turn Regen does not trigger Blood Cauldron and next turn resets its eligibility")
	battle.monsters[0]["hp"] = 10
	play(t, battle, "patch_up", "m0", "m0")
	t.check(triggers(battle, "blood_cauldron") == 2, "Blood Cauldron can trigger on a later turn")
	battle = fixture(t, ["wildfire"], [t.enemy("a"), t.enemy("b"), t.enemy("c")])
	for foe in battle.enemies: foe["block"] = 3
	play(t, battle, "arcane_sweep", "a")
	t.check(triggers(battle, "wildfire") == 0 and not battle.trait_state["wildfire_triggered"], "Fully blocked shared AoE does not consume Wildfire")
	battle.enemies[1]["block"] = 3
	battle._status(battle.enemies[2], "evasion", 1)
	play(t, battle, "arcane_sweep", "a")
	t.check(triggers(battle, "wildfire") == 1 and battle.enemies[0]["status_layers"]["burn"] == [1] and not battle.enemies[1]["statuses"].has("burn") and not battle.enemies[2]["statuses"].has("burn"), "Wildfire only burns actual HP-damaged surviving recipients")
	play(t, battle, "ember_storm", "a")
	t.check(triggers(battle, "wildfire") == 1 and battle.enemies[0]["status_layers"]["burn"] == [1, 2], "A second shared area attack retains its normal rider but cannot repeat Wildfire that turn")
	battle.end_turn()
	play(t, battle, "ember_burst", "a", "m0")
	t.check(triggers(battle, "wildfire") == 1, "Owned area attack does not consume newly reset shared-only Wildfire")
	play(t, battle, "arcane_sweep", "a")
	t.check(triggers(battle, "wildfire") == 2, "Wildfire refreshes on a later turn")
	battle = fixture(t, ["wildfire"], [t.enemy("a", "guard", 3), t.enemy("b")])
	battle.enemies[1]["block"] = 3
	play(t, battle, "arcane_sweep", "a")
	t.check(triggers(battle, "wildfire") == 0 and battle.enemies[0]["statuses"].is_empty(), "A lethal-only area payoff does not burn KOs or spend Wildfire without a damaged survivor")
	battle = fixture(t, ["lingering_wards"])
	play(t, battle, "sanctuary", "m0")
	battle.monsters[1]["block"] = 2
	battle.monsters[2]["hp"] = 0
	battle.end_turn()
	t.check(battle.monsters[0]["block"] == 3 and battle.monsters[1]["block"] == 2 and battle.monsters[2]["block"] == 0 and triggers(battle, "lingering_wards") == 1, "Lingering Wards retains up to three surviving Block per living monster and counts one turn activation")
	t.check("\n".join(battle.action_log).contains("Rook keeps 3 Block"), "Kept Block has a precise Lingering Wards action receipt")
	play(t, battle, "rally", "m0")
	t.check(battle.monsters[0]["block"] == 8 and battle.monsters[1]["block"] == 7, "New Block stacks on retained Wards normally")
	battle = fixture(t, ["lingering_wards"], [t.enemy("e0", "strike")])
	battle.monsters[0]["block"] = 6
	battle.intents = [{"enemy_id": "e0", "ability": "strike", "target_id": "m0"}]
	battle.end_turn()
	t.check(battle.monsters[0]["block"] == 0 and triggers(battle, "lingering_wards") == 0, "Wards cannot invent Block after an attack spends all of it")
	battle = fixture(t, ["spellweaver"])
	play(t, battle, "battle_orders", "m0")
	play(t, battle, "heavy_blow", "e0", "m0")
	t.check(triggers(battle, "spellweaver") == 0, "Spellweaver ignores cheap shared and costly owned cards")
	var energy_before: int = battle.energy
	play(t, battle, "echo_rune", "m0")
	t.check(battle.energy == energy_before - 1 and triggers(battle, "spellweaver") == 1, "First accepted printed-cost-two shared spell refunds one after full cost")
	energy_before = battle.energy
	play(t, battle, "sanctuary", "m0")
	t.check(battle.energy == energy_before - 2 and triggers(battle, "spellweaver") == 1, "Later costly shared spells cannot repeat Spellweaver that turn")
	battle.end_turn()
	t.check(not battle.trait_state["spellweaver_triggered"], "Spellweaver eligibility resets next turn")
	battle.energy = 1
	rejected_unchanged(t, battle, "sanctuary", "m0")
	t.check(triggers(battle, "spellweaver") == 1, "Future refund never makes an upfront unaffordable spell playable")
	battle.energy = 3
	play(t, battle, "sanctuary", "m0")
	t.check(battle.energy == 2 and triggers(battle, "spellweaver") == 2, "Spellweaver can return energy again next turn")
	var people: Array = t.roster()
	people[0]["form"] = "ancient_ogre"
	people[0]["max_hp"] = 36
	people[0]["hp"] = 20
	battle = fixture(t, ["blood_cauldron", "war_drums", "pack_instinct", "spellweaver"], [], people)
	play(t, battle, "renewing_aegis", "m0", "m0")
	t.check(triggers(battle, "blood_cauldron") == 1 and triggers(battle, "war_drums") == 1 and triggers(battle, "spellweaver") == 0 and battle.hand.size() == 2 and battle.energy == 19, "Actual owned healing/protection independently rewards Blood Cauldron and War Drums once without triggering shared Spellweaver")
	t.check(battle.form_state["m0"]["ready"] and battle.trait_state["owners"] == ["m0"] and battle.recap_state["cards_played"] == 1, "Combined perk rewards keep Ancient Ogre charge and owner/card counters neutral")

func test_preview_snapshot_replay(t) -> void:
	var battle = fixture(t, ["blood_cauldron", "wildfire", "lingering_wards", "spellweaver"], [t.enemy("a"), t.enemy("b")])
	battle.monsters[0]["hp"] = 10
	battle._status(battle.enemies[0], "poison", 3)
	for ability in SPELLS:
		var card: Dictionary = t.card(ability, "")
		var before: Dictionary = battle.to_dict()
		var receipt: Array = battle.action_log.duplicate()
		for target in battle.legal_targets(card):
			var described: String = battle.preview(card, target)
			var copied: String = Copy.preview(battle, card, battle.get_actor(target))
			t.check(not described.is_empty() and not copied.is_empty(), "Legal new spell has nonempty target forecast: " + ability)
		Copy.card_effect(battle, card)
		Copy.guidance(battle, -1, false)
		Copy.unavailable(battle, card)
		t.check(t.same_saved_value(before, battle.to_dict()) and receipt == battle.action_log, "New spell preview/copy queries preserve full snapshot, RNG and log: " + ability)
	play(t, battle, "echo_rune", "m0")
	play(t, battle, "hunters_mark", "a")
	var before: Dictionary = battle.to_dict()
	var preview: String = battle.preview(t.card("strike", "m0"), "a")
	t.check(preview.contains("10 damage") and preview.contains("Echo: 6 damage") and preview.contains("Hunter's Mark spent") and t.same_saved_value(before, battle.to_dict()), "Owned forecast accurately shows first-hit mark bonus, unmarked Echo hit and immutable state")
	var restored = clone(battle)
	t.check(t.same_saved_value(battle.to_dict(), restored.to_dict()), "JSON-restored combat preserves Echo, marks, perk flags, piles, intents and RNG exactly")
	play(t, battle, "strike", "a", "m0")
	play(t, restored, "strike", "a", "m0")
	t.check(t.same_saved_value(battle.to_dict(), restored.to_dict()), "Identical actual attacks resolve identically after restored Echo/Mark state")
	var replay_before: Dictionary = battle.to_dict()
	var replay = Replay.make(battle)
	t.check(t.same_saved_value(replay_before, battle.to_dict()), "End-turn playback remains an observer of live new spell/perk state")
	var ordinary = clone(battle)
	ordinary.end_turn()
	t.check(t.same_saved_value(ordinary.to_dict(), replay.to_dict()), "Playback and ordinary end-turn agree with new persistent spell/perk state")
	var legacy: Dictionary = battle.to_dict()
	legacy.erase("dungeon_state")
	for key in ["blood_cauldron_triggered", "wildfire_triggered", "spellweaver_triggered"]: legacy["trait_state"].erase(key)
	for key in ["blood_cauldron", "wildfire", "lingering_wards", "spellweaver"]: legacy["trait_state"]["trigger_counts"].erase(key)
	var old = Combat.new()
	old.restore(legacy, battle.monsters.duplicate(true), RandomNumberGenerator.new())
	t.check(not old.dungeon_state["echo_ready"] and not old.trait_state["spellweaver_triggered"] and triggers(old, "blood_cauldron") == 0 and old.hand == battle.hand and old.rng.state == battle.rng.state, "Legacy snapshots gain neutral new defaults without replacing actual saved cards or RNG")
