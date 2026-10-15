class_name Player
extends Area2D

## The plane always cruises forward at this constant speed (pixels/second).
const CRUISE_SPEED := 320.0
## Fraction of cruise speed used while hold-to-steering (left mouse button).
## Fun Fact: Setting HOLD_STEER_SPEED_FACTOR to 0 makes the plane into a VTOL
## Basically, holding it down while HOLD_STEER_SPEED_FACTOR is 0 makes the
## player abruptly stop.
## I set it to 1 because I realized it doesn't serve a purpose, but can be reserved
## for games using this flight model.
const HOLD_STEER_SPEED_FACTOR := 1
## Maximum turning speed while steering toward a target (radians/second).
const MAX_TURN_RATE := 5.0
## Distance (px) below which the plane considers its target reached.
const TARGET_EPSILON := 10.0

## Deployed countermeasure projectile scene.
const COUNTERMEASURE_SCENE := preload("res://scenes/countermeasure.tscn")
## Number of countermeasure flares released per deployment.
const FLARE_COUNT := 6
## Minimum seconds between deployments.
const FLARE_COOLDOWN := 20.0
## Seconds knocked off the flare cooldown for each enemy shot down.
const FLARE_KILL_REDUCTION := 10.0
## Directions (degrees) the flares fan out around the plane's heading. Six
## directions kept to a tight spread so they stay clustered near the plane
## without scattering far.
const FLARE_SPREAD_DEG := [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]

## The player's lock-on missile scene (homes to a locked enemy).
const PLAYER_MISSILE_SCENE := preload("res://scenes/player_missile.tscn")
## The shared plane-wreck death animation (smoke trail, drift, shrink + fade,
## occasional parachute). Universal: used by the player too.
const DEATH_ANIM_SCENE := preload("res://scenes/death_anim.tscn")

## Max player HP.
const MAX_HP := 100.0
## HP regenerated every REGEN_INTERVAL seconds.
const REGEN_RATE := 5.0
## Seconds between HP regen ticks.
const REGEN_INTERVAL := 5.0
## HP restored when the player shoots down an enemy plane.
const KILL_HEAL := 25.0
## Seconds of invulnerability granted when the player is hit by a missile.
const INVULNERABILITY_TIME := 2.0
## How fast the invulnerability blink fades in/out (radians/second).
const BLINK_RATE := 24.0
## Seconds an enemy must stay in the fan before it is locked on.
const LOCK_TIME := 1.0
## How long the auto-fire window lasts once locked (seconds).
const FIRE_TIME := 1.0
## Delay between auto-fired missiles while locked (seconds).
const FIRE_INTERVAL := 0.6
## Half-angle (degrees) of the lock-on fan ahead of the plane — a tight cone.
const FAN_HALF_ANGLE_DEG := 40.0
## Length (px) of the lock-on fan.
const FAN_LENGTH := 420.0

## Unit vector describing the plane's current heading / direction of travel.
var _heading: Vector2 = Vector2.UP
## World-space point the plane is currently steering toward.
var _target: Vector2 = Vector2.ZERO
var _has_target := false
## Seconds remaining before countermeasures can be deployed again.
var _flare_cooldown := 0.0

## Lock-on / auto-fire state machine.
enum LockState { NONE, LOCKING, LOCKED }
var _lock_state := LockState.NONE
var _lock_enemy: Node2D = null
var _lock_time := 0.0
var _fire_timer := 0.0
var _fire_cd := 0.0
## Seconds until the player can fire missiles again (0 = ready / firing).
var _missile_cooldown := 0.0
## Whether the player can steer and fight. False while the main menu is up (the
## plane just cruises straight ahead); turned on when the game actually starts.
var _control_enabled := false

## Current player HP (starts full).
var _hp := MAX_HP
## Accumulated time toward the next HP regen tick.
var _regen_timer := 0.0
## Seconds of invulnerability remaining (0 = vulnerable). Set when hit by a
## missile; while > 0 the player takes no damage and the sprite blinks.
var _invuln_timer := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _lockon: TextureRect = get_node("../HUD/LockON")



func _ready() -> void:
	# Tag ourselves so missiles (and other systems) can find the player.
	add_to_group("player")
	# Keep cruising straight ahead even while the tree is paused on the main
	# menu; steering/combat stays locked until enable_control().
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The plane starts flying straight up the screen.
	_target = global_position + Vector2.UP * 200.0
	_has_target = true


## The plane's current heading (unit vector direction of travel).
func get_heading() -> Vector2:
	return _heading


## Hands control to the player: called when the game actually starts (the main
## menu keeps the plane cruising straight ahead on its own before this).
func enable_control() -> void:
	_control_enabled = true
	# Don't inherit any steering direction from before the game started (e.g.
	# the click that launched it). The plane keeps flying straight ahead until
	# the player gives an explicit click during gameplay.
	_has_target = false


