extends Node

## Точка входа «Круглосуточный» (Godot 4.3, Mobile, Android).
## Всё строится кодом вокруг минимальной сцены main.tscn.

var _shop: ShopBuilder = null
var _player: PlayerController = null
var _cctv: CCTVSystem = null
var _director: NightDirector = null

var _vhs_overlay: VHSOverlay = null
var _ui_layer: CanvasLayer = null
var _touch_controls: TouchControls = null
var _hud: HUDUI = null
var _rulebook: RulebookUI = null
var _pause_menu: PauseMenu = null
var _end_night_ui: EndNightUI = null
var _main_menu: Control = null
var _minigame_holder: Control = null

## Очередь мини-игр для текущего обслуживания покупателя
var _mg_customer: CustomerEntity = null
var _mg_queue: Array[String] = []
var _mg_quality_sum: float = 0.0
var _mg_count: int = 0
var _mg_all_ok: bool = true
var _active_mg: MiniGame = null


func _ready() -> void:
	## Понижаем 3D-разрешение для эффекта дешёвой камеры (UI остаётся в полном разрешении)
	var vp: Viewport = get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.65

	_build_world()
	_build_ui_stack()
	_connect_signals()
	_show_main_menu()


func _build_world() -> void:
	_shop = ShopBuilder.new()
	_shop.name = "ShopWorld"
	add_child(_shop)

	_player = PlayerController.new()
	_player.name = "Player"
	add_child(_player)

	_cctv = CCTVSystem.new()
	_cctv.name = "CCTVSystem"
	add_child(_cctv)
	_cctv.setup(_shop)

	_director = NightDirector.new()
	_director.name = "NightDirector"
	add_child(_director)
	_director.setup(_shop, _player)


func _build_ui_stack() -> void:
	## Слой VHS пост-процесса + оверлей REC/таймкод
	_vhs_overlay = VHSOverlay.new()
	add_child(_vhs_overlay)

	## Интерактивный UI-слой поверх VHS (в полном разрешении)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 60
	add_child(_ui_layer)

	_touch_controls = TouchControls.new()
	_ui_layer.add_child(_touch_controls)

	_hud = HUDUI.new()
	_ui_layer.add_child(_hud)

	_minigame_holder = Control.new()
	_minigame_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_minigame_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_minigame_holder)

	_rulebook = RulebookUI.new()
	_ui_layer.add_child(_rulebook)

	_pause_menu = PauseMenu.new()
	_ui_layer.add_child(_pause_menu)

	_end_night_ui = EndNightUI.new()
	_ui_layer.add_child(_end_night_ui)

	_build_main_menu()


func _build_main_menu() -> void:
	_main_menu = Control.new()
	_main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(_main_menu)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.03, 0.86)
	_main_menu.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -330
	vbox.offset_top = -230
	vbox.offset_right = 330
	vbox.offset_bottom = 230
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_main_menu.add_child(vbox)

	var title: Label = Label.new()
	title.text = "КРУГЛОСУТОЧНЫЙ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 0.78))
	vbox.add_child(title)

	var sub: Label = Label.new()
	sub.text = "Смена 22:00 – 06:00  |  19 НОЯ 1998  |  ЗАПИСЬ #04"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.68, 0.78, 0.64))
	vbox.add_child(sub)

	var btn_start: Button = Button.new()
	btn_start.text = "НАЧАТЬ СМЕНУ (НОЧЬ %d)" % SaveSystem.best_night
	btn_start.custom_minimum_size = Vector2(420, 62)
	btn_start.add_theme_font_size_override("font_size", 22)
	btn_start.pressed.connect(func() -> void: _start_game(SaveSystem.best_night, GameState.MODE_CAMPAIGN))
	vbox.add_child(btn_start)

	var btn_n1: Button = Button.new()
	btn_n1.text = "НОВАЯ КАМПАНИЯ (НОЧЬ 1)"
	btn_n1.custom_minimum_size = Vector2(420, 56)
	btn_n1.add_theme_font_size_override("font_size", 20)
	btn_n1.pressed.connect(func() -> void:
		SaveSystem.reset_campaign_upgrades()
		_start_game(1, GameState.MODE_CAMPAIGN)
	)
	vbox.add_child(btn_n1)

	var btn_endless: Button = Button.new()
	btn_endless.text = "БЕСКОНЕЧНЫЙ РЕЖИМ" if SaveSystem.endless_unlocked else "БЕСКОНЕЧНЫЙ РЕЖИМ (ОТКРЫТ СРАЗУ ДЛЯ ТЕСТА)"
	btn_endless.custom_minimum_size = Vector2(420, 56)
	btn_endless.add_theme_font_size_override("font_size", 19)
	btn_endless.pressed.connect(func() -> void: _start_game(5, GameState.MODE_ENDLESS))
	vbox.add_child(btn_endless)

	var hint: Label = Label.new()
	hint.text = "Управление: джойстик слева, взгляд справа, тап по покупателю — осмотр.\nЧитайте «Книгу правил» каждую ночь!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.70, 0.76, 0.68))
	vbox.add_child(hint)


