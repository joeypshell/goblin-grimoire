extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const CardFace = preload("res://scripts/ui_card.gd")
const OFFER_EFFECTS = {
	"soul_harvest": "4 damage to all foes; each direct kill heals a wounded living monster for 5.",
	"renewal_wave": "Heal every living monster for 5 and cleanse Poison and Burn.",
	"plague_bloom": "Copy one foe's Poison strength to every other living foe.",
	"ember_storm": "3 damage and 2 Burn to every living foe.",
	"arcane_sweep": "3 damage to every living foe.",
	"shatter_wave": "Remove all foe Block, then deal 4 damage to each foe.",
	"hunters_mark": "3 damage; the next owned direct hit on a surviving foe gains +4.",
	"sanctuary": "6 Block and 1 Regen for every living monster.",
	"echo_rune": "Store Echo: the next owned attack repeats its direct hits once.",
	"battle_orders": "Draw 2 cards for 1 energy.",
	"wild_growth": "Every living monster gets Regen healing 2, then 1 at turn end.",
	"cinder_seed": "2 damage and 2 Burn to a surviving foe."
}
var ui
var _draft_selected := ""
var _trader_selected := ""

func _init(owner) -> void:
	ui = owner

func enabled() -> bool:
	return int(ui.state.run.get("loot_version", 0)) == 1

func pending() -> bool:
	var offer = ui.state.run.get("spell_offer", {})
	return enabled() and offer is Dictionary and not offer.is_empty() and not offer.get("resolved", false)

func sync() -> void:
	if ui.state.run.get("phase", "") != "feeding": _draft_selected = ""
	if ui.state.run.get("phase", "") != "trader": _trader_selected = ""

func milestone(parent: Node) -> void:
	if not enabled(): return
	var visited: Array = ui.state.run.get("trader_visited_raids", [])
	var next_visit: int = 2 if not visited.has(2) else 5
	if visited.has(next_visit): return
	var message := "TRADER AHEAD · After raid %d, spend gold on spells before the %s champion." % [next_visit, "F" if next_visit == 2 else "E"]
	if ui.state.run.get("phase", "") == "trader": return
	var cue = ui.label(message, 13, ui.EMBER, true)
	cue.name = "TraderMilestone"
	parent.add_child(cue)

func draft(parent: Node) -> void:
	if not enabled(): return
	var offer: Dictionary = ui.state.run.get("spell_offer", {})
	if offer.is_empty(): return
	var box = ui.panel(parent)
	box.name = "SpellDraft"
	box.add_child(ui.label("DUNGEON SPELL REWARD", 18, ui.EMBER, true))
	if offer.get("resolved", false):
		var id: String = str(offer.get("chosen", ""))
		var text := "Spell reward skipped. Your equipped spells stay the same."
		if Data.ABILITIES.has(id):
			text = "%s learned and equipped in dungeon slot %d. %s" % [ui.ability_name(id), int(offer.get("slot", 0)) + 1, Data.ABILITIES[id]["description"]]
		var receipt = ui.label(text, 14, ui.MOSS, true)
		receipt.name = "SpellDraftReceipt"
		box.add_child(receipt)
		return
	var options: Array = ui.state.spell_reward_choices()
	if not options.has(_draft_selected): _draft_selected = ""
	var next = ui.label("Choose one spell, then choose the equipped spell it replaces. Selection alone does not claim it. Or skip this reward.", 14, ui.PARCHMENT, true)
	next.name = "SpellDraftGuidance"
	box.add_child(next)
	var choices = VBoxContainer.new() if ui.is_compact() else HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	box.add_child(choices)
	for id in options:
		_spell_card(choices, id, "SpellOffer_" + id, _draft_selected == id, "Select " + ui.ability_name(id), func():
			_draft_selected = id
			ui.refresh())
	if _draft_selected != "":
		_replacements(box, _draft_selected, "SpellReplace_", func(slot):
			var id: String = _draft_selected
			if not ui.state.choose_spell_reward(id, slot): return
			_draft_selected = ""
			ui.refresh()
			ui.toast.text = ui.ability_name(id) + " is equipped for the next raid.")
	var skip = ui.button("Skip spell reward", func():
		if not ui.state.skip_spell_reward(): return
		_draft_selected = ""
		ui.refresh())
	skip.name = "SkipSpellReward"
	box.add_child(skip)

