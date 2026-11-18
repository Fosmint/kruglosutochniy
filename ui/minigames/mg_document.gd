class_name MGDocument
extends MiniGame

## Мини-игра C: ДОКУМЕНТ (алкоголь / сигареты)
## Сравните фото (генерируется FaceGenerator), возраст (18+), срок действия с датой смены.

signal zoom_face_requested(enable: bool)

var _app: CustomerAppearance = null
var _panel: PanelContainer = null
var _zoom_toggled: bool = false
var _btn_zoom: Button = null


func setup(app: CustomerAppearance) -> void:
	_app = app
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.02, 0.45)
	add_child(dim)

	_panel = _make_styled_panel(Color(0.11, 0.13, 0.11, 0.96))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_panel.offset_left = 40
	_panel.offset_top = -220
	_panel.offset_right = 680
	_panel.offset_bottom = 220
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	var shift_d: Array[int] = GameState.get_shift_date_tuple()
	var header: Label = Label.new()
	header.text = "ПРОВЕРКА ДОКУМЕНТА (18+)  |  Сегодня: %02d.%02d.%04d" % [shift_d[0], shift_d[1], shift_d[2]]
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.92, 0.96, 0.82))
	vbox.add_child(header)

	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 18)
	vbox.add_child(card_row)

	var photo_rect: TextureRect = TextureRect.new()
	photo_rect.custom_minimum_size = Vector2(180, 180)
	photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_rect.texture = FaceGenerator.generate_face_texture(_app.doc_face_params)
	card_row.add_child(photo_rect)

	var info: Label = Label.new()
	info.text = "ФИО: %s\nДата рожд.: %s\nДействителен до: %s\n\nПроверьте:\n• Возраст >= 18 (до 1980 г.р.)\n• Срок >= 11.1998\n• Лицо и глаза на фото" % [
		_app.doc_name,
		_app.doc_birth_str,
		_app.doc_expiry_str,
	]
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.88, 0.92, 0.86))
	card_row.add_child(info)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_btn_zoom = Button.new()
	_btn_zoom.text = "СВЕРИТЬ ЛИЦО (ЗУМ)"
	_btn_zoom.custom_minimum_size = Vector2(210, 62)
	_btn_zoom.add_theme_font_size_override("font_size", 18)
	_btn_zoom.pressed.connect(_on_toggle_zoom)
	btn_row.add_child(_btn_zoom)

	var btn_accept: Button = Button.new()
	btn_accept.text = "ПРИНЯТЬ ID"
	btn_accept.custom_minimum_size = Vector2(185, 62)
	btn_accept.add_theme_font_size_override("font_size", 20)
	btn_accept.pressed.connect(_on_accept)
	btn_row.add_child(btn_accept)

	var btn_reject: Button = Button.new()
	btn_reject.text = "ОТКЛОНИТЬ (ПОДДЕЛКА)"
	btn_reject.custom_minimum_size = Vector2(215, 62)
	btn_reject.add_theme_font_size_override("font_size", 18)
	btn_reject.pressed.connect(_on_reject)
	btn_row.add_child(btn_reject)


func _on_toggle_zoom() -> void:
	_zoom_toggled = not _zoom_toggled
	SoundBank.play_sfx("ui_click", 1.15, -3.0)
	zoom_face_requested.emit(_zoom_toggled)


func _on_accept() -> void:
	if _zoom_toggled:
		zoom_face_requested.emit(false)
	SoundBank.play_sfx("ui_click", 1.0, -3.0)
	_finish_game(_app.doc_is_valid, 1.0 if _app.doc_is_valid else 0.0)


func _on_reject() -> void:
	if _zoom_toggled:
		zoom_face_requested.emit(false)
	SoundBank.play_sfx("ui_click", 0.8, -2.0)
	_reject_customer()
