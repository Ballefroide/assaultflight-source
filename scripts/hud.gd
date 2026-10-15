extends CanvasLayer
## HUD: shows the elapsed time in the "time" label, off-screen arrows, and the
## countermeasure cooldown readout.

const ARROW_SCRIPT := preload("res://scripts/missile_arrow.gd")
## Arrow colors match each entity's ribbon trail.
const MISSILE_TRAIL_COLOR := Color(1.0, 0.7, 0.2, 1.0)
const ENEMY_TRAIL_COLOR := Color(1.0, 0.5, 0.4, 1.0)

@onready var _label: Label = $time
@onready var _cooldown_f: Label = $"cooldown-f"
@onready var _score_label: Label = $Score

## Center-screen overlay flash textures.
@onready var _start_overlay: TextureRect = $Start
@onready var _damage_overlay: TextureRect = $Damage
@onready var _destroy_enemy_overlay: TextureRect = $DestroyEnemy
@onready var _end_overlay: TextureRect = $End

## Player health status icon.
@onready var _player_health: TextureRect = $playerHealth

## Health-status textures: full, damaged, and critical.
const HP_FULL_TEXTURE := preload("res://assets/hpfull.png")
const HP_DAMAGED_TEXTURE := preload("res://assets/hpdamaged.png")
const HP_CRITICAL_TEXTURE := preload("res://assets/hpcritical.png")

## Black vignette overlay flashed when the player takes a hit.
var _vignette: Vignette

## How long a brief overlay stays at full opacity before fading out.
const OVERLAY_HOLD := 0.6
## How long the brief overlay fade-out lasts.
const OVERLAY_FADE := 0.4
## Active fade tweens per overlay, so a re-trigger cancels the previous one.
var _overlay_tweens := {}

## Live score: +1 per second alive, +5 per missile hit, +10 per shoot-down.
var _score := 0
## Fractional time-score accumulator, so we can award 1 point per full second.
var _time_score_f := 0.0
## Elapsed gameplay time in seconds. Starts at 0 and resets on every new game
## (the HUD is recreated whenever the main scene reloads).
var _game_time := 0.0


func _ready() -> void:
	add_to_group("hud")
	# The "time" label keeps its scene layout (bottom-right, next to the
	# "Elapsed Time:" caption) — we only drive its text from here.
	# The center-screen overlay flashes start hidden.
	_start_overlay.visible = false
	_damage_overlay.visible = false
	_destroy_enemy_overlay.visible = false
	_end_overlay.visible = false
	_build_vignette()
	_build_ring()
	_build_tracker("MissileArrow", "missiles", MISSILE_TRAIL_COLOR)
	_build_tracker("EnemyArrow", "enemies", ENEMY_TRAIL_COLOR)


## Builds the hit vignette overlay and keeps it behind the HUD labels so the
## score/time readouts stay crisp on top of it.
func _build_vignette() -> void:
	_vignette = Vignette.new()
	_vignette.name = "Vignette"
	add_child(_vignette)
	move_child(_vignette, 0)


## Builds the target ring drawn around the player; the off-screen missile and
## enemy trackers sit on it, pointing outward from the player.
func _build_ring() -> void:
	var ring := PlayerRing.new()
	ring.name = "PlayerRing"
	add_child(ring)
	move_child(ring, 1)


## Briefly flashes the vignette (called by the player when it takes a hit).
func flash_vignette() -> void:
	if _vignette != null:
		_vignette.flash()


## Briefly shows the "Start" overlay right after a game begins.
func flash_start() -> void:
	_flash_overlay(_start_overlay)


## Briefly shows the "Damage" overlay when the player takes a hit.
func flash_damage() -> void:
	_flash_overlay(_damage_overlay)


## Briefly shows the "DestroyEnemy" overlay when the player shoots down a plane.
func flash_destroy_enemy() -> void:
	_flash_overlay(_destroy_enemy_overlay)


## Shows the "End" marker the moment the player dies. It's unique: it stays up
## through the whole death sequence — exempt from hide_gameplay_ui — and is
## only hidden again when the game-over transition begins.
func show_end() -> void:
	if _end_overlay != null:
		_end_overlay.visible = true
		_end_overlay.modulate.a = 1.0


