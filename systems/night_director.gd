class_name NightDirector
extends Node

## Режиссёр смены: спавн покупателей каждые 25-50 с, решения, агрессивная фаза,
## отключения света в ночь 5 и запуск последовательности мини-игр.

signal customer_arrived(customer: CustomerEntity)
signal customer_cleared()
signal request_minigame_sequence(customer: CustomerEntity)
signal aggressive_warning(active: bool, hold_progress: float)
signal status_banner(text: String)

var shop: ShopBuilder = null
var player: PlayerController = null
var current_customer: CustomerEntity = null

var _spawn_timer: float = 4.0
var _blackout_timer: float = 55.0
var _aggressive_timer: float = 0.0
var _light_hold_progress: float = 0.0
var _is_holding_light_switch: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed_counter: int = 100


func setup(p_shop: ShopBuilder, p_player: PlayerController) -> void:
	shop = p_shop
	player = p_player
	_rng.randomize()
	_seed_counter = _rng.randi_range(1000, 99999)
	GameState.night_started.connect(_on_night_started)


func _on_night_started(night_num: int) -> void:
	clear_current_customer()
	var cfg: Dictionary = NightsDB.get_night_config(night_num, GameState.game_mode == GameState.MODE_ENDLESS)
	_spawn_timer = 4.5
	_blackout_timer = _rng.randf_range(48.0, 82.0)
	_aggressive_timer = 0.0
	_light_hold_progress = 0.0
	_is_holding_light_switch = false
	GameState.radio_message_received.emit("НАЧАЛЬНИК", str(cfg.get("intro_radio", "")))


func clear_current_customer() -> void:
	if current_customer != null and is_instance_valid(current_customer):
		current_customer.queue_free()
	current_customer = null
	aggressive_warning.emit(false, 0.0)


func set_holding_light_switch(holding: bool) -> void:
	_is_holding_light_switch = holding
	if shop != null:
		shop.set_temporary_lights_off(holding)


func _process(delta: float) -> void:
	if GameState.phase != GameState.PHASE_PLAYING:
		return
	if GameState.is_shift_paused:
		return

	GameState.advance_shift_time(delta)

	## Случайные отключения света в ночь 5 / бесконечном режиме
	var cfg: Dictionary = NightsDB.get_night_config(GameState.current_night, GameState.game_mode == GameState.MODE_ENDLESS)
	if bool(cfg.get("blackouts", false)) and GameState.power_on:
		_blackout_timer -= delta
		if _blackout_timer <= 0.0:
			GameState.set_power(false)
			GameState.trigger_glitch(0.7, 0.6, false)
			status_banner.emit("ВЫБИЛО ЩИТОК! Включите рубильник в подсобке!")
			_blackout_timer = _rng.randf_range(65.0, 105.0)

	## Обновляем УФ-реакцию на лице покупателя
	if current_customer != null and is_instance_valid(current_customer) and player != null:
		current_customer.set_uv_illuminated(player.flashlight_on)

	## Обработка агрессивной аномалии (удержание выключателя света 3 с или таймер атаки)
	if current_customer != null and is_instance_valid(current_customer) and current_customer.state == CustomerEntity.STATE_AGGRESSIVE:
		_aggressive_timer += delta
		if _is_holding_light_switch:
			_light_hold_progress += delta
			aggressive_warning.emit(true, clampf(_light_hold_progress / 3.0, 0.0, 1.0))
			if _light_hold_progress >= 3.0:
				set_holding_light_switch(false)
				_resolve_aggressive_defeated()
				return
		else:
			_light_hold_progress = maxf(0.0, _light_hold_progress - delta * 0.8)
			aggressive_warning.emit(true, clampf(_light_hold_progress / 3.0, 0.0, 1.0))

		if _aggressive_timer >= 9.0:
			## Не успел обезвредить
			set_holding_light_switch(false)
			SoundBank.play_sfx("stinger", 1.0, 2.0)
			GameState.trigger_glitch(1.0, 1.2, true)
			GameState.change_sanity(-28.0)
			GameState.add_strike("Агрессивная аномалия прорвалась за кассу!")
			current_customer.command_leave(true)
			aggressive_warning.emit(false, 0.0)
			return

	## Спавн следующего покупателя
	if current_customer == null:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_next_customer(cfg)


