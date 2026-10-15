extends Node
## Spawns the missiles that fly around the level.
##
## Number of missiles on the map = BASE_MISSILE_COUNT + number of enemy planes
## currently in the "enemies" group. Enemy planes are not set up yet, so today
## that means BASE_MISSILE_COUNT missiles. Each missile spawns at a random
## location away from (just off-screen from) the camera.

const BASE_MISSILE_COUNT := 3
const SPAWN_MARGIN := 120.0
## How often a new wave spawns once missiles are almost all gone.
const RESPAWN_INTERVAL := 5.0
## How often a new wave of enemy planes spawns, regardless of circumstances.
const ENEMY_SPAWN_INTERVAL := 15.0
## Maximum enemy planes that can spawn in a single wave.
const MAX_ENEMIES_PER_WAVE := 3

const MISSILE_SCENE := preload("res://scenes/missile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

## Level backgrounds that rotate per game. Excludes background-main.png and
## bg_mountain.png (the non-gameplay set). All are 512x512, matching the
## Background sprite's tiling setup.
const BACKGROUND_TEXTURES := [
	preload("res://assets/bg_clouds.png"),
	preload("res://assets/bg_desert.png"),
	preload("res://assets/bg_forest.png"),
	preload("res://assets/bg_ocean.png"),
	preload("res://assets/bg_urban.png"),
]
## Index into BACKGROUND_TEXTURES used by the previous game, so we never show the
## same background twice in a row. Static so it survives scene reloads.
static var _last_bg_index := -1

const TimeOfDayScript := preload("res://scripts/time_of_day.gd")
## Time-of-day chosen by the previous game, so we never repeat it twice in a
## row. Static so it survives scene reloads.
static var _last_tod_index := -1

## Seconds at the start of a run during which every missile/plane spawns from the
## EnemySpawn marker (instead of off-screen), giving the level a defined opener.
const MARKER_SPAWN_TIME := 3.0

@onready var _player: Node2D = $Player
@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _enemy_spawn: Marker2D = $EnemySpawn

var _respawn_timer: Timer
var _enemy_timer: Timer
## Gameplay seconds elapsed since the run started. Only advances while the tree
## is unpaused, so the main-menu pause doesn't count toward the opener window.
var _game_elapsed := 0.0


func _ready() -> void:
	# Rotate the background so each game (and its main-menu preview) differs.
	_pick_background()
	# Pick a random time of day (day/sunrise/sunset/night), like the background.
	_apply_time_of_day()
	# Spawn the player at the PlayerSpawn marker.
	_player.global_position = _player_spawn.global_position
	_spawn_missiles()
	_respawn_timer = Timer.new()
	_respawn_timer.wait_time = RESPAWN_INTERVAL
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_spawn_missiles)
	add_child(_respawn_timer)

	# Spawn an enemy plane every 15 seconds, no matter what.
	_enemy_timer = Timer.new()
	_enemy_timer.wait_time = ENEMY_SPAWN_INTERVAL
	_enemy_timer.timeout.connect(_spawn_enemy)
	add_child(_enemy_timer)
	_enemy_timer.start()

	_add_entity_trails()


## Picks the level background for this game, choosing one different from the
## previous game, and applies it to the Background sprite. Runs on scene load so
## the main menu previews the same background the gameplay will use.
func _pick_background() -> void:
	var sprite := get_node_or_null("Background/Sprite2D") as Sprite2D
	if sprite == null or BACKGROUND_TEXTURES.is_empty():
		return
	var idx := randi_range(0, BACKGROUND_TEXTURES.size() - 1)
	if BACKGROUND_TEXTURES.size() > 1:
		while idx == _last_bg_index:
			idx = randi_range(0, BACKGROUND_TEXTURES.size() - 1)
	_last_bg_index = idx
	sprite.texture = BACKGROUND_TEXTURES[idx]


## Randomly picks a time of day for this game (Day / Sunrise / Sunset / Night),
## avoiding the one used last game, and applies it via the HUD's TimeOfDay
## overlay. Day applies no tint. Runs on scene load so the main-menu preview
## shows the same lighting the gameplay will use.
func _apply_time_of_day() -> void:
	var hud := get_node_or_null("HUD") as Node
	if hud == null:
		return
	var tod := hud.get_node_or_null("TimeOfDay") as ColorRect
	if tod == null:
		tod = TimeOfDayScript.new()
		tod.name = "TimeOfDay"
		hud.add_child(tod)
		# Keep it first in the HUD so it tints the world but stays under the HUD
		# labels, reticle, ring, and arrows.
		hud.move_child(tod, 0)
	var idx := randi_range(0, TimeOfDayScript.Tod.size() - 1)
	if TimeOfDayScript.Tod.size() > 1:
		while idx == _last_tod_index:
			idx = randi_range(0, TimeOfDayScript.Tod.size() - 1)
	_last_tod_index = idx
	tod.call("apply_tod", idx)


