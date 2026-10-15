extends Node2D
## A HUD arrow set that points toward threats outside the player's ring.
##
## Each frame it shows one small, thin triangle per target (in the configured
## group) that is currently outside the ring around the player — whether it's
## merely past the ring edge or fully off-screen — sitting on the ring itself
## and pointing outward toward the target. Used for both missiles and enemies.

const PlayerRingScript := preload("res://scripts/player_ring.gd")

## Radius of the ring the arrows sit on (matches the ring drawn around player).
const RING_RADIUS := PlayerRingScript.RING_RADIUS

## Group of entities this tracker watches (e.g. "missiles" or "enemies").
var group_name := "missiles"
## Triangle color — matches the group's ribbon trail color.
var arrow_color := Color(1.0, 0.7, 0.2, 0.95)

var _triangles: Array[Polygon2D] = []


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		visible = false
		return
	var cam_center: Vector2 = cam.get_screen_center_position()
	var ring_center := _ring_center(cam_center)

	var targets: Array[Node2D] = _ring_targets()
	visible = targets.size() > 0
	while _triangles.size() < targets.size():
		_triangles.append(_make_triangle())
	for i in range(_triangles.size()):
		_triangles[i].visible = i < targets.size()
		if i < targets.size():
			_position_arrow(_triangles[i], targets[i], ring_center)


## The ring's center = the player's position in screen space.
func _ring_center(cam_center: Vector2) -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return get_viewport().get_visible_rect().size * 0.5
	return get_viewport().get_visible_rect().size * 0.5 + (player.global_position - cam_center)


## Every target in the group that lies outside the ring around the player
## (i.e. farther than RING_RADIUS from the player's position).
func _ring_targets() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return out
	var radius_sq := RING_RADIUS * RING_RADIUS
	for node in get_tree().get_nodes_in_group(group_name):
		if not (node is Node2D) or node.is_queued_for_deletion():
			continue
		var offset: Vector2 = (node as Node2D).global_position - player.global_position
		if offset.length_squared() <= radius_sq:
			continue  # target is inside the ring — no indicator needed
		out.append(node)
	return out


## Places a thin triangle on the ring, pointing from the player toward target.
func _position_arrow(tri: Polygon2D, target: Node2D, ring_center: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		tri.visible = false
		return
	var offset: Vector2 = target.global_position - player.global_position
	if offset.length_squared() < 1.0:
		tri.visible = false
		return
	var dir: Vector2 = offset.normalized()
	tri.position = ring_center + dir * RING_RADIUS
	tri.rotation = dir.angle()


func _make_triangle() -> Polygon2D:
	var tri := Polygon2D.new()
	# Thin, compact arrow so it doesn't block the view.
	tri.polygon = PackedVector2Array([Vector2(0, -7), Vector2(0, 7), Vector2(14, 0)])
	tri.color = arrow_color
	add_child(tri)
	return tri
