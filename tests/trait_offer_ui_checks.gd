extends RefCounted

const Traits = preload("res://scripts/dungeon_traits.gd")

# Search the production seed-derived offer generator, never inject a desired
# option. UI fixtures then earn and select those offers through RunState.
static func seed_for(required: Array) -> int:
	for seed_value in range(1, 4097):
		var offered: Array = Traits.first_offer(seed_value)
		if required.all(func(id): return offered.has(id)): return seed_value
	return 0
