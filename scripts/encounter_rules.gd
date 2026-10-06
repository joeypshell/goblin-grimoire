extends RefCounted

const WARD_BLOCK: int = 4
const WARD_LOG_PREFIX: String = "WARD / "

# Only Battle's direct damage branch collects a ward. HP loss is measured after
# Armor, Block and Evade; ticking statuses and retaliation never call this hook.
static func collect_damage(battle, caster: Dictionary, target: Dictionary, hp_lost: int, pending: Array) -> void:
	if hp_lost <= 0 or target.get("encounter_rule", "") != "ward_captain": return
	var player_attack: bool = caster.is_empty()
	for monster in battle.monsters:
		if monster.get("id", "") == caster.get("id", ""):
			player_attack = true
			break
	if not player_attack: return
	var enemy_id: String = str(target.get("id", ""))
	if enemy_id == "" or not battle.enemies.any(func(actor): return actor.get("id", "") == enemy_id): return
	if not pending.has(enemy_id): pending.append(enemy_id)

# Resolve after every hit/effect in the card. In particular, a captain hit first
# by an area card cannot protect its allies against later hits of that same card.
static func apply_after_card(battle, pending: Array) -> void:
	var captain_ids: Array = pending.duplicate()
	pending.clear()
	for captain_id in captain_ids:
		var captain: Dictionary = battle.get_actor(str(captain_id))
		if captain.is_empty() or int(captain.get("hp", 0)) <= 0: continue
		var recipient: Dictionary = ward_recipient(battle.enemies, str(captain_id))
		if recipient.is_empty(): continue
		recipient["block"] = int(recipient.get("block", 0)) + WARD_BLOCK
		battle._add_log(WARD_LOG_PREFIX + "%s reinforces %s: +%d Block after the attack." % [captain["name"], recipient["name"], WARD_BLOCK])

static func ward_recipient(party: Array, captain_id: String) -> Dictionary:
	var recipient: Dictionary = {}
	for actor in party:
		if actor.get("id", "") == captain_id or int(actor.get("hp", 0)) <= 0: continue
		# Cross multiplication gives exact health-ratio ordering; equal ratios keep
		# the first actor in the party, so inspecting or reloading cannot reroll it.
		if recipient.is_empty() or int(actor["hp"]) * maxi(1, int(recipient.get("max_hp", 1))) < int(recipient["hp"]) * maxi(1, int(actor.get("max_hp", 1))):
			recipient = actor
	return recipient

static func description(actor: Dictionary) -> String:
	match actor.get("encounter_rule", ""):
		"ward_captain":
			return "WARD CAPTAIN / If an attack costs this captain HP and it survives the whole card, it gives 4 Block to the other living invader with the lowest HP percentage. Once per card; poison and Burn do not trigger it."
		"ritual_priest":
			return "RENEWAL RITUAL / On rounds 2, 5, 8…, heals another wounded invader for 9 HP instead of its normal action. Defeat or stun this priest before the announced ritual."
	return ""

static func card_preview(battle, card: Dictionary, target_id: String) -> String:
	if not battle.enemies.any(func(actor): return actor.get("encounter_rule", "") == "ward_captain" and int(actor.get("hp", 0)) > 0): return ""
	# Runtime loads avoid the Data -> EncounterRules -> Data/Battle preload cycle.
	var data = load("res://scripts/game_data.gd")
	var ability: Dictionary = data.ABILITIES.get(card.get("ability", ""), {})
	if ability.is_empty() or not ability.get("effects", []).any(func(effect): return effect.get("kind", "") == "damage"): return ""
	var snapshot: Dictionary = battle.to_dict()
	var probe = load("res://scripts/battle.gd").new()
	probe.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	probe.hand = [card.duplicate(true)]
	probe.energy = maxi(probe.energy, int(ability.get("cost", 0)))
	if not probe.play_card(0, target_id): return ""
	var consequences: PackedStringArray = []
	for line in probe.action_log:
		if str(line).begins_with(WARD_LOG_PREFIX): consequences.append(str(line).trim_prefix(WARD_LOG_PREFIX))
	return " ".join(consequences)