func _unhandled_input(event: InputEvent) -> void:
	if not _control_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicking anywhere steers the plane toward that point on the screen.
		_target = get_global_mouse_position()
		_has_target = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click deploys countermeasures that lure missiles away.
		_deploy_countermeasures()


func _physics_process(delta: float) -> void:
	# Always cruise forward at constant speed, even while cruising idle on the
	# menu before control is handed over. While hold-to-steering the plane
	# slows to half speed for tighter, more precise control.
	var speed: float = CRUISE_SPEED
	if _control_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		speed = CRUISE_SPEED * HOLD_STEER_SPEED_FACTOR
	global_position += _heading * speed * delta
	_sprite.rotation = _heading.angle() + PI / 2.0

	_update_invulnerability(delta)

	if not _control_enabled:
		# On the menu: fly straight ahead with no steering, combat, or regen.
		return

	_flare_cooldown = maxf(_flare_cooldown - delta, 0.0)
	_update_regen(delta)

	# Holding the left mouse button steers continuously toward the live cursor
	# position for precise control: drag the mouse to trace a path and the plane
	# keeps chasing the cursor until the button is released.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_target = get_global_mouse_position()
		_has_target = true

	if _has_target:
		var to_target: Vector2 = _target - global_position
		if to_target.length() > TARGET_EPSILON:
			var desired: Vector2 = to_target.normalized()
			# Turn the heading toward the desired direction at a fixed max rate.
			var angle_step: float = clampf(
				_heading.angle_to(desired),
				-MAX_TURN_RATE * delta,
				MAX_TURN_RATE * delta
			)
			_heading = _heading.rotated(angle_step)
		else:
			_has_target = false

	# Lock-on + automatic missile firing.
	_update_lock(delta)


## Drives the lock-on / auto-fire state machine each physics frame.
func _update_lock(delta: float) -> void:
	# Pick the nearest enemy still inside the fan. Only one can be tracked at a
	# time, so a change of target resets the lock.
	var target := _nearest_fan_enemy()
	if target != _lock_enemy:
		_lock_enemy = target
		_lock_state = LockState.NONE
		_lock_time = 0.0
		_fire_timer = 0.0
		_fire_cd = 0.0

	if _lock_enemy == null:
		_missile_cooldown = LOCK_TIME
		_lockon.visible = false
		return

	# The locked enemy vanished (e.g. it was shot down) -> drop the lock.
	if not is_instance_valid(_lock_enemy):
		_lock_enemy = null
		_lock_state = LockState.NONE
		_lock_time = 0.0
		_missile_cooldown = LOCK_TIME
		_lockon.visible = false
		return

	# Glue the reticle to the locked enemy on screen.
	_lockon.visible = true
	_lockon.position = _world_to_screen(_lock_enemy.global_position) - _lockon.size * 0.5

	match _lock_state:
		LockState.NONE, LockState.LOCKING:
			_lockon.modulate.a = 0.5  # acquiring
			_missile_cooldown = maxf(LOCK_TIME - _lock_time, 0.0)
			_lock_time += delta
			if _lock_time >= LOCK_TIME:
				_lock_state = LockState.LOCKED
				_fire_timer = FIRE_TIME
				_fire_cd = 0.0
		LockState.LOCKED:
			_lockon.modulate.a = 1.0  # locked, firing
			_missile_cooldown = 0.0
			_fire_cd -= delta
			if _fire_cd <= 0.0:
				_fire_at(_lock_enemy)
				_fire_cd = FIRE_INTERVAL
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				# Firing window over -> require a fresh lock.
				_lock_state = LockState.NONE
				_lock_time = 0.0


## The nearest enemy still inside the lock fan (or null if none).
func _nearest_fan_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if not _in_fan(e.global_position):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


## Whether a world position lies inside the tight fan-shaped zone ahead of the
## plane — bounded by the plane's heading, the fan half-angle, and its length.
func _in_fan(world_pos: Vector2) -> bool:
	var to := world_pos - global_position
	var dist_sq := to.length_squared()
	if dist_sq < 1.0 or dist_sq > FAN_LENGTH * FAN_LENGTH:
		return false
	return absf(to.angle_to(_heading)) <= deg_to_rad(FAN_HALF_ANGLE_DEG)


## Automatically fires a player missile that homes to the given enemy.
func _fire_at(enemy: Node2D) -> void:
	var pm: PlayerMissile = PLAYER_MISSILE_SCENE.instantiate()
	pm.global_position = global_position
	pm.target = enemy
	pm.setup(_heading)
	get_parent().add_child(pm)


## Converts a world position to screen (HUD) coordinates for the current camera.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return world_pos
	return get_viewport().get_canvas_transform() * world_pos


## Seconds remaining before countermeasures can be deployed again (0 = ready).
func get_flare_cooldown() -> float:
	return _flare_cooldown


## Current player HP (0..MAX_HP).
func get_hp() -> float:
	return _hp


