extends RefCounted

const Traits = preload("res://scripts/dungeon_traits.gd")

# Search the production seed-derived offer generator, never inject a desired
# option. UI fixtures then earn and select those offers through RunState.
static func seed_for(required: Array) -> int:
	for seed_value in range(1, 4097):
		var offered: Array = Traits.first_offer(seed_value)
		if required.all(func(id): return offered.has(id)): return seed_value
	return 0

# Focused non-reward fixtures explicitly accept a real saved offer before
# exercising feeding. Dedicated choice/touch tests cover the complete UI path.
static func enter_feeding(game) -> bool:
	if game.run.get("phase", "") == "trait" and game.run.get("trait_return", "") == "feeding":
		var offered: Array = game.trait_choices()
		if offered.is_empty() or not game.choose_trait(offered[0]): return false
	return game.run.get("phase", "") == "feeding"
