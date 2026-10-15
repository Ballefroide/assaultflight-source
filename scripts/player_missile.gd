class_name PlayerMissile
extends Area2D
## A missile fired by the player during a lock-on.
##
## Unlike the enemy's homing missiles (which chase the player and last 20s),
## this one homes in on the locked enemy and lasts only 5 seconds. It detonates
## on reaching the target, shooting it down.

## Flight speed (px/s).
const SPEED := 420.0
## Turn rate toward the target (radians/second).
const TURN_RATE := 3.0
## Lifetime before the missile gives up and frees itself (seconds). Player
## missiles are short-lived compared to the enemy homing missiles.
const LIFETIME := 5.0
## Distance to the target at which the missile detonates.
const HIT_RADIUS := 30.0

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

var velocity: Vector2 = Vector2.ZERO
## The enemy this missile is chasing (set by the player before adding it).
var target: Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player_missiles")
	var timer := get_tree().create_timer(LIFETIME)
	timer.timeout.connect(queue_free)
	_setup_trail()


## Sets the missile's initial direction (its speed is fixed).
func setup(direction: Vector2) -> void:
	velocity = direction.normalized() * SPEED
	_rotate_to_velocity()


func _physics_process(delta: float) -> void:
	# Home in on the locked target.
	if target != null and is_instance_valid(target):
		var desired: Vector2 = global_position.direction_to(target.global_position)
		var step: float = clampf(velocity.angle_to(desired), -TURN_RATE * delta, TURN_RATE * delta)
		velocity = velocity.rotated(step)

	global_position += velocity * delta
	_rotate_to_velocity()

	# Detonate once we reach the target, shooting it down.
	if target != null and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) <= HIT_RADIUS:
		_shoot_down(target)
		return


func _shoot_down(enemy: Node2D) -> void:
	if enemy is Enemy:
		(enemy as Enemy).die()
		_reward_kill()
	else:
		enemy.queue_free()
	explode()


## A successful enemy shoot-down knocks time off the player's flare cooldown.
func _reward_kill() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p):
		p.call("on_enemy_destroyed")


func _rotate_to_velocity() -> void:
	if velocity.length_squared() > 0.0 and _sprite != null:
		_sprite.rotation = velocity.angle() + PI / 2.0


## Non-particle ribbon trail, tinted blue so the player can tell their own
## missiles apart from the enemy's orange ones.
func _setup_trail() -> void:
	var trail := Trail2D.new()
	trail.trail_color = Color(0.4, 0.8, 1.0, 1.0)
	trail.trail_width = 2.5
	trail.fade_time = 0.35
	trail.max_points = 18
	trail.spacing = 4.0
	trail.offset = Vector2(0, 5)
	trail.set_target(self)
	get_parent().add_child(trail)


func explode() -> void:
	if is_queued_for_deletion():
		return
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	queue_free()