func library(parent: Node) -> void:
	if not enabled(): return
	var box = ui.panel(parent)
	box.name = "DungeonSpellLibrary"
	box.add_child(ui.label("DUNGEON SPELLS / NEXT DECK", 16, ui.MOSS, true))
	box.add_child(ui.label("Three shared cards in the 12-card deck. These spells have no monster owner. Learned monster skills and transformations stay separate.", 13, ui.MUTED, true))
	var loadout: Array = ui.state.dungeon_spell_loadout()
	var known: Array = ui.state.run.get("spell_library", loadout)
	for slot in range(loadout.size()):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		row.add_child(ui.label("Slot %d" % (slot + 1), 13, ui.MUTED))
		var picker = OptionButton.new()
		picker.name = "DungeonSpellSlot_%d" % slot
		picker.custom_minimum_size.y = 44
		picker.fit_to_longest_item = false
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_theme_font_size_override("font_size", 14)
		var popup = picker.get_popup()
		popup.add_theme_font_size_override("font_size", 16)
		popup.add_theme_constant_override("v_separation", maxi(24, ceili(44.0 - ui.theme.default_font.get_height(16))))
		popup.max_size = Vector2i(int(ui.content_width()), maxi(80, int(ui.get_viewport_rect().size.y) - 40))
		for index in range(known.size()):
			var id: String = known[index]
			picker.add_item("%s · %d energy" % [ui.ability_name(id), Data.ABILITIES[id]["cost"]])
			picker.set_item_tooltip(index, Data.ABILITIES[id]["description"])
			picker.set_item_disabled(index, loadout.has(id) and loadout[slot] != id)
			if id == loadout[slot]: picker.select(index)
		picker.item_selected.connect(func(index): ui.act(func(): ui.state.select_dungeon_spell(slot, known[index]), "Dungeon spell slot updated."))
		row.add_child(picker)
		var effect = ui.label(Data.ABILITIES[loadout[slot]]["description"], 13, ui.PARCHMENT, true)
		effect.name = "DungeonSpellEffect_%d" % slot
		box.add_child(effect)

func render_trader() -> void:
	var champion: String = "F" if int(ui.state.run.get("trader_raid", 2)) == 2 else "E"
	var page = ui.scroll(ui.content)
	page.get_parent().name = "TraderScroll"
	page.add_child(ui.label("The dungeon trader", 25 if ui.is_compact() else 30, ui.EMBER, true))
	var balance = ui.label("GOLD %d · Stock and purchases are saved with this run." % int(ui.state.run.get("gold", 0)), 15, ui.MOSS, true)
	balance.name = "TraderGold"
	page.add_child(balance)
	var guidance = ui.label("NEXT: Select a spell to inspect its replacement choices. Buy & equip spends gold and replaces one dungeon slot. Leave when ready to prepare for the %s champion." % champion, 14, ui.PARCHMENT, true)
	guidance.name = "TraderGuidance"
	page.add_child(guidance)
	var stock: Array = ui.state.trader_stock()
	var selected: Dictionary = {}
	var rows = VBoxContainer.new() if ui.is_compact() else HBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	page.add_child(rows)
	for item in stock:
		var price: int = int(item["price"])
		var sold: bool = item.get("sold", false)
		var enough: bool = int(ui.state.run.get("gold", 0)) >= price
		var suffix: String = "Already learned / equip below" if item.get("owned", false) else ("SOLD" if sold else "%d gold%s" % [price, " · need %d more" % (price - int(ui.state.run.get("gold", 0))) if not enough else ""])
		_spell_card(rows, item["ability"], "TraderSelect_" + item["id"], _trader_selected == item["id"], suffix, func():
			_trader_selected = item["id"]
			ui.refresh(), sold)
		if _trader_selected == item["id"] and not sold: selected = item
	if not selected.is_empty():
		var box = ui.panel(page)
		box.name = "TraderReplacement"
		var affordable: bool = int(ui.state.run.get("gold", 0)) >= int(selected["price"])
		_replacements(box, selected["ability"], "TraderBuy_", func(slot):
			if not ui.state.buy_spell(selected["id"], slot): return
			_trader_selected = ""
			ui.refresh()
			ui.toast.text = "%s bought and equipped. %d gold remains." % [ui.ability_name(selected["ability"]), int(ui.state.run.get("gold", 0))], not affordable, "Buy & equip")
	var leave = ui.primary("Leave & prepare for the %s champion" % champion, func():
		if not ui.state.leave_trader(): return
		_trader_selected = ""
		ui.refresh())
	leave.name = "LeaveTrader"
	leave.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(leave)
	library(page)

