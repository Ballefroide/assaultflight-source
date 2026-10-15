class_name TimeOfDay
extends ColorRect

## Full-screen time-of-day tint overlay.
##
## Sits at the front of the HUD layer (index 0) so its screen-texture shader
## captures the already-rendered world but leaves the HUD (score, reticle,
## ring, arrows) crisp and untinted on top. One instance is created per game
## and given a randomly chosen time of day, mirroring the background rotation.
##
## "Day" applies no shader at all (the overlay is simply hidden).

const SUNRISE_SHADER := preload("res://shaders/sunrise.gdshader")
const SUNSET_SHADER := preload("res://shaders/sunset.gdshader")
const NIGHT_SHADER := preload("res://shaders/night.gdshader")

## Time-of-day options. DAY applies no tint.
enum Tod { DAY, SUNRISE, SUNSET, NIGHT }
## Human-readable labels for each option.
const TOD_NAMES := ["Day", "Sunrise", "Sunset", "Night"]

var _mat: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)


## Covers the whole screen so the grade applies everywhere.
func _resize_to_viewport() -> void:
	size = get_viewport_rect().size


## Applies the given time of day (see the Tod enum). DAY disables the overlay.
func apply_tod(tod: int) -> void:
	if tod == Tod.DAY:
		visible = false
		_mat = null
		material = null
		return
	visible = true
	var shader: Shader
	match tod:
		Tod.SUNRISE:
			shader = SUNRISE_SHADER
		Tod.SUNSET:
			shader = SUNSET_SHADER
		_:
			shader = NIGHT_SHADER
	if _mat == null:
		_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
