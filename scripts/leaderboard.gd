class_name LeaderboardPanel
extends Control

## Popup leaderboard shown from the main menu. A centered panel (mirroring the
## settings panel's look) that lists the all-time top-5 scores, refreshed every
## time it opens. Closes on its BACK button, or on a click outside the panel
## (handled by the main menu's _input guard).

@onready var _board_label: Label = $Panel/VBox/BoardLabel
@onready var _back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	visible = false
	_back_button.pressed.connect(_on_back_pressed)
	_refresh()


## Re-reads the leaderboard and reveals the popup. Called by the menu's
## "High Scores" button so the board is always fresh when opened.
func open() -> void:
	_refresh()
	visible = true


## The panel's inner rect, used by the main menu's click guard to decide
## whether a click lands inside the panel (let the GUI handle it) or outside
## (close the popup).
func panel_rect() -> Rect2:
	var panel := get_node_or_null("Panel") as Control
	if panel == null:
		return Rect2()
	return panel.get_global_rect()


func _refresh() -> void:
	HighScores.ensure_loaded()
	_board_label.text = HighScores.entries_text()


func _on_back_pressed() -> void:
	visible = false