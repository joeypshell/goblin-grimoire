extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/game_data.gd")

var ui
var game
var captured := 0
var errors: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = State.new("user://verification/visual_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	ui = MainScene.instantiate()
	ui.state = game
	root.add_child(ui)
	if ui.state != game: errors.append("Scene startup failed to retain its isolated verification profile")
	ui.refresh()
	await capture("01_title")
	ui.menu = "grimoire"
	ui.refresh()
	await capture("02_empty_grimoire")
	game.new_run(730204)
	ui.menu = "game"
	ui.refresh()
	await capture("03_preparation")
	game.start_raid()
	ui.refresh()
	await capture("04_combat")
	ui.card_index = 0
	ui.refresh()
	await capture("05_target_selection")
	ui.card_index = -1
	# UI fixtures complement the mechanically played campaign in test_runner.gd.
	game.run["phase"] = "feeding"
	game.run["rewards"] = []
	for actor in game.battle.enemies:
		game.run["rewards"].append({"id": actor["id"], "name": actor["name"], "class_name": actor["class_name"], "form": actor["form"], "abilities": actor["abilities"].duplicate(), "armor": Data.armor(actor), "claimed": false})
	game.run["resolved_id"] = 1
	ui.refresh()
	await capture("06_feeding")
	var monster: Dictionary = game.run["monsters"][0]
	game.claim_body(0, monster["id"])
	game.claim_body(1, monster["id"])
	# Explicit earned-evolution visual fixture, independent of random results.
	for ability in ["heavy_blow", "firebolt"]:
		if not monster["learned"].has(ability): monster["learned"].append(ability)
		if not monster["consumed"].has(ability): monster["consumed"].append(ability)
	game.evolve(monster["id"], "red_ogre")
	var reveal_info: Dictionary = game.last_evolution.duplicate(true)
	game.last_evolution = {}
	ui.refresh()
	ui.rewards_screen.reveal(reveal_info)
	await capture("07_evolution_reveal")
	ui.close_modal()
	ui.menu = "grimoire"
	ui.refresh()
	await capture("08_discovered_grimoire")
	ui.menu = "game"
	for index in range(game.run["rewards"].size()):
		game.skip_body(index)
	game.finish_feeding()
	ui.refresh()
	await capture("09_raid_result")
	game.run["phase"] = "victory"
	game.run["raid"] = 6
	game.run["promotion"] = "D"
	ui.refresh()
	await capture("10_promotion")
	game.run["phase"] = "defeat"
	game.run["core"] = 0
	ui.refresh()
	await capture("11_defeat")
	game.new_run(730205)
	var evolved: Dictionary = game.run["monsters"][0]
	evolved["form"] = "oni"
	evolved["max_hp"] = Data.FORMS["oni"]["max_hp"]
	evolved["hp"] = 30
	evolved["learned"].append("regrowth")
	evolved["selected"] = ["regrowth", "patch_up"]
	game.run["raid"] = 5
	game.run.erase("party")
	game.start_raid()
	game.battle.hand = [{"id": "aoe_1", "ability": "spirit_flame", "owner": evolved["id"]}, {"id": "aoe_2", "ability": "regrowth", "owner": evolved["id"]}, {"id": "aoe_3", "ability": "rally", "owner": ""}, {"id": "aoe_4", "ability": "core_pulse", "owner": ""}, {"id": "aoe_5", "ability": "mend", "owner": evolved["id"]}]
	ui.refresh()
	await capture("12_evolved_combat")
	ui.card_index = 0
	ui.refresh()
	await capture("13_evolved_area_targets")
	ui.card_index = 1
	ui.refresh()
	await capture("14_regrowth_targets")
	ui.card_index = 2
	ui.refresh()
	await capture("15_shared_rally_targets")
	print("VISUAL SMOKE: %d native screenshots at 1280x720; %d layout/content issues" % [captured, errors.size()])
	for issue in errors:
		print("VISUAL ISSUE: ", issue)
	quit(0 if errors.is_empty() else 1)

func capture(name: String) -> void:
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var destination := "res://tests/artifacts/"
	DirAccess.make_dir_recursive_absolute(destination)
	var picture := root.get_texture().get_image()
	var result := picture.save_png(destination + name + ".png")
	if result != OK:
		errors.append("Screenshot failed: " + name)
	captured += 1
	print("CAPTURE: ", name)
	inspect_controls(ui, name)
	var screen_text := gather_text(ui)
	if name in ["01_title", "02_empty_grimoire", "03_preparation", "04_combat", "05_target_selection", "06_feeding"]:
		for id in Data.FORMS:
			if id != "goblin" and screen_text.contains(Data.FORMS[id]["name"]):
				errors.append(name + ": undiscovered form revealed: " + Data.FORMS[id]["name"])
	if name == "08_discovered_grimoire" and not (screen_text.contains("Might + Flame") and screen_text.contains("Signature:")):
		errors.append("Discovered grimoire failed to render performed recipe and signature")

func gather_text(node: Node) -> String:
	var result := ""
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button):
		result += node.text + "\n"
	for child in node.get_children():
		result += gather_text(child)
	return result

func inspect_controls(node: Node, screen: String) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Label):
		var in_scroll := false
		var owner_button
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				in_scroll = true
			if ancestor is BaseButton and owner_button == null:
				owner_button = ancestor
			ancestor = ancestor.get_parent()
		if not in_scroll:
			var rect: Rect2 = node.get_global_rect()
			if rect.position.x < -1 or rect.position.y < -1 or rect.end.x > 1281 or rect.end.y > 721:
				errors.append("%s: %s outside viewport %s" % [screen, node.text if node is Button or node is Label else node.name, rect])
			if owner_button != null:
				var owner_rect: Rect2 = owner_button.get_global_rect().grow(1)
				if not owner_rect.encloses(rect):
					errors.append("%s: %s outside its actor panel %s" % [screen, node.text if node is Label else node.name, rect])
	for child in node.get_children():
		inspect_controls(child, screen)
