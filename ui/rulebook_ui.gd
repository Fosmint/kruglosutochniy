class_name RulebookUI
extends Control

## Планшет «Книга правил»: Правила ночи, Справочник аномалий и Записки прошлого кассира

signal closed()

var _content_box: VBoxContainer = null
var _tab_idx: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_book() -> void:
	visible = true
	SoundBank.play_sfx("ui_click", 1.0, -3.0)
	_refresh_tab(_tab_idx)


func close_book() -> void:
	visible = false
	SoundBank.play_sfx("ui_click", 0.85, -3.0)
	closed.emit()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.02, 0.82)
	add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_top = -270
	panel.offset_right = 460
	panel.offset_bottom = 270
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.10, 0.98)
	sb.border_color = Color(0.45, 0.56, 0.42)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root_v: VBoxContainer = VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	panel.add_child(root_v)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root_v.add_child(top_row)

	var tabs: Array[String] = ["ПРАВИЛА НОЧИ", "АНОМАЛИИ", "ЗАПИСКИ КАССИРА"]
	for i in range(tabs.size()):
		var b: Button = Button.new()
		b.text = tabs[i]
		b.custom_minimum_size = Vector2(215, 52)
		b.add_theme_font_size_override("font_size", 18)
		var ti: int = i
		b.pressed.connect(func() -> void: _on_tab_pressed(ti))
		top_row.add_child(b)

	var btn_close: Button = Button.new()
	btn_close.text = "ЗАКРЫТЬ [X]"
	btn_close.custom_minimum_size = Vector2(180, 52)
	btn_close.add_theme_font_size_override("font_size", 18)
	btn_close.pressed.connect(close_book)
	top_row.add_child(btn_close)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(scroll)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_content_box)


func _on_tab_pressed(idx: int) -> void:
	SoundBank.play_sfx("ui_click", 1.1, -4.0)
	_refresh_tab(idx)


func _refresh_tab(idx: int) -> void:
	_tab_idx = idx
	if _content_box == null:
		return
	for ch: Node in _content_box.get_children():
		ch.queue_free()

	var is_endless: bool = (GameState.game_mode == GameState.MODE_ENDLESS)
	if idx == 0:
		var rules: Array[String] = RulesDB.get_rules_up_to_night(GameState.current_night, is_endless)
		for line: String in rules:
			_add_entry(line, Color(0.88, 0.94, 0.84))
	elif idx == 1:
		var anoms: Array[Dictionary] = AnomaliesDB.get_available_for_night(GameState.current_night, is_endless)
		for a: Dictionary in anoms:
			var txt: String = "• %s [%s] — %s" % [str(a["name"]), str(a["tool"]), str(a["clue"])]
			_add_entry(txt, Color(0.94, 0.86, 0.72))
	else:
		var notes: Array[Dictionary] = RulesDB.get_notes_up_to_night(GameState.current_night, is_endless)
		for n: Dictionary in notes:
			_add_entry(str(n["title"]) + "\n" + str(n["text"]), Color(0.84, 0.92, 0.96))


func _add_entry(text: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", col)
	_content_box.add_child(lbl)
