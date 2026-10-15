class_name Vignette
extends ColorRect
## Full-screen black vignette overlay that briefly flashes when the player is
## hit. The screen edges darken while the center stays clear, then fade away.

const VIGNETTE_SHADER := preload("res://shaders/vignette.gdshader")
const FLASH_DURATION := 0.45
const PEAK_INTENSITY := 0.9

var _mat: ShaderMaterial
var _flash_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = VIGNETTE_SHADER
	material = _mat
	_mat.set_shader_parameter("intensity", 0.0)
	set_process(false)
	_resize_to_viewport()
	# Keep the overlay covering the whole screen if the window is resized.
	get_viewport().size_changed.connect(_resize_to_viewport)


## Covers the whole screen (the overlay is a top-level control under the HUD
## CanvasLayer, so it's sized directly from the viewport).
func _resize_to_viewport() -> void:
	size = get_viewport_rect().size


## Starts a brief vignette pulse (darkens the edges, then fades out).
func flash() -> void:
	_flash_time = FLASH_DURATION
	set_process(true)


func _process(delta: float) -> void:
	_flash_time -= delta
	if _flash_time <= 0.0:
		_flash_time = 0.0
		_mat.set_shader_parameter("intensity", 0.0)
		set_process(false)
		return
	var intensity: float = PEAK_INTENSITY * (_flash_time / FLASH_DURATION)
	_mat.set_shader_parameter("intensity", intensity)
