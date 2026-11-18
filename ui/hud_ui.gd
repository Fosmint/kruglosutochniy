class_name HUDUI
extends Control

## Основной HUD смены: статы, шкала рассудка, субтитры, рация босса,
## подпись зоны осмотра, контекстные кнопки инструментов и панель решений.

signal flashlight_pressed()
signal rulebook_pressed()
signal cctv_switch_pressed()
signal pause_pressed()
signal decision_pressed(decision: int)
signal light_hold_changed(holding: bool)
signal fuse_fix_pressed()

var _lbl_stats: Label = null
var _sanity_bar: ProgressBar = null
var _lbl_subtitle: Label = null
var _subtitle_panel: PanelContainer = null
var _lbl_radio: Label = null
var _radio_panel: PanelContainer = null
var _lbl_zone: Label = null
var _lbl_banner: Label = null
var _lbl_cctv_ch: Label = null
var _decision_panel: HBoxContainer = null
var _btn_alarm: Button = null
var _btn_light_hold: Button = null
var _btn_fuse_fix: Button = null
var _aggro_bar: ProgressBar = null

var _radio_timer: float = 0.0
var _banner_timer: float = 0.0
var _zone_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameState.stats_changed.connect(refresh_stats)
	GameState.sanity_changed.connect(_on_sanity_changed)
	GameState.radio_message_received.connect(show_radio)
	GameState.power_state_changed.connect(_on_power_changed)
	refresh_stats()


