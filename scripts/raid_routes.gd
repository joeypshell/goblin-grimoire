extends RefCounted

const Data = preload("res://scripts/game_data.gd")

# Comparable raid budgets, different threats and actual meals. Champions stay fixed.
const ALTERNATIVES = {
	1: {"name": "Runebound Pilgrims", "classes": ["warrior", "mage", "priest"],
		"forced": [["heavy_blow"], ["firebolt", "arcane_bolt"], ["mend", "regrowth"]], "hp_bonus": 1,
		"rules": ["", "", "ritual_priest"],
		"description": "Heavy hits and burning, backed by a 9-HP healing ritual. Save an interrupt for the priest. Their actual corpse may grant Renewal Ritual."},
	3: {"name": "Venom Seekers", "classes": ["rogue", "controller", "priest"],
		"forced": [["poisoned_blade", "smoke_step"], ["snare", "arcane_bolt"], ["mend", "regrowth"]], "hp_bonus": 4,
		"description": "Poison and control, backed by a healer. Plan for damage that bypasses your defenses."},
	4: {"name": "Iron Wardens", "classes": ["defender", "mage", "controller"],
		"forced": [["shield_wall", "heavy_blow"], ["firebolt", "arcane_bolt"], ["snare", "smoke_step"]], "hp_bonus": 6,
		"description": "An armored defender protects burning and control magic. Bring a way through their defenses."}
}
const STANDARD_DESCRIPTIONS = {
	1: "Hurting the ward captain shields another invader for 4 Block. Finish the captain or pick off their allies first; expect stun and poison.",
	3: "Burning and control magic behind an armored defender. Protect announced targets and break their Block.",
	4: "Poison, heavy hits and a healer. Removing the priest limits their recovery."
}

static func choices(raid: int, seed_value: int, standard_party: Array) -> Array:
	if not ALTERNATIVES.has(raid): return []
	var random := RandomNumberGenerator.new()
	# An independent stream leaves baseline combat and inheritance RNG untouched.
	random.seed = seed_value ^ ((raid + 1) * 104729) ^ 0x5a17c3
	var alternative: Dictionary = ALTERNATIVES[raid]
	return [
		{"id": "standard", "name": Data.ENCOUNTERS[raid]["name"], "description": STANDARD_DESCRIPTIONS[raid], "party": standard_party.duplicate(true)},
		{"id": "alternate", "name": alternative["name"], "description": alternative["description"], "party": Data.generate_party(raid, random, alternative)}
	]
