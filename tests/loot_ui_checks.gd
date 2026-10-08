extends RefCounted

# Focused tests retain the new earned reward boundary and resolve it through
# its public skip action; dedicated loot tests exercise acquisition and buying.
static func skip_draft(t, game) -> bool:
	var offered: Array = game.spell_reward_choices()
	if not offered.is_empty():
		t.check(game.skip_spell_reward(), "Focused fixture explicitly skips its actual saved spell draft")
	var offer: Dictionary = game.run.get("spell_offer", {})
	return offer.is_empty() or offer.get("resolved", false)

static func leave_if_trader(t, game) -> bool:
	if game.run.get("phase", "") == "trader":
		t.check(game.leave_trader(), "Focused fixture deliberately leaves the earned trader before preparing")
	return game.run.get("phase", "") == "prep"
