class_name TouchControls
extends Control

## Мобильное мультитач-управление (landscape):
## - Левая часть экрана: виртуальный джойстик движения
## - Правая часть экрана: свайп для поворота взгляда
## - Тап (сдвиг < 12 px и время < 250 мс) -> сигнал screen_tapped(pos) для осмотра зон

signal move_changed(vec: Vector2)
signal look_delta(delta_px: Vector2)
signal screen_tapped(screen_pos: Vector2)

const JOY_RADIUS: float = 78.0
const TAP_MAX_DIST: float = 12.0
const TAP_MAX_MS: int = 250

var _joy_touch_id: int = -1
var _joy_origin: Vector2 = Vector2(145.0, 550.0)
var _joy_current: Vector2 = Vector2(145.0, 550.0)
var _joy_vec: Vector2 = Vector2.ZERO

var _look_touch_id: int = -1
var _look_start_pos: Vector2 = Vector2.ZERO
var _look_last_pos: Vector2 = Vector2.ZERO
var _look_start_ms: int = 0
var _look_moved_dist: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func reset_inputs() -> void:
	_joy_touch_id = -1
	_look_touch_id = -1
	_joy_vec = Vector2.ZERO
	move_changed.emit(Vector2.ZERO)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if GameState.phase != GameState.PHASE_PLAYING:
		return
	var view_size: Vector2 = size if size.x > 10.0 else get_viewport_rect().size
	var half_w: float = view_size.x * 0.42

	if event is InputEventScreenTouch:
		var ev: InputEventScreenTouch = event as InputEventScreenTouch
		if ev.pressed:
			if ev.position.x < half_w and _joy_touch_id == -1:
				_joy_touch_id = ev.index
				_joy_origin = ev.position
				_joy_current = ev.position
				_joy_vec = Vector2.ZERO
				queue_redraw()
			elif _look_touch_id == -1:
				_look_touch_id = ev.index
				_look_start_pos = ev.position
				_look_last_pos = ev.position
				_look_start_ms = Time.get_ticks_msec()
				_look_moved_dist = 0.0
		else:
			if ev.index == _joy_touch_id:
				_joy_touch_id = -1
				_joy_vec = Vector2.ZERO
				move_changed.emit(Vector2.ZERO)
				queue_redraw()
			elif ev.index == _look_touch_id:
				var elapsed: int = Time.get_ticks_msec() - _look_start_ms
				var dist: float = _look_moved_dist
				_look_touch_id = -1
				if dist < TAP_MAX_DIST and elapsed < TAP_MAX_MS:
					screen_tapped.emit(ev.position)
		accept_event()
		return

	if event is InputEventScreenDrag:
		var ev_d: InputEventScreenDrag = event as InputEventScreenDrag
		if ev_d.index == _joy_touch_id:
			var diff: Vector2 = ev_d.position - _joy_origin
			if diff.length() > JOY_RADIUS:
				diff = diff.normalized() * JOY_RADIUS
			_joy_current = _joy_origin + diff
			_joy_vec = diff / JOY_RADIUS
			move_changed.emit(_joy_vec)
			queue_redraw()
		elif ev_d.index == _look_touch_id:
			var delta_p: Vector2 = ev_d.position - _look_last_pos
			_look_last_pos = ev_d.position
			_look_moved_dist += delta_p.length()
			if _look_moved_dist >= TAP_MAX_DIST:
				look_delta.emit(delta_p)
		accept_event()


func _draw() -> void:
	if GameState.phase != GameState.PHASE_PLAYING:
		return
	var view_size: Vector2 = size if size.x > 10.0 else get_viewport_rect().size
	var base_pos: Vector2 = _joy_origin if _joy_touch_id != -1 else Vector2(130.0, view_size.y - 145.0)
	var knob_pos: Vector2 = _joy_current if _joy_touch_id != -1 else base_pos
	var alpha: float = 0.72 if _joy_touch_id != -1 else 0.35
	draw_circle(base_pos, JOY_RADIUS, Color(0.08, 0.10, 0.08, alpha * 0.35))
	draw_arc(base_pos, JOY_RADIUS, 0.0, TAU, 36, Color(0.84, 0.94, 0.80, alpha), 3.0)
	draw_circle(knob_pos, 30.0, Color(0.84, 0.94, 0.80, alpha * 0.80))
