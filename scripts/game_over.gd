class_name GameOverScreen
extends CanvasLayer

## Game-over overlay: shown after the player's death sequence. The looping death
## animation (still playing behind this screen) becomes the background, and the
## world is left frozen until the player chooses what to do next — Play Again
## (fresh run) or Main Menu (title screen). Only then is the scene cleaned up
## (by reloading).

## Darkening over the frozen world + wreck so the UI stays readable.
const DIM_ALPHA := 0.45
## Slow autoscroll speeds for the parallax sky while the game-over is up
## (foreground layers drift faster for depth). Reset automatically on reload.
const SKY_AUTOSCROLL := {
	"Background": Vector2(6, 0),
	"Clouds": Vector2(14, 0),
	"Clouds2": Vector2(22, 0),
}

@onready var _score_label: Label = $ScoreLabel
@onready var _best_label: Label = $BestLabel
@onready var _hi_scores_label: Label = $HiScoresLabel
@onready var _play_again: Button = $PlayAgain
@onready var _main_menu: Button = $MainMenu

## Gold highlight for a freshly-set record.
const RECORD_COLOR := Color(1, 0.84, 0.3, 1)

## False until the reveal cross-fade finishes, so clicks during the fade don't
## trigger an early choice.
var _accepting_input := false


func _ready() -> void:
	visible = false
	# Keep receiving input (and stay interactive) while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play_again.pressed.connect(_on_play_again)
	_main_menu.pressed.connect(_on_main_menu)
	_blink_play_again()


## Reveals the overlay with a cross-fade, shows the player's final score, and
## pauses the world.
func show_game_over(score: int) -> void:
	_score_label.text = "Final Score: %d" % score
	_refresh_high_scores(score)
	# Cut background loops (wind + jet) as the game-over fade begins —
	# background audio is silent on the menu and game-over screens.
	AudioManager.stop_all()
	_accepting_input = false
	# Keep the frozen world + looping wreck as a living background. Hide the
	# gameplay HUD except the time-of-day tint so the lighting stays consistent.
	_hide_hud_but_tod()
	_enable_dynamic_background()
	_enable_world_drift()
	get_tree().paused = true
	# Hide the "End" marker the instant the game-over transition begins — it
	# stays up through the whole death sequence, but must not linger behind the
	# fading-in game-over screen.
	_hide_end_marker()
	# A slow, eased cross-fade for the game-over reveal — the gameplay UI is
	# already gone (hidden at the instant of death), so the game-over screen
	# simply fades in over the smoldering wreck.
	ScreenTransition.transition(func() -> void:
		visible = true
		_accepting_input = true
	, ScreenTransition.STYLE_FADE, 0.8)


## Submits the run's score to the leaderboard and refreshes the best-score and
## board labels. Highlights a newly-set record with a gold callout + pulse.
func _refresh_high_scores(score: int) -> void:
	var new_best := HighScores.submit(score)
	_hi_scores_label.text = HighScores.board_text()
	if new_best:
		_best_label.text = "★ NEW HIGH SCORE! %d ★" % score
		_best_label.add_theme_color_override("font_color", RECORD_COLOR)
		_pulse_record()
	else:
		_best_label.text = "Best: %d" % HighScores.best()
		_best_label.remove_theme_color_override("font_color")


## Gently pulses the record label so a new high score stands out.
func _pulse_record() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_best_label, "modulate:a", 0.55, 0.5)
	tween.tween_property(_best_label, "modulate:a", 1.0, 0.5)


## Hides every HUD child except the time-of-day overlay, so the sunset/night
## tint keeps lighting the world (and the wreck) behind the game-over screen.
## The leftover gameplay HUD (labels, ring, arrows) is gameplay-only. Delegates
## to the HUD's own method — the same one that hides the UI instantly at death.
func _hide_hud_but_tod() -> void:
	var hud := get_node_or_null("../HUD")
	if hud == null:
		return
	if hud.has_method("hide_gameplay_ui"):
		hud.call("hide_gameplay_ui")


## Hides the HUD's unique "End" marker once the game-over transition begins, so
## it doesn't linger behind the fading-in game-over screen.
func _hide_end_marker() -> void:
	var hud := get_node_or_null("../HUD")
	if hud == null:
		return
	if hud.has_method("hide_end"):
		hud.call("hide_end")


## Keeps the parallax sky drifting behind the game-over: the layers get
## PROCESS_MODE_ALWAYS (so they animate while the tree is paused) plus a slow
## autoscroll. Cleared automatically when the scene reloads on the player's
## choice.
func _enable_dynamic_background() -> void:
	var main := get_parent()
	if main == null:
		return
	for layer_name: String in SKY_AUTOSCROLL:
		var p := main.get_node_or_null(layer_name) as Parallax2D
		if p == null:
			continue
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.autoscroll = SKY_AUTOSCROLL[layer_name]


## Puts every leftover enemy plane and missile into drift mode: they stop
## homing/maneuvering and keep flying straight in their final heading while the
## world is paused, so the game-over background stays subtly alive. Each entity
## sets its own PROCESS_MODE_ALWAYS so it keeps moving during the pause.
func _enable_world_drift() -> void:
	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity.has_method("begin_drift"):
			entity.call("begin_drift")
	for entity in get_tree().get_nodes_in_group("missiles"):
		if entity.has_method("begin_drift"):
			entity.call("begin_drift")


## "Play Again": start a fresh run immediately (skips the title screen). The
## scene reload re-randomizes the background + time of day and rebuilds the
## world; the reload letterbox reveals the new game directly.
func _on_play_again() -> void:
	if not _accepting_input:
		return
	_accepting_input = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	MainMenu.quick_start = true
	ScreenTransition.transition(func() -> void:
		get_tree().reload_current_scene()
	, ScreenTransition.STYLE_LETTERBOX, 0.6)


## "Main Menu": return to the title screen. The scene reload lands on the menu,
## which fades itself in from black.
func _on_main_menu() -> void:
	if not _accepting_input:
		return
	_accepting_input = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	ScreenTransition.transition(func() -> void:
		get_tree().reload_current_scene()
	, ScreenTransition.STYLE_LETTERBOX, 0.6)


## Gently pulses the "Play Again" button so it reads as the primary action.
func _blink_play_again() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_play_again, "modulate:a", 0.6, 0.55)
	tween.tween_property(_play_again, "modulate:a", 1.0, 0.55)
