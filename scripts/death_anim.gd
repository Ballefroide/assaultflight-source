class_name DeathAnim
extends Node2D

## Plane-wreck death animation, used for both enemies and the player.
##
## When a plane is destroyed it doesn't just pop out of existence: this node
## takes over its appearance (same sprite texture) and:
##   - drifts slowly onward in the plane's last facing direction,
##   - emits a smoke trail (smoke.png) behind it,
##   - shrinks and fades away over a short duration, and
##   - spawns a pilot parachute (deathanim_parachute.png) — guaranteed for the
##     player (`guarantee_parachute`), a chance otherwise — which stays briefly
##     before shrinking and fading.
##
## For a player death, `cinematic` is set: the world slows down as the wreck
## fades, then is restored at the end. If `loop` is also set (player only), the
## wreck then re-emerges and smolders forever — bobbing wreck, drifting smoke,
## cycling parachute — becoming the living background behind the game-over
## screen instead of freeing itself. Set `process_mode` to ALWAYS so it keeps
## animating while the game-over screen pauses the tree.

const SMOKE_TEXTURE := preload("res://assets/smoke.png")

## Slow drift speed of the dying plane (px/s) — far slower than cruise speed.
const DRIFT_SPEED := 60.0
## Total duration before the wreck has fully shrunk and faded (seconds).
const DURATION := 1.6
## Seconds between smoke puffs emitted while drifting.
const SMOKE_INTERVAL := 0.05
## Seconds each smoke puff expands and fades over.
const SMOKE_LIFETIME := 0.6
## Chance (0..1) that a pilot parachute spawns.
const PARACHUTE_CHANCE := 0.9
## Seconds the parachute stays visible before it starts to shrink + fade.
const PARACHUTE_STAY := 2.0
## Seconds the parachute shrinks + fades for.
const PARACHUTE_FADE := 0.6
## Slow drift speed of the parachute (px/s) in a random direction, so it stays
## clearly visible even while the wreck is moving.
const PARACHUTE_DRIFT_SPEED := 40.0
## Slow rotation speed of the parachute (radians/second, signed).
const PARACHUTE_SPIN := 1.0
## Slow rotation speed of smoke puffs (radians/second, signed).
const SMOKE_SPIN := 1.5
## Seconds over which the player-death slow-mo ramps to full.
const CINEMATIC_TIME := 1.2
## Floor the world time scale eases down to during the player death.
const CINEMATIC_TIME_SCALE := 0.2
## Seconds of the wreck's smoldering bob cycle (loop mode).
const LOOP_BOB_PERIOD := 3.0
## Seconds over which the wreck re-emerges from the faded state (loop mode).
const REEMERGE_TIME := 1.2
## Delay before the parachute reappears after it fades (loop mode).
const PARACHUTE_RESPAWN_MIN := 1.0
const PARACHUTE_RESPAWN_MAX := 3.0

## If true, the parachute is guaranteed to spawn (used for the player).
var guarantee_parachute := false
## If true, this is a player death: slow the world down as the animation
## proceeds, then restore it when it ends.
var cinematic := false
## If true (player only), the wreck re-emerges after the first cycle and keeps
## smoldering forever instead of freeing itself. This is what makes the death
## animation play infinitely behind the game-over screen.
var loop := false

## The dying plane's drift velocity.
var _velocity: Vector2 = Vector2.ZERO
## Milliseconds the animation started (real time, unaffected by time scale).
var _start_ms := 0
## Milliseconds of the last physics frame (for real-time deltas).
var _last_ms := 0
## Seconds since the death animation started (real time).
var _elapsed := 0.0
var _smoke_timer := 0.0
## Countdown for the parachute; < 0 means no parachute spawned.
var _parachute_timer := -1.0
## Slow drift velocity of the parachute in a random direction.
var _parachute_drift: Vector2 = Vector2.ZERO
## Parachute spin (radians/second, random direction).
var _parachute_spin := 0.0
## Whether the wreck has entered the infinite smoldering loop.
var _looping := false
## Guards so the game-over reveal only fires once (loop mode).
var _game_over_fired := false
## Countdown to the parachute reappearing after it fades (loop mode).
var _parachute_respawn_timer := -1.0

@onready var _wreck: Sprite2D = $Wreck
@onready var _parachute: Sprite2D = $Parachute


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	_last_ms = _start_ms
	# The pilot ejects — guaranteed for the player, otherwise a chance.
	if guarantee_parachute or randf() < PARACHUTE_CHANCE:
		_spawn_parachute()


## Configures the wreck from the dying plane: its texture and its last facing
## direction (which becomes the slow drift direction).
func setup(direction: Vector2, texture: Texture2D) -> void:
	_velocity = direction.normalized() * DRIFT_SPEED
	_wreck.texture = texture
	_wreck.visible = true