func _connect_signals() -> void:
	_touch_controls.move_changed.connect(_player.set_move_input)
	_touch_controls.look_delta.connect(_player.add_look_delta)
	_touch_controls.screen_tapped.connect(_on_screen_tapped)

	_player.autofocus_triggered.connect(_vhs_overlay.trigger_autofocus_blur)
	_player.inspect_zone_hit.connect(_on_inspect_zone_hit)

	_cctv.channel_changed.connect(func(_idx: int, ch_name: String) -> void: _hud.set_cctv_channel_label(ch_name))

	_hud.flashlight_pressed.connect(_player.toggle_flashlight)
	_hud.rulebook_pressed.connect(_rulebook.open_book)
	_hud.cctv_switch_pressed.connect(_cctv.toggle_channel)
	_hud.pause_pressed.connect(_pause_menu.open_pause)
	_hud.decision_pressed.connect(_director.handle_player_decision)
	_hud.light_hold_changed.connect(_director.set_holding_light_switch)
	_hud.fuse_fix_pressed.connect(_on_try_fix_fuse)

	_director.customer_arrived.connect(_on_customer_arrived)
	_director.customer_cleared.connect(_on_customer_cleared)
	_director.request_minigame_sequence.connect(_start_minigame_sequence)
	_director.aggressive_warning.connect(_hud.set_aggressive_ui)
	_director.status_banner.connect(_hud.show_banner)

	_pause_menu.quit_to_menu.connect(_show_main_menu)
	_end_night_ui.next_night_requested.connect(func(n: int) -> void: _start_game(n, GameState.MODE_CAMPAIGN))
	_end_night_ui.retry_night_requested.connect(func(n: int) -> void: _start_game(n, GameState.game_mode))
	_end_night_ui.menu_requested.connect(_show_main_menu)

	GameState.night_ended.connect(_on_night_ended)


func _show_main_menu() -> void:
	_clear_active_minigame()
	_director.clear_current_customer()
	GameState.phase = GameState.PHASE_MENU
	_main_menu.visible = true
	_hud.visible = false
	_touch_controls.visible = false
	_end_night_ui.visible = false


func _start_game(night_num: int, mode: int) -> void:
	SoundBank.play_sfx("ui_click", 1.1, -2.0)
	_clear_active_minigame()
	_main_menu.visible = false
	_end_night_ui.visible = false
	_hud.visible = true
	_touch_controls.visible = true
	_touch_controls.reset_inputs()
	_hud.set_decision_visible(false)
	_player.refresh_upgrades()
	_cctv.refresh_upgrades()
	_player.reset_to_spawn(ShopBuilder.SPAWN_PLAYER_POS)
	GameState.start_night(night_num, mode)


func _on_screen_tapped(screen_pos: Vector2) -> void:
	if GameState.phase != GameState.PHASE_PLAYING:
		return
	_player.inspect_at_screen_pos(screen_pos)


func _on_inspect_zone_hit(zone_id: String, zone_label: String, _world_pos: Vector3) -> void:
	if zone_label != "":
		_hud.show_zone_label(zone_label)
	if zone_id == "fuse_box" and not GameState.power_on:
		GameState.set_power(true)
		_hud.show_banner("Питание восстановлено!")
	elif zone_id == "light_switch":
		_hud.show_banner("Используйте кнопку «ДЕРЖАТЬ СВЕТ (3 с)» при угрозе!")


