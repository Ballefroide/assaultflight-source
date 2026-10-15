class_name Missile
extends Area2D

## Flight speed of the missile in pixels/second.
const SPEED := 400.0
## How fast the missile can turn toward the player (radians/second).
## High enough that the missile tracks tightly instead of orbiting the player.
const TURN_RATE := 2.0
## Safety net: a missile that never hits anything frees itself after this long.
const MAX_LIFETIME := 20.0
## Distance from the player at which the missile detonates.
const PLAYER_HIT_RADIUS := 25.0
## Distance between two missiles at which both detonate.
const MISSILE_HIT_RADIUS := 26.0
## Damage dealt to the player on impact (two missiles bring the player down).
const MISSILE_DAMAGE := 50.0

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

## Current velocity of the missile.
var velocity: Vector2 = Vector2.ZERO
## Guards against one impact dealing damage twice in the same frame.
var _spent := false
## True once the game-over begins: the missile stops homing/detonating and keeps
## flying straight in its final heading while the world is paused.
var _drifting := false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	add_to_group("missiles")
	var timer := get_tree().create_timer(MAX_LIFETIME)
	timer.timeout.connect(queue_free)
	_setup_trail()


## Replaces the old particle trail with a non-particle ribbon trail. The ribbon
## is added as a sibling (child of our parent) so it isn't rotated with us.
func _setup_trail() -> void:
	for child in get_children():
		if child is CPUParticles2D:
			child.emitting = false

	var trail := Trail2D.new()
	trail.trail_color = Color(1.0, 0.7, 0.2, 1.0)
	trail.trail_width = 2.5
	trail.fade_time = 0.35
	trail.max_points = 18
	trail.spacing = 4.0
	# Start the trail from the middle of the missile sprite (the sprite node sits
	# at local (0, 5), so its center is there).
	trail.offset = Vector2(0, 5)
	trail.set_target(self)
	get_parent().add_child(trail)


## Sets the missile's initial direction of travel (speed is fixed).
func setup(direction: Vector2) -> void:
	velocity = direction.normalized() * SPEED
	_rotate_to_velocity()


## Puts this missile into drift mode for the game-over background: it keeps
## translating along its current velocity (no homing, no detonation) and keeps
## processing while the tree is paused.
func begin_drift() -> void:
	_drifting = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	# Drift mode (game-over background): no homing or detonation — just carry on
	# straight in the final heading while the world is paused.
	if _drifting:
		global_position += velocity * delta
		_rotate_to_velocity()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	# Homing: if any countermeasure is active we are lured to the nearest one,
	# otherwise we chase the player.
	var target := _homing_target()
	if target != null:
		var desired: Vector2 = global_position.direction_to(target.global_position)
		var step: float = clampf(velocity.angle_to(desired), -TURN_RATE * delta, TURN_RATE * delta)
		velocity = velocity.rotated(step)

	global_position += velocity * delta
	_rotate_to_velocity()

	# Proximity detonation: the hitboxes are tiny, so we also blow up when we get
	# close enough to the player or another missile.
	if player != null and global_position.distance_to(player.global_position) <= PLAYER_HIT_RADIUS:
		_hit_player(player)
		return
	for other in get_tree().get_nodes_in_group("missiles"):
		if other != self and is_instance_valid(other) \
				and global_position.distance_to(other.global_position) <= MISSILE_HIT_RADIUS:
			(other as Missile).explode()
			explode()
			return


func _rotate_to_velocity() -> void:
	if velocity.length_squared() > 0.0 and _sprite != null:
		_sprite.rotation = velocity.angle() + PI / 2.0


## The missile homes toward the nearest active countermeasure (it is lured),
## falling back to the player when none are deployed.
func _homing_target() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for cm in get_tree().get_nodes_in_group("countermeasures"):
		if not (cm is Node2D) or cm.is_queued_for_deletion():
			continue
		var d := global_position.distance_squared_to((cm as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = cm
	if best != null:
		return best
	return get_tree().get_first_node_in_group("player") as Node2D


func _on_area_entered(area: Area2D) -> void:
	# Blow up when touching the player or another missile.
	if area is Player:
		_hit_player(area)
	elif area is Missile:
		explode()


## Hits the player: deals damage (guarded so a single impact only counts once)
## and detonates.
func _hit_player(player: Node2D) -> void:
	if _spent:
		return
	_spent = true
	if player != null and is_instance_valid(player):
		player.call("take_damage", MISSILE_DAMAGE, true)
	_add_score(5)
	explode()


## Adds score to the HUD (surviving a missile hit).
func _add_score(amount: int) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("add_score", amount)


func _on_body_entered(_body: Node2D) -> void:
	explode()


## Triggers the explosion effect and removes the missile from the scene.
func explode() -> void:
	if is_queued_for_deletion():
		return
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	explosion.global_position = global_position
	# Add to our own parent (always present) rather than current_scene, so the
	# explosion reliably appears even if no scene is marked current.
	get_parent().add_child(explosion)
	AudioManager.play_missile_blast()
	queue_free()