func _spawn_next_customer(cfg: Dictionary) -> void:
	_seed_counter += _rng.randi_range(3, 19)
	var anom_chance: float = float(cfg.get("anomaly_chance", 0.45))
	var weirdo_chance: float = float(cfg.get("weirdo_chance", 0.20))

	var is_anom: bool = _rng.randf() < anom_chance
	var anom_id: String = ""
	var weirdo_id: String = ""

	if is_anom:
		var chosen: Dictionary = AnomaliesDB.pick_weighted_anomaly(GameState.current_night, GameState.game_mode == GameState.MODE_ENDLESS, _rng)
		anom_id = str(chosen["id"])
	elif _rng.randf() < weirdo_chance:
		var w: Dictionary = AnomaliesDB.HARMLESS_WEIRDOS[_rng.randi() % AnomaliesDB.HARMLESS_WEIRDOS.size()]
		weirdo_id = str(w["id"])

	var app: CustomerAppearance = CustomerAppearance.create_from_seed(_seed_counter, is_anom, anom_id, weirdo_id, GameState.weather)
	var needs_id: bool = (anom_id == "fake_document") or (_rng.randf() < 0.28 and GameState.current_night >= 3)
	var include_strange: bool = _rng.randf() < (0.35 if is_anom else 0.12)
	var basket: Array[Dictionary] = ItemsDB.build_basket(GameState.current_night, needs_id, include_strange, _rng)
	var greeting: String = DialogueDB.pick_greeting(is_anom, anom_id, weirdo_id, _rng)

	var cust: CustomerEntity = CustomerEntity.new()
	shop.add_child(cust)
	cust.setup(app, basket, greeting, player)
	cust.arrived_at_counter.connect(_on_customer_arrived)
	cust.exited_shop.connect(_on_customer_exited)
	current_customer = cust

	shop.ring_doorbell()
	if is_anom:
		GameState.trigger_glitch(0.28, 0.45, false)


func _on_customer_arrived(cust: CustomerEntity) -> void:
	customer_arrived.emit(cust)


func _on_customer_exited(_cust: CustomerEntity) -> void:
	current_customer = null
	customer_cleared.emit()
	aggressive_warning.emit(false, 0.0)
	var cfg: Dictionary = NightsDB.get_night_config(GameState.current_night, GameState.game_mode == GameState.MODE_ENDLESS)
	_spawn_timer = _rng.randf_range(float(cfg.get("spawn_min", 25.0)), float(cfg.get("spawn_max", 45.0)))


func handle_player_decision(decision: int) -> void:
	if current_customer == null or not is_instance_valid(current_customer):
		return
	if current_customer.state != CustomerEntity.STATE_AT_COUNTER and current_customer.state != CustomerEntity.STATE_AGGRESSIVE:
		return

	var app: CustomerAppearance = current_customer.appearance

	if decision == GameState.DECISION_SERVE:
		if current_customer.state == CustomerEntity.STATE_AGGRESSIVE:
			return
		## Запускаем мини-игры на кассе; итог проверим после их завершения
		request_minigame_sequence.emit(current_customer)
		return

	if decision == GameState.DECISION_DENY:
		if app.is_anomaly:
			if app.is_aggressive and current_customer.state != CustomerEntity.STATE_AGGRESSIVE:
				_aggressive_timer = 0.0
				_light_hold_progress = 0.0
				current_customer.start_aggressive_mode()
				GameState.trigger_glitch(0.55, 0.7, false)
				status_banner.emit("ОН НЕ УХОДИТ! Жми [ТРЕВОГА] или держи выключатель света 3 с!")
				return
			## Верно отказал аномалии
			GameState.denied_anomalies += 1
			GameState.endless_customers_cleared += 1
			GameState.add_money(35, false)
			GameState.change_sanity(4.0)
			GameState.trigger_glitch(0.45, 0.55, false)
			SoundBank.play_sfx("jingle_win", 1.15, -4.0)
			status_banner.emit("Верный отказ! Аномалия рассеялась (+35 ₽)")
			current_customer.command_leave(true)
		else:
			## Отказал нормальному (или безобидному чудаку)
			var react: String = DialogueDB.DENY_NORMAL_REACTIONS[_rng.randi() % DialogueDB.DENY_NORMAL_REACTIONS.size()]
			current_customer.start_speaking(react)
			GameState.add_money(-40, false)
			GameState.add_strike("Отказано нормальному покупателю (-40 ₽)!")
			SoundBank.play_sfx("jingle_fail", 1.0, -2.0)
			status_banner.emit("ОШИБКА: это был живой человек! Штраф и страйк.")
			current_customer.command_leave(false)
		return

	if decision == GameState.DECISION_ALARM:
		var cost: int = GameState.get_alarm_cost()
		SoundBank.play_sfx("alarm_siren", 1.0, -1.0)
		GameState.add_money(-cost, false)
		if app.is_anomaly and (app.is_aggressive or current_customer.state == CustomerEntity.STATE_AGGRESSIVE):
			_resolve_aggressive_defeated()
		else:
			## Ошибочная тревога
			GameState.add_strike("Ложная тревога! Списано %d ₽." % cost)
			status_banner.emit("Ложная тревога! Штраф %d ₽ и страйк." % cost)
			current_customer.command_leave(app.is_anomaly)


