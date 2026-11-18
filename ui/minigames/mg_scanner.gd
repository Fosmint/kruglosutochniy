class_name MGScanner
extends MiniGame

## Мини-игра A: СКАНЕР
## Перетащите обычные товары через красную линию сканера (бип).
## Запрещённые товары («Соль 5 кг», «Свеча для ритуала», «Банка с тенью») сбрасывайте в зону СБРОС!

var _items: Array[Dictionary] = []
var _item_buttons: Array[Button] = []
var _dragging_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _done_flags: Array[bool] = []
var _mistakes: int = 0
var _elapsed: float = 0.0

var _arena: Control = null
var _status_lbl: Label = null
var _scan_line_x: float = 420.0
var _discard_x: float = 650.0


func setup(basket: Array[Dictionary]) -> void:
	_items.assign(basket.duplicate(true))
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.03, 0.78)
	add_child(dim)

	var panel: PanelContainer = _make_styled_panel(Color(0.09, 0.11, 0.09, 0.96))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -430
	panel.offset_top = -250
	panel.offset_right = 430
	panel.offset_bottom = 250
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "СКАНЕР КАССЫ — перетащите товары через красную линию (запрещённые — в СБРОС)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.88, 0.95, 0.80))
	vbox.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.text = "Осталось товаров: %d" % _items.size()
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 0.70))
	vbox.add_child(_status_lbl)

	_arena = Control.new()
	_arena.custom_minimum_size = Vector2(820, 380)
	_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_arena)

	## Фон ленты
	var belt_bg: ColorRect = ColorRect.new()
	belt_bg.position = Vector2(0, 10)
	belt_bg.size = Vector2(820, 360)
	belt_bg.color = Color(0.14, 0.15, 0.14)
	_arena.add_child(belt_bg)

	## Красная линия сканера
	_scan_line_x = 430.0
	var scan_bar: ColorRect = ColorRect.new()
	scan_bar.position = Vector2(_scan_line_x, 10)
	scan_bar.size = Vector2(10, 360)
	scan_bar.color = Color(0.95, 0.16, 0.12, 0.92)
	_arena.add_child(scan_bar)

	var scan_lbl: Label = Label.new()
	scan_lbl.text = "СКАНЕР\n(ПРОБИТЬ)"
	scan_lbl.position = Vector2(_scan_line_x - 36, 16)
	scan_lbl.add_theme_font_size_override("font_size", 16)
	scan_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30))
	_arena.add_child(scan_lbl)

	## Зона сброса запрещённых товаров
	_discard_x = 640.0
	var disc_zone: ColorRect = ColorRect.new()
	disc_zone.position = Vector2(_discard_x, 10)
	disc_zone.size = Vector2(175, 360)
	disc_zone.color = Color(0.32, 0.12, 0.10, 0.85)
	_arena.add_child(disc_zone)

	var disc_lbl: Label = Label.new()
	disc_lbl.text = "СБРОС\nЗАПРЕЩЁННЫХ\nТОВАРОВ"
	disc_lbl.position = Vector2(_discard_x + 14, 130)
	disc_lbl.add_theme_font_size_override("font_size", 18)
	disc_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.72))
	_arena.add_child(disc_lbl)

	## Спавним карточки товаров слева
	_done_flags.clear()
	_item_buttons.clear()
	for i in range(_items.size()):
		_done_flags.append(false)
		var item: Dictionary = _items[i]
		var btn: Button = Button.new()
		btn.text = str(item["name"]) + "\n" + str(item["price"]) + " ₽"
		btn.size = Vector2(185, 68)
		btn.position = Vector2(18 + (i % 2) * 195, 36 + int(i / 2) * 105)
		btn.add_theme_font_size_override("font_size", 16)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = item.get("color", Color(0.35, 0.35, 0.35))
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.9, 0.9, 0.85)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		var idx_copy: int = i
		btn.gui_input.connect(func(ev: InputEvent) -> void: _on_item_gui_input(ev, idx_copy))
		_arena.add_child(btn)
		_item_buttons.append(btn)


func _process(delta: float) -> void:
	_elapsed += delta


func _on_item_gui_input(event: InputEvent, idx: int) -> void:
	if _done_flags[idx]:
		return
	var btn: Button = _item_buttons[idx]
	if event is InputEventScreenTouch:
		var ev: InputEventScreenTouch = event as InputEventScreenTouch
		if ev.pressed:
			_dragging_idx = idx
			_drag_offset = ev.position
		elif _dragging_idx == idx:
			_dragging_idx = -1
			_evaluate_drop(idx)
	elif event is InputEventScreenDrag:
		if _dragging_idx == idx:
			var ev_d: InputEventScreenDrag = event as InputEventScreenDrag
			btn.position += ev_d.relative
			btn.position.x = clampf(btn.position.x, 4.0, 640.0)
			btn.position.y = clampf(btn.position.y, 12.0, 300.0)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging_idx = idx
				_drag_offset = mb.position
			elif _dragging_idx == idx:
				_dragging_idx = -1
				_evaluate_drop(idx)
	elif event is InputEventMouseMotion:
		if _dragging_idx == idx:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			btn.position += mm.relative
			btn.position.x = clampf(btn.position.x, 4.0, 640.0)
			btn.position.y = clampf(btn.position.y, 12.0, 300.0)


func _evaluate_drop(idx: int) -> void:
	var btn: Button = _item_buttons[idx]
	var center_x: float = btn.position.x + btn.size.x * 0.5
	var item: Dictionary = _items[idx]
	var is_banned: bool = int(item.get("banned_min_night", 99)) <= GameState.current_night

	if center_x >= _discard_x:
		## Сброшен
		_done_flags[idx] = true
		btn.visible = false
		if is_banned:
			SoundBank.play_sfx("ui_click", 1.3, -2.0)
			_status_lbl.text = "Запрещённый товар сброшен верно!"
		else:
			_mistakes += 1
			SoundBank.play_sfx("jingle_fail", 1.2, -6.0)
			_status_lbl.text = "Зря сбросили обычный товар!"
		_check_completion()
	elif center_x >= _scan_line_x:
		## Просканирован
		_done_flags[idx] = true
		btn.visible = false
		SoundBank.play_sfx("scanner_beep", 1.0, -2.0)
		if is_banned:
			_mistakes += 1
			_status_lbl.text = "ОШИБКА: запрещённый товар («%s») нельзя пробивать!" % str(item["name"])
		else:
			_status_lbl.text = "Пробито: " + str(item["name"])
		_check_completion()


func _check_completion() -> void:
	var rem: int = 0
	for d: bool in _done_flags:
		if not d:
			rem += 1
	if rem > 0:
		return
	var speed_score: float = clampf(1.0 - maxf(0.0, _elapsed - 5.0) / 18.0, 0.2, 1.0)
	var acc_score: float = clampf(1.0 - float(_mistakes) * 0.4, 0.0, 1.0)
	_finish_game(_mistakes == 0, speed_score * acc_score)
