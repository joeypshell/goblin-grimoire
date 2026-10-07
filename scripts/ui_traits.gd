extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Traits = preload("res://scripts/dungeon_traits.gd")
const SHORT = {
	"venom_nest": "Poisoned KO spreads 2 Poison",
	"spiteful_shields": "Block absorbs a hit: retaliate 3",
	"pack_instinct": "3 different owners: +1 energy, draw 1",
	"war_drums": "Protect a teammate: +1 energy, draw 1"
}
var ui

func _init(owner) -> void:
	ui = owner

func render() -> void:
	var compact: bool = ui.is_compact()
	var page = ui.scroll(ui.content)
	page.get_parent().name = "TraitChoiceScroll"
	var heading = ui.label("Dungeon trait reward", 25 if compact else 30, ui.EMBER, true)
	heading.name = "TraitMilestone"
	page.add_child(heading)
	var offered: Array = ui.state.trait_choices()
	var first: bool = ui.state._pending_trait_milestone() == int(Traits.MILESTONES[0])
	var offer_copy: String = "Choose one of this run's two offers. Continue keeps these same offers. Your chosen trait lasts for this run."
	if first and offered.size() != 2: offer_copy = "Choose from this run's saved offers. Continue keeps these same offers. Your chosen trait lasts for this run."
	if not first: offer_copy = "Choose a second trait from all remaining options. Your first trait stays active; both last for this run."
	var offer_summary = ui.label(offer_copy + " Devouring still grants one random unknown skill.", 15, ui.PARCHMENT, true)
	offer_summary.name = "TraitOfferSummary"
	page.add_child(offer_summary)
	var recovery: String = "Recovery is already applied. Complete the earned trait choices, then view the raid result and prepare."
	if ui.state.run.get("trait_return", "result") == "prep": recovery = "Complete the earned trait choices, then return to preparation."
	var return_guidance = ui.label(recovery, 13, ui.MUTED, true)
	return_guidance.name = "TraitReturnGuidance"
	page.add_child(return_guidance)
	summary(page, false)
	var choices = VBoxContainer.new() if compact else HBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	page.add_child(choices)
	for id in offered:
		var definition: Dictionary = Traits.DEFINITIONS[id]
		var box = ui.panel(choices, true)
		box.name = "TraitChoice_" + id
		box.add_child(ui.label(definition["name"], 22, ui.MOSS, true))
		box.add_child(ui.label(definition["description"], 15, ui.PARCHMENT, true))
		var current = ui.label(compatibility(id), 14, ui.EMBER, true)
		current.name = "TraitCompatibility_" + id
		box.add_child(current)
		box.add_child(ui.label(definition["hint"], 13, ui.MUTED, true))
		var take = ui.primary("Choose " + definition["name"], func(): _choose(id))
		take.name = "TraitSelect_" + id
		take.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(take)
	page.add_child(ui.label("These offers are saved with this run. A new run starts with fresh offers." if first else "Your chosen traits are saved with this run. A new run starts with fresh choices.", 12, ui.MUTED, true))

func _choose(id: String) -> void:
	if not ui.state.choose_trait(id): return
	ui.card_index = -1
	ui.refresh()
	ui.toast.text = Traits.DEFINITIONS[id]["name"] + " now shapes your dungeon."

func summary(parent: Node, show_milestone: bool = true) -> void:
	var lines: Array = []
	for id in ui.state.run.get("traits", []):
		if Traits.DEFINITIONS.has(id): lines.append(Traits.DEFINITIONS[id]["name"] + " / " + SHORT.get(id, Traits.DEFINITIONS[id]["description"]))
	if not lines.is_empty():
		var build = ui.label("YOUR DUNGEON BUILD\n" + "\n".join(lines), 13, ui.MOSS, true)
		build.name = "TraitSummary"
		parent.add_child(build)
	if show_milestone:
		var next = ui.label(Traits.milestone(ui.state.run), 13, ui.EMBER, true)
		next.name = "TraitMilestone"
		parent.add_child(next)

func combat_summary(battle) -> String:
	var names: Array = []
	for id in battle.traits:
		if not Traits.DEFINITIONS.has(id): continue
		if id == "pack_instinct":
			names.append("Pack 3/3 used" if battle.trait_state.get("pack_triggered", false) else "Pack %d/3" % battle.trait_state.get("owners", []).size())
		elif id == "war_drums":
			names.append("War Drums used" if battle.trait_state.get("war_drums_triggered", false) else "War Drums ready")
		else: names.append(Traits.DEFINITIONS[id]["name"])
	return " · ".join(names)