func _replacements(parent: Node, id: String, prefix: String, apply: Callable, disabled: bool = false, verb: String = "Equip") -> void:
	var loadout: Array = ui.state.dungeon_spell_loadout()
	if ui.is_compact():
		var detail = ui.label(Data.ABILITIES[id]["description"], 14, ui.PARCHMENT, true)
		detail.name = prefix + "FullEffect"
		parent.add_child(detail)
	var title = ui.label("%s / choose one dungeon slot to replace" % ui.ability_name(id), 15, ui.EMBER, true)
	title.name = prefix + "Guidance"
	parent.add_child(title)
	for slot in range(loadout.size()):
		var replace = ui.primary("%s · replace %s (slot %d)" % [verb, ui.ability_name(loadout[slot]), slot + 1], func(): apply.call(slot))
		replace.name = prefix + str(slot)
		replace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		replace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replace.disabled = disabled or (loadout.has(id) and loadout[slot] != id)
		parent.add_child(replace)

func _spell_card(parent: Node, id: String, node_name: String, selected: bool, action_text: String, action: Callable, disabled: bool = false) -> void:
	var ability: Dictionary = Data.ABILITIES[id]
	var box = ui.panel(parent, true)
	box.name = node_name + "Card"
	if not ui.is_compact(): box.custom_minimum_size.x = 190
	var family: String = CardFace._art_family(ability)
	var art = CardFace.ArtPane.new()
	art.name = node_name + "Art"
	art.family = family
	art.accent = CardFace._affinity_color(ability.get("affinity", "Neutral"), family)
	art.texture = CardFace.texture_for(id)
	art.custom_minimum_size = Vector2(48, 48) if ui.is_compact() else Vector2(0, 64)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pick_text: String = ("SELECTED · " if selected else "") + action_text
	if ui.is_compact():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		row.add_child(art)
		pick_text = ("SELECTED · " if selected else "") + ability["name"] + "\n%d energy · %s" % [int(ability["cost"]), str(ability.get("rarity", "common")).capitalize()]
		if disabled or node_name.begins_with("TraderSelect_"): pick_text += "\n" + action_text
		var pick = _offer_action(pick_text, action, node_name, selected, disabled)
		pick.add_theme_font_size_override("font_size", 14)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pick)
	else:
		box.add_child(art)
		box.add_child(ui.label(ability["name"], 19, ui.MOSS if selected else ui.PARCHMENT, true))
		box.add_child(ui.label("%d energy · %s · Dungeon shared" % [int(ability["cost"]), str(ability.get("rarity", "common")).capitalize()], 13, ui.EMBER, true))
	var effect = ui.label(OFFER_EFFECTS.get(id, ability["description"]) if ui.is_compact() else ability["description"], 13 if ui.is_compact() else 14, ui.PARCHMENT, true)
	effect.name = node_name + "Effect"
	box.add_child(effect)
	if not ui.is_compact(): box.add_child(_offer_action(pick_text, action, node_name, selected, disabled))

func _offer_action(value: String, action: Callable, node_name: String, selected: bool, disabled: bool) -> Button:
	var pick = ui.button(value, action)
	pick.name = node_name
	pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick.disabled = disabled
	if selected: pick.add_theme_stylebox_override("normal", ui.style(Color("494631"), ui.EMBER))
	return pick
