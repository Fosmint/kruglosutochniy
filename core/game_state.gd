extends Node

## Autoload GameState (без class_name)
## Все константы состояний — int (никаких match по enum автолоада)

const MODE_CAMPAIGN: int = 0
const MODE_ENDLESS: int = 1

const PHASE_MENU: int = 0
const PHASE_PLAYING: int = 1
const PHASE_MINIGAME: int = 2
const PHASE_NIGHT_END: int = 3
const PHASE_GAME_OVER: int = 4

const WEATHER_CLEAR: int = 0
const WEATHER_RAIN: int = 1

const DECISION_SERVE: int = 0
const DECISION_DENY: int = 1
const DECISION_ALARM: int = 2

signal night_started(night_num: int)
signal night_ended(victory: bool, summary: Dictionary)
signal stats_changed()
signal sanity_changed(new_sanity: float)
signal strikes_changed(new_strikes: int)
signal glitch_spike_requested(amount: float, duration: float, signal_lost: bool)
signal radio_message_received(sender: String, text: String)
signal power_state_changed(power_on: bool)
signal weather_changed(weather_type: int)
signal vhs_settings_changed(level: int)

@export var night_real_duration_sec: float = 420.0 ## ~7 реальных минут (22:00 - 06:00)

var game_mode: int = MODE_CAMPAIGN
var phase: int = PHASE_MENU
var current_night: int = 1
var endless_customers_cleared: int = 0

## Игровое время: 0.0 -> 22:00, 1.0 -> 06:00 (8 игровых часов = 480 минут)
var shift_elapsed_sec: float = 0.0
var is_shift_paused: bool = false

## Показатели смены
var money: int = 0
var quota: int = 150
var strikes: int = 0
var max_strikes: int = 3
var sanity: float = 100.0
var weather: int = WEATHER_CLEAR
var power_on: bool = true

## Статистика за ночь
var served_correct: int = 0
var denied_anomalies: int = 0
var mistakes_count: int = 0
var tips_earned: int = 0


func start_night(night_num: int, mode: int = MODE_CAMPAIGN) -> void:
	game_mode = mode
	current_night = maxi(1, night_num)
	phase = PHASE_PLAYING
	shift_elapsed_sec = 0.0
	is_shift_paused = false
	money = 0
	strikes = 0
	sanity = 100.0
	power_on = true
	served_correct = 0
	denied_anomalies = 0
	mistakes_count = 0
	tips_earned = 0

	var night_cfg: Dictionary = NightsDB.get_night_config(current_night, game_mode == MODE_ENDLESS)
	quota = int(night_cfg.get("quota", 150))
	weather = int(night_cfg.get("weather", WEATHER_CLEAR))

	weather_changed.emit(weather)
	power_state_changed.emit(power_on)
	stats_changed.emit()
	sanity_changed.emit(sanity)
	strikes_changed.emit(strikes)
	night_started.emit(current_night)


func advance_shift_time(delta: float) -> void:
	if phase != PHASE_PLAYING and phase != PHASE_MINIGAME:
		return
	if is_shift_paused:
		return
	shift_elapsed_sec += delta
	if game_mode == MODE_CAMPAIGN and shift_elapsed_sec >= night_real_duration_sec:
		shift_elapsed_sec = night_real_duration_sec
		finish_night(true)


func get_shift_progress() -> float:
	if night_real_duration_sec <= 1.0:
		return 0.0
	return clampf(shift_elapsed_sec / night_real_duration_sec, 0.0, 1.0)


func get_in_game_time_string() -> String:
	## 22:00 + progress * 8 hours (480 minutes = 28800 in-game seconds)
	var total_ig_sec: int = int(get_shift_progress() * 28800.0)
	if game_mode == MODE_ENDLESS:
		total_ig_sec = int(fmod(shift_elapsed_sec * 68.57, 28800.0))
	var start_sec: int = 22 * 3600
	var cur_sec: int = (start_sec + total_ig_sec) % 86400
	var hh: int = cur_sec / 3600
	var mm: int = (cur_sec % 3600) / 60
	var ss: int = cur_sec % 60
	var day_num: int = 18 + current_night
	if hh < 22:
		day_num += 1
	return "%02d НОЯ 1998 %02d:%02d:%02d" % [day_num, hh, mm, ss]


func get_shift_date_tuple() -> Array[int]:
	## Возвращает [day, month, year] для проверки документов
	var day_num: int = 18 + current_night
	return [day_num, 11, 1998]


func add_money(amount: int, is_tip: bool = false) -> void:
	money = maxi(0, money + amount)
	if is_tip and amount > 0:
		tips_earned += amount
	stats_changed.emit()


func change_sanity(delta_val: float) -> void:
	sanity = clampf(sanity + delta_val, 0.0, 100.0)
	sanity_changed.emit(sanity)
	stats_changed.emit()


func add_strike(reason: String) -> void:
	strikes += 1
	mistakes_count += 1
	strikes_changed.emit(strikes)
	stats_changed.emit()
	radio_message_received.emit("НАЧАЛЬНИК", "Штраф! " + reason)
	if strikes >= max_strikes:
		finish_night(false)


func get_alarm_cost() -> int:
	var discount: int = SaveSystem.upg_cheap_alarm * 20
	return maxi(20, 80 - discount)


func trigger_glitch(amount: float, duration: float, signal_lost: bool = false) -> void:
	glitch_spike_requested.emit(amount, duration, signal_lost)


func set_power(on: bool) -> void:
	if power_on == on:
		return
	power_on = on
	power_state_changed.emit(power_on)


func finish_night(victory: bool) -> void:
	if phase == PHASE_NIGHT_END or phase == PHASE_GAME_OVER:
		return
	var quota_met: bool = (money >= quota) or (game_mode == MODE_ENDLESS)
	var final_victory: bool = victory and strikes < max_strikes and quota_met
	if final_victory:
		phase = PHASE_NIGHT_END
		if game_mode == MODE_CAMPAIGN:
			if current_night >= SaveSystem.best_night:
				SaveSystem.best_night = mini(5, current_night + 1)
			if current_night >= 5:
				SaveSystem.endless_unlocked = true
			SaveSystem.save_data()
	else:
		phase = PHASE_GAME_OVER
		if game_mode == MODE_ENDLESS and endless_customers_cleared > SaveSystem.endless_best_score:
			SaveSystem.endless_best_score = endless_customers_cleared
			SaveSystem.save_data()

	var summary: Dictionary = {
		"night": current_night,
		"victory": final_victory,
		"money": money,
		"quota": quota,
		"quota_met": quota_met,
		"strikes": strikes,
		"served": served_correct,
		"denied": denied_anomalies,
		"tips": tips_earned,
		"endless": game_mode == MODE_ENDLESS,
		"endless_cleared": endless_customers_cleared,
	}
	night_ended.emit(final_victory, summary)
