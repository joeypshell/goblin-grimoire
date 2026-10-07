extends "res://tests/test_runner.gd"

# Bounded developer diagnostic, not a human playtest or an estimated win rate.
# Normal State APIs own all parties, damage, corpses, weighted rolls and rewards.
# Feeding concentrates on the first recipient and uses the existing earned-form
# helper (which knows the developer recipe ordering). Combat sees only current
# forms, actual learned skills, locked intents and the offered party preview.
const SEEDS: Array = [730204, 101, 730215, 730205]
const RAID_TURN_BOUND: int = 24
const POLICY_TURN_BOUND: int = 72
const POLICY_ATTEMPT_BOUND: int = 3

var diagnostic_rows: Array = []
var total_stores: int = 0
var total_smashes: int = 0
var total_cross_turn_smashes: int = 0
var total_drums: int = 0
var total_wards: int = 0
var total_rituals: int = 0
var completed_policies: int = 0

func _run() -> void:
	profile_root = "user://verification/first_act_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(profile_root)
	print("FIRST ACT DIAGNOSTIC: ", profile_root)
	print("Policy: concentrated actual-corpse feeding, earned visible forms, learned form-aware slots, actual offered traits, protection-aware tactical probes. No grants, HP resets, uploader or run-report upload.")
	for seed_value in SEEDS:
		for route in ["standard", "alternate"]:
			diagnostic_rows.append(_simulate_policy(int(seed_value), str(route)))
	# The normal score-based policies may correctly pick off the captain's allies
	# first, never triggering a ward. A separate targeted policy attacks the
	# captain first with real available cards to exercise that opposing strategy.
	var captain_focus: Dictionary = _simulate_policy(730205, "standard", true)
	check(completed_policies > 0, "At least one normal seeded policy completes all first three raids")
	check(total_stores > 0 and total_smashes > 0, "Actual earned Green/Ancient Ogre stores and spends Bulwark in first-act combat")
	check(total_cross_turn_smashes > 0, "At least one actual earned Ogre spends a charge stored on an earlier turn")
	check(total_drums > 0, "An earned War Drums trait activates during normal first-act combat")
	check(total_wards > 0, "A real standard second-raid ward captain protects an ally after surviving player damage")
	check(total_rituals > 0, "A real alternate second-raid priest announces Renewal Ritual")
	DirAccess.make_dir_recursive_absolute("res://build")
	var file := FileAccess.open("res://build/first_act_playtest_results.json", FileAccess.WRITE)
	check(file != null, "Ignored diagnostic JSON output opens")
	var report: Dictionary = {"scope": "first three raids of six; eight bounded developer policies, not casual-player win rates or fun evidence", "profile_root": profile_root,
		"policy": "concentrated first-recipient feeding through actual corpse rolls; existing earned-form priority; learned protection loadout after earned War Drums; state-copy tactical card probes", "raid_turn_bound": RAID_TURN_BOUND,
		"policy_turn_bound": POLICY_TURN_BOUND, "completed_policies": completed_policies, "bulwark_stores": total_stores, "stored_smashes": total_smashes,
		"cross_turn_smashes": total_cross_turn_smashes, "war_drums": total_drums, "captain_wards": total_wards, "rituals_announced": total_rituals,
		"checks": checks, "failures": failures, "policies": diagnostic_rows, "captain_first_consequence_policy": captain_focus}
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("FIRST ACT RESULT: %d checks; %d failures; %d/9 developer policies complete (8 comparison policies + separate captain-first consequence policy); %d stores / %d smashes (%d across turns), %d War Drums, %d wards, %d rituals" % [checks, failures.size(), completed_policies, total_stores, total_smashes, total_cross_turn_smashes, total_drums, total_wards, total_rituals])
	for failure in failures: print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func position_value(battle) -> float:
	var score: float = super.position_value(battle)
	# Visible persistent charges, usable energy and newly drawn cards have value.
	# The bonus is less than the eventual damage score, so it cannot incentivize
	# endless protecting instead of cashing out an attack when available.
	for monster in battle.monsters:
		if int(monster["hp"]) > 0 and monster["form"] in ["green_ogre", "ancient_ogre"] and battle.form_state.get(monster["id"], {}).get("ready", false):
			score += 7.0 if monster["form"] == "green_ogre" else 9.0
	score += float(battle.energy) * 0.5 + float(battle.hand.size()) * 1.2
	return score

func _configure_protection_loadout(game) -> void:
	configure_loadout(game)
	if not game.run.get("traits", []).has("war_drums"): return
	for monster in game.run["monsters"]:
		if monster["form"] in ["goblin", "green_ogre", "ancient_ogre"] and monster["selected"][0] != "guard":
			check(game.set_selected(monster["id"], 1, "guard"), "War Drums policy equips the actually learned Guard to protect another monster")