func _physics_process(_delta: float) -> void:
	# Use real time so the animation keeps its pace even while the world slows.
	var now := Time.get_ticks_msec()
	var rdt := (now - _last_ms) / 1000.0
	_last_ms = now
	_elapsed = (now - _start_ms) / 1000.0

	if _looping:
		_process_loop(rdt)
		return

	# Drift slowly onward in the plane's last facing direction.
	global_position += _velocity * rdt

	# The wreck shrinks and fades out over the duration.
	var t := clampf(_elapsed / DURATION, 0.0, 1.0)
	_wreck.scale = Vector2.ONE * (1.0 - t)
	_wreck.modulate.a = 1.0 - t

	# Emit a puff of smoke trailing behind the wreck.
	_smoke_timer -= rdt
	if _smoke_timer <= 0.0:
		_emit_smoke()
		_smoke_timer = SMOKE_INTERVAL

	# Animate the parachute (if one spawned): drift slowly, stay, then shrink + fade.
	_animate_parachute(rdt)

	# Player-death cinematic: slow the world down.
	if cinematic:
		var f := clampf(_elapsed / CINEMATIC_TIME, 0.0, 1.0)
		Engine.time_scale = lerpf(1.0, CINEMATIC_TIME_SCALE, f)

	if _elapsed >= DURATION:
		_end_cinematic()
		if not _game_over_fired:
			_game_over_fired = true
			_trigger_game_over()
		if loop:
			_begin_loop()
		else:
			queue_free()


## After a player-death sequence finishes, reveal the game-over screen.
func _trigger_game_over() -> void:
	if cinematic:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("show_game_over")


## Restores normal time scale once a player-death sequence ends.
func _end_cinematic() -> void:
	if cinematic:
		Engine.time_scale = 1.0


## Switches the wreck from the one-shot death into the infinite smoldering
## loop: stop drifting (so the camera/world stay put), re-emerge the wreck to
## full size, and keep smoking + parachuting forever.
func _begin_loop() -> void:
	_looping = true
	_velocity = Vector2.ZERO
	_wreck.rotation = 0.0
	_smoke_timer = 0.0
	# Re-emerge the wreck from the faded state to a full smoldering wreck as the
	# game-over screen fades in over it.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_wreck, "scale", Vector2.ONE, REEMERGE_TIME)
	tween.parallel().tween_property(_wreck, "modulate:a", 1.0, REEMERGE_TIME)


## Per-frame behavior of the infinite smoldering loop: a gently breathing wreck
## with continuous smoke and a parachute that keeps cycling.
func _process_loop(rdt: float) -> void:
	var phase := _elapsed * (TAU / LOOP_BOB_PERIOD)
	_wreck.scale = Vector2.ONE * (0.94 + 0.06 * sin(phase))
	_wreck.modulate.a = 0.92 + 0.08 * sin(phase * 1.3)
	_wreck.rotation = 0.02 * sin(phase * 0.7)

	# Keep a steady plume of smoke rising from the wreck.
	_smoke_timer -= rdt
	if _smoke_timer <= 0.0:
		_emit_smoke()
		_smoke_timer = SMOKE_INTERVAL

	# Cycle the parachute: drift, stay, fade, then reappear after a pause.
	if _parachute_timer >= 0.0:
		_animate_parachute(rdt)
		if _parachute_timer < 0.0:
			_parachute_respawn_timer = randf_range(PARACHUTE_RESPAWN_MIN, PARACHUTE_RESPAWN_MAX)
	else:
		_parachute_respawn_timer -= rdt
		if _parachute_respawn_timer <= 0.0:
			_spawn_parachute()


## Spawns (or respawns) the pilot parachute: visible, drifting in a random
## direction, spinning slowly, fading out after its stay time.
func _spawn_parachute() -> void:
	_parachute.visible = true
	_parachute.scale = Vector2.ONE
	_parachute.modulate.a = 1.0
	_parachute.position = Vector2.ZERO
	_parachute_timer = PARACHUTE_STAY + PARACHUTE_FADE
	_parachute_drift = Vector2.from_angle(randf_range(0.0, TAU)) * PARACHUTE_DRIFT_SPEED
	_parachute_spin = randf_range(-PARACHUTE_SPIN, PARACHUTE_SPIN)
	_parachute_respawn_timer = -1.0


## Steps the parachute (if active): drifts slowly, stays, then shrinks + fades
## before hiding.
func _animate_parachute(rdt: float) -> void:
	if _parachute_timer < 0.0:
		return
	_parachute_timer -= rdt
	_parachute.position += _parachute_drift * rdt
	_parachute.rotation += _parachute_spin * rdt
	if _parachute_timer <= PARACHUTE_FADE:
		var pt := clampf(1.0 - _parachute_timer / PARACHUTE_FADE, 0.0, 1.0)
		_parachute.scale = Vector2.ONE * (1.0 - pt)
		_parachute.modulate.a = 1.0 - pt
		if _parachute_timer <= 0.0:
			_parachute.visible = false
			_parachute_timer = -1.0


## Spawns a small smoke puff that expands and fades, then frees itself.
func _emit_smoke() -> void:
	var puff := Sprite2D.new()
	puff.texture = SMOKE_TEXTURE
	puff.position = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	puff.scale = Vector2.ONE * randf_range(0.15, 0.3)
	puff.modulate = Color(1, 1, 1, 0.7)
	# Each puff starts at a random angle and slowly rotates as it expands/fades.
	puff.rotation = randf_range(0.0, TAU)
	var spin := randf_range(-SMOKE_SPIN, SMOKE_SPIN)
	add_child(puff)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", puff.scale * 2.4, SMOKE_LIFETIME)
	tween.tween_property(puff, "modulate:a", 0.0, SMOKE_LIFETIME)
	tween.tween_property(puff, "rotation", puff.rotation + spin * SMOKE_LIFETIME, SMOKE_LIFETIME)
	tween.chain().tween_callback(puff.queue_free)
