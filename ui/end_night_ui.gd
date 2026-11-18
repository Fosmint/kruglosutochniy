class_name EndNightUI
extends Control

## Экран итогов ночи + выбор 1 из 3 улучшений (или повтор ночи при провале)

signal next_night_requested(next_night: int)
signal retry_night_requested(night_num: int)
signal menu_requested()

var _title_lbl: Label = null
var _stats_lbl: Label = null
var _upg_box: HBoxContainer = null
var _action_box: HBoxContainer = null
var _current_summary: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func show_summary(victory: bool, summary: Dictionary) -> void:
	_current_summary = summary
	visible = true

	var night_n: int = int(summary.get("night", 1))
	var money_v: int = int(summary.get("money", 0))
	var quota_v: int = int(summary.get("quota", 0))
	var strikes_v: int = int(summary.get("strikes", 0))
	var served_v: int = int(summary.get("served", 0))
	var denied_v: int = int(summary.get("denied", 0))
	var tips_v: int = int(summary.get("tips", 0))
	var is_endless: bool = bool(summary.get("endless", false))

	if victory:
		SoundBank.play_sfx("jingle_win", 1.0, -2.0)
		if night_n >= 5 and not is_endless:
			_title_lbl.text = "06:00 — ПЕТЛЯ РАЗОРВАНА! КАМПАНИЯ ПРОЙДЕНА"
			_title_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 0.60))
		else:
			_title_lbl.text = "06:00 — СМЕНА ЗАВЕРШЕНА (НОЧЬ %d)" % night_n
			_title_lbl.add_theme_color_override("font_color", Color(0.70, 0.96, 0.65))
	else:
		SoundBank.play_sfx("jingle_fail", 1.0, -1.0)
		_title_lbl.text = "СМЕНА ПРОВАЛЕНА (НОЧЬ %d)" % night_n
		_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.35, 0.30))

	var extra_note: String = ""
	if not victory:
		if strikes_v >= GameState.max_strikes:
			extra_note = "\nПричина: получено 3 страйка."
		elif not bool(summary.get("quota_met", true)):
			extra_note = "\nПричина: не выполнена квота кассы."
	elif night_n >= 5 and not is_endless:
		extra_note = "\nВы вырвались из кассеты 19 ноября 1998 года! Бесконечный режим открыт."

	_stats_lbl.text = "Выручка: %d ₽ (квота: %d ₽)\nОбслужено людей: %d  |  Раскрыто аномалий: %d\nЧаевые: +%d ₽  |  Ошибки (страйки): %d / 3%s" % [
		money_v, quota_v, served_v, denied_v, tips_v, strikes_v, extra_note
	]

	_upg_box.visible = victory and not is_endless and night_n < 5
	_action_box.visible = not _upg_box.visible


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.02, 0.90)
	add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_top = -250
	panel.offset_right = 440
	panel.offset_bottom = 250
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.08, 0.98)
	sb.border_color = Color(0.45, 0.56, 0.42)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_stats_lbl.add_theme_font_size_override("font_size", 20)
	_stats_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.85))
	vbox.add_child(_stats_lbl)

	_upg_box = HBoxContainer.new()
	_upg_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_upg_box.add_theme_constant_override("separation", 14)
	vbox.add_child(_upg_box)

	var upg_defs: Array[Dictionary] = [
		{"id": "flashlight", "title": "СИЛЬНЕЕ ФОНАРИК\n(+яркость и радиус УФ)"},
		{"id": "cctv", "title": "ОБЗОР КАМЕРЫ\n(+широкий угол CCTV)"},
		{"id": "alarm", "title": "ДЕШЁВАЯ ТРЕВОГА\n(-20 ₽ за вызов)"},
	]
	for u: Dictionary in upg_defs:
		var btn: Button = Button.new()
		btn.text = str(u["title"])
		btn.custom_minimum_size = Vector2(255, 86)
		btn.add_theme_font_size_override("font_size", 18)
		var uid: String = str(u["id"])
		btn.pressed.connect(func() -> void: _on_pick_upgrade(uid))
		_upg_box.add_child(btn)

	_action_box = HBoxContainer.new()
	_action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_box.add_theme_constant_override("separation", 18)
	vbox.add_child(_action_box)

	var btn_retry: Button = Button.new()
	btn_retry.text = "ПЕРЕИГРАТЬ НОЧЬ"
	btn_retry.custom_minimum_size = Vector2(250, 64)
	btn_retry.add_theme_font_size_override("font_size", 20)
	btn_retry.pressed.connect(_on_retry)
	_action_box.add_child(btn_retry)

	var btn_menu: Button = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ"
	btn_menu.custom_minimum_size = Vector2(250, 64)
	btn_menu.add_theme_font_size_override("font_size", 20)
	btn_menu.pressed.connect(_on_menu)
	_action_box.add_child(btn_menu)


func _on_pick_upgrade(uid: String) -> void:
	SoundBank.play_sfx("ui_click", 1.2, -2.0)
	if uid == "flashlight":
		SaveSystem.upg_flashlight = mini(3, SaveSystem.upg_flashlight + 1)
	elif uid == "cctv":
		SaveSystem.upg_cctv_fov = mini(3, SaveSystem.upg_cctv_fov + 1)
	elif uid == "alarm":
		SaveSystem.upg_cheap_alarm = mini(3, SaveSystem.upg_cheap_alarm + 1)
	SaveSystem.save_data()
	visible = false
	var next_n: int = mini(5, int(_current_summary.get("night", 1)) + 1)
	next_night_requested.emit(next_n)


func _on_retry() -> void:
	SoundBank.play_sfx("ui_click", 1.0, -3.0)
	visible = false
	retry_night_requested.emit(int(_current_summary.get("night", 1)))


func _on_menu() -> void:
	SoundBank.play_sfx("ui_click", 0.9, -3.0)
	visible = false
	menu_requested.emit()
