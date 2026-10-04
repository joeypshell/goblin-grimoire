class_name GameData
extends RefCounted

# All tuning and transferable effects live here. Targets are relative to the caster.
const BALANCE = {
	"recovery": 0.25, "breach": 25, "core": 100, "energy": 3, "hand": 5,
	"raids": 6, "dot_decay": 1
}
const ABILITIES = {
	"strike": {"name": "Strike", "cost": 1, "target": "enemy", "affinity": "Neutral", "description": "Deal 6 damage.", "effects": [{"kind": "damage", "amount": 6}]},
	"guard": {"name": "Guard", "cost": 1, "target": "ally", "affinity": "Neutral", "description": "Give an ally 7 block until their next turn.", "effects": [{"kind": "block", "amount": 7}]},
	"patch_up": {"name": "Patch Up", "cost": 1, "target": "ally", "affinity": "Neutral", "description": "Restore 6 HP to a living ally. Cycles normally and can be reused.", "effects": [{"kind": "heal", "amount": 6}]},
	"mend": {"name": "Mend", "cost": 1, "target": "ally", "affinity": "Vitality", "description": "Restore 6 HP to a living ally. Cycles normally and can be reused.", "effects": [{"kind": "heal", "amount": 6}]},
	"stab": {"name": "Goblin Stab", "cost": 1, "target": "enemy", "affinity": "Neutral", "description": "Deal 5 damage.", "effects": [{"kind": "damage", "amount": 5}]},
	"rally": {"name": "Dungeon Rally", "cost": 1, "target": "all_allies", "affinity": "Neutral", "description": "Give every living monster 5 block.", "effects": [{"kind": "block", "amount": 5}]},
	"core_pulse": {"name": "Core Pulse", "cost": 1, "target": "all_allies", "affinity": "Neutral", "description": "Restore 4 HP to every living monster. Repeatable.", "effects": [{"kind": "heal", "amount": 4}]},
	"snare_dungeon": {"name": "Dungeon Snare", "cost": 1, "target": "enemy", "affinity": "Neutral", "description": "Deal 2 damage and stun for one announced action.", "effects": [{"kind": "damage", "amount": 2}, {"kind": "status", "status": "stun", "amount": 1}]},
	"heavy_blow": {"name": "Heavy Blow", "cost": 1, "target": "enemy", "affinity": "Might", "description": "Deal 8 damage.", "effects": [{"kind": "damage", "amount": 8}]},
	"shield_wall": {"name": "Shield Wall", "cost": 1, "target": "all_allies", "affinity": "Guard", "description": "Give all living allies 7 block.", "effects": [{"kind": "block", "amount": 7}]},
	"firebolt": {"name": "Firebolt", "cost": 1, "target": "enemy", "affinity": "Flame", "description": "Deal 5 damage and add 2 burning.", "effects": [{"kind": "damage", "amount": 5}, {"kind": "status", "status": "burn", "amount": 2}]},
	"poisoned_blade": {"name": "Poisoned Blade", "cost": 1, "target": "enemy", "affinity": "Venom", "description": "Deal 4 damage and add 3 poison.", "effects": [{"kind": "damage", "amount": 4}, {"kind": "status", "status": "poison", "amount": 3}]},
	"snare": {"name": "Snare", "cost": 1, "target": "enemy", "affinity": "Control", "description": "Deal 3 damage and stun. A stunned adventurer loses its next announced action; a stunned monster cannot play owned cards next turn.", "effects": [{"kind": "damage", "amount": 3}, {"kind": "status", "status": "stun", "amount": 1}]},
	"smoke_step": {"name": "Smoke Step", "cost": 1, "target": "self", "affinity": "Trickery", "description": "Gain 4 block and evade the next damaging hit.", "effects": [{"kind": "block", "amount": 4}, {"kind": "status", "status": "evasion", "amount": 1}]},
	"arcane_bolt": {"name": "Arcane Bolt", "cost": 1, "target": "enemy", "affinity": "Mystic", "description": "Deal 7 damage.", "effects": [{"kind": "damage", "amount": 7}]},
	"regrowth": {"name": "Regrowth", "cost": 1, "target": "ally", "affinity": "Vitality", "description": "Add 3 regeneration: heal its strength at faction turn end, then decay by 1. Reapplications add strength.", "effects": [{"kind": "status", "status": "regen", "amount": 3}]},
	"ogre_aegis": {"name": "Ogre Aegis", "cost": 1, "target": "all_allies", "affinity": "Guard", "description": "Give every ally 8 block; your passive adds 2 more.", "effects": [{"kind": "block", "amount": 8}]},
	"burning_cleave": {"name": "Burning Cleave", "cost": 1, "target": "all_enemies", "affinity": "Flame", "description": "Deal 4 damage and add 2 burning to every foe; your passive adds another 1.", "effects": [{"kind": "damage", "amount": 4}, {"kind": "status", "status": "burn", "amount": 2}]},
	"petrifying_gaze": {"name": "Petrifying Gaze", "cost": 1, "target": "enemy", "affinity": "Control", "description": "Add 4 poison and stun one action; your passive adds 1 more poison.", "effects": [{"kind": "status", "status": "poison", "amount": 4}, {"kind": "status", "status": "stun", "amount": 1}]},
	"ambush": {"name": "Ambush", "cost": 1, "target": "enemy", "affinity": "Trickery", "description": "Deal 9 damage and gain one evasion. Gain +2 damage against a foe with a harmful status.", "effects": [{"kind": "damage", "amount": 9}, {"kind": "status", "status": "evasion", "amount": 1, "to": "self"}]},
	"spirit_flame": {"name": "Spirit Flame", "cost": 1, "target": "all_enemies", "affinity": "Mystic", "description": "Deal 6 damage and add 2 burning to all foes. Your Mystic passive adds 2 damage.", "effects": [{"kind": "damage", "amount": 6}, {"kind": "status", "status": "burn", "amount": 2}]},
	"ember_venom": {"name": "Ember Venom", "cost": 1, "target": "all_enemies", "affinity": "Venom", "description": "Deal 3 damage and add 4 poison to all foes. Poison also adds 2 burning.", "effects": [{"kind": "damage", "amount": 3}, {"kind": "status", "status": "poison", "amount": 4}]}
}
const FORMS = {
	"goblin": {"name": "Goblin", "max_hp": 20, "signature": "stab", "passive": "Scrappy beginnings. Learn from the invaders you consume.", "color": "80b66d"},
	"green_ogre": {"name": "Green Ogre", "max_hp": 36, "signature": "ogre_aegis", "passive": "Bulwark: your block cards grant 2 additional block to each target.", "color": "68ac71"},
	"red_ogre": {"name": "Red Ogre", "max_hp": 32, "signature": "burning_cleave", "passive": "Kindling: each of your damage cards adds 1 burning to its victims.", "color": "db7961"},
	"basilisk": {"name": "Basilisk", "max_hp": 28, "signature": "petrifying_gaze", "passive": "Venom gland: your poison applications gain 1 strength.", "color": "a2be63"},
	"shadow_stalker": {"name": "Shadow Stalker", "max_hp": 26, "signature": "ambush", "passive": "Opportunist: deal 2 extra damage to foes with poison, burning, or stun.", "color": "a399d1"},
	"oni": {"name": "Oni", "max_hp": 44, "signature": "spirit_flame", "passive": "Spirit mastery: your Mystic and Flame damage cards deal 2 extra damage.", "color": "e4a174"},
	"ember_basilisk": {"name": "Ember Basilisk", "max_hp": 40, "signature": "ember_venom", "passive": "Volatile venom: your poison applications also add 2 burning.", "color": "dfb464"}
}
const RECIPES = [
	{"id": "green_ogre", "source": "goblin", "result": "green_ogre", "affinities": ["Might", "Guard"], "feeds": 2},
	{"id": "red_ogre", "source": "goblin", "result": "red_ogre", "affinities": ["Might", "Flame"], "feeds": 2},
	{"id": "basilisk", "source": "goblin", "result": "basilisk", "affinities": ["Venom", "Control"], "feeds": 2},
	{"id": "shadow_stalker", "source": "goblin", "result": "shadow_stalker", "affinities": ["Trickery", "Mystic"], "feeds": 2},
	{"id": "oni", "source": "red_ogre", "result": "oni", "affinities": ["Mystic"], "feeds": 4},
	{"id": "ember_basilisk", "source": "basilisk", "result": "ember_basilisk", "affinities": ["Flame"], "feeds": 4}
]
const CLASSES = {
	"warrior": {"name": "Warrior", "pool": ["heavy_blow", "strike", "guard"], "base_hp": 15, "names": ["Bran", "Torren", "Edric"]},
	"defender": {"name": "Defender", "pool": ["shield_wall", "heavy_blow", "guard"], "base_hp": 18, "names": ["Vera", "Oswin", "Mara"]},
	"rogue": {"name": "Rogue", "pool": ["poisoned_blade", "smoke_step", "strike"], "base_hp": 13, "names": ["Kestrel", "Dax", "Silas"]},
	"mage": {"name": "Mage", "pool": ["firebolt", "arcane_bolt"], "base_hp": 12, "names": ["Iris", "Caldus", "Senna"]},
	"priest": {"name": "Priest", "pool": ["mend", "regrowth", "arcane_bolt"], "base_hp": 14, "names": ["Sister Edda", "Brother Sol", "Aster"]},
	"controller": {"name": "Controller", "pool": ["snare", "arcane_bolt", "smoke_step"], "base_hp": 13, "names": ["Wren", "Vale", "Orrin"]}
}
const RANKS = {
	"F": {"name": "F", "playable": true, "raids": 3}, "E": {"name": "E", "playable": true, "raids": 3},
	"D": {"name": "D", "playable": false, "raids": 0}, "C": {"name": "C", "playable": false, "raids": 0},
	"B": {"name": "B", "playable": false, "raids": 0}, "A": {"name": "A", "playable": false, "raids": 0},
	"S": {"name": "S", "playable": false, "raids": 0}
}
const ENCOUNTERS = [
	{"name": "Torchlight Scouts", "classes": ["warrior", "mage", "rogue"], "forced": [["heavy_blow"], ["firebolt", "arcane_bolt"], ["smoke_step", "poisoned_blade"]], "hp_bonus": 0},
	{"name": "The Iron Company", "classes": ["defender", "controller", "rogue"], "forced": [["shield_wall", "heavy_blow"], ["snare"], ["poisoned_blade"]], "hp_bonus": 3},
	{"name": "F Champion · The Cinder Banner", "classes": ["warrior", "mage", "priest"], "forced": [["heavy_blow"], ["firebolt", "arcane_bolt"], ["regrowth", "mend"]], "hp_bonus": 7},
	{"name": "Ashen Expedition", "classes": ["mage", "defender", "controller"], "forced": [["firebolt", "arcane_bolt"], ["shield_wall", "heavy_blow"], ["snare", "smoke_step"]], "hp_bonus": 9},
	{"name": "Sanctum Hunters", "classes": ["rogue", "priest", "warrior"], "forced": [["poisoned_blade", "smoke_step"], ["regrowth", "mend"], ["heavy_blow"]], "hp_bonus": 12},
	{"name": "E Champion · The Corebreakers", "classes": ["defender", "mage", "controller"], "forced": [["shield_wall", "heavy_blow"], ["firebolt", "arcane_bolt"], ["snare", "arcane_bolt"]], "hp_bonus": 17}
]

