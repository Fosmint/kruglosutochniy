class_name PauseMenu
extends Control

## Меню паузы: интенсивность VHS (Низкая/Средняя/Высокая) + 4 ползунка громкости

signal resumed()
signal quit_to_menu()

var _btn_vhs: Button = null
const VHS_LABELS: Array[String] = ["Низкая", "Средняя", "Высокая"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_pause() -> void:
	visible = true
	GameState.is_shift_paused = true
	_refresh_vhs_label()
	SoundBank.play_sfx("ui_click", 0.9, -3.0)


func close_pause() -> void:
	visible = false
	GameState.is_shift_paused = false
	SaveSystem.save_data()
	SoundBank.play_sfx("ui_click", 1.1, -3.0)
	resumed.emit()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.84)
	add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_top = -250
	panel.offset_right = 320
	panel.offset_bottom = 250
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.09, 0.97)
	sb.border_color = Color(0.45, 0.56, 0.42)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "ПАУЗА // НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.96, 0.82))
	vbox.add_child(title)

	_btn_vhs = Button.new()
	_btn_vhs.custom_minimum_size = Vector2(0, 52)
	_btn_vhs.add_theme_font_size_override("font_size", 20)
	_btn_vhs.pressed.connect(_on_cycle_vhs)
	vbox.add_child(_btn_vhs)
	_refresh_vhs_label()

	_add_slider(vbox, "Общая громкость (Master)", SaveSystem.vol_master, func(v: float) -> void:
		SaveSystem.vol_master = v
		SoundBank.apply_volumes()
	)
	_add_slider(vbox, "Эффекты (SFX)", SaveSystem.vol_sfx, func(v: float) -> void:
		SaveSystem.vol_sfx = v
		SoundBank.apply_volumes()
	)
	_add_slider(vbox, "Атмосфера (Ambience)", SaveSystem.vol_ambience, func(v: float) -> void:
		SaveSystem.vol_ambience = v
		SoundBank.apply_volumes()
	)
	_add_slider(vbox, "Голоса (Voice)", SaveSystem.vol_voice, func(v: float) -> void:
		SaveSystem.vol_voice = v
		SoundBank.apply_volumes()
	)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var btn_resume: Button = Button.new()
	btn_resume.text = "ПРОДОЛЖИТЬ"
	btn_resume.custom_minimum_size = Vector2(240, 56)
	btn_resume.add_theme_font_size_override("font_size", 20)
	btn_resume.pressed.connect(close_pause)
	row.add_child(btn_resume)

	var btn_menu: Button = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ"
	btn_menu.custom_minimum_size = Vector2(240, 56)
	btn_menu.add_theme_font_size_override("font_size", 20)
	btn_menu.pressed.connect(_on_quit_to_menu)
	row.add_child(btn_menu)


func _add_slider(parent: VBoxContainer, label_text: String, init_val: float, cb: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(280, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)

	var sl: HSlider = HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = init_val
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(cb)
	row.add_child(sl)


func _on_cycle_vhs() -> void:
	SaveSystem.vhs_level = (SaveSystem.vhs_level + 1) % 3
	SaveSystem.save_data()
	GameState.vhs_settings_changed.emit(SaveSystem.vhs_level)
	SoundBank.play_sfx("ui_click", 1.15, -3.0)
	_refresh_vhs_label()


func _refresh_vhs_label() -> void:
	if _btn_vhs != null:
		_btn_vhs.text = "Интенсивность VHS: " + VHS_LABELS[clampi(SaveSystem.vhs_level, 0, 2)]


func _on_quit_to_menu() -> void:
	visible = false
	GameState.is_shift_paused = false
	SaveSystem.save_data()
	quit_to_menu.emit()
