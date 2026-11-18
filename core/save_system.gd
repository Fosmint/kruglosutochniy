extends Node

## Autoload SaveSystem (без class_name, чтобы не конфликтовать с синглтоном)
const SAVE_PATH: String = "user://nightshift_save.cfg"

var best_night: int = 1
var endless_unlocked: bool = false
var endless_best_score: int = 0

## Настройки графики и звука
## vhs_level: 0 = Низкая, 1 = Средняя, 2 = Высокая
var vhs_level: int = 1
var vol_master: float = 0.85
var vol_sfx: float = 0.90
var vol_ambience: float = 0.75
var vol_voice: float = 0.95
var look_sensitivity: float = 0.0045

## Улучшения между ночами (уровни 0..3)
var upg_flashlight: int = 0
var upg_cctv_fov: int = 0
var upg_cheap_alarm: int = 0


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		return
	best_night = int(cfg.get_value("progress", "best_night", 1))
	endless_unlocked = bool(cfg.get_value("progress", "endless_unlocked", false))
	endless_best_score = int(cfg.get_value("progress", "endless_best_score", 0))

	vhs_level = clampi(int(cfg.get_value("settings", "vhs_level", 1)), 0, 2)
	vol_master = clampf(float(cfg.get_value("settings", "vol_master", 0.85)), 0.0, 1.0)
	vol_sfx = clampf(float(cfg.get_value("settings", "vol_sfx", 0.90)), 0.0, 1.0)
	vol_ambience = clampf(float(cfg.get_value("settings", "vol_ambience", 0.75)), 0.0, 1.0)
	vol_voice = clampf(float(cfg.get_value("settings", "vol_voice", 0.95)), 0.0, 1.0)
	look_sensitivity = clampf(float(cfg.get_value("settings", "look_sensitivity", 0.0045)), 0.001, 0.012)

	upg_flashlight = clampi(int(cfg.get_value("upgrades", "flashlight", 0)), 0, 3)
	upg_cctv_fov = clampi(int(cfg.get_value("upgrades", "cctv_fov", 0)), 0, 3)
	upg_cheap_alarm = clampi(int(cfg.get_value("upgrades", "cheap_alarm", 0)), 0, 3)


func save_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("progress", "best_night", best_night)
	cfg.set_value("progress", "endless_unlocked", endless_unlocked)
	cfg.set_value("progress", "endless_best_score", endless_best_score)

	cfg.set_value("settings", "vhs_level", vhs_level)
	cfg.set_value("settings", "vol_master", vol_master)
	cfg.set_value("settings", "vol_sfx", vol_sfx)
	cfg.set_value("settings", "vol_ambience", vol_ambience)
	cfg.set_value("settings", "vol_voice", vol_voice)
	cfg.set_value("settings", "look_sensitivity", look_sensitivity)

	cfg.set_value("upgrades", "flashlight", upg_flashlight)
	cfg.set_value("upgrades", "cctv_fov", upg_cctv_fov)
	cfg.set_value("upgrades", "cheap_alarm", upg_cheap_alarm)
	cfg.save(SAVE_PATH)


func reset_campaign_upgrades() -> void:
	upg_flashlight = 0
	upg_cctv_fov = 0
	upg_cheap_alarm = 0
	save_data()