func rules(parent: Node, battle) -> void:
	if battle.traits.is_empty(): return
	parent.add_child(ui.label("YOUR DUNGEON TRAITS", 15, ui.MOSS, true))
	for id in battle.traits:
		if not Traits.DEFINITIONS.has(id): continue
		var definition: Dictionary = Traits.DEFINITIONS[id]
		parent.add_child(ui.label(definition["name"] + ": " + definition["description"], 14, ui.PARCHMENT, true))
		parent.add_child(ui.label(definition["hint"], 13, ui.MUTED, true))

func reward_after_raid() -> bool:
	var next_raid: int = int(ui.state.run.get("raid", 0)) + 1
	return Traits.MILESTONES.has(next_raid) and not ui.state.run.get("trait_milestones", []).has(next_raid) and not Traits.choices(ui.state.run.get("traits", [])).is_empty()

func compatibility(id: String) -> String:
	var cards: Array = []
	var affordable: Array = []
	var protectors: Array = []
	for monster in ui.state.run.get("monsters", []):
		var abilities: Array = [Data.FORMS[monster["form"]]["signature"]] + monster["selected"]
		var has_affordable: bool = false
		for ability_id in abilities:
			cards.append(ability_id)
			if int(Data.ABILITIES[ability_id]["cost"]) <= 1: has_affordable = true
			var ability: Dictionary = Data.ABILITIES[ability_id]
			if ability["target"] not in ["ally", "all_allies"]: continue
			for effect in ability["effects"]:
				if effect["kind"] == "block" and effect.get("to", "target") != "self" and int(effect.get("amount", 0)) > 0:
					if not protectors.has(monster["name"]): protectors.append(monster["name"])
					break
		if has_affordable: affordable.append(monster["name"])
	if id == "war_drums":
		if protectors.is_empty(): return "NEXT DECK: Equip Guard or another ally-protection skill. Its owner must protect a teammate; self-only and shared cards do not trigger War Drums."
		return "READY NOW: %s can protect a teammate to gain 1 energy and draw 1 card. Try Guard on another monster, then use the extra card this turn." % ", ".join(protectors)
	if id == "pack_instinct":
		return "CURRENT DECK: %d/3 monsters have a 1-energy card equipped%s." % [affordable.size(), " / " + ", ".join(affordable) if not affordable.is_empty() else ""]
	cards.append_array(["rally", "core_pulse", "snare_dungeon"])
	var count: int = 0
	var names: Array = []
	for ability_id in cards:
		for effect in Data.ABILITIES[ability_id]["effects"]:
			if (id == "venom_nest" and effect.get("status", "") == "poison") or (id == "spiteful_shields" and effect["kind"] == "block"):
				count += 1
				if not names.has(Data.ABILITIES[ability_id]["name"]): names.append(Data.ABILITIES[ability_id]["name"])
				break
	if count == 0:
		var known: Dictionary = {}
		for monster in ui.state.run.get("monsters", []):
			for ability_id in monster.get("learned", []):
				for effect in Data.ABILITIES.get(ability_id, {}).get("effects", []):
					if effect.get("status", "") != "poison": continue
					if not known.has(ability_id): known[ability_id] = []
					if not known[ability_id].has(monster["name"]): known[ability_id].append(monster["name"])
		var learned: Array = []
		for ability_id in known:
			learned.append(Data.ABILITIES[ability_id]["name"] + " (" + ", ".join(known[ability_id]) + ")")
		if not learned.is_empty():
			return "CURRENT DECK: No poison equipped. Your team knows %s; equip %s during next preparation." % [", ".join(learned), "it" if learned.size() == 1 else "a poison skill"]
		return "CURRENT DECK: No poison equipped yet. Look for Poisoned Blade in future meals."
	return "CURRENT DECK: %d %s cards / %s." % [count, "poison" if id == "venom_nest" else "Block", ", ".join(names)]

func champion_warning(party: Array, parent: Node) -> void:
	for actor in party:
		if actor.get("champion", "") == "iron_marshal":
			var warning = ui.label("MARSHAL'S BREACH ORDER: On rounds 2, 5, 8... she removes ALL monster Block, then deals 6 damage to each. Stun or defeat her to cancel it; Resolve can prevent Stun. Evade still protects against the hit.", 14, ui.RED, true)
			warning.name = "MarshalWarning"
			parent.add_child(warning)
			return
		if actor.get("champion", "") != "cinder_banner": continue
		var warning = ui.label("CAPTAIN'S BANNER: Every third round, Banner Volley deals 5 damage and adds 1 Burn to ALL monsters. Stun cancels the announced volley unless Resolve protects him; defeat the captain to stop future volleys.", 14, ui.RED, true)
		warning.name = "BannerWarning"
		parent.add_child(warning)
		return