## Adds a non-particle ribbon trail for the player and disables any old
## CPUParticles2D trails. (Each enemy sets up its own twin ribbons in _ready.)
func _add_entity_trails() -> void:
	var player_trail := Trail2D.new()
	player_trail.trail_color = Color(0.4, 0.8, 1.0, 1.0)
	player_trail.trail_width = 3.0
	player_trail.fade_time = 0.4
	player_trail.set_target(_player)
	add_child(player_trail)

	_disable_particle_trails($Player)
	if has_node("EnemyPlane"):
		_disable_particle_trails($EnemyPlane)


## Spawns a wave of enemy planes. Usually just one, but with a chance of up to
## MAX_ENEMIES_PER_WAVE at once, to keep the level livelier.
func _spawn_enemy() -> void:
	var count := randi_range(1, MAX_ENEMIES_PER_WAVE)
	for i in range(count):
		_spawn_one_enemy()


## Instantiates a single enemy plane at a (slightly jittered) spawn position.
func _spawn_one_enemy() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	# Jitter keeps multiple planes from stacking on the exact same spot, which
	# is otherwise possible during the opening marker-spawn window.
	enemy.global_position = _spawn_position() + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	add_child(enemy)


## Recursively turns off all CPUParticles2D descendants of a node (the old
## particle trails), so the new ribbon trails are the only trail shown.
func _disable_particle_trails(root: Node) -> void:
	for child in root.get_children():
		if child is CPUParticles2D:
			child.emitting = false
		_disable_particle_trails(child)


func _process(delta: float) -> void:
	# Do nothing while the game is paused (main menu / game over).
	if get_tree().paused:
		return
	_game_elapsed += delta
	# Every 5 seconds after missiles drop to 0 or 1 left, spawn a fresh wave.
	# The spawn timers may have been freed when the game-over screen cleared
	# the scene, so guard against that before touching them.
	if _missile_count() <= 1:
		if _respawn_timer != null and is_instance_valid(_respawn_timer) and _respawn_timer.is_stopped():
			_respawn_timer.start()


## How many missiles are currently alive on the map.
func _missile_count() -> int:
	return get_tree().get_nodes_in_group("missiles").size()


## Spawns all the missiles for the current enemy count.
func _spawn_missiles() -> void:
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	var total: int = BASE_MISSILE_COUNT + enemy_count
	for i in range(total):
		_spawn_missile()


func _spawn_missile() -> void:
	var missile: Missile = MISSILE_SCENE.instantiate()
	missile.global_position = _spawn_position()
	# Add to the tree first so the missile's _ready() runs and its sprite is
	# ready before we orient it.
	add_child(missile)
	# Give it an initial direction generally toward the player area (it homes in
	# from there, so the exact initial angle is not critical).
	var center: Vector2 = _player.global_position if _player != null and is_instance_valid(_player) else Vector2.ZERO
	missile.setup(center - missile.global_position)


## Returns where a new enemy (missile or plane) should appear: from the
## EnemySpawn marker during the opening MARKER_SPAWN_TIME seconds, then at a
## random off-screen position afterwards.
func _spawn_position() -> Vector2:
	if _game_elapsed < MARKER_SPAWN_TIME:
		return _enemy_spawn.global_position
	return _off_screen_position()


## Returns a random position just off-screen relative to the camera (which is
## centered on the player), so missiles appear from beyond the visible area.
func _off_screen_position() -> Vector2:
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var center: Vector2 = _player.global_position if _player != null and is_instance_valid(_player) else Vector2.ZERO

	match randi() % 4:
		0:  # top
			return center + Vector2(randf_range(-vw * 0.5, vw * 0.5), -(vh * 0.5 + SPAWN_MARGIN))
		1:  # bottom
			return center + Vector2(randf_range(-vw * 0.5, vw * 0.5), vh * 0.5 + SPAWN_MARGIN)
		2:  # left
			return center + Vector2(-(vw * 0.5 + SPAWN_MARGIN), randf_range(-vh * 0.5, vh * 0.5))
		_:  # right
			return center + Vector2(vw * 0.5 + SPAWN_MARGIN, randf_range(-vh * 0.5, vh * 0.5))
