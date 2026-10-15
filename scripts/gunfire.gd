class_name Gunfire
extends Node2D

## Speed of the projectile in pixels/second.
const SPEED := 420.0
## Lifetime before the projectile fades out (seconds). Shorter than a missile.
const LIFETIME := 5.0
## How long the fade-out at the end of the lifetime takes (seconds).
const FADE_TIME := 0.5
## Damage dealt to the player on hit (20 shots bring the player down).
const GUNFIRE_DAMAGE := 5.0

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

## Straight-line travel direction. Unlike a missile it does NOT home at the
## player once fired — it keeps going the way it was aimed.
var velocity: Vector2 = Vector2.ZERO

var _born := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area: Area2D = $Area2D


func _ready() -> void:
	_born = Time.get_ticks_msec() / 1000.0
	add_to_group("gunfire")
	_area.area_entered.connect(_on_area_entered)
	_setup_trail()


## Adds a non-particle ribbon trail, like the other moving entities. The ribbon
## is added as a sibling (child of our parent) so it isn't rotated with us.
func _setup_trail() -> void:
	var trail := Trail2D.new()
	trail.trail_color = Color(1.0, 0.85, 0.35, 1.0)
	trail.trail_width = 1.5
	trail.fade_time = 0.25
	trail.max_points = 14
	trail.spacing = 3.0
	# The projectile sprite is centered on our root, so offset (0,0) spawns the
	# trail in the middle of the projectile sprite.
	trail.offset = Vector2.ZERO
	trail.set_target(self)
	get_parent().add_child(trail)


## Sets the projectile's travel direction. It flies in a straight line from
## here and never steers toward the player.
func setup(direction: Vector2) -> void:
	velocity = direction.normalized() * SPEED
	if _sprite != null:
		_sprite.rotation = velocity.angle() + PI / 2.0


func _process(delta: float) -> void:
	global_position += velocity * delta

	# Fade out over the final FADE_TIME of the lifetime, then despawn.
	var age: float = Time.get_ticks_msec() / 1000.0 - _born
	if age >= LIFETIME - FADE_TIME:
		modulate.a = clampf(1.0 - (age - (LIFETIME - FADE_TIME)) / FADE_TIME, 0.0, 1.0)
	if age >= LIFETIME:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# Struck the player — deal damage, then the projectile is spent.
	if area is Player:
		area.call("take_damage", GUNFIRE_DAMAGE)
		_explode()


## Spawns the explosion effect at our position and removes the projectile.
func _explode() -> void:
	if is_queued_for_deletion():
		return
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	queue_free()