func _make_bg_panel(bg_col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _style_btn(btn: Button, bg: Color, border: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg.lightened(0.14)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = bg.darkened(0.16)
	btn.add_theme_stylebox_override("pressed", sb_p)


func _build_ui() -> void:
	## Прицел-точка в центре экрана для удобства осмотра
	var dot: ColorRect = ColorRect.new()
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.offset_left = -3
	dot.offset_top = -3
	dot.offset_right = 3
	dot.offset_bottom = 3
	dot.color = Color(0.90, 0.96, 0.84, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)

	## Верхняя строка статуса (смещена ниже REC/PLAY)
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.position = Vector2(22, 52)
	top_bar.add_theme_constant_override("separation", 16)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	_lbl_stats = Label.new()
	_lbl_stats.add_theme_font_size_override("font_size", 20)
	_lbl_stats.add_theme_color_override("font_color", Color(0.90, 0.96, 0.84))
	top_bar.add_child(_lbl_stats)

	var san_lbl: Label = Label.new()
	san_lbl.text = "РАССУДОК:"
	san_lbl.add_theme_font_size_override("font_size", 18)
	san_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.80))
	top_bar.add_child(san_lbl)

	_sanity_bar = ProgressBar.new()
	_sanity_bar.custom_minimum_size = Vector2(150, 22)
	_sanity_bar.min_value = 0.0
	_sanity_bar.max_value = 100.0
	_sanity_bar.value = 100.0
	_sanity_bar.show_percentage = false
	top_bar.add_child(_sanity_bar)

	## Кнопка паузы (правый верхний угол, под батареей)
	var btn_pause: Button = Button.new()
	btn_pause.text = "ПАУЗА"
	btn_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	btn_pause.offset_left = -148
	btn_pause.offset_top = 52
	btn_pause.offset_right = -18
	btn_pause.offset_bottom = 100
	btn_pause.add_theme_font_size_override("font_size", 18)
	_style_btn(btn_pause, Color(0.14, 0.17, 0.14, 0.88), Color(0.55, 0.65, 0.50))
	btn_pause.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(btn_pause)

	## Рация начальника (сверху по центру на полупрозрачной подложке)
	_radio_panel = _make_bg_panel(Color(0.04, 0.05, 0.04, 0.72))
	_radio_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_radio_panel.offset_left = 140
	_radio_panel.offset_top = 92
	_radio_panel.offset_right = -215
	_radio_panel.offset_bottom = 160
	_radio_panel.visible = false
	add_child(_radio_panel)

	_lbl_radio = Label.new()
	_lbl_radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_radio.add_theme_font_size_override("font_size", 18)
	_lbl_radio.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
	_lbl_radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_panel.add_child(_lbl_radio)

	## Баннер событий / предупреждений
	_lbl_banner = Label.new()
	_lbl_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_lbl_banner.offset_left = 160
	_lbl_banner.offset_top = 168
	_lbl_banner.offset_right = -215
	_lbl_banner.offset_bottom = 216
	_lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_banner.add_theme_font_size_override("font_size", 21)
	_lbl_banner.add_theme_color_override("font_color", Color(1.0, 0.46, 0.36))
	_lbl_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_banner)

	## Правая колонка контекстных кнопок инструментов (крупные, под палец)
	var tool_col: VBoxContainer = VBoxContainer.new()
	tool_col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tool_col.offset_left = -202
	tool_col.offset_top = -145
	tool_col.offset_right = -16
	tool_col.offset_bottom = 195
	tool_col.add_theme_constant_override("separation", 10)
	add_child(tool_col)

	var btn_uv: Button = Button.new()
	btn_uv.text = "УФ-ФОНАРИК"
	btn_uv.custom_minimum_size = Vector2(184, 58)
	btn_uv.add_theme_font_size_override("font_size", 18)
	_style_btn(btn_uv, Color(0.16, 0.14, 0.32, 0.90), Color(0.54, 0.48, 0.92))
	btn_uv.pressed.connect(func() -> void: flashlight_pressed.emit())
	tool_col.add_child(btn_uv)

	var btn_book: Button = Button.new()
	btn_book.text = "КНИГА ПРАВИЛ"
	btn_book.custom_minimum_size = Vector2(184, 58)
	btn_book.add_theme_font_size_override("font_size", 18)
	_style_btn(btn_book, Color(0.14, 0.22, 0.16, 0.90), Color(0.52, 0.72, 0.52))
	btn_book.pressed.connect(func() -> void: rulebook_pressed.emit())
	tool_col.add_child(btn_book)

	var btn_cctv: Button = Button.new()
	btn_cctv.text = "CCTV КАНАЛ"
	btn_cctv.custom_minimum_size = Vector2(184, 58)
	btn_cctv.add_theme_font_size_override("font_size", 18)
	_style_btn(btn_cctv, Color(0.14, 0.20, 0.22, 0.90), Color(0.46, 0.72, 0.74))
	btn_cctv.pressed.connect(func() -> void: cctv_switch_pressed.emit())
	tool_col.add_child(btn_cctv)

	_lbl_cctv_ch = Label.new()
	_lbl_cctv_ch.text = "КАМ-01: КАССА"
	_lbl_cctv_ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_cctv_ch.add_theme_font_size_override("font_size", 15)
	_lbl_cctv_ch.add_theme_color_override("font_color", Color(0.65, 0.94, 0.68))
	tool_col.add_child(_lbl_cctv_ch)

	## Кнопка удержания выключателя света (появляется при агрессивной аномалии)
	_btn_light_hold = Button.new()
	_btn_light_hold.text = "ДЕРЖАТЬ СВЕТ (3 с)"
	_btn_light_hold.custom_minimum_size = Vector2(184, 62)
	_btn_light_hold.add_theme_font_size_override("font_size", 16)
	_style_btn(_btn_light_hold, Color(0.45, 0.16, 0.12, 0.94), Color(0.95, 0.45, 0.30))
	_btn_light_hold.visible = false
	_btn_light_hold.button_down.connect(func() -> void: light_hold_changed.emit(true))
	_btn_light_hold.button_up.connect(func() -> void: light_hold_changed.emit(false))
	tool_col.add_child(_btn_light_hold)

	_aggro_bar = ProgressBar.new()
	_aggro_bar.custom_minimum_size = Vector2(184, 16)
	_aggro_bar.min_value = 0.0
	_aggro_bar.max_value = 1.0
	_aggro_bar.show_percentage = false
	_aggro_bar.visible = false
	tool_col.add_child(_aggro_bar)

	## Кнопка включения щитка (появляется при блэкауте в ночь 5)
	_btn_fuse_fix = Button.new()
	_btn_fuse_fix.text = "ВКЛЮЧИТЬ ЩИТОК"
	_btn_fuse_fix.custom_minimum_size = Vector2(184, 58)
	_btn_fuse_fix.add_theme_font_size_override("font_size", 16)
	_style_btn(_btn_fuse_fix, Color(0.45, 0.34, 0.10, 0.94), Color(0.96, 0.80, 0.30))
	_btn_fuse_fix.visible = false
	_btn_fuse_fix.pressed.connect(func() -> void: fuse_fix_pressed.emit())
	tool_col.add_child(_btn_fuse_fix)

	## Панель решений (появляется, когда покупатель у кассы)
	_decision_panel = HBoxContainer.new()
	_decision_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_decision_panel.offset_left = -330
	_decision_panel.offset_top = -138
	_decision_panel.offset_right = 330
	_decision_panel.offset_bottom = -74
	_decision_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_decision_panel.add_theme_constant_override("separation", 14)
	_decision_panel.visible = false
	add_child(_decision_panel)

	var btn_serve: Button = Button.new()
	btn_serve.text = "ОБСЛУЖИТЬ"
	btn_serve.custom_minimum_size = Vector2(205, 62)
	btn_serve.add_theme_font_size_override("font_size", 20)
	_style_btn(btn_serve, Color(0.14, 0.38, 0.18, 0.94), Color(0.48, 0.90, 0.52))
	btn_serve.pressed.connect(func() -> void: decision_pressed.emit(GameState.DECISION_SERVE))
	_decision_panel.add_child(btn_serve)

	var btn_deny: Button = Button.new()
	btn_deny.text = "ОТКАЗАТЬ"
	btn_deny.custom_minimum_size = Vector2(205, 62)
	btn_deny.add_theme_font_size_override("font_size", 20)
	_style_btn(btn_deny, Color(0.44, 0.24, 0.12, 0.94), Color(0.95, 0.60, 0.34))
	btn_deny.pressed.connect(func() -> void: decision_pressed.emit(GameState.DECISION_DENY))
	_decision_panel.add_child(btn_deny)

	_btn_alarm = Button.new()
	_btn_alarm.text = "ТРЕВОГА (80 ₽)"
	_btn_alarm.custom_minimum_size = Vector2(215, 62)
	_btn_alarm.add_theme_font_size_override("font_size", 19)
	_style_btn(_btn_alarm, Color(0.48, 0.10, 0.10, 0.94), Color(0.98, 0.36, 0.32))
	_btn_alarm.pressed.connect(func() -> void: decision_pressed.emit(GameState.DECISION_ALARM))
	_decision_panel.add_child(_btn_alarm)

	## Субтитры речи покупателя (на читаемой полупрозрачной плашке)
	_subtitle_panel = _make_bg_panel(Color(0.03, 0.04, 0.03, 0.76))
	_subtitle_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_panel.offset_left = 230
	_subtitle_panel.offset_top = -214
	_subtitle_panel.offset_right = -230
	_subtitle_panel.offset_bottom = -150
	_subtitle_panel.visible = false
	add_child(_subtitle_panel)

	_lbl_subtitle = Label.new()
	_lbl_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_subtitle.add_theme_font_size_override("font_size", 20)
	_lbl_subtitle.add_theme_color_override("font_color", Color(0.96, 0.98, 0.90))
	_lbl_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.add_child(_lbl_subtitle)

	## Подпись зоны осмотра внизу экрана
	_lbl_zone = Label.new()
	_lbl_zone.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_lbl_zone.offset_left = 240
	_lbl_zone.offset_top = -56
	_lbl_zone.offset_right = -240
	_lbl_zone.offset_bottom = -16
	_lbl_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_zone.add_theme_font_size_override("font_size", 22)
	_lbl_zone.add_theme_color_override("font_color", Color(0.55, 0.96, 0.72))
	_lbl_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_zone)