## Hides the "End" marker (called once the game-over transition begins, so the
## marker doesn't linger behind the game-over screen).
func hide_end() -> void:
	if _end_overlay != null:
		_end_overlay.visible = false


## Hides every gameplay HUD element instantly the moment the player dies
## (score, time, health, reticle, ring, arrows, vignette, overlays). Keeps the
## "End" marker (unique — it stays up through the death sequence) and the
## time-of-day overlay (so the world keeps its sunset/night lighting grade
## behind the death + game-over screens).
func hide_gameplay_ui() -> void:
	for child in get_children():
		if child.name != "TimeOfDay" and child.name != "End":
			child.visible = false


## Shows one of the center-screen overlays at full opacity, holds it, then
## fades it out and hides it. A re-trigger cancels any in-progress fade first.
func _flash_overlay(rect: TextureRect) -> void:
	if rect == null:
		return
	if _overlay_tweens.has(rect):
		var old: Tween = _overlay_tweens[rect]
		if is_instance_valid(old):
			old.kill()
	rect.visible = true
	rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(OVERLAY_HOLD)
	tw.tween_property(rect, "modulate:a", 0.0, OVERLAY_FADE)
	tw.tween_callback(func() -> void: rect.visible = false)
	_overlay_tweens[rect] = tw


func _process(delta: float) -> void:
	# Only counts while the game is actually running: the tree is paused during
	# the menu and game-over screens, so _process (and this accumulation) is
	# skipped then. It resets to 0 because a fresh HUD is built per game.
	_game_time += delta
	var minutes := floori(_game_time / 60.0)
	var seconds := int(_game_time) % 60
	_label.text = "%d:%02d" % [minutes, seconds]
	_update_cooldowns()
	_update_player_health()
	_update_time_score(delta)


## Reads the player's cooldowns and shows them in the cooldown-f / cooldown-m
## labels. Displays "Ready" when a system is available.
func _update_cooldowns() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	_cooldown_f.text = _format_cooldown(player.get_flare_cooldown())


## Shows the health-status icon based on the player's current HP:
## full (>= 75%), damaged (< 75%), or critical (<= 25%, incl. dead).
func _update_player_health() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or _player_health == null:
		return
	var ratio: float = player.get_hp() / float(Player.MAX_HP)
	var tex: Texture2D
	if ratio >= 0.75:
		tex = HP_FULL_TEXTURE
	elif ratio > 0.25:
		tex = HP_DAMAGED_TEXTURE
	else:
		tex = HP_CRITICAL_TEXTURE
	if _player_health.texture != tex:
		_player_health.texture = tex



func _format_cooldown(cd: float) -> String:
	if cd <= 0.0:
		return "Ready"
	return str(ceili(cd))


## Builds an off-screen tracker: one arrow per off-screen target in the group,
## tinted with the given color.
func _build_tracker(node_name: String, target_group: String, color: Color) -> void:
	var tracker := Node2D.new()
	tracker.name = node_name
	tracker.set_script(ARROW_SCRIPT)
	tracker.set("group_name", target_group)
	tracker.set("arrow_color", color)
	add_child(tracker)


## Awards +1 point per full second the player is alive.
func _update_time_score(delta: float) -> void:
	_time_score_f += delta
	while _time_score_f >= 1.0:
		_time_score_f -= 1.0
		_score += 1
	_update_score_label()


## Adds points for gameplay events (missile hits, enemy shoot-downs).
func add_score(amount: int) -> void:
	_score += amount
	_update_score_label()


func _update_score_label() -> void:
	if _score_label != null:
		_score_label.text = str(_score)


## Called once the player-death sequence finishes: shows the game-over overlay
## with the final score. The "End" marker is unique and stays visible — the
## game-over screen draws over it, so it doesn't need hiding.
func show_game_over() -> void:
	var go := get_node_or_null("../GameOver")
	if go != null:
		go.call("show_game_over", _score)
