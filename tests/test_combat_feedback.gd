extends RefCounted

const Feedback = preload("res://scripts/combat_feedback.gd")

func run(t) -> void:
	t.group("numeric charge receipts distinguish attack bonuses from actual damage")
	for form in ["green_ogre", "ancient_ogre"]:
		for defense in ["armor", "evade", "block", "overkill", "area"]:
			var people: Array = t.roster()
			people[0]["form"] = form
			var battle = t.fixture(people, [t.enemy("e0"), t.enemy("e1")])
			battle.energy = 10
			battle.hand = [t.card("guard")]
			t.check(battle.play_card(0, "m1"), "Receipt fixture stores its charge through a real protection card")
			var victim: Dictionary = battle.enemies[0]
			if defense == "armor": victim["armor"] = 1
			if defense == "evade": battle._status(victim, "evasion", 1)
			if defense == "block": victim["block"] = 100
			if defense == "overkill": victim["hp"] = 1
			battle.hand = [t.card("ember_burst" if defense == "area" else "strike")]
			var before: Dictionary = battle.to_dict()
			t.check(battle.play_card(0, "e0"), "Receipt fixture accepts a charged attack: " + defense)
			var after: Dictionary = battle.to_dict()
			var bonus: int = 14 if form == "ancient_ogre" else 10
			var expected: String = "Rook: BULWARK +%d attack bonus per hit" % bonus
			var saved_before: Dictionary = before.duplicate(true)
			var receipt: String = Feedback.describe(before, after)
			t.check(receipt.begins_with(expected), "Numeric charged payoff leads the action receipt: " + receipt)
			t.check(Feedback.bulwark_payoffs(before, after).size() == 1, "One card produces one charged payoff receipt, including area attacks")
			var hp_lost: int = int(before["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"])
			if hp_lost > 0: t.check(receipt.contains("-%d HP" % hp_lost), "Actual HP loss is separately reported after defenses and overkill")
			else: t.check(not receipt.contains("HP"), "Absorbed or evaded bonus is not presented as HP damage")
			if defense == "evade": t.check(receipt.contains("Evaded"), "Evaded charge clearly shows both the bonus spent and avoided hit")
			for repeat in range(4): Feedback.describe(before, after)
			t.check(t.same_saved_value(before, saved_before) and t.same_saved_value(after, battle.to_dict()), "Reading a payoff receipt preserves authoritative counters, battle and RNG")
			t.check(Feedback.bulwark_payoffs(after, after).is_empty(), "Refresh without a new action cannot produce another charge receipt")
