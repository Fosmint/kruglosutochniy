class_name MGUVBills
extends MiniGame

## Мини-игра D: УФ-ПРОВЕРКА КУПЮР
## 3 купюры на прилавке. Включите УФ-фонарик и тапните по тем, где светятся аномальные метки.

var _has_fake_marks: Array[bool] = [false, false, false]
var _tapped_marks: Array[bool] = [false, false, false]
var _bill_buttons: Array[Button] = []
var _uv_on: bool = false
var _btn_uv: Button = null
var _lbl_hint: Label = null


func setup(is_strange_payment: bool, seed_val: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val * 541 + 11
	_has_fake_marks = [false, false, false]
	_tapped_marks = [false, false, false]
	if is_strange_payment:
		var fake_count: int = rng.randi_range(1, 2)
		for _i in range(fake_count):
			_has_fake_marks[rng.randi() % 3] = true
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.04, 0.80)
	add_child(dim)

	var panel: PanelContainer = _make_styled_panel(Color(0.08, 0.09, 0.12, 0.96))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -390
	panel.offset_top = -220
	panel.offset_right = 390
	panel.offset_bottom = 220
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "УФ-ПРОВЕРКА КРУПНЫХ КУПЮР"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.76, 0.82, 1.0))
	vbox.add_child(title)

	_lbl_hint = Label.new()
	_lbl_hint.text = "Включите УФ-лампу. Тапните купюры со светящимися символами (или нажмите «ВСЕ ЧИСТЫЕ»)."
	_lbl_hint.add_theme_font_size_override("font_size", 18)
	_lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_lbl_hint)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	_bill_buttons.clear()
	for i in range(3):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(220, 145)
		btn.add_theme_font_size_override("font_size", 20)
		var idx_copy: int = i
		btn.pressed.connect(func() -> void: _on_bill_pressed(idx_copy))
		row.add_child(btn)
		_bill_buttons.append(btn)

	var ctrl_row: HBoxContainer = HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 16)
	ctrl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(ctrl_row)

	_btn_uv = Button.new()
	_btn_uv.text = "УФ-ЛАМПА: ВЫКЛ"
	_btn_uv.custom_minimum_size = Vector2(240, 62)
	_btn_uv.add_theme_font_size_override("font_size", 20)
	_btn_uv.pressed.connect(_on_toggle_uv)
	ctrl_row.add_child(_btn_uv)

	var btn_done: Button = Button.new()
	btn_done.text = "ЗАВЕРШИТЬ / ВСЕ ЧИСТЫЕ"
	btn_done.custom_minimum_size = Vector2(280, 62)
	btn_done.add_theme_font_size_override("font_size", 19)
	btn_done.pressed.connect(_on_confirm)
	ctrl_row.add_child(btn_done)

	_refresh_bills()


func _on_toggle_uv() -> void:
	_uv_on = not _uv_on
	SoundBank.play_sfx("ui_click", 1.3 if _uv_on else 0.85, -3.0)
	_btn_uv.text = "УФ-ЛАМПА: ВКЛ (СВЕТ)" if _uv_on else "УФ-ЛАМПА: ВЫКЛ"
	_refresh_bills()


func _on_bill_pressed(idx: int) -> void:
	_tapped_marks[idx] = not _tapped_marks[idx]
	SoundBank.play_sfx("ui_click", 1.1, -3.0)
	_refresh_bills()


func _refresh_bills() -> void:
	for i in range(3):
		var btn: Button = _bill_buttons[i]
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(3)
		if _uv_on:
			sb.bg_color = Color(0.18, 0.14, 0.36)
			if _has_fake_marks[i]:
				btn.text = "100 ₽\n✦ МЕТКА УФ ✦\n" + ("[ОТМЕЧЕНА]" if _tapped_marks[i] else "(влажная)")
				sb.border_color = Color(0.25, 1.0, 0.85)
			else:
				btn.text = "100 ₽\n(чисто)\n" + ("[ОТМЕЧЕНА]" if _tapped_marks[i] else "")
				sb.border_color = Color(0.45, 0.45, 0.65)
		else:
			sb.bg_color = Color(0.26, 0.32, 0.24)
			btn.text = "100 ₽\nКупюра #%d\n%s" % [i + 1, "[ОТМЕЧЕНА]" if _tapped_marks[i] else ""]
			sb.border_color = Color(0.75, 0.80, 0.70)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)


func _on_confirm() -> void:
	var any_fake: bool = false
	var any_tapped: bool = false
	var exact_match: bool = true
	for i in range(3):
		if _has_fake_marks[i]:
			any_fake = true
		if _tapped_marks[i]:
			any_tapped = true
		if _has_fake_marks[i] != _tapped_marks[i]:
			exact_match = false

	if any_fake and exact_match:
		## Игрок нашёл все аномальные УФ-метки -> отклоняем оплату аномалии!
		_reject_customer()
	elif not any_fake and not any_tapped:
		## Все купюры чистые
		_finish_game(true, 1.0)
	else:
		## Ошибка проверки
		_finish_game(false, 0.0)
