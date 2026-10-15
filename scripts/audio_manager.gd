extends Node

## Central audio manager for Assault Flight. Registered as an autoload
## so any script can call its methods without holding a node reference.
##
## Background loops (wind, jet engine) play only during active gameplay
## and are silent on the main menu and game-over screen. One-shot SFX
## (explosion, missile blast) fire during combat only.

const WIND_STREAM := preload("res://assets/audio/soundreality-wind-blowing-457954.mp3")
const JET_STREAM := preload("res://assets/audio/freesound_community-jet-engine-6753.mp3")
const EXPLOSION_STREAM := preload("res://assets/audio/soundreality-explosion-fx-343683.mp3")
const MISSILE_BLAST_STREAM := preload("res://assets/audio/freesound_community-missile-blast-2-95177.mp3")

var _wind_player: AudioStreamPlayer
var _jet_player: AudioStreamPlayer
var _explosion_player: AudioStreamPlayer
var _missile_blast_player: AudioStreamPlayer
## Whether game audio is enabled. See set_enabled().
var _enabled := true


func _ready() -> void:
	_wind_player = _make_player("WindPlayer", WIND_STREAM, true, -6.0)
	_jet_player = _make_player("JetEnginePlayer", JET_STREAM, true, 0.0)
	_explosion_player = _make_player("ExplosionPlayer", EXPLOSION_STREAM, false, 0.0)
	_missile_blast_player = _make_player("MissileBlastPlayer", MISSILE_BLAST_STREAM, false, 0.0)


func _make_player(node_name: String, stream: AudioStream, loop: bool, volume: float) -> AudioStreamPlayer:
	# Non-positional (AudioStreamPlayer) so the background ambience plays at a
	# constant volume no matter how far the camera flies from the origin. An
	# AudioStreamPlayer2D anchored at the origin fades to silence as the player
	# climbs away (default max_distance is 2000px), which looks like the loop
	# having stopped.
	var p := AudioStreamPlayer.new()
	p.name = node_name
	# Looping lives on the stream resource, not the player node. The ambience
	# MP3s are imported with loop disabled, so enable it here.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	p.stream = stream
	p.volume_db = volume
	p.bus = &"Master"
	add_child(p)
	return p


## Starts the wind ambient loop.
func play_wind() -> void:
	_wind_player.play()


## Stops the wind ambient loop.
func stop_wind() -> void:
	_wind_player.stop()


## Starts the jet-engine loop.
func play_jet_engine() -> void:
	_jet_player.play()


## Stops the jet-engine loop.
func stop_jet_engine() -> void:
	_jet_player.stop()


## Plays the enemy-explosion one-shot SFX.
func play_explosion() -> void:
	_explosion_player.play()


## Plays the missile-detonation one-shot SFX.
func play_missile_blast() -> void:
	_missile_blast_player.play()


## Stops both background loops (wind + jet engine). Called when the
## game-over screen begins or the menu loads, so background audio is
## never audible outside active gameplay.
func stop_all() -> void:
	_wind_player.stop()
	_jet_player.stop()


## Whether game audio is enabled.
func is_enabled() -> bool:
	return _enabled


## Enables or disables all game audio by muting the Master bus. Every sound in
## the game routes through Master, so this silences the ambience loops and the
## one-shot SFX at once. Unmuting is seamless: a loop that is already playing
## simply becomes audible again instead of restarting with a gap.
func set_enabled(p_enabled: bool) -> void:
	_enabled = p_enabled
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, not p_enabled)