func _simulate_policy(seed_value: int, route: String, captain_first: bool = false) -> Dictionary:
	var game = state_at("seed_%d_%s%s" % [seed_value, route, "_captain_first" if captain_first else ""])
	game.new_run(seed_value)
	var row: Dictionary = {"seed": seed_value, "second_raid_route": route, "target_policy": "captain first on raid 2; mechanic consequence exercise" if captain_first else "position score", "attempts": [], "meals": [], "trait_rewards": [], "ended_turns": 0, "card_plays": 0, "defeats": 0}
	var attempt_count: int = 0
	while int(game.run["raid"]) < 3 and game.run["phase"] != "defeat" and attempt_count < POLICY_ATTEMPT_BOUND and int(row["ended_turns"]) < POLICY_TURN_BOUND:
		check(game.run["phase"] == "prep", "First-act attempt begins in normal preparation")
		if game.run["phase"] != "prep": break
		game.party_preview()
		if int(game.run["raid"]) == 1 and not game.run.get("party_locked", false):
			check(game.select_party(route), "Second-raid policy chooses an actually offered party")
		_configure_protection_loadout(game)
		var party: Array = game.party_preview().duplicate(true)
		var raid_number: int = int(game.run["raid"]) + 1
		var incoming_identity: Array = party.map(func(actor): return {"id": actor["id"], "class": actor["class_name"], "abilities": actor["abilities"].duplicate(), "rule": actor.get("encounter_rule", "")})
		game.start_raid()
		check(game.run["phase"] == "combat", "Normal preparation starts actual first-act combat")
		check(JSON.stringify(game.battle.enemies.map(func(actor): return actor["abilities"])) == JSON.stringify(party.map(func(actor): return actor["abilities"])), "Actual combat retains previewed corpse ability identities")
		var attempt: Dictionary = _fight(game, captain_first and raid_number == 2)
		attempt["raid"] = raid_number
		attempt["party"] = incoming_identity
		attempt["forms"] = game.run["monsters"].map(func(actor): return actor["form"])
		attempt["selected"] = game.run["monsters"].map(func(actor): return actor["selected"].duplicate())
		row["attempts"].append(attempt)
		row["ended_turns"] += int(attempt["ended_turns"])
		row["card_plays"] += int(attempt["card_plays"])
		attempt_count += 1
		print("  seed %d %s%s raid %d: %d turns / %d plays; %s; forms %s; Drums %d, smash %d (%d across turns), ward %d, ritual %d announced / %d used / %d canceled" % [seed_value, route, " captain-first" if captain_first else "", raid_number, attempt["ended_turns"], attempt["card_plays"], game.run["phase"], str(attempt["forms"]), attempt["war_drums"], attempt["stored_smashes"], attempt["cross_turn_smashes"], attempt["captain_wards"], attempt["rituals_announced"], attempt["rituals_used"], attempt["rituals_canceled"]])
		if game.run["phase"] == "combat":
			check(false, "First-act tactical attempt respects %d-turn bound (seed %d %s raid %d)" % [RAID_TURN_BOUND, seed_value, route, raid_number])
			break
		if game.run["phase"] == "feeding":
			feed_campaign(game, false)
			for body in game.run["rewards"]:
				row["meals"].append({"raid": raid_number, "body": body["id"], "actual_pool": body["abilities"].duplicate(), "recipient": body.get("recipient", ""), "taken": body.get("taken", ""), "weight": Data.INHERITANCE_WEIGHTS.get(Data.ABILITIES.get(body.get("taken", ""), {}).get("rarity", ""), 0), "skipped": body.get("skipped", false)})
			check(game.finish_feeding(), "First-act feeding completes through normal recovery and raid advancement")
			var offered: Array = game.trait_choices()
			var owned_before: Array = game.run.get("traits", []).duplicate()
			choose_campaign_trait(game, ["war_drums", "spiteful_shields", "venom_nest", "pack_instinct"])
			if not offered.is_empty():
				var selected: Array = game.run.get("traits", []).filter(func(id): return not owned_before.has(id))
				check(selected.size() == 1 and offered.has(selected[0]), "First-act reward policy selects only an actually offered trait")
				row["trait_rewards"].append({"raid": raid_number, "offered": offered, "chosen": selected[0] if not selected.is_empty() else ""})
		else:
			check(game.run["phase"] == "defeat" and game.run["monsters"].all(func(monster): return monster["hp"] == 0) and game.run["rewards"].is_empty(), "First-act full wipe immediately destroys the dungeon without recovery, rewards or retries")
			row["defeats"] += 1
		if game.run["phase"] == "result" and int(game.run["raid"]) < 3: game.continue_after_result()
	row["completed"] = int(game.run["raid"]) == 3
	row["ending_phase"] = game.run["phase"]
	check(not game.run.has("core") and int(row["defeats"]) <= 1, "First-act policy has no separate dungeon HP and ends on its first full wipe")
	row["final_forms"] = game.run["monsters"].map(func(actor): return actor["form"])
	row["final_traits"] = game.run.get("traits", []).duplicate()
	if row["completed"]: completed_policies += 1
	check(int(row["ended_turns"]) < POLICY_TURN_BOUND or row["completed"] or game.run["phase"] == "defeat", "First-act policy respects its total turn bound")
	return row