func _on_try_fix_fuse() -> void:
	## Если игрок дошёл до подсобки (z > 1.8) или просто нажал кнопку щитка
	if _player.global_position.z < 1.6:
		_hud.show_banner("Подойдите в подсобку (за перегородку) к электрощитку!")
		return
	GameState.set_power(true)
	_hud.show_banner("Щиток включён! Свет восстановлен.")


func _on_customer_arrived(cust: CustomerEntity) -> void:
	cust.speech_updated.connect(_hud.show_subtitle)
	_hud.set_decision_visible(true)


func _on_customer_cleared() -> void:
	_hud.set_decision_visible(false)
	_player.clear_zoom()


func _start_minigame_sequence(cust: CustomerEntity) -> void:
	_mg_customer = cust
	_mg_queue.clear()
	_mg_quality_sum = 0.0
	_mg_count = 0
	_mg_all_ok = true

	if cust.needs_id_check:
		_mg_queue.append("document")
	_mg_queue.append("scanner")
	if cust.uses_large_bill:
		_mg_queue.append("uv_bills")
	_mg_queue.append("change")

	GameState.phase = GameState.PHASE_MINIGAME
	_touch_controls.reset_inputs()
	_hud.set_decision_visible(false)
	_launch_next_minigame()


func _launch_next_minigame() -> void:
	_clear_active_minigame()
	if _mg_customer == null or not is_instance_valid(_mg_customer):
		GameState.phase = GameState.PHASE_PLAYING
		return

	if _mg_queue.is_empty():
		GameState.phase = GameState.PHASE_PLAYING
		var avg_q: float = _mg_quality_sum / float(maxi(1, _mg_count))
		_director.complete_serve_outcome(_mg_all_ok, avg_q, false)
		return

	var next_id: String = _mg_queue.pop_front()
	var mg: MiniGame = null
	if next_id == "document":
		var doc_mg: MGDocument = MGDocument.new()
		doc_mg.setup(_mg_customer.appearance)
		doc_mg.zoom_face_requested.connect(_on_doc_zoom_face)
		mg = doc_mg
	elif next_id == "scanner":
		var scan_mg: MGScanner = MGScanner.new()
		scan_mg.setup(_mg_customer.basket)
		mg = scan_mg
	elif next_id == "uv_bills":
		var uv_mg: MGUVBills = MGUVBills.new()
		uv_mg.setup(_mg_customer.appearance.strange_payment, _mg_customer.appearance.seed_val)
		mg = uv_mg
	else:
		var total_p: int = 0
		for item: Dictionary in _mg_customer.basket:
			total_p += int(item.get("price", 30))
		var ch_mg: MGChange = MGChange.new()
		ch_mg.setup(total_p, _mg_customer.appearance.strange_payment, _mg_customer.appearance.seed_val)
		mg = ch_mg

	_active_mg = mg
	_active_mg.finished.connect(_on_minigame_finished)
	_active_mg.rejected_by_player.connect(_on_minigame_rejected)
	_minigame_holder.add_child(_active_mg)


func _on_doc_zoom_face(enable: bool) -> void:
	if enable and _mg_customer != null and is_instance_valid(_mg_customer):
		var face_pos: Vector3 = _mg_customer.global_position + Vector3(0.0, 1.65 * _mg_customer.appearance.height_scale, 0.0)
		_player.set_zoom_target(face_pos, "doc_face")
	else:
		_player.clear_zoom()


func _on_minigame_finished(success: bool, quality: float) -> void:
	_mg_count += 1
	_mg_quality_sum += quality
	if not success:
		_mg_all_ok = false
	_launch_next_minigame()


func _on_minigame_rejected() -> void:
	_clear_active_minigame()
	_mg_queue.clear()
	_player.clear_zoom()
	GameState.phase = GameState.PHASE_PLAYING
	_director.complete_serve_outcome(true, 1.0, true)


func _clear_active_minigame() -> void:
	if _active_mg != null and is_instance_valid(_active_mg):
		_active_mg.queue_free()
	_active_mg = null


func _on_night_ended(victory: bool, summary: Dictionary) -> void:
	_clear_active_minigame()
	_director.clear_current_customer()
	_touch_controls.reset_inputs()
	_hud.set_decision_visible(false)
	_end_night_ui.show_summary(victory, summary)
