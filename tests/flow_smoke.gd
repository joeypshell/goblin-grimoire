extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Replay = preload("res://scripts/battle_replay.gd")
const Feedback = preload("res://scripts/combat_feedback.gd")
const State = preload("res://scripts/run_state.gd")
const CountingState = preload("res://tests/flow_state_fixture.gd")
const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var errors: Array = []
var captured := 0
var profile_root: String
var ui
var game
var surface: SubViewport
var can_render := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/flow_%d/" % Time.get_ticks_usec()
	can_render = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/flow/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	test_copy()
	test_replay()
	surface = SubViewport.new()
	surface.size = Vector2i(1280, 720)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	ui = MainScene.instantiate()
	surface.add_child(ui)
	await test_controller()
	await test_terminal_transitions()
	await test_visible_sequence(Vector2i(1280, 720))
	await test_visible_sequence(Vector2i(390, 844))
	print("FLOW SMOKE: %d assertions; %d screenshots; %d issues" % [checks, captured, errors.size()])
	for issue in errors: print("FLOW ISSUE: ", issue)
	quit(0 if errors.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		push_error(message)

func equal(left, right) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func roster() -> Array:
	return [Data.new_monster("m0", "Rook"), Data.new_monster("m1", "Moss"), Data.new_monster("m2", "Pip")]

func enemy(id: String, ability: String, hp: int = 100) -> Dictionary:
	return {"id": id, "name": "Invader " + id, "class_name": "warrior", "form": "warrior", "hp": hp, "max_hp": hp, "abilities": [ability], "block": 0, "statuses": {}}

func fixture(party: Array = []) -> RefCounted:
	var battle = Combat.new()
	var random := RandomNumberGenerator.new()
	random.seed = 43811
	battle.setup(roster(), [enemy("e0", "heavy_blow")] if party.is_empty() else party, random)
	return battle

func card(ability: String, owner: String = "m0") -> Dictionary:
	return {"id": "flow_" + ability, "ability": ability, "owner": owner}

func clone(battle):
	var saved: Dictionary = battle.to_dict()
	var result = Combat.new()
	result.restore(saved, saved["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	return result

func locked(battle, id: String, ability: String, target: String) -> void:
	battle.intents.append({"enemy_id": id, "ability": ability, "target_id": target, "text": "fixture"})

func test_copy() -> void:
	var battle = fixture([enemy("e0", "heavy_blow"), enemy("e1", "mend")])
	battle.intents.clear()
	locked(battle, "e0", "heavy_blow", "m0")
	locked(battle, "e1", "mend", "e0")
	battle.enemies[0]["hp"] = 95
	battle.monsters[0]["block"] = 3
	var before: Dictionary = battle.to_dict()
	var announced: Dictionary = Copy.intent(battle, battle.enemies[0])
	check(announced["targets"] == ["m0"] and announced["damage"] == 8, "Numeric heavy blow names the actual monster destination and raw damage")
	check(announced["line"].contains("8 damage") and announced["line"].contains("Rook"), "Enemy announcement visibly states damage and destination")
	var heal: Dictionary = Copy.intent(battle, battle.enemies[1])
	check(heal["targets"] == ["e0"] and heal["line"].contains("Heal 6"), "Enemy Mend derives its own faction rather than monster ally targets")
	var preview: String = Copy.preview(battle, card("heavy_blow"), battle.monsters[0])
	check(preview.contains("5 HP lost") and preview.contains("3 blocked"), "Target preview separates damage from blocked HP loss")
	battle.monsters[0]["statuses"]["evasion"] = 1
	check(Copy.preview(battle, card("heavy_blow"), battle.monsters[0]).contains("Evades 8"), "Target preview explains an evasion instead of promising HP damage")
	battle.monsters[0]["statuses"].clear()
	battle.monsters[0]["hp"] = 19
	check(Copy.preview(battle, card("mend"), battle.monsters[0]).contains("+1 HP"), "Heal preview is capped to missing HP")
	battle.hand = [card("strike"), card("rally", "")]
	check(Copy.guidance(battle, 0, false).contains("Rook") and Copy.guidance(battle, 0, false).contains("Strike"), "Selected owned card says which monster uses which ability")
	check(Copy.guidance(battle, 1, false).contains("Dungeon") and Copy.guidance(battle, 1, false).contains("Rally"), "Selected shared card names the dungeon and ability")
	check(Copy.guidance(battle, 1, false).contains("ALL monsters"), "Shared area action identifies every affected side")
	check(Copy.unavailable(battle, battle.hand[0], true) != "", "Busy card explains why it is unavailable")
	battle.energy = 0
	check(Copy.guidance(battle, -1, false).contains("End your turn"), "Empty energy tells the player the next action")
	battle.enemies[0]["statuses"]["stun"] = 1
	check(Copy.intent(battle, battle.enemies[0])["targets"].is_empty(), "Stunned actor makes no promised attack")
	battle.enemies[0]["hp"] = 0
	check(Copy.intent(battle, battle.enemies[0])["line"].contains("DEFEATED"), "Dead actor explicitly cannot act")
	var fresh = clone(fixture())
	var untouched: Dictionary = fresh.to_dict()
	for index in range(20):
		Copy.intent(fresh, fresh.enemies[0])
		Copy.threats(fresh, "m0")
		Copy.card_effect(fresh, card("rally", ""))
		Copy.preview(fresh, card("strike"), fresh.enemies[0])
	check(equal(untouched, fresh.to_dict()), "Repeated presentation queries preserve all combat fields and RNG")
	check(before["monster_combat"][0]["hp"] == 20, "Copy query fixtures use independent snapshots")

func verify_replay(battle, tag: String):
	var before: Dictionary = battle.to_dict()
	var expected = clone(battle)
	expected.end_turn()
	var replay = Replay.make(battle)
	check(equal(expected.to_dict(), replay.to_dict()), tag + ": trace and ordinary simulation end at identical battle/RNG")
	check(equal(before, battle.to_dict()), tag + ": capture does not mutate authoritative source")
	check(not replay.frames.is_empty(), tag + ": trace records presentation frames")
	for frame in replay.frames:
		check(frame.has("before") and frame.has("after") and frame.has("message"), tag + ": frame carries immutable before/after and meaningful message")
		check(frame["before"].has("rng_state") and frame["after"].has("intents"), tag + ": snapshots preserve RNG and locked intentions")
	check(equal(replay.frames.back()["after"], replay.to_dict()), tag + ": final trace snapshot is actual final result")
	return replay

func enemy_frames(replay) -> Array:
	return replay.frames.filter(func(frame): return frame["kind"] == "enemy")

func test_replay() -> void:
	var battle = fixture()
	battle.monsters[0]["block"] = 5
	var replay = verify_replay(battle, "blocked attack / draw")
	var action: Dictionary = enemy_frames(replay)[0]
	check(action["before"]["monster_combat"][0]["hp"] == 20 and action["after"]["monster_combat"][0]["hp"] == 17, "Trace shows the individual attack HP change after block")
	check(Feedback.describe(action["before"], action["after"]).contains("Rook: -3 HP"), "Action feedback reports the actual recipient and HP lost")
	check(replay.frames[0]["kind"] == "player_end" and replay.frames.back()["kind"] == "draw", "Chronology separates ending player turn from refreshed player hand")
	var saved_last: Dictionary = replay.frames.back()["after"].duplicate(true)
	replay.frames[0]["before"]["monster_combat"][0]["hp"] = 999
	check(equal(saved_last, replay.frames.back()["after"]) and battle.monsters[0]["hp"] == 20, "Editing one tape snapshot cannot alter later snapshots or real state")
	var rotating = fixture([enemy("e0", "heavy_blow"), enemy("e1", "strike")])
	rotating.monsters[0]["hp"] = 1
	rotating.intents.clear()
	locked(rotating, "e0", "heavy_blow", "m0")
	locked(rotating, "e1", "strike", "m0")
	var chain = verify_replay(rotating, "KO retarget")
	check(enemy_frames(chain)[0]["target_ids"] == ["m0"] and enemy_frames(chain)[1]["target_ids"] == ["m1"], "Sequential action destinations rotate only after target KO")
	check(Feedback.describe(enemy_frames(chain)[0]["before"], enemy_frames(chain)[0]["after"]).contains("KO"), "KO callout is tied to the precise attack")
	var skipped = fixture([enemy("e0", "strike"), enemy("e1", "strike"), enemy("e2", "guard")])
	skipped.enemies[0]["hp"] = 0
	skipped.enemies[1]["statuses"]["stun"] = 1
	var skipping = verify_replay(skipped, "dead and stunned actors")
	check(enemy_frames(skipping).size() == 1 and enemy_frames(skipping)[0]["actor_id"] == "e2", "Dead and stunned enemies never produce attacking frames")
	check(skipping.frames.filter(func(frame): return frame["kind"] == "stun").size() == 1, "Stun consumption has an explicit skipped-action beat")
	var dots = fixture([enemy("e0", "heavy_blow", 1)])
	dots.enemies[0]["statuses"]["poison"] = 1
	var victory = verify_replay(dots, "enemy DoT victory")
	check(victory.outcome == "won" and enemy_frames(victory).size() == 1, "Enemy acts before its own ending poison wins the raid")
	check(victory.frames.back()["kind"] == "finish" and victory.turn == 1, "Terminal victory tape has no new player draw")
	var breach = fixture()
	for monster in breach.monsters:
		monster["hp"] = 1
		monster["statuses"]["burn"] = 1
	var loss = verify_replay(breach, "monster DoT breach")
	check(loss.outcome == "breach" and enemy_frames(loss).is_empty(), "Friendly lethal ending status ends raid before enemy acts")
	check(loss.frames.back()["after"]["monster_combat"].all(func(m): return m["hp"] == 0), "Breach finish snapshots retain KO before recovery")
	var regen = fixture([enemy("e0", "guard")])
	regen.monsters[0]["hp"] = 10
	regen.monsters[0]["statuses"] = {"poison": 3, "burn": 2, "regen": 4, "stun": 1}
	var healed = verify_replay(regen, "additive statuses and regeneration")
	check(healed.monsters[0]["hp"] == 9 and healed.monsters[0]["statuses"].get("stun", 0) == 0, "Status timeline preserves damage-before-healing and friendly stun decay")
	var empty = fixture()
	empty.hand.clear()
	empty.draw_pile.clear()
	empty.discard.clear()
	verify_replay(empty, "empty hand and deck")

func set_game(tag: String, party: Array = []) -> void:
	game = CountingState.new(profile_root + tag + "/")
	game.new_run(43811)
	game.run["monsters"] = roster()
	game.run["party"] = [enemy("e0", "heavy_blow"), enemy("e1", "guard")] if party.is_empty() else party
	game.start_raid()
	game.end_calls = 0
	game.save_calls = 0
	ui.state = game
	ui.menu = "game"
	ui.card_index = -1
	ui.last_action = ""
	ui.refresh()

func settle() -> void:
	for index in range(6): await process_frame
	if can_render: await RenderingServer.frame_post_draw

func test_controller() -> void:
	set_game("controller")
	game.battle.hand = [card("strike"), card("rally", "")]
	ui.card_index = 0
	ui.refresh()
	await settle()
	ui.play_selected_card("e0")
	await settle()
	check(game.battle.enemies[0]["hp"] == 94 and game.battle.energy == 2, "Player action controller resolves actual owned card once")
	check(ui.last_action.contains("Rook") and ui.last_action.contains("Strike") and ui.last_action.contains("-6 HP"), "Player action feedback names actor, ability and actual HP result")
	game.save_calls = 0
	ui.flow.delay_scale = 1.0
	ui.end_player_turn()
	check(ui.resolving_turn and game.end_calls == 1 and game.save_calls == 1, "First end click commits exactly one authoritative turn and save before playback")
	var final: Dictionary = game.battle.to_dict()
	var turn: int = game.battle.turn
	ui.end_player_turn()
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	ui._unhandled_key_input(space)
	ui.card_index = 0
	ui.play_selected_card("e0")
	ui.act(game.end_turn)
	check(game.end_calls == 1 and equal(final, game.battle.to_dict()), "Duplicate End / Space / stale target / generic action cannot act during enemy sequence")
	var reloaded = State.new(profile_root + "controller/")
	check(reloaded.load_game() and equal(final, reloaded.battle.to_dict()), "Reload during playback restores already committed final state and RNG")
	var view_before: Dictionary = ui.combat_battle().to_dict()
	var stage: String = ui.turn_stage
	surface.size = Vector2i(390, 844)
	await settle()
	check(ui.resolving_turn and ui.turn_stage == stage and equal(view_before, ui.combat_battle().to_dict()), "Orientation during a beat preserves the visual frame")
	check(equal(final, game.battle.to_dict()), "Orientation during playback never changes authoritative combat")
	ui.skip_turn_animation()
	await settle()
	check(not ui.resolving_turn and ui.combat_battle() == game.battle and game.battle.turn == turn, "Skip discards tape and reveals the committed next turn")
	await create_timer(0.4).timeout
	check(game.end_calls == 1 and equal(final, game.battle.to_dict()), "Cancelled timers cannot resume the old sequence or resolve a second turn")
	ui.flow.delay_scale = 0
	ui.end_player_turn()
	await wait_finished()
	check(game.end_calls == 2 and game.battle.turn == turn + 1, "A completed skipped sequence allows exactly one later turn")

func wait_finished() -> void:
	for step in range(300):
		if not ui.resolving_turn: return
		await create_timer(0.01).timeout
	check(false, "Presentation finishes within bounded timeout")
	ui.skip_turn_animation()

func test_terminal_transitions() -> void:
	set_game("breach")
	for monster in game.battle.monsters:
		monster["hp"] = 1
		monster["statuses"]["poison"] = 1
	ui.flow.delay_scale = 1.0
	ui.end_player_turn()
	check(game.run["phase"] == "result" and game.run["core"] == 75, "Breach state and core loss commit before terminal playback")
	check(game.run["monsters"].all(func(m): return m["hp"] == 5), "Authoritative breach recovery occurs exactly once before visual tape")
	var recovered: Dictionary = game.run.duplicate(true)
	var reload = State.new(profile_root + "breach/")
	check(reload.load_game() and reload.run["core"] == 75 and reload.run["monsters"].all(func(m): return m["hp"] == 5), "Mid-breach reload retains the once-recovered result")
	ui.skip_turn_animation()
	await settle()
	check(equal(recovered, game.run) and game.end_calls == 1, "Skipping breach sequence cannot change recovery or core")
	set_game("won", [enemy("e0", "guard", 1)])
	game.battle.enemies[0]["statuses"]["poison"] = 1
	ui.end_player_turn()
	check(game.run["phase"] == "feeding" and game.run["rewards"].size() == 1, "Victory creates actual feeding body before playback ends")
	ui.skip_turn_animation()
	await settle()
	check(game.run["monsters"].all(func(m): return m["hp"] == 20) and game.run["recovered_id"] == 0, "Victory playback cannot apply the recovery reserved for feeding completion")

func test_visible_sequence(pixels: Vector2i) -> void:
	surface.size = pixels
	set_game("visible_%dx%d" % [pixels.x, pixels.y])
	game.battle.monsters[0]["block"] = 3
	ui.flow.delay_scale = 1.0
	ui.refresh()
	await capture("%dx%d_player" % [pixels.x, pixels.y])
	if pixels.x >= 1000:
		for monster in game.run["monsters"]:
			var actor_button = named_button(ui, "Actor_" + monster["id"])
			if actor_button == null: actor_button = ui.actor_nodes.get(monster["id"])
			check(actor_button != null, "Desktop renders each monster's actual target control")
			if actor_button == null: continue
			var sc = actor_button.get_parent()
			while sc != null and not sc is ScrollContainer: sc = sc.get_parent()
			if sc == null and is_instance_valid(ui.battlefield): sc = ui.battlefield
			check(sc != null and sc.get_global_rect().grow(1).encloses(actor_button.get_global_rect()), "Desktop baseline shows all three monster actors without scrolling")
	ui.end_player_turn()
	var committed: Dictionary = game.battle.to_dict()
	var seen: Dictionary = {}
	for step in range(500):
		if not ui.resolving_turn: break
		var key: String = ui.turn_stage + "_" + ui.acting_actor_id + ("_after" if ui.turn_detail != "" else "_before")
		if not seen.has(key):
			seen[key] = true
			check(ui.turn_message != "", "Every visible beat names the current action")
			check(ui.combat_battle() != game.battle and equal(committed, game.battle.to_dict()), "Visible sequence uses an isolated model without changing committed combat")
			var end_button = named_button(ui, "EndTurn")
			var skip_button = named_button(ui, "SkipTurn")
			check((end_button == null or end_button.disabled) and skip_button != null and not skip_button.disabled, "Enemy playback replaces end-turn action with an enabled skip action")
			if ui.turn_stage == "enemy" and ui.acting_actor_id == "e0":
				check(ui.acting_target_ids == ["m0"], "Visible attack identifies precise caster and recipient")
				await capture("%dx%d_%s" % [pixels.x, pixels.y, key])
			elif ui.turn_stage in ["player_end", "draw"]:
				await capture("%dx%d_%s" % [pixels.x, pixels.y, key])
		await create_timer(0.01).timeout
	check(not ui.resolving_turn, "Visible timeline completes")
	check(seen.keys().any(func(key): return key.begins_with("enemy_e0")), "Visible timeline actually presents an announced enemy action")
	check(seen.keys().any(func(key): return key.begins_with("draw")), "Visible timeline actually presents the new player hand")
	await capture("%dx%d_next_player" % [pixels.x, pixels.y])
	# Let temporary native action callouts expire before creating another fixture.
	await create_timer(0.8).timeout
	await capture_terminal(pixels, false)
	await capture_terminal(pixels, true)

func capture_terminal(pixels: Vector2i, breach: bool) -> void:
	var label_ := "breach" if breach else "victory"
	set_game("terminal_%s_%dx%d" % [label_, pixels.x, pixels.y], [enemy("e0", "guard", 1)])
	if breach:
		for monster in game.battle.monsters:
			monster["hp"] = 1
			monster["statuses"]["poison"] = 1
	else:
		game.battle.enemies[0]["statuses"]["poison"] = 1
	ui.flow.delay_scale = 1.0
	ui.end_player_turn()
	var saw_finish := false
	for step in range(500):
		if not ui.resolving_turn: break
		if ui.turn_stage == "finish" and not saw_finish:
			saw_finish = true
			check(ui.turn_message.contains("next"), "Terminal beat identifies the next progression action")
			if breach:
				check(ui.combat_battle().monsters.all(func(m): return m["hp"] == 0) and game.run["monsters"].all(func(m): return m["hp"] == 5), "Terminal breach displays KO while persisted run is already recovered")
			await capture("%dx%d_%s_finish" % [pixels.x, pixels.y, label_])
		await create_timer(0.01).timeout
	check(saw_finish and not ui.resolving_turn, "Terminal sequence presents completion then reaches its final screen")
	await capture("%dx%d_%s_result" % [pixels.x, pixels.y, label_])

func named_button(node: Node, name_: String):
	if node is Button and node.name == name_ and node.is_visible_in_tree() and not node.is_queued_for_deletion(): return node
	for child in node.get_children():
		var found = named_button(child, name_)
		if found != null: return found
	return null

func capture(tag: String) -> void:
	await settle()
	inspect_bounds(ui, tag)
	if can_render:
		check(surface.get_texture().get_image().save_png("res://tests/artifacts/flow/" + tag + ".png") == OK, "Flow capture saved " + tag)
		captured += 1

func inspect_bounds(node: Node, tag: String) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is BaseButton):
		var scrolled := false
		var horizontally_scrolled := false
		var owner_button
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is BaseButton and owner_button == null: owner_button = ancestor
			if ancestor is ScrollContainer:
				scrolled = scrolled or ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				horizontally_scrolled = horizontally_scrolled or ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		if not horizontally_scrolled: check(rect.position.x >= -1 and rect.end.x <= surface.size.x + 1, tag + ": horizontal bounds " + str(node.name) + " " + str(rect) + " " + (node.text if node is Label else ""))
		if not scrolled: check(rect.position.y >= -1 and rect.end.y <= surface.size.y + 1, tag + ": vertical bounds " + str(node.name))
		if node is Label and owner_button != null:
			check(owner_button.get_global_rect().grow(1).encloses(rect), tag + ": actor/button contains label " + node.text.left(100))
	for child in node.get_children(): inspect_bounds(child, tag)