## Called when the player shoots down an enemy: reduces the flare cooldown by
## FLARE_KILL_REDUCTION seconds (never below 0) and restores KILL_HEAL HP.
## Deploying flares resets the cooldown back to the full FLARE_COOLDOWN.
func on_enemy_destroyed() -> void:
	_flare_cooldown = maxf(_flare_cooldown - FLARE_KILL_REDUCTION, 0.0)
	_heal(KILL_HEAL)
	_call_hud("flash_destroy_enemy")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("add_score", 10)


## Reduces the player's HP by `amount`, and takes the player down if HP reaches
## zero. Damage comes from enemy missiles/gunfire. A missile hit (`is_missile`)
## also grants a short window of invulnerability; while invulnerable the player
## takes no damage at all.
func take_damage(amount: float, is_missile: bool = false) -> void:
	if _hp <= 0.0 or _invuln_timer > 0.0:
		return
	_hp = maxf(_hp - amount, 0.0)
	_flash_hit_vignette()

	# Only flash the "Damage" overlay on a non-lethal hit; on a killing blow the
	# "End" overlay (shown in die()) is what should appear instead.
	if _hp > 0.0:
		_call_hud("flash_damage")

	if is_missile:
		_grant_invulnerability()

	if _hp <= 0.0:
		die()


## Calls a method on the HUD if it exists (safe no-op when there is no HUD).
func _call_hud(method_name: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method(method_name):
		hud.call(method_name)


## Briefly flashes a dark vignette on screen to telegraph taking a hit.
func _flash_hit_vignette() -> void:
	_call_hud("flash_vignette")


## Starts the missile-hit invulnerability window (the player blinks for
## INVULNERABILITY_TIME seconds and is immune to damage during it).
func _grant_invulnerability() -> void:
	_invuln_timer = INVULNERABILITY_TIME
	_sprite.modulate.a = 1.0


## Counts down the invulnerability window and drives the rapid fade in/out of
## the sprite that signals it. Ensures the sprite is fully opaque when it ends.
func _update_invulnerability(delta: float) -> void:
	if _invuln_timer <= 0.0:
		_invuln_timer = 0.0
		if _sprite.modulate.a != 1.0:
			_sprite.modulate.a = 1.0
		return
	_invuln_timer -= delta
	_sprite.modulate.a = 0.25 + 0.75 * absf(sin(_invuln_timer * BLINK_RATE))


## Restores up to MAX_HP.
func _heal(amount: float) -> void:
	if _hp <= 0.0 or amount <= 0.0:
		return
	_hp = minf(_hp + amount, MAX_HP)


## Regenerates REGEN_RATE HP every REGEN_INTERVAL seconds.
func _update_regen(delta: float) -> void:
	if _hp <= 0.0 or _hp >= MAX_HP:
		return
	_regen_timer += delta
	if _regen_timer >= REGEN_INTERVAL:
		_regen_timer = 0.0
		_heal(REGEN_RATE)


## Seconds remaining before the player can fire missiles again (0 = ready).
func get_missile_cooldown() -> float:
	return _missile_cooldown


## Releases a fan of countermeasure flares around the plane's heading. Only
## works when the cooldown has elapsed.
func _deploy_countermeasures() -> void:
	if _flare_cooldown > 0.0:
		return
	_flare_cooldown = FLARE_COOLDOWN
	for deg in FLARE_SPREAD_DEG:
		var cm: Countermeasure = COUNTERMEASURE_SCENE.instantiate()
		# Spawn at the plane's center, aimed along the heading fanned by `deg`.
		cm.global_position = global_position
		cm.setup(_heading.rotated(deg_to_rad(deg)))
		get_parent().add_child(cm)


## Plays the shared plane-wreck death animation (smoke trail, slow drift,
## shrink + fade, occasional parachute) and removes the plane. Game-over
## mechanics aren't wired up yet, so nothing calls this yet — it just makes
## the death visual universal/available for the player too.
func die() -> void:
	if is_queued_for_deletion():
		return
	# The "End" marker is unique: it's shown here and stays up through the death
	# sequence even though the rest of the gameplay UI vanishes instantly. Only
	# the End marker and the time-of-day lighting overlay remain on screen.
	_call_hud("show_end")
	_call_hud("hide_gameplay_ui")
	var anim: DeathAnim = DEATH_ANIM_SCENE.instantiate()
	anim.global_position = global_position
	# Guarantee the player's parachute and play the slow-mo + greyscale death
	# cinematic (the world slows down and greys out while the wreck fades).
	anim.guarantee_parachute = true
	anim.cinematic = true
	# The player's wreck loops forever behind the game-over screen instead of
	# freeing itself, so set it to ALWAYS to keep animating while the tree is
	# paused (the game-over screen pauses the world).
	anim.loop = true
	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(anim)
	anim.setup(_heading, _sprite.texture)
	# Lock the camera onto the wreck so it keeps following the player entity
	# through the death animation (the Camera2D normally lives under this node).
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reparent(anim)
		cam.position = Vector2.ZERO
	queue_free()