func _resolve_aggressive_defeated() -> void:
	aggressive_warning.emit(false, 0.0)
	GameState.denied_anomalies += 1
	GameState.endless_customers_cleared += 1
	GameState.add_money(60, false)
	GameState.change_sanity(8.0)
	GameState.trigger_glitch(0.6, 0.5, false)
	SoundBank.play_sfx("jingle_win", 1.0, -3.0)
	status_banner.emit("Агрессивная аномалия нейтрализована! (+60 ₽)")
	if current_customer != null and is_instance_valid(current_customer):
		current_customer.command_leave(true)


func complete_serve_outcome(minigame_ok: bool, quality: float, rejected_in_minigame: bool) -> void:
	if current_customer == null or not is_instance_valid(current_customer):
		return
	var app: CustomerAppearance = current_customer.appearance

	## Если игрок отклонил поддельный документ или фальшивые деньги/монеты внутри мини-игры
	if rejected_in_minigame:
		if app.is_anomaly:
			GameState.denied_anomalies += 1
			GameState.endless_customers_cleared += 1
			GameState.add_money(45, false)
			SoundBank.play_sfx("jingle_win", 1.1, -3.0)
			status_banner.emit("Подделка раскрыта на кассе! (+45 ₽)")
			current_customer.command_leave(true)
		else:
			GameState.add_strike("Вы отклонили честный документ/оплату!")
			SoundBank.play_sfx("jingle_fail", 1.0, -2.0)
			current_customer.command_leave(false)
		return

	if app.is_anomaly:
		## Обслужил аномалию -> страйк, падает рассудок, хоррор-событие
		SoundBank.play_sfx("stinger", 1.0, 2.0)
		GameState.trigger_glitch(1.0, 1.35, true)
		GameState.change_sanity(-24.0)
		var anom_info: Dictionary = AnomaliesDB.get_by_id(app.anomaly_id)
		var aname: String = str(anom_info.get("name", "Аномалия"))
		GameState.add_strike("Вы обслужили аномалию («%s»)!" % aname)
		status_banner.emit("УЖАС! Вы обслужили аномалию: " + aname)
		current_customer.command_leave(true)
	else:
		## Верно обслужил нормального
		GameState.served_correct += 1
		GameState.endless_customers_cleared += 1
		var base_pay: int = 40
		var tip: int = int(roundf(clampf(quality, 0.0, 1.0) * 25.0)) if minigame_ok else 0
		GameState.add_money(base_pay, false)
		if tip > 0:
			GameState.add_money(tip, true)
		SoundBank.play_sfx("cash_register", 1.0, -2.0)
		if minigame_ok:
			status_banner.emit("Обслужен! +%d ₽ (чаевые +%d ₽)" % [base_pay, tip])
		else:
			status_banner.emit("Обслужен с ошибкой на кассе (+%d ₽, без чаевых)" % base_pay)
		current_customer.command_leave(false)
