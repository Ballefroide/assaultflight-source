class_name Countermeasure
extends Area2D
## A deployed countermeasure flare.
##
## Released by the player (right-click), it flies outward in a fan around the
## plane's heading, slowly drifting away. It wears the same orange ribbon trail
## as the missiles so that every missile currently on the map is lured toward
## it (missiles home to the nearest countermeasure and detonate on contact).
## It renders below the player and despawns after a fixed lifetime.

## Flight speed (px/s). Slightly slower than the player's cruise speed (320).
const SPEED := 260.0
## Lifetime before despawning (seconds).
const LIFETIME := 3.0
## Fade-out duration near the end of life.
const FADE_TIME := 0.5
## Ribbon trail color — matches the missiles so they are lured by them.
const TRAIL_COLOR := Color(1.0, 0.7, 0.2, 1.0)

var velocity: Vector2 = Vector2.ZERO

var _born := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("countermeasures")
	# Render below the player so the plane stays on top of its own decoys.
	z_index = -1
	area_entered.connect(_on_area_entered)
	_born = Time.get_ticks_msec() / 1000.0
	_setup_trail()


## Sets the flare's direction of travel (its speed is fixed).
func setup(direction: Vector2) -> void:
	velocity = direction.normalized() * SPEED
	if _sprite != null:
		_sprite.rotation = velocity.angle() + PI / 2.0


func _process(delta: float) -> void:
	global_position += velocity * delta

	var age := Time.get_ticks_msec() / 1000.0 - _born
	if age >= LIFETIME - FADE_TIME:
		modulate.a = clampf(1.0 - (age - (LIFETIME - FADE_TIME)) / FADE_TIME, 0.0, 1.0)
	if age >= LIFETIME:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# A missile reached the decoy: it explodes and consumes the flare.
	if area is Missile and is_instance_valid(area):
		(area as Missile).explode()
		queue_free()


## Non-particle ribbon trail, same look as the missiles.
func _setup_trail() -> void:
	var trail := Trail2D.new()
	trail.trail_color = TRAIL_COLOR
	trail.trail_width = 2.5
	trail.fade_time = 0.35
	trail.max_points = 18
	trail.spacing = 4.0
	trail.offset = Vector2.ZERO
	trail.set_target(self)
	get_parent().add_child(trail)
