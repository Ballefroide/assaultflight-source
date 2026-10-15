class_name Trail2D
extends Line2D
## A non-particle ribbon trail that follows a moving entity.
##
## Instead of emitting particles, this records the entity's recent world
## positions and draws a fading polyline behind it. It is deterministic, never
## offsets from the entity, and always trails in the correct direction.
##
## Place it as a child of a non-moving, non-rotating node (e.g. the scene root)
## so its own transform is the world origin. Point data is stored in world
## space, so the trail stays put behind the entity regardless of how the entity
## rotates or moves.

@export var target: NodePath
@export var trail_color := Color(1, 1, 1, 1)
@export var trail_width := 3.0
@export var max_points := 30
## Minimum distance (px) between recorded points.
@export var spacing := 6.0
## How long a point stays before fading out (seconds).
@export var fade_time := 0.4
## Local point on the followed entity that the trail emerges from (e.g. the
## exhaust nozzle). Defaults to the entity's origin.
@export var offset := Vector2.ZERO

var _follow: Node2D = null
var _world_points := PackedVector2Array()
var _ages := PackedFloat32Array()


func _ready() -> void:
	antialiased = true
	# Keep recording (and fading) points even while the tree is paused — e.g. on
	# the main menu the player cruises in PROCESS_MODE_ALWAYS, so its ribbon must
	# keep updating too, and after a death the ribbon fades out behind the
	# (paused) game-over screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Render behind the entity sprites (which default to z=0) but still above
	# the background (which we place at a lower z_index).
	z_index = -1
	if target != NodePath(""):
		_follow = get_node_or_null(target) as Node2D
	# Fade the ribbon from transparent (tail) to opaque (at the entity).
	var g := Gradient.new()
	g.set_color(0, Color(trail_color, 0.0))
	g.set_color(1, trail_color)
	gradient = g
	# Taper the width: thin at the tail, full width at the entity.
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.05))
	wc.add_point(Vector2(1, 1.0))
	width_curve = wc
	width = trail_width
	default_color = trail_color


## Assigns the entity to follow (used when the trail is created at runtime).
func set_target(node: Node2D) -> void:
	_follow = node


func _process(delta: float) -> void:
	# Keep recording points while the followed entity is alive.
	if _follow != null and is_instance_valid(_follow):
		var pos: Vector2 = _follow.to_global(offset)
		if _world_points.is_empty() or _world_points[_world_points.size() - 1].distance_to(pos) >= spacing:
			_world_points.append(pos)
			_ages.append(0.0)

	# Always age the points so the ribbon fades out even after the entity dies
	# (we stop recording but the existing points keep getting older each frame).
	for i in range(_ages.size() - 1, -1, -1):
		_ages[i] += delta
		if _ages[i] > fade_time:
			_world_points.remove_at(i)
			_ages.remove_at(i)

	# Hard cap on total points (drop the oldest).
	while _world_points.size() > max_points:
		_world_points.remove_at(0)
		_ages.remove_at(0)

	# Points are world-space and this node sits at the world origin, so feed them
	# straight to the Line2D.
	points = _world_points

	# Once the followed entity is gone and every point has faded away, remove us.
	if (_follow == null or not is_instance_valid(_follow)) and _world_points.is_empty():
		queue_free()
