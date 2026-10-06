class_name GameData
extends RefCounted

# All tuning and transferable effects live here. Targets are relative to the caster.
const BALANCE = {
	"recovery": 0.25, "breach": 25, "core": 100, "energy": 3, "hand": 5,
	"raids": 6, "dot_decay": 1
}
const INHERITANCE_WEIGHTS = {"common": 4, "uncommon": 2, "rare": 1}
const ABILITIES = {
	"shield_bash": {"name": "Shield Bash", "rarity": "uncommon", "cost": 1, "target": "enemy", "affinity": "Guard", "description": "Deal 5 damage and give the owner 4 Block.", "effects": [{"kind": "damage", "amount": 5}, {"kind": "block", "amount": 4, "to": "self"}]},
	"ember_burst": {"name": "Ember Burst", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Flame", "description": "Deal 3 damage and add 1 Burn to every living foe.", "effects": [{"kind": "damage", "amount": 3}, {"kind": "status", "status": "burn", "amount": 1}]},
	"quick_jab": {"name": "Quick Jab", "rarity": "common", "cost": 0, "target": "enemy", "affinity": "Trickery", "description": "Deal 3 damage. Costs no energy; uses a card from your hand.", "effects": [{"kind": "damage", "amount": 3}]},
	"shatter_guard": {"name": "Shatter Guard", "rarity": "uncommon", "cost": 1, "target": "enemy", "affinity": "Might", "description": "Remove the target's Block, then deal 7 damage. Armor and Evade still apply.", "effects": [{"kind": "break_block", "amount": 0}, {"kind": "damage", "amount": 7}]},
	"breach_order": {"name": "Breach Order", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Guard", "description": "Remove all foes' Block, then deal 6 damage to each. Marshal Vera announces this on rounds 2, 5, 8...; stun or defeat her to cancel it.", "effects": [{"kind": "break_block", "amount": 0}, {"kind": "damage", "amount": 6}]},
	"strike": {"name": "Strike", "rarity": "common", "cost": 1, "target": "enemy", "affinity": "Neutral", "description": "Deal 6 damage.", "effects": [{"kind": "damage", "amount": 6}]},
	"guard": {"name": "Guard", "rarity": "common", "cost": 1, "target": "ally", "affinity": "Neutral", "description": "Give an ally 7 block until their next turn.", "effects": [{"kind": "block", "amount": 7}]},
	"patch_up": {"name": "Patch Up", "rarity": "common", "cost": 1, "target": "ally", "affinity": "Neutral", "description": "Restore 6 HP to a living ally. Cycles normally and can be reused.", "effects": [{"kind": "heal", "amount": 6}]},
	"mend": {"name": "Mend", "rarity": "common", "cost": 1, "target": "ally", "affinity": "Vitality", "description": "Restore 4 HP and remove all poison and burning from a living ally. Repeatable.", "effects": [{"kind": "heal", "amount": 4}, {"kind": "cleanse", "statuses": ["poison", "burn"]}]},
	"stab": {"name": "Goblin Stab", "rarity": "common", "cost": 1, "target": "enemy", "affinity": "Neutral", "description": "Deal 5 damage.", "effects": [{"kind": "damage", "amount": 5}]},
	"rally": {"name": "Dungeon Rally", "rarity": "common", "cost": 1, "target": "all_allies", "affinity": "Neutral", "description": "Give every living monster 5 block.", "effects": [{"kind": "block", "amount": 5}]},
	"core_pulse": {"name": "Core Pulse", "rarity": "common", "cost": 2, "target": "all_allies", "affinity": "Neutral", "description": "Restore 4 HP to every living monster. Repeatable.", "effects": [{"kind": "heal", "amount": 4}]},
	"snare_dungeon": {"name": "Dungeon Snare", "rarity": "common", "cost": 1, "target": "enemy", "affinity": "Neutral", "description": "Deal 2 damage and stun one action. After skipping, the target gains Resolve until it acts; further stun fails during Resolve.", "effects": [{"kind": "damage", "amount": 2}, {"kind": "status", "status": "stun", "amount": 1}]},
	"heavy_blow": {"name": "Heavy Blow", "rarity": "common", "cost": 2, "target": "enemy", "affinity": "Might", "description": "Deal 12 damage in one hit. Costs 2 energy; good against armor and for finishing a foe.", "effects": [{"kind": "damage", "amount": 12}]},
	"shield_wall": {"name": "Shield Wall", "rarity": "uncommon", "cost": 2, "target": "all_allies", "affinity": "Guard", "description": "Give all living allies 8 block. Costs 2 energy; protects several announced targets.", "effects": [{"kind": "block", "amount": 8}]},
	"firebolt": {"name": "Firebolt", "rarity": "uncommon", "cost": 1, "target": "enemy", "affinity": "Flame", "description": "Deal 5 damage and add burning that ticks 2, then 1. Each application decays separately and bypasses armor and block.", "effects": [{"kind": "damage", "amount": 5}, {"kind": "status", "status": "burn", "amount": 2}]},
	"poisoned_blade": {"name": "Poisoned Blade", "rarity": "uncommon", "cost": 1, "target": "enemy", "affinity": "Venom", "description": "Deal 4 damage and add poison that ticks 3, then 2, then 1. Each application decays separately and bypasses armor and block.", "effects": [{"kind": "damage", "amount": 4}, {"kind": "status", "status": "poison", "amount": 3}]},
	"snare": {"name": "Snare", "rarity": "uncommon", "cost": 1, "target": "enemy", "affinity": "Control", "description": "Deal 3 damage and stun one action or owned-card turn. Stun does not stack. After skipping, Resolve prevents another stun until the target acts.", "effects": [{"kind": "damage", "amount": 3}, {"kind": "status", "status": "stun", "amount": 1}]},
	"smoke_step": {"name": "Smoke Step", "rarity": "uncommon", "cost": 1, "target": "self", "affinity": "Trickery", "description": "Gain 4 block and evade the next damaging hit.", "effects": [{"kind": "block", "amount": 4}, {"kind": "status", "status": "evasion", "amount": 1}]},
	"arcane_bolt": {"name": "Arcane Bolt", "rarity": "common", "cost": 1, "target": "enemy", "affinity": "Mystic", "description": "Deal 7 damage.", "effects": [{"kind": "damage", "amount": 7}]},
	"regrowth": {"name": "Regrowth", "rarity": "rare", "cost": 1, "target": "ally", "affinity": "Vitality", "description": "Add a regeneration application healing 3, then 2, then 1 at your faction's turn end. Each reapplication decays separately. Repeatable.", "effects": [{"kind": "status", "status": "regen", "amount": 3}]},
	"banner_volley": {"name": "Banner Volley", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Flame", "description": "Deal 5 damage and add 1 burning to every foe. Captain Torren announces this every third round; stun him to cancel that action.", "effects": [{"kind": "damage", "amount": 5}, {"kind": "status", "status": "burn", "amount": 1}]},
	"ogre_aegis": {"name": "Ogre Aegis", "rarity": "rare", "cost": 2, "target": "all_allies", "affinity": "Guard", "description": "Give every ally 8 block; your passive adds 2 more. Costs 2 energy.", "effects": [{"kind": "block", "amount": 8}]},
	"burning_cleave": {"name": "Burning Cleave", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Flame", "description": "Deal 4 damage and add a 2-strength burning application to every foe; your passive adds a separate 1 burning. Costs 2 energy.", "effects": [{"kind": "damage", "amount": 4}, {"kind": "status", "status": "burn", "amount": 2}]},
	"petrifying_gaze": {"name": "Petrifying Gaze", "rarity": "rare", "cost": 2, "target": "enemy", "affinity": "Control", "description": "Add 4 poison and stun one action; your passive adds 1 poison strength. Resolve prevents consecutive stuns. Costs 2 energy.", "effects": [{"kind": "status", "status": "poison", "amount": 4}, {"kind": "status", "status": "stun", "amount": 1}]},
	"ambush": {"name": "Ambush", "rarity": "rare", "cost": 1, "target": "enemy", "affinity": "Trickery", "description": "Deal 9 damage and gain one evasion. Gain +2 damage against a foe with a harmful status.", "effects": [{"kind": "damage", "amount": 9}, {"kind": "status", "status": "evasion", "amount": 1, "to": "self"}]},
	"spirit_flame": {"name": "Spirit Flame", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Mystic", "description": "Deal 6 damage and add 2 burning to all foes. Your Mystic passive adds 2 damage. Costs 2 energy.", "effects": [{"kind": "damage", "amount": 6}, {"kind": "status", "status": "burn", "amount": 2}]},
	"ember_venom": {"name": "Ember Venom", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Venom", "description": "Deal 3 damage and add 4 poison to all foes. Poison also adds 2 burning. Costs 2 energy.", "effects": [{"kind": "damage", "amount": 3}, {"kind": "status", "status": "poison", "amount": 4}]},
	"renewing_aegis": {"name": "Renewing Aegis", "rarity": "rare", "cost": 2, "target": "all_allies", "affinity": "Vitality", "description": "Give every living ally 7 block and restore 3 HP. Your passive adds 3 block. Repeatable; costs 2 energy.", "effects": [{"kind": "block", "amount": 7}, {"kind": "heal", "amount": 3}]},
	"nightfall": {"name": "Nightfall", "rarity": "rare", "cost": 2, "target": "all_enemies", "affinity": "Trickery", "description": "Deal 7 damage to every foe and gain one evasion. Your passive adds 3 damage against foes with poison, burning or stun. Costs 2 energy.", "effects": [{"kind": "damage", "amount": 7}, {"kind": "status", "status": "evasion", "amount": 1, "to": "self"}]}
}
const FORMS = {
	"goblin": {"name": "Goblin", "max_hp": 20, "signature": "stab", "passive": "Scrappy beginnings. Learn from the invaders you consume.", "color": "80b66d"},
	"green_ogre": {"name": "Green Ogre", "max_hp": 28, "signature": "ogre_aegis", "passive": "Bulwark: your block cards grant 2 additional block to each target.", "tactic": "Bulwark chain: once per turn, protect another ally with an owned block card, then your next owned attack gains 6 damage.", "color": "68ac71"},
	"red_ogre": {"name": "Red Ogre", "max_hp": 26, "signature": "burning_cleave", "passive": "Kindling: each of your damage cards adds 1 burning to its victims.", "tactic": "Fire chain: once per turn, attack an already-burning foe to spread 2 Burn to every other living invader.", "color": "db7961"},
	"basilisk": {"name": "Basilisk", "max_hp": 24, "signature": "petrifying_gaze", "passive": "Venom gland: your poison applications gain 1 strength.", "tactic": "Venom trap: once per turn, successfully stun an already-poisoned foe to draw 1 card.", "color": "a2be63"},
	"shadow_stalker": {"name": "Shadow Stalker", "max_hp": 22, "signature": "ambush", "passive": "Opportunist: deal 2 extra damage to foes with poison, burning, or stun.", "tactic": "Ambush chain: once per turn, attack a foe already affected by Poison, Burn or Stun to return 1 energy.", "color": "a399d1"},
	"oni": {"name": "Oni", "max_hp": 34, "signature": "spirit_flame", "passive": "Spirit mastery: your Mystic and Flame damage cards deal 2 extra damage.", "tactic": "Spirit chain: once per turn, attack an already-burning foe to spread 2 Burn to the other invaders and return 1 energy.", "color": "e4a174"},
	"ember_basilisk": {"name": "Ember Basilisk", "max_hp": 32, "signature": "ember_venom", "passive": "Volatile venom: your poison applications also add 2 burning.", "tactic": "Venom trap: once per turn, successfully stun an already-poisoned foe to draw 2 cards.", "color": "dfb464"},
	"ancient_ogre": {"name": "Ancient Ogre", "max_hp": 36, "signature": "renewing_aegis", "passive": "Ancient bulwark: your block cards grant 3 additional block to each target.", "tactic": "Bulwark chain: once per turn, protect another ally with an owned block card, then your next owned attack gains 8 damage.", "color": "9fbd77"},
	"nightstalker": {"name": "Nightstalker", "max_hp": 30, "signature": "nightfall", "passive": "Predator: deal 3 extra damage to foes with poison, burning or stun.", "tactic": "Ambush chain: once per turn, attack a foe already affected by Poison, Burn or Stun to return 1 energy and draw 1 card.", "color": "bbb0e4"}
}
const RECIPES = [
	{"id": "green_ogre", "source": "goblin", "result": "green_ogre", "affinities": ["Might", "Guard"], "feeds": 2},
	{"id": "red_ogre", "source": "goblin", "result": "red_ogre", "affinities": ["Might", "Flame"], "feeds": 2},
	{"id": "basilisk", "source": "goblin", "result": "basilisk", "affinities": ["Venom", "Control"], "feeds": 2},
	{"id": "shadow_stalker", "source": "goblin", "result": "shadow_stalker", "affinities": ["Trickery", "Mystic"], "feeds": 2},
	{"id": "oni", "source": "red_ogre", "result": "oni", "affinities": ["Mystic"], "feeds": 4},
	{"id": "ember_basilisk", "source": "basilisk", "result": "ember_basilisk", "affinities": ["Flame"], "feeds": 4},
	{"id": "ancient_ogre", "source": "green_ogre", "result": "ancient_ogre", "affinities": ["Vitality"], "feeds": 4},
	{"id": "nightstalker", "source": "shadow_stalker", "result": "nightstalker", "affinities": ["Venom"], "feeds": 4}
]
const CLASSES = {
	"warrior": {"name": "Warrior", "pool": ["heavy_blow", "strike", "shatter_guard"], "base_hp": 13, "armor": 1, "names": ["Bran", "Torren", "Edric"]},
	"defender": {"name": "Defender", "pool": ["shield_wall", "shield_bash", "shatter_guard"], "base_hp": 16, "armor": 2, "names": ["Vera", "Oswin", "Mara"]},
	"rogue": {"name": "Rogue", "pool": ["poisoned_blade", "smoke_step", "quick_jab"], "base_hp": 11, "armor": 0, "names": ["Kestrel", "Dax", "Silas"]},
	"mage": {"name": "Mage", "pool": ["firebolt", "arcane_bolt", "ember_burst"], "base_hp": 10, "armor": 0, "names": ["Iris", "Caldus", "Senna"]},
	"priest": {"name": "Priest", "pool": ["mend", "regrowth", "arcane_bolt"], "base_hp": 12, "armor": 0, "names": ["Sister Edda", "Brother Sol", "Aster"]},
	"controller": {"name": "Controller", "pool": ["snare", "arcane_bolt", "smoke_step"], "base_hp": 11, "armor": 0, "names": ["Wren", "Vale", "Orrin"]}
}
const RANKS = {
	"F": {"name": "F", "playable": true, "raids": 3}, "E": {"name": "E", "playable": true, "raids": 3},
	"D": {"name": "D", "playable": false, "raids": 0}, "C": {"name": "C", "playable": false, "raids": 0},
	"B": {"name": "B", "playable": false, "raids": 0}, "A": {"name": "A", "playable": false, "raids": 0},
	"S": {"name": "S", "playable": false, "raids": 0}
}
const ENCOUNTERS = [
	{"name": "Torchlight Scouts", "classes": ["warrior", "mage", "rogue"], "forced": [["heavy_blow"], ["firebolt", "arcane_bolt"], ["smoke_step", "poisoned_blade"]], "hp_bonus": 0},
	{"name": "The Iron Company", "classes": ["defender", "controller", "rogue"], "forced": [["shield_wall", "heavy_blow", "shield_bash"], ["snare"], ["poisoned_blade"]], "hp_bonus": 1},
	{"name": "F Champion · The Cinder Banner", "classes": ["warrior", "mage", "priest"], "forced": [["heavy_blow"], ["firebolt", "arcane_bolt", "ember_burst"], ["regrowth", "mend"]], "hp_bonus": 3},
	{"name": "Ashen Expedition", "classes": ["mage", "defender", "controller"], "forced": [["firebolt", "arcane_bolt"], ["shield_wall", "heavy_blow", "shatter_guard"], ["snare", "smoke_step"]], "hp_bonus": 4},
	{"name": "Sanctum Hunters", "classes": ["rogue", "priest", "warrior"], "forced": [["poisoned_blade", "smoke_step", "quick_jab"], ["regrowth", "mend"], ["heavy_blow"]], "hp_bonus": 6},
	{"name": "E Champion · The Corebreakers", "classes": ["defender", "mage", "controller"], "forced": [["shield_wall", "heavy_blow"], ["firebolt", "arcane_bolt"], ["snare", "arcane_bolt"]], "hp_bonus": 8}
]

static func new_monster(id: String, monster_name: String) -> Dictionary:
	var health: int = int(FORMS["goblin"]["max_hp"])
	return {"id": id, "name": monster_name, "form": "goblin", "hp": health, "max_hp": health,
		"learned": ["strike", "guard", "patch_up"], "selected": ["strike", "guard"], "consumed": [], "feeds": 0,
		"armor": 0, "block": 0, "statuses": {}}

static func armor(actor: Dictionary) -> int:
	return maxi(0, int(actor.get("armor", 0)))

static func inheritance_outcomes(abilities: Array, learned: Array) -> Array:
	var outcomes: Array = []
	var seen: Array = []
	var total_weight: int = 0
	for ability_id in abilities:
		if seen.has(ability_id) or learned.has(ability_id) or not ABILITIES.has(ability_id): continue
		seen.append(ability_id)
		var rarity: String = ABILITIES[ability_id].get("rarity", "common")
		var weight: int = int(INHERITANCE_WEIGHTS.get(rarity, INHERITANCE_WEIGHTS["common"]))
		outcomes.append({"ability": ability_id, "rarity": rarity, "weight": weight, "chance": 0.0})
		total_weight += weight
	for outcome in outcomes: outcome["chance"] = float(outcome["weight"]) / float(total_weight)
	return outcomes

static func consumed_affinities(monster: Dictionary) -> Array:
	var affinities: Array = []
	var seen: Array = []
	for ability_id in monster.get("consumed", []):
		if seen.has(ability_id) or not ABILITIES.has(ability_id):
			continue
		seen.append(ability_id)
		var affinity: String = ABILITIES[ability_id]["affinity"]
		if affinity != "Neutral" and not affinities.has(affinity):
			affinities.append(affinity)
	return affinities

static func eligible(monster: Dictionary) -> Array:
	var affinities: Array = consumed_affinities(monster)
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

static func generate_party(raid_index: int, rng: RandomNumberGenerator, encounter_override: Dictionary = {}) -> Array:
	var index: int = clampi(raid_index, 0, ENCOUNTERS.size() - 1)
	var encounter: Dictionary = ENCOUNTERS[index] if encounter_override.is_empty() else encounter_override
	var party: Array = []
	for slot in range(encounter["classes"].size()):
		var class_id: String = encounter["classes"][slot]
		var template: Dictionary = CLASSES[class_id]
		var skills: Array = encounter["forced"][slot].duplicate()
		var extras: Array = template["pool"].duplicate()
		if index == 0:
			for new_skill in ["shatter_guard", "shield_bash", "ember_burst", "quick_jab"]: extras.erase(new_skill)
		if class_id == "warrior":
			for attack in ["strike", "heavy_blow"]:
				if not skills.has(attack): skills.append(attack)
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
			"abilities": skills, "tactics": true, "armor": maxi(0, int(template.get("armor", 0))), "block": 0, "statuses": {}})
	ensure_priest_offense(party)
	ensure_champion_mechanics(party)
	return party

static func ensure_champion_mechanics(party: Array) -> void:
	# Idempotent migration preserves HP, defenses and already locked intentions.
	for actor in party:
		if actor.get("id", "") == "raid_5_foe_0" and actor.get("tactics", false):
			actor["champion"] = "iron_marshal"
			if not actor.get("abilities", []).has("breach_order"): actor["abilities"].append("breach_order")
		if actor.get("id", "") != "raid_2_foe_0": continue
		actor["champion"] = "cinder_banner"
		if not actor.get("abilities", []).has("banner_volley"):
			actor["abilities"].append("banner_volley")

static func ensure_priest_offense(party: Array) -> void:
	# Older active parties can contain heal-only priests. Keep their locked intent,
	# but supply an actual offensive ability for later turns and their eventual body.
	for actor in party:
		if actor.get("class_name", actor.get("form", "")) == "priest" and not actor.get("abilities", []).has("arcane_bolt"):
			actor["abilities"].append("arcane_bolt")
