class_name Enemy
extends Area2D

## Flight speed of the enemy plane (pixels/second).
const SPEED := 380.0
## How fast the enemy can turn toward the player (radians/second).
const TURN_RATE := 1.5
## Distance (px) from the player at which the enemy starts firing. Small =
## it must get very close before it opens fire.
const FIRE_RANGE := 90.0
## How aligned (radians) the enemy's facing must be with the player to fire.
## Small = it must point almost directly at the player.
const FIRE_ANGLE_TOLERANCE := 0.25
## Seconds between shots. Low = rapid fire.
const FIRE_COOLDOWN := 0.08

const GUNFIRE_SCENE := preload("res://scenes/gunfire.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const DEATH_ANIM_SCENE := preload("res://scenes/death_anim.tscn")

## Current velocity of the enemy plane.
var velocity: Vector2 = Vector2.ZERO

var _player: Node2D = null
var _fire_cd := 0.0
## True once the game-over begins: the enemy stops homing/firing and keeps
## flying straight in its final heading while the world is paused.
var _drifting := false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Enemies are counted by the spawner to scale the number of missiles on the
	# map, and are found by homing systems.
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_setup_trails()
	# The EnemyPlane is placed in the scene directly, so give it an initial
	# velocity pointing at the player (it homes in from there).
	if velocity == Vector2.ZERO:
		var dir: Vector2 = Vector2.DOWN
		if _player != null:
			dir = global_position.direction_to(_player.global_position)
		velocity = dir * SPEED
		_rotate_to_velocity()


## Adds this enemy's twin exhaust ribbons (one per engine). The nozzles sit at
## sprite-local (±2, 10.5) in the enemy jet art. Following the Sprite2D (rather
## than the enemy root) keeps each trail fixed to its nozzle and lets it rotate
## correctly with the plane's direction. The ribbons are added as siblings so
## they aren't rotated with us.
func _setup_trails() -> void:
	_add_trail(Vector2(-2, 10.5))
	_add_trail(Vector2(2, 10.5))


func _add_trail(offset: Vector2) -> void:
	var trail := Trail2D.new()
	trail.trail_color = Color(1.0, 0.5, 0.4, 1.0)
	trail.trail_width = 2.0
	trail.fade_time = 0.4
	trail.max_points = 18
	trail.spacing = 4.0
	trail.offset = offset
	trail.set_target($Sprite2D)
	# Deferred so it works both when this enemy is a static scene child (added
	# while the parent is still setting up children) and when spawned at runtime.
	get_parent().add_child.call_deferred(trail)


## Sets the enemy's initial direction of travel (speed is fixed). Used if an
## enemy is ever spawned dynamically.
func setup(direction: Vector2) -> void:
	velocity = direction.normalized() * SPEED
	_rotate_to_velocity()


## Puts this enemy into drift mode for the game-over background: it keeps
## translating along its current velocity (no steering, no firing) and keeps
## processing while the tree is paused.
func begin_drift() -> void:
	_drifting = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	# Drift mode (game-over background): no homing or firing — just carry on
	# straight in the final heading while the world is paused.
	if _drifting:
		global_position += velocity * delta
		_rotate_to_velocity()
		return

	# Homing: gently steer toward the player, just like a missile. Unlike a
	# missile it does NOT explode on contact — it just keeps flying.
	if _player != null and is_instance_valid(_player):
		var desired: Vector2 = global_position.direction_to(_player.global_position)
		var step: float = clampf(velocity.angle_to(desired), -TURN_RATE * delta, TURN_RATE * delta)
		velocity = velocity.rotated(step)

	global_position += velocity * delta
	_rotate_to_velocity()

	# Attack: only once very close to the player AND directly facing it. The
	# round fires straight ahead in the plane's facing direction (it never homes).
	_fire_cd -= delta
	if _player != null and is_instance_valid(_player) \
			and _fire_cd <= 0.0 \
			and global_position.distance_to(_player.global_position) <= FIRE_RANGE \
			and _facing_player():
		_fire_at()
		_fire_cd = FIRE_COOLDOWN


## Whether the enemy's facing (direction of travel) is aligned with the player,
## i.e. it is pointing straight at the player.
func _facing_player() -> bool:
	if velocity.length_squared() <= 0.0:
		return false
	var facing: Vector2 = velocity.normalized()
	var to_player: Vector2 = global_position.direction_to(_player.global_position)
	return absf(facing.angle_to(to_player)) <= FIRE_ANGLE_TOLERANCE


## Fires a projectile straight ahead in the enemy's facing direction. The round
## flies in a straight line — it does not lock on / home once fired.
func _fire_at() -> void:
	var gunfire: Gunfire = GUNFIRE_SCENE.instantiate()
	gunfire.global_position = global_position
	get_parent().add_child(gunfire)
	gunfire.setup(velocity.normalized())


func _rotate_to_velocity() -> void:
	if velocity.length_squared() > 0.0 and _sprite != null:
		_sprite.rotation = velocity.angle() + PI / 2.0


## The enemy plane is shot down (hit by a player missile): spawn an impact
## explosion plus the universal drifting-wreck death animation, then remove it.
func die() -> void:
	if is_queued_for_deletion():
		return
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	AudioManager.play_explosion()
	_spawn_death_anim()
	queue_free()


## Spawns the shared death animation (smoke trail, slow drift, shrink + fade,
## occasional parachute) using this plane's texture and last facing direction.
func _spawn_death_anim() -> void:
	var anim: Node2D = DEATH_ANIM_SCENE.instantiate()
	anim.global_position = global_position
	get_parent().add_child(anim)
	anim.setup(velocity, _sprite.texture)
