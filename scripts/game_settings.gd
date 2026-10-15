class_name GameSettings
extends RefCounted

## Persistent game settings (graphics + audio) for the main menu. Uses static
## state so it survives scene reloads (same pattern as MainMenu.quick_start) and
## saves to user:// so choices persist across game restarts.

const SETTINGS_PATH := "user://settings.cfg"
## The three fullscreen resolutions offered to the player.
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## Whether game audio is enabled. Applied by muting the Master bus.
static var audio_enabled := true
## Whether the cloud layers are shown.
static var clouds_enabled := true
## Whether the window runs in fullscreen (borderless) mode.
static var fullscreen := false
## Index into RESOLUTIONS used while fullscreen (default: 1080p).
static var resolution_index := 1
## The size to restore when switching back to windowed mode (the project default).
static var windowed_size := Vector2i(1152, 648)
## Guards ensure_loaded() so the disk read happens at most once per process.
static var _loaded := false


## Loads the saved settings from disk once (defaults on first run) and captures
## the project's default window size to restore in windowed mode.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	windowed_size = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	audio_enabled = bool(cfg.get_value("audio", "enabled", true))
	clouds_enabled = bool(cfg.get_value("graphics", "clouds", true))
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
	resolution_index = clampi(int(cfg.get_value("graphics", "resolution_index", 1)), 0, RESOLUTIONS.size() - 1)


## Writes the current settings to user://settings.cfg.
static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "enabled", audio_enabled)
	cfg.set_value("graphics", "clouds", clouds_enabled)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "resolution_index", resolution_index)
	cfg.save(SETTINGS_PATH)


## Applies the window mode and size: fullscreen uses the selected resolution as
## the base render size (the stretch mode scales it to the display); windowed
## restores the project's default window size.
static func apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(windowed_size)


## Shows or hides the cloud layers in the given scene root.
static func apply_clouds(scene_root: Node) -> void:
	if scene_root == null:
		return
	for layer_name: String in ["Clouds", "Clouds2"]:
		var layer := scene_root.get_node_or_null(layer_name)
		if layer != null:
			layer.visible = clouds_enabled


## Applies the saved sound setting to the audio system: mutes the Master bus
## when audio is off, unmutes it when on.
static func apply_audio() -> void:
	AudioManager.set_enabled(audio_enabled)
