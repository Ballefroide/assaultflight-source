extends CanvasLayer

## Full-screen transition overlay used to animate between screens cinematically:
##   main menu -> game, game -> game over, and game over -> main menu.
##
## Lives as an autoload (persists across scene reloads) and runs with
## PROCESS_MODE_ALWAYS, so it keeps animating even while the game tree is
## paused (the main menu and game-over screens pause the world behind them).
##
## Three cinematic styles are available:
##   - "fade":      a smooth, eased cross-fade through black.
##   - "letterbox": a film-style cut — black bars slide in while the picture
##                  fades to black, the screen swaps, then the picture fades
##                  back in and the bars slide away. Reads like a movie cut.
##   - "flash":     a quick white impact flash (good for hard cuts).

const DEFAULT_DURATION := 0.4

const STYLE_FADE := "fade"
const STYLE_LETTERBOX := "letterbox"
const STYLE_FLASH := "flash"

## Letterbox bar height as a fraction of the viewport height.
const BAR_HEIGHT_RATIO := 0.13

## The current transition tween, so a new transition can cancel an old one.
var _tween: Tween = null

## Full-screen black rect whose `modulate.a` we animate (0 = invisible).
var _rect: ColorRect
## Full-screen white rect used by the "flash" style.
var _flash: ColorRect
## Film letterbox bars that slide in/out for the "letterbox" style.
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _bar_h := 0.0


func _ready() -> void:
	# Draw above every other layer (menus use 2/3, the HUD uses 1).
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_on_viewport_resized)

	_rect = _make_fill_rect("FadeRect", Color(0, 0, 0, 1))
	# Start opaque so the very first scene fades in from black (cinematic open).
	_rect.modulate.a = 1.0
	add_child(_rect)

	_flash = _make_fill_rect("FlashRect", Color(1, 1, 1, 1))
	_flash.modulate.a = 0.0
	add_child(_flash)

	_bar_top = _make_bar("BarTop")
	add_child(_bar_top)
	_bar_bottom = _make_bar("BarBottom")
	add_child(_bar_bottom)

	_layout_bars()


func _make_fill_rect(node_name: String, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


func _make_bar(node_name: String) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	return r


## Positions/sizes the letterbox bars based on the current viewport size.
func _layout_bars() -> void:
	var vs := get_viewport().get_visible_rect().size
	_bar_h = vs.y * BAR_HEIGHT_RATIO
	_bar_top.size = Vector2(vs.x, _bar_h)
	_bar_top.position = Vector2(0, -_bar_h)
	_bar_bottom.size = Vector2(vs.x, _bar_h)
	_bar_bottom.position = Vector2(0, vs.y)


func _on_viewport_resized() -> void:
	_layout_bars()


## Whether a transition is currently animating. Useful so scenes that reload
## mid-transition (e.g. a game-over restart back to the menu) don't double up
## on the opening fade.
func is_transitioning() -> bool:
	return _tween != null and _tween.is_valid()


## Cross-fades between two screens using the given cinematic style: closes to
## black, runs `mid` (which should swap the visible screen), then opens back
## in. Returns immediately; the tween drives the rest. Because this node is
## PROCESS_MODE_ALWAYS, the tween keeps running even while the tree is paused.
func transition(mid: Callable, style: String = STYLE_FADE, duration: float = DEFAULT_DURATION) -> void:
	_reset()
	match style:
		STYLE_LETTERBOX:
			_run_letterbox(mid, duration)
		STYLE_FLASH:
			_run_flash(mid, duration)
		_:
			_run_fade(mid, duration)


## Classic eased cross-fade through black.
func _run_fade(mid: Callable, duration: float) -> void:
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_rect, "modulate:a", 1.0, duration)
	_tween.tween_callback(mid)
	_tween.tween_property(_rect, "modulate:a", 0.0, duration)


## Film-style cut: the bars slide in while the picture fades to black, the
## screen swaps, then the picture fades back in and the bars slide away.
func _run_letterbox(mid: Callable, duration: float) -> void:
	_layout_bars()
	var vs := get_viewport().get_visible_rect().size
	_bar_top.visible = true
	_bar_bottom.visible = true
	_rect.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Close: fade to black as the bars slide in.
	_tween.tween_property(_rect, "modulate:a", 1.0, duration)
	_tween.parallel().tween_property(_bar_top, "position:y", 0.0, duration)
	_tween.parallel().tween_property(_bar_bottom, "position:y", vs.y - _bar_h, duration)
	# Swap the screen while fully black.
	_tween.tween_callback(mid)
	# Open: fade back in as the bars slide away.
	_tween.tween_property(_rect, "modulate:a", 0.0, duration)
	_tween.parallel().tween_property(_bar_top, "position:y", -_bar_h, duration)
	_tween.parallel().tween_property(_bar_bottom, "position:y", vs.y, duration)
	_tween.tween_callback(_hide_bars)


## Quick white impact flash.
func _run_flash(mid: Callable, duration: float) -> void:
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_flash, "modulate:a", 1.0, duration * 0.6)
	_tween.tween_callback(mid)
	_tween.tween_property(_flash, "modulate:a", 0.0, duration * 0.6)


func _hide_bars() -> void:
	_bar_top.visible = false
	_bar_bottom.visible = false


## Fades the screen to black and runs `then` once it is fully black (no fade
## back). Used when the next screen is shown by some other mechanism.
func fade_to_black(duration: float = DEFAULT_DURATION, then: Callable = Callable()) -> void:
	_reset()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_rect, "modulate:a", 1.0, duration)
	if then.is_valid():
		_tween.tween_callback(then)


## Fades back in from a black screen (assumes the screen is currently black).
func fade_in(duration: float = DEFAULT_DURATION) -> void:
	_reset()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_rect, "modulate:a", 0.0, duration)


## Cinematic opening: fades the very first scene in from an opaque black start.
## Refuses to run if a transition is already in progress, so a game-over
## restart (which arrives via a letterbox that is still fading in) doesn't
## double up and hard-cut the screen.
func fade_in_from_black(duration: float = DEFAULT_DURATION) -> void:
	if is_transitioning():
		return
	_rect.modulate.a = 1.0
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_rect, "modulate:a", 0.0, duration)


## Cancels any in-progress transition and resets the overlay to a clean state.
func _reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_rect.modulate.a = 0.0
	_flash.modulate.a = 0.0
	_bar_top.visible = false
	_bar_bottom.visible = false