func refresh_stats() -> void:
	if _lbl_stats != null:
		var q_str: String = "∞" if GameState.game_mode == GameState.MODE_ENDLESS else str(GameState.quota)
		_lbl_stats.text = "НОЧЬ %d  |  КАССА: %d / %s ₽  |  СТРАЙКИ: %d / 3" % [
			GameState.current_night,
			GameState.money,
			q_str,
			GameState.strikes,
		]
	if _btn_alarm != null:
		_btn_alarm.text = "ТРЕВОГА (%d ₽)" % GameState.get_alarm_cost()


func _on_sanity_changed(val: float) -> void:
	if _sanity_bar != null:
		_sanity_bar.value = val


func _on_power_changed(power_on: bool) -> void:
	if _btn_fuse_fix != null:
		_btn_fuse_fix.visible = not power_on


func set_decision_visible(vis: bool) -> void:
	if _decision_panel != null:
		_decision_panel.visible = vis
	if not vis:
		if _lbl_subtitle != null:
			_lbl_subtitle.text = ""
		if _subtitle_panel != null:
			_subtitle_panel.visible = false


func set_aggressive_ui(active: bool, progress: float) -> void:
	if _btn_light_hold != null:
		_btn_light_hold.visible = active
	if _aggro_bar != null:
		_aggro_bar.visible = active
		_aggro_bar.value = progress


func set_cctv_channel_label(ch_name: String) -> void:
	if _lbl_cctv_ch != null:
		_lbl_cctv_ch.text = ch_name


func show_subtitle(speaker: String, text: String) -> void:
	if _lbl_subtitle != null:
		_lbl_subtitle.text = (speaker + ": " + text) if text != "" else ""
	if _subtitle_panel != null:
		_subtitle_panel.visible = (text != "")


func show_radio(sender: String, text: String) -> void:
	if _lbl_radio != null:
		_lbl_radio.text = "[РАЦИЯ — %s]: %s" % [sender, text]
		_radio_timer = 7.5
	if _radio_panel != null:
		_radio_panel.visible = (text != "")


func show_banner(text: String) -> void:
	if _lbl_banner != null:
		_lbl_banner.text = text
		_banner_timer = 4.5


func show_zone_label(text: String) -> void:
	if _lbl_zone != null:
		_lbl_zone.text = text
		_zone_timer = 3.2


func _process(delta: float) -> void:
	if _radio_timer > 0.0:
		_radio_timer -= delta
		if _radio_timer <= 0.0:
			if _lbl_radio != null:
				_lbl_radio.text = ""
			if _radio_panel != null:
				_radio_panel.visible = false
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _lbl_banner != null:
			_lbl_banner.text = ""
	if _zone_timer > 0.0:
		_zone_timer -= delta
		if _zone_timer <= 0.0 and _lbl_zone != null:
			_lbl_zone.text = ""
