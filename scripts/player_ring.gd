class_name PlayerRing
extends Node2D

## A thin target ring drawn around the player (in screen space). Off-screen
## missile/enemy trackers sit on this ring, pointing outward from the player,
## instead of crowding the edges of the screen.

## Radius (px) of the ring around the player.
const RING_RADIUS := 150.0
## Ring line width (px) — kept thin so it doesn't block the view.
const RING_WIDTH := 1.5
## Ring color (subtle white, partly transparent).
const RING_COLOR := Color(1, 1, 1, 0.30)
## Number of segments used to draw the circle outline.
const RING_SEGMENTS := 64


func _process(_delta: float) -> void:
	position = _ring_center()
	queue_redraw()


## The ring's center = the player's position in screen space (falls back to the
## screen center while the player is gone, e.g. mid-death).
func _ring_center() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cam := get_viewport().get_camera_2d()
	if player == null or cam == null:
		return vs * 0.5
	var cam_center: Vector2 = cam.get_screen_center_position()
	return vs * 0.5 + (player.global_position - cam_center)


func _draw() -> void:
	# Drawn around the local origin, so it follows the node's position (which is
	# snapped to the player each frame).
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, RING_SEGMENTS, RING_COLOR, RING_WIDTH, true)
