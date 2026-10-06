extends RefCounted

var ui

func _init(owner) -> void:
	ui = owner

func open(return_to: Callable = Callable()) -> void:
	var box: VBoxContainer = ui.open_modal()
	box.name = "SoundSettings"
	box.add_child(ui.label("Sound settings", 23 if ui.is_compact() else 27, ui.EMBER, true))
	var row = HBoxContainer.new()
	box.add_child(row)
	var title: Label = ui.label("Music volume", 17, ui.PARCHMENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var percentage: Label = ui.label("", 16, ui.MOSS)
	percentage.name = "MusicPercentage"
	row.add_child(percentage)
	var volume = HSlider.new()
	volume.name = "MusicVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = roundi(ui.audio.volume * 100)
	volume.custom_minimum_size = Vector2(0, 44)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.focus_mode = Control.FOCUS_ALL
	volume.tooltip_text = "Music volume, from 0 to 100 percent."
	box.add_child(volume)
	var toggle = Button.new()
	toggle.name = "ToggleMusic"
	toggle.custom_minimum_size = Vector2(0, 44)
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.pressed.connect(func():
		ui.audio.set_enabled(not ui.audio.enabled, true)
		_update(percentage, toggle))
	box.add_child(toggle)
	volume.value_changed.connect(func(value: float):
		ui.audio.set_volume(value / 100.0, true)
		_update(percentage, toggle))
	_update(percentage, toggle)
	box.add_child(ui.label("Changes are saved on this device. Muting keeps your chosen volume.", 13, ui.MUTED, true))
	var credits: Label = ui.label("Music: Darkest Child and Darkest Child var A\nKevin MacLeod (incompetech.com)\nCC BY 4.0 · edited for looping and volume", 13, ui.MUTED, true)
	credits.name = "MusicCredits"
	box.add_child(credits)
	var source: Button = ui.button("Composer & music source", func(): OS.shell_open("https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100783"))
	source.name = "MusicSource"
	source.focus_mode = Control.FOCUS_ALL
	box.add_child(source)
	var license: Button = ui.button("Music license · CC BY 4.0", func(): OS.shell_open("https://creativecommons.org/licenses/by/4.0/"))
	license.name = "MusicLicense"
	license.focus_mode = Control.FOCUS_ALL
	box.add_child(license)
	var close_text: String = "Return to log & rules" if return_to.is_valid() else ("Return to battle" if ui.menu == "game" and ui.state.battle != null else "Return to game")
	var close: Button = ui.button(close_text, func():
		ui.close_modal()
		if return_to.is_valid(): return_to.call())
	close.name = "CloseSoundSettings"
	close.focus_mode = Control.FOCUS_ALL
	box.add_child(close)

func _update(percentage: Label, toggle: Button) -> void:
	percentage.text = "%d%%" % roundi(ui.audio.volume * 100)
	if not ui.audio.enabled: percentage.text += " · muted"
	toggle.text = "Mute music" if ui.audio.enabled else "Restore music"
