class_name MGChange
extends MiniGame

## Мини-игра B: СДАЧА
## Соберите точную сдачу кнопками 1 / 2 / 5 / 10 / 50 / 100 за ограниченное время.
## Если покупатель дал странную/ржавую монету нестандартного номинала или лист — нажмите ОТКЛОНИТЬ!

const DENOMS: Array[int] = [1, 2, 5, 10, 50, 100]

var _total_price: int = 64
var _paid_amount: int = 100
var _target_change: int = 36
var _current_change: int = 0
var _is_strange_coin: bool = false
var _time_left: float = 20.0

var _lbl_info: Label = null
var _lbl_collected: Label = null
var _lbl_timer: Label = null


func setup(total_price: int, is_strange_payment: bool, seed_val: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val * 313 + 7
	_total_price = maxi(15, total_price)
	_is_strange_coin = is_strange_payment
	if _total_price < 100:
		_paid_amount = 100
	elif _total_price < 200:
		_paid_amount = 200
	else:
		_paid_amount = ((_total_price / 100) + 1) * 100
	_target_change = _paid_amount - _total_price
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.03, 0.78)
	add_child(dim)

	var panel: PanelContainer = _make_styled_panel(Color(0.09, 0.11, 0.09, 0.96))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_top = -230
	panel.offset_right = 360
	panel.offset_bottom = 230
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "КАССА: ВЫДАЧА СДАЧИ"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.88, 0.96, 0.80))
	vbox.add_child(title)

	_lbl_timer = Label.new()
	_lbl_timer.text = "Время: 20.0 с"
	_lbl_timer.add_theme_font_size_override("font_size", 18)
	_lbl_timer.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	vbox.add_child(_lbl_timer)

	_lbl_info = Label.new()
	if _is_strange_coin:
		_lbl_info.text = "Сумма чека: %d ₽\nПокупатель протянул: [РЖАВАЯ МОНЕТА 3.7 ₽ и МОКРЫЙ ЛИСТ] (!)" % _total_price
		_lbl_info.add_theme_color_override("font_color", Color(0.98, 0.58, 0.38))
	else:
		_lbl_info.text = "Сумма чека: %d ₽  |  Получено: %d ₽  |  Нужно сдачи: %d ₽" % [_total_price, _paid_amount, _target_change]
		_lbl_info.add_theme_color_override("font_color", Color(0.90, 0.94, 0.86))
	_lbl_info.add_theme_font_size_override("font_size", 20)
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_lbl_info)

	_lbl_collected = Label.new()
	_lbl_collected.text = "Набрано сдачи: 0 ₽"
	_lbl_collected.add_theme_font_size_override("font_size", 24)
	_lbl_collected.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
	vbox.add_child(_lbl_collected)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	for denom: int in DENOMS:
		var btn: Button = Button.new()
		btn.text = "+%d ₽" % denom
		btn.custom_minimum_size = Vector2(210, 62)
		btn.add_theme_font_size_override("font_size", 22)
		var d_val: int = denom
		btn.pressed.connect(func() -> void: _add_coin(d_val))
		grid.add_child(btn)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var btn_clear: Button = Button.new()
	btn_clear.text = "СБРОС"
	btn_clear.custom_minimum_size = Vector2(150, 58)
	btn_clear.add_theme_font_size_override("font_size", 19)
	btn_clear.pressed.connect(_on_clear)
	row.add_child(btn_clear)

	var btn_give: Button = Button.new()
	btn_give.text = "ВЫДАТЬ СДАЧУ"
	btn_give.custom_minimum_size = Vector2(240, 58)
	btn_give.add_theme_font_size_override("font_size", 20)
	btn_give.pressed.connect(_on_submit)
	row.add_child(btn_give)

	var btn_reject: Button = Button.new()
	btn_reject.text = "ОТКЛОНИТЬ ОПЛАТУ"
	btn_reject.custom_minimum_size = Vector2(250, 58)
	btn_reject.add_theme_font_size_override("font_size", 19)
	btn_reject.pressed.connect(_on_reject)
	row.add_child(btn_reject)


func _process(delta: float) -> void:
	_time_left -= delta
	if _lbl_timer != null:
		_lbl_timer.text = "Время: %.1f с" % maxf(0.0, _time_left)
	if _time_left <= 0.0:
		_finish_game(false, 0.0)


func _add_coin(val: int) -> void:
	_current_change += val
	SoundBank.play_sfx("coin_clink", randf_range(0.92, 1.12), -3.0)
	_lbl_collected.text = "Набрано сдачи: %d ₽" % _current_change


func _on_clear() -> void:
	_current_change = 0
	SoundBank.play_sfx("ui_click", 0.9, -4.0)
	_lbl_collected.text = "Набрано сдачи: 0 ₽"


func _on_submit() -> void:
	if _is_strange_coin:
		_finish_game(false, 0.0)
		return
	var ok: bool = (_current_change == _target_change)
	var qual: float = clampf(_time_left / 20.0, 0.25, 1.0) if ok else 0.0
	_finish_game(ok, qual)


func _on_reject() -> void:
	SoundBank.play_sfx("ui_click", 0.75, -2.0)
	_reject_customer()
