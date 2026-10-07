extends RefCounted

# Choices steer a run without changing the random skill inherited from a body.
const MILESTONES = [1, 3]
const DEFINITIONS = {
	"venom_nest": {
		"name": "Venom Nest",
		"description": "When a poisoned invader is defeated, add 2 poison to every surviving invader. Each application decays separately.",
		"hint": "Poison a foe, then finish it. Look for Poisoned Blade and Venom affinities."
	},
	"spiteful_shields": {
		"name": "Spiteful Shields",
		"description": "Whenever a living monster's Block absorbs an invader's direct attack, it retaliates for 3 damage. Armor, Block and Evasion can reduce the retaliation.",
		"hint": "Protect announced targets with Guard, Dungeon Rally or Shield Wall. Armor and Evasion alone do not trigger retaliation."
	},
	"pack_instinct": {
		"name": "Pack Instinct",
		"description": "Play cards from three different monsters in one turn to gain 1 energy and draw 1 card. Once per turn; dungeon cards do not count.",
		"hint": "Keep the whole pack alive and equip affordable cards across all three monsters."
	},
	"war_drums": {
		"name": "War Drums",
		"description": "The first monster-owned card each turn that gives Block to another living monster grants 1 energy and draws 1 card. Once per turn; protecting yourself and shared dungeon cards do not count.",
		"hint": "Guard another monster to keep your turn going. Shared and self-only protection do not count."
	}
}

static func choices(owned: Array) -> Array:
	var result: Array = []
	for id in DEFINITIONS:
		if not owned.has(id): result.append(id)
	return result

static func first_offer(seed_value: int, owned: Array = []) -> Array:
	var available: Array = choices(owned)
	var offered: Array = []
	var random := RandomNumberGenerator.new()
	# A separate seed-derived stream never changes combat or corpse inheritance.
	random.seed = seed_value ^ (int(MILESTONES[0]) * 104729) ^ 0x74726169
	for pick in range(mini(2, available.size())):
		var index: int = random.randi_range(0, available.size() - 1)
		offered.append(available[index])
		available.remove_at(index)
	return offered

static func milestone(run: Dictionary) -> String:
	var raid := int(run.get("raid", 0))
	if run.get("phase", "") == "trait":
		return "REWARD READY: Choose a dungeon trait that lasts for this run."
	if raid == 0 and run.get("trait_milestones", []).has(int(MILESTONES[0])):
		return "FIRST TRAIT CHOSEN: Feed the fallen, then recover. F champion victory earns your second dungeon trait."
	match raid:
		0: return "NEXT REWARD: Win this raid to choose your first dungeon trait."
		1: return "One raid until the F champion. Champion victory earns a second dungeon trait."
		2: return "F CHAMPION NEXT: Defeat Captain Torren to earn a second dungeon trait and reach rank E."
		3: return "Two raids until the E champion. Build around your two dungeon traits."
		4: return "One raid until the E champion. Champion victory completes the campaign and earns rank D."
		5: return "FINAL CHAMPION: Victory completes the campaign and earns rank D."
	return "Campaign complete. Try another dungeon trait combination in a new run."