func _fight(game, captain_first: bool = false) -> Dictionary:
	var stats: Dictionary = {"ended_turns": 0, "card_plays": 0, "bulwark_stores": 0, "stored_smashes": 0, "cross_turn_smashes": 0, "war_drums": 0, "captain_wards": 0, "rituals_announced": 0, "rituals_used": 0, "rituals_canceled": 0, "ritual_cancellation_reasons": [], "payoff_cards": []}
	var charge_turn: Dictionary = {}
	while game.run["phase"] == "combat" and int(stats["ended_turns"]) < RAID_TURN_BOUND:
		var rituals: Array = game.battle.intents.filter(func(intent): return intent["ability"] == "renewal_ritual").duplicate(true)
		stats["rituals_announced"] += rituals.size()
		for action in range(12):
			if game.run["phase"] != "combat": break
			var best_index: int = -1
			var best_target: String = ""
			var best_gain: float = 0.1
			var baseline: float = position_value(game.battle)
			for index in range(game.battle.hand.size()):
				var value: Dictionary = game.battle.hand[index]
				if int(Data.ABILITIES[value["ability"]]["cost"]) > game.battle.energy: continue
				for target in game.battle.legal_targets(value):
					var copy = clone_battle(game)
					if not copy.play_card(index, str(target)): continue
					var gain: float = (position_value(copy) - baseline) / maxf(1.0, float(Data.ABILITIES[value["ability"]]["cost"]))
					if captain_first:
						for captain in game.battle.enemies:
							if captain.get("encounter_rule", "") == "ward_captain" and int(captain["hp"]) > int(copy.get_actor(captain["id"]).get("hp", 0)):
								gain += 100.0
					if copy.outcome == "won": gain += 1000.0
					if gain > best_gain:
						best_gain = gain
						best_index = index
						best_target = str(target)
			if best_index < 0: break
			var played_card: Dictionary = game.battle.hand[best_index].duplicate(true)
			check(game.play_card(best_index, best_target), "First-act policy plays a real legal card through normal State API")
			stats["card_plays"] += 1
			_record_card_logs(game.battle, played_card, best_target, stats, charge_turn)
		for intent in rituals:
			var priest: Dictionary = game.battle.get_actor(intent["enemy_id"])
			var cancellation: String = ""
			if int(priest.get("hp", 0)) <= 0: cancellation = "priest defeated"
			elif int(priest.get("statuses", {}).get("stun", 0)) > 0: cancellation = "priest stunned"
			elif game.run["phase"] != "combat": cancellation = "battle ended"
			if cancellation != "":
				stats["rituals_canceled"] += 1
				stats["ritual_cancellation_reasons"].append({"turn": game.battle.turn, "priest": intent["enemy_id"], "reason": cancellation})
		if game.run["phase"] == "combat":
			game.end_turn()
			stats["ended_turns"] += 1
			for line in game.battle.action_log:
				if str(line).contains(" uses Renewal Ritual."): stats["rituals_used"] += 1
				if str(line).contains("Renewal Ritual has no wounded ally left"):
					stats["rituals_canceled"] += 1
					stats["ritual_cancellation_reasons"].append({"turn": game.battle.turn, "reason": "no wounded ally remains"})
	stats["war_drums"] = game.battle.trait_state.get("trigger_counts", {}).get("war_drums", 0)
	stats["result"] = game.battle.outcome
	total_stores += int(stats["bulwark_stores"])
	total_smashes += int(stats["stored_smashes"])
	total_cross_turn_smashes += int(stats["cross_turn_smashes"])
	total_drums += int(stats["war_drums"])
	total_wards += int(stats["captain_wards"])
	total_rituals += int(stats["rituals_announced"])
	return stats

func _record_card_logs(battle, card_value: Dictionary, target: String, stats: Dictionary, charge_turn: Dictionary) -> void:
	var owner_id: String = str(card_value.get("owner", ""))
	for line_value in battle.action_log:
		var line: String = str(line_value)
		if line.contains("Bulwark STORED,"):
			stats["bulwark_stores"] += 1
			charge_turn[owner_id] = battle.turn
		elif line.contains("unleashes stored Bulwark:"):
			stats["stored_smashes"] += 1
			var cross_turn: bool = int(charge_turn.get(owner_id, battle.turn)) < battle.turn
			if cross_turn: stats["cross_turn_smashes"] += 1
			stats["payoff_cards"].append({"turn": battle.turn, "owner": owner_id, "ability": card_value["ability"], "target": target, "stored_on_turn": charge_turn.get(owner_id, battle.turn), "cross_turn": cross_turn, "log": battle.action_log.duplicate()})
			charge_turn.erase(owner_id)
		elif line.begins_with("WARD / "): stats["captain_wards"] += 1
