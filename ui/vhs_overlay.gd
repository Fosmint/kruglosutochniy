class_name VHSOverlay
extends CanvasLayer

## Полноэкранный VHS пост-эффект + оверлей камеры (REC, PLAY, таймкод, батарея)

var _shader_rect: ColorRect = null
var _shader_mat: ShaderMaterial = null
var _rec_label: Label = null
var _timecode_label: Label = null
var _signal_lost_label: Label = null

var _glitch_spike: float = 0.0
var _glitch_timer: float = 0.0
var _signal_lost_timer: float = 0.0
var _blur_pulse: float = 0.0
var _blink_t: float = 0.0


func _ready() -> void:
	layer = 50
	_build_post_rect()
	_build_camcorder_hud()

	GameState.glitch_spike_requested.connect(_on_glitch_spike)
	GameState.vhs_settings_changed.connect(_on_vhs_settings_changed)
	_on_vhs_settings_changed(SaveSystem.vhs_level)


func trigger_autofocus_blur() -> void:
	_blur_pulse = 1.0


func _build_post_rect() -> void:
	_shader_rect = ColorRect.new()
	_shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = load("res://shaders/vhs_post.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = sh
	_shader_mat.set_shader_parameter("glitch", 0.0)
	_shader_mat.set_shader_parameter("vhs_strength", 1.0)
	_shader_mat.set_shader_parameter("blur_amount", 0.0)
	_shader_mat.set_shader_parameter("signal_lost", 0.0)
	_shader_mat.set_shader_parameter("sanity_ratio", 1.0)
	_shader_rect.material = _shader_mat
	add_child(_shader_rect)


func _build_camcorder_hud() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_rec_label = Label.new()
	_rec_label.text = "● REC"
	_rec_label.position = Vector2(22, 16)
	_rec_label.add_theme_font_size_override("font_size", 24)
	_rec_label.add_theme_color_override("font_color", Color(0.95, 0.18, 0.14))
	_rec_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_rec_label)

	var play_lbl: Label = Label.new()
	play_lbl.text = "PLAY ►"
	play_lbl.position = Vector2(128, 16)
	play_lbl.add_theme_font_size_override("font_size", 24)
	play_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 0.84, 0.88))
	play_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_lbl)

	var bat_lbl: Label = Label.new()
	bat_lbl.text = "[■■■□] BAT"
	bat_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bat_lbl.offset_left = -165
	bat_lbl.offset_top = 16
	bat_lbl.offset_right = -20
	bat_lbl.offset_bottom = 48
	bat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bat_lbl.add_theme_font_size_override("font_size", 22)
	bat_lbl.add_theme_color_override("font_color", Color(0.86, 0.94, 0.80, 0.85))
	bat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bat_lbl)

	_timecode_label = Label.new()
	_timecode_label.text = "19 НОЯ 1998 22:00:00"
	_timecode_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_timecode_label.offset_left = 22
	_timecode_label.offset_top = -44
	_timecode_label.offset_right = 440
	_timecode_label.offset_bottom = -12
	_timecode_label.add_theme_font_size_override("font_size", 21)
	_timecode_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.85, 0.86))
	_timecode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_timecode_label)

	_signal_lost_label = Label.new()
	_signal_lost_label.text = "НЕТ СИГНАЛА // SIGNAL LOST"
	_signal_lost_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_signal_lost_label.offset_left = -260
	_signal_lost_label.offset_top = -30
	_signal_lost_label.offset_right = 260
	_signal_lost_label.offset_bottom = 30
	_signal_lost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_signal_lost_label.add_theme_font_size_override("font_size", 32)
	_signal_lost_label.add_theme_color_override("font_color", Color(0.96, 0.98, 0.92))
	_signal_lost_label.visible = false
	_signal_lost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_signal_lost_label)


func _on_glitch_spike(amount: float, duration: float, is_signal_lost: bool) -> void:
	_glitch_spike = maxf(_glitch_spike, clampf(amount, 0.0, 1.0))
	_glitch_timer = maxf(_glitch_timer, duration)
	if is_signal_lost:
		_signal_lost_timer = maxf(_signal_lost_timer, minf(duration, 0.75))


func _on_vhs_settings_changed(level: int) -> void:
	if _shader_mat == null:
		return
	var strength: float = 1.0
	if level == 0:
		strength = 0.45
	elif level == 1:
		strength = 0.95
	else:
		strength = 1.38
	_shader_mat.set_shader_parameter("vhs_strength", strength)


func _process(delta: float) -> void:
	_blink_t += delta
	if _rec_label != null:
		_rec_label.visible = fmod(_blink_t, 1.2) < 0.7
	if _timecode_label != null:
		_timecode_label.text = GameState.get_in_game_time_string()

	if _glitch_timer > 0.0:
		_glitch_timer -= delta
		if _glitch_timer <= 0.0:
			_glitch_spike = 0.0
	else:
		_glitch_spike = lerpf(_glitch_spike, 0.0, clampf(delta * 5.0, 0.0, 1.0))

	if _signal_lost_timer > 0.0:
		_signal_lost_timer -= delta
	var sig_val: float = clampf(_signal_lost_timer * 2.5, 0.0, 1.0)
	if _signal_lost_label != null:
		_signal_lost_label.visible = sig_val > 0.35

	_blur_pulse = maxf(0.0, _blur_pulse - delta * 4.5)

	if _shader_mat != null:
		var sanity_ratio: float = clampf(GameState.sanity / 100.0, 0.0, 1.0)
		var base_glitch: float = (1.0 - sanity_ratio) * 0.45
		_shader_mat.set_shader_parameter("glitch", clampf(base_glitch + _glitch_spike, 0.0, 1.0))
		_shader_mat.set_shader_parameter("blur_amount", _blur_pulse)
		_shader_mat.set_shader_parameter("signal_lost", sig_val)
		_shader_mat.set_shader_parameter("sanity_ratio", sanity_ratio)
