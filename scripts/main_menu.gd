class_name MainMenu
extends CanvasLayer

## Simple main menu overlay. Pauses the game behind it until the player clicks
## anywhere, then cross-fades to black, hands control back to the game, and
## removes the menu overlay.
##
## Runs with PROCESS_MODE_ALWAYS so it keeps receiving input while the rest of
## the tree is paused.

## When true, the freshly-loaded scene skips the menu and goes straight into a
## new run. Set by the game-over "Play Again" button before reloading the
## scene; the reload's letterbox reveals the new game directly.
static var quick_start := false

var _transitioning := false

## The "Click anywhere to get airborne" prompt, which blinks to invite a click.
@onready var _prompt: Label = $Prompt

## The "HIGH SCORES" button that opens the leaderboard popup, and the popup
## itself (an instanced scene that shows the all-time top-5 board).
@onready var _high_scores_button: Button = $HighScoresButton
@onready var _leaderboard: Control = $Leaderboard

## Settings UI: the button that opens the panel, the panel itself, and the
## graphics/audio controls inside it.
@onready var _settings_button: Button = $SettingsButton
@onready var _exit_button: Button = $ExitButton
@onready var _settings_panel: PanelContainer = $SettingsPanel
@onready var _audio_toggle: CheckButton = $SettingsPanel/VBox/AudioToggle
@onready var _clouds_toggle: CheckButton = $SettingsPanel/VBox/CloudsToggle
@onready var _fullscreen_toggle: CheckButton = $SettingsPanel/VBox/FullscreenToggle
@onready var _res_option: OptionButton = $SettingsPanel/VBox/ResRow/ResOption
@onready var _back_button: Button = $SettingsPanel/VBox/BackButton


func _ready() -> void:
	# Make sure the menu is on screen: the instance can start hidden in the
	# scene file, and nothing else ever shows it. Without this the "Main Menu"
	# return path would reload into an invisible, dead-end screen.
	visible = true
	# Freeze the game world behind the menu.
	get_tree().paused = true
	# The HUD belongs to gameplay, so keep it hidden behind the menu overlay.
	get_node("../HUD").visible = false
	# Apply the saved settings (graphics + audio) and populate the settings
	# panel. Runs before the quick-start branch so the settings are in effect
	# on every load, quick-start or not.
	GameSettings.ensure_loaded()
	GameSettings.apply_window()
	GameSettings.apply_clouds(get_parent())
	GameSettings.apply_audio()
	_setup_settings_ui()
	_setup_leaderboard()
	# Silence any background audio from a previous run — background
	# loops only play during active gameplay.
	AudioManager.stop_all()
	# "Play Again" reloaded the scene: skip the menu and jump straight into a
	# fresh run. The reload's letterbox is still opening, so it reveals the
	# new game directly.
	if quick_start:
		quick_start = false
		_begin_game()
		return
	# Cinematic opening: fade in from black to reveal the title screen.
	ScreenTransition.fade_in_from_black(0.9)
	# Blink the "click to start" prompt so players notice it's interactive.
	_blink_prompt()


## Loops the prompt's opacity between dim and bright to draw the eye.
func _blink_prompt() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_prompt, "modulate:a", 0.15, 0.55)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.55)


func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var pos := mb.position
		# The settings and leaderboard UIs handle their own clicks — never start
		# the game on them.
		if _settings_panel.visible:
			# Clicks inside the panel go to its controls; clicks outside close it.
			if _settings_panel.get_global_rect().has_point(pos):
				return
			_settings_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if _leaderboard.visible:
			# Clicks inside the panel go to its controls; clicks outside close it.
			if _leaderboard.panel_rect().has_point(pos):
				return
			_leaderboard.visible = false
			get_viewport().set_input_as_handled()
			return
		if _high_scores_button.get_global_rect().has_point(pos):
			return
		if _settings_button.get_global_rect().has_point(pos):
			return
		if _exit_button.get_global_rect().has_point(pos):
			return
		# Consume the click so it doesn't also steer the plane on the first frame.
		get_viewport().set_input_as_handled()
		_start_game()


## Wires up the "HIGH SCORES" button that opens the leaderboard popup.
func _setup_leaderboard() -> void:
	_high_scores_button.pressed.connect(_on_high_scores_pressed)


## Opens or closes the leaderboard popup.
func _on_high_scores_pressed() -> void:
	if _leaderboard.visible:
		_leaderboard.visible = false
	else:
		_leaderboard.open()


## Populates the settings panel controls with the saved values and wires them up.
func _setup_settings_ui() -> void:
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_audio_toggle.toggled.connect(_on_audio_toggled)
	_clouds_toggle.toggled.connect(_on_clouds_toggled)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_res_option.item_selected.connect(_on_resolution_selected)
	_back_button.pressed.connect(_on_back_pressed)
	for res: Vector2i in GameSettings.RESOLUTIONS:
		_res_option.add_item("%d x %d" % [res.x, res.y])
	_audio_toggle.set_pressed_no_signal(GameSettings.audio_enabled)
	_clouds_toggle.set_pressed_no_signal(GameSettings.clouds_enabled)
	_fullscreen_toggle.set_pressed_no_signal(GameSettings.fullscreen)
	_res_option.select(GameSettings.resolution_index)


func _on_settings_pressed() -> void:
	_settings_panel.visible = not _settings_panel.visible


## Exit button: closes the game. The button is exempt from the click-anywhere
## start (handled in _input), so clicking it never starts a run.
func _on_exit_pressed() -> void:
	get_tree().quit()


## Sound toggle: applies immediately (like the graphics toggles) by muting or
## unmuting the game's audio and persisting the choice.
func _on_audio_toggled(pressed: bool) -> void:
	GameSettings.audio_enabled = pressed
	GameSettings.save()
	GameSettings.apply_audio()


func _on_clouds_toggled(pressed: bool) -> void:
	GameSettings.clouds_enabled = pressed
	GameSettings.save()
	GameSettings.apply_clouds(get_parent())


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.fullscreen = pressed
	GameSettings.save()
	GameSettings.apply_window()


func _on_resolution_selected(index: int) -> void:
	GameSettings.resolution_index = index
	GameSettings.save()
	GameSettings.apply_window()


func _on_back_pressed() -> void:
	_settings_panel.visible = false


## Starts the game: cross-fades to black, then unpauses the world and removes
## the menu overlay before fading back in.
func _start_game() -> void:
	_transitioning = true
	# A film-style letterbox cut makes the jump into gameplay feel like a scene
	# change in a movie rather than a hard wipe.
	ScreenTransition.transition(_begin_game, ScreenTransition.STYLE_LETTERBOX, 0.6)


## Hands control to the game and removes the menu overlay. Used both by the
## normal click-to-start flow (wrapped in a letterbox by _start_game) and by
## the "Play Again" quick-start (called directly on load).
func _begin_game() -> void:
	# Hand control to the plane now that the game is actually starting.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("enable_control"):
		player.call("enable_control")
	get_node("../HUD").visible = true
	var hud := get_node_or_null("../HUD")
	if hud != null and hud.has_method("flash_start"):
		hud.call("flash_start")
	get_tree().paused = false
	# Background loops only during active gameplay — silent on the
	# menu and game-over screen.
	AudioManager.play_wind()
	AudioManager.play_jet_engine()
	queue_free()