static func new_monster(id: String, monster_name: String) -> Dictionary:
	var health: int = int(FORMS["goblin"]["max_hp"])
	return {"id": id, "name": monster_name, "form": "goblin", "hp": health, "max_hp": health,
		"learned": ["strike", "guard", "patch_up"], "selected": ["strike", "patch_up"], "consumed": [], "feeds": 0,
		"block": 0, "statuses": {}}

static func eligible(monster: Dictionary) -> Array:
	var affinities: Array = []
	var seen: Array = []
	for ability_id in monster.get("consumed", []):
		if seen.has(ability_id) or not ABILITIES.has(ability_id):
			continue
		seen.append(ability_id)
		var affinity: String = ABILITIES[ability_id]["affinity"]
		if not affinities.has(affinity):
			affinities.append(affinity)
	var choices: Array = []
	for recipe in RECIPES:
		if recipe["source"] != monster["form"] or int(monster["feeds"]) < int(recipe["feeds"]):
			continue
		var matches: bool = true
		for requirement in recipe["affinities"]:
			if not affinities.has(requirement):
				matches = false
		if matches:
			choices.append(recipe.duplicate(true))
	return choices

static func generate_party(raid_index: int, rng: RandomNumberGenerator) -> Array:
	var index: int = clampi(raid_index, 0, ENCOUNTERS.size() - 1)
	var encounter: Dictionary = ENCOUNTERS[index]
	var party: Array = []
	for slot in range(encounter["classes"].size()):
		var class_id: String = encounter["classes"][slot]
		var template: Dictionary = CLASSES[class_id]
		var skills: Array = encounter["forced"][slot].duplicate()
		var extras: Array = template["pool"].duplicate()
		var extra = extras[rng.randi_range(0, extras.size() - 1)]
		if not skills.has(extra):
			skills.append(extra)
		var hp: int = int(template["base_hp"]) + int(encounter["hp_bonus"]) + rng.randi_range(0, 2)
		var actor_name: String = template["names"][rng.randi_range(0, template["names"].size() - 1)]
		if index == 2 and slot == 0:
			actor_name = "Captain Torren"
		if index == 5 and slot == 0:
			actor_name = "Marshal Vera"
		party.append({"id": "raid_%d_foe_%d" % [index, slot], "name": actor_name,
			"class_name": class_id, "form": class_id, "hp": hp, "max_hp": hp,
			"abilities": skills, "block": 0, "statuses": {}})
	return party
