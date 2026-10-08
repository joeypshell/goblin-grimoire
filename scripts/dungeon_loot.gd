extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const STARTERS = ["rally", "core_pulse", "snare_dungeon"]
const SPELLS = ["soul_harvest", "renewal_wave", "plague_bloom", "ember_storm", "arcane_sweep", "shatter_wave", "hunters_mark", "sanctuary", "echo_rune", "battle_orders", "wild_growth", "cinder_seed"]
const ROLES = {
	"heal": ["soul_harvest", "renewal_wave", "wild_growth"],
	"area": ["plague_bloom", "ember_storm", "arcane_sweep", "shatter_wave"],
	"utility": ["hunters_mark", "sanctuary", "echo_rune", "battle_orders", "cinder_seed"]
}
const PRICES = {"common": 45, "uncommon": 65, "rare": 90}
const OFFER_WEIGHTS = {"common": 4, "uncommon": 2, "rare": 1}
const TRADER_RAIDS = [2, 5]

static func valid_spell(id: String) -> bool:
	return id in STARTERS or id in SPELLS

static func reward(seed_value: int, raid: int, library: Array) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ ((raid + 1) * 104729) ^ 0x6c6f6f74
	var available: Array = []
	for id in SPELLS:
		if not library.has(id): available.append(id)
	var options: Array = []
	for pick in range(mini(3, available.size())):
		var total: int = 0
		for id in available: total += int(OFFER_WEIGHTS.get(Data.ABILITIES.get(id, {}).get("rarity", "common"), 4))
		var roll: int = random.randi_range(1, total)
		var index: int = available.size() - 1
		for candidate in range(available.size()):
			roll -= int(OFFER_WEIGHTS.get(Data.ABILITIES.get(available[candidate], {}).get("rarity", "common"), 4))
			if roll <= 0:
				index = candidate
				break
		options.append(available[index])
		available.remove_at(index)
	return {"raid": raid + 1, "options": options, "resolved": options.is_empty(), "chosen": "", "slot": -1, "skipped": false}

static func price(id: String) -> int:
	return int(PRICES.get(Data.ABILITIES.get(id, {}).get("rarity", "common"), PRICES["common"]))

static func stock(seed_value: int, library: Array, raid: int = 2) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ (raid * 104729) ^ 0x74726164
	var result: Array = []
	var picked: Array = []
	for role in ROLES:
		var available: Array = []
		for id in ROLES[role]:
			if not library.has(id) and not picked.has(id): available.append(id)
		if available.is_empty():
			# A later visit can exhaust a role. Keep a truthful known reference;
			# library spells remain freely equippable and cannot be purchased again.
			result.append({"id": "trader_%d_%s" % [raid, role], "ability": ROLES[role][0], "price": 0, "sold": true, "owned": true})
			continue
		var id: String = str(available[random.randi_range(0, available.size() - 1)])
		picked.append(id)
		result.append({"id": "trader_%d_%s" % [raid, role], "ability": id, "price": price(id), "sold": false, "owned": false})
	# At least one practical purchase at 70 gold, while still retaining role coverage.
	var affordable: bool = result.any(func(row): return not row["sold"] and int(row["price"]) <= 70)
	if not affordable:
		for row in result:
			if row["sold"]: continue
			var role: String = str(row["id"]).get_slice("_", 2)
			var cheaper: Array = []
			for id in ROLES[role]:
				if not library.has(id) and not picked.has(id) and price(id) <= 70: cheaper.append(id)
			if cheaper.is_empty(): continue
			picked.erase(row["ability"])
			row["ability"] = cheaper[random.randi_range(0, cheaper.size() - 1)]
			row["price"] = price(row["ability"])
			picked.append(row["ability"])
			break
	var rares: Array = []
	for id in SPELLS:
		if not library.has(id) and not picked.has(id) and Data.ABILITIES.get(id, {}).get("rarity", "") == "rare": rares.append(id)
	if not rares.is_empty():
		var id: String = str(rares[random.randi_range(0, rares.size() - 1)])
		result.append({"id": "trader_%d_rare" % raid, "ability": id, "price": price(id), "sold": false, "owned": false})
	return result
