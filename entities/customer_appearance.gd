class_name CustomerAppearance
extends RefCounted

## Детерминированная генерация внешности, одежды, аксессуаров и ID-документа из seed

const FIRST_NAMES: Array[String] = [
	"Алексей", "Дмитрий", "Сергей", "Иван", "Андрей",
	"Елена", "Ольга", "Наталья", "Татьяна", "Виктор",
	"Николай", "Марина", "Павел", "Светлана", "Олег",
]

const LAST_NAMES: Array[String] = [
	"Иванов", "Петров", "Сидоров", "Козлов", "Морозов",
	"Волков", "Соколов", "Новиков", "Фёдоров", "Орлов",
	"Белов", "Смирнов", "Кузнецов", "Попов", "Громов",
]

const SKIN_TONES: Array[Color] = [
	Color(0.88, 0.74, 0.64),
	Color(0.82, 0.66, 0.54),
	Color(0.74, 0.57, 0.45),
	Color(0.91, 0.80, 0.72),
	Color(0.64, 0.48, 0.38),
]

const HAIR_COLORS: Array[Color] = [
	Color(0.12, 0.10, 0.09),
	Color(0.28, 0.18, 0.12),
	Color(0.55, 0.42, 0.24),
	Color(0.45, 0.46, 0.48),
	Color(0.38, 0.16, 0.10),
]

const IRIS_COLORS: Array[Color] = [
	Color(0.22, 0.40, 0.58),
	Color(0.26, 0.44, 0.28),
	Color(0.36, 0.24, 0.14),
	Color(0.35, 0.38, 0.42),
]

const CLOTH_COLORS: Array[Color] = [
	Color(0.22, 0.28, 0.36),
	Color(0.42, 0.22, 0.20),
	Color(0.24, 0.34, 0.25),
	Color(0.38, 0.34, 0.24),
	Color(0.28, 0.24, 0.32),
	Color(0.48, 0.45, 0.40),
]

var seed_val: int = 1
var full_name: String = ""
var skin_color: Color = Color.WHITE
var hair_color: Color = Color.BLACK
var iris_color: Color = Color.BLUE
var cloth_color: Color = Color.GRAY
var cloth_pattern: int = 0
var pants_color: Color = Color(0.16, 0.18, 0.22)
var voice_pitch: float = 1.0

var has_cap: bool = false
var has_glasses: bool = false
var has_scarf: bool = false
var freckles: bool = false
var wrinkles: bool = false

## Признаки состояния/аномалий
var is_anomaly: bool = false
var anomaly_id: String = ""
var weirdo_id: String = ""
var is_wet: bool = false
var finger_count: int = 5
var long_fingers: bool = false
var height_scale: float = 1.0
var crouch_under_ceiling: bool = false
var has_shadow: bool = true
var visible_in_mirror_cctv: bool = true
var has_doppelganger: bool = false
var breathes: bool = true
var desync_speech: bool = false
var is_aggressive: bool = false
var strange_payment: bool = false
var fake_document: bool = false

## Параметры ID-документа
var doc_name: String = ""
var doc_birth_year: int = 1974
var doc_birth_str: String = ""
var doc_expiry_str: String = ""
var doc_face_params: Dictionary = {}
var doc_is_valid: bool = true
var doc_defect_reason: String = ""


static func create_from_seed(p_seed: int, p_is_anomaly: bool, p_anomaly_id: String, p_weirdo_id: String, shop_weather: int) -> CustomerAppearance:
	var a: CustomerAppearance = CustomerAppearance.new()
	a.seed_val = p_seed
	a.is_anomaly = p_is_anomaly
	a.anomaly_id = p_anomaly_id
	a.weirdo_id = p_weirdo_id

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = p_seed

	a.full_name = LAST_NAMES[rng.randi() % LAST_NAMES.size()] + " " + FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	a.skin_color = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	a.hair_color = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	a.iris_color = IRIS_COLORS[rng.randi() % IRIS_COLORS.size()]
	a.cloth_color = CLOTH_COLORS[rng.randi() % CLOTH_COLORS.size()]
	a.cloth_pattern = rng.randi() % 3
	a.voice_pitch = rng.randf_range(0.75, 1.35)

	a.has_cap = rng.randf() < 0.30
	a.has_glasses = rng.randf() < 0.25
	a.has_scarf = rng.randf() < 0.35
	a.freckles = rng.randf() < 0.28
	a.wrinkles = rng.randf() < 0.32

	## Чудаки (нормальные люди с заметным образом)
	if p_weirdo_id == "dino_suit":
		a.cloth_color = Color(0.22, 0.62, 0.26)
		a.cloth_pattern = 0
		a.has_cap = false
	elif p_weirdo_id == "babushka_curlers":
		a.hair_color = Color(0.75, 0.76, 0.78)
		a.wrinkles = true
		a.cloth_color = Color(0.55, 0.30, 0.45)
		a.cloth_pattern = 2
	elif p_weirdo_id == "courier":
		a.cloth_color = Color(0.90, 0.76, 0.14)
		a.cloth_pattern = 1
		a.has_cap = true
	elif p_weirdo_id == "student_energy":
		a.cloth_color = Color(0.20, 0.20, 0.24)
		a.cloth_pattern = 0

	## Погода: в дождь нормальные мокрые, в ясную сухие
	a.is_wet = (shop_weather == GameState.WEATHER_RAIN)

	## Применяем конкретную аномалию
	if p_is_anomaly:
		if p_anomaly_id == "no_reflection":
			a.visible_in_mirror_cctv = false
		elif p_anomaly_id == "no_shadow":
			a.has_shadow = false
		elif p_anomaly_id == "extra_fingers":
			if rng.randf() < 0.6:
				a.finger_count = 6
			else:
				a.long_fingers = true
		elif p_anomaly_id == "too_tall":
			a.height_scale = 1.44
			a.crouch_under_ceiling = true
		elif p_anomaly_id == "cctv_doppelganger":
			a.has_doppelganger = true
		elif p_anomaly_id == "fake_document":
			a.fake_document = true
		elif p_anomaly_id == "strange_payment":
			a.strange_payment = true
		elif p_anomaly_id == "no_breathing":
			a.breathes = false
		elif p_anomaly_id == "desync_speech":
			a.desync_speech = true
		elif p_anomaly_id == "weather_mismatch":
			a.is_wet = not a.is_wet
		elif p_anomaly_id == "aggressive":
			a.is_aggressive = true

	a._build_document_data(rng)
	return a


func get_face_params(uv_active: bool, for_id_card: bool = false) -> Dictionary:
	return {
		"seed": seed_val,
		"skin": skin_color,
		"iris": iris_color,
		"brow": hair_color,
		"big_pupils": is_anomaly and anomaly_id == "uv_pupils",
		"uv_glow_eyes": uv_active and is_anomaly and anomaly_id == "uv_pupils" and not for_id_card,
		"wide_smile": is_anomaly and anomaly_id == "wide_smile",
		"red_eyes": weirdo_id == "student_energy",
		"freckles": freckles,
		"wrinkles": wrinkles,
		"for_id_card": for_id_card,
	}


func _build_document_data(rng: RandomNumberGenerator) -> void:
	doc_name = full_name
	var b_day: int = rng.randi_range(1, 28)
	var b_month: int = rng.randi_range(1, 12)
	doc_birth_year = rng.randi_range(1955, 1978)
	var exp_year: int = rng.randi_range(1999, 2004)
	var exp_month: int = rng.randi_range(1, 12)
	doc_face_params = get_face_params(false, true)
	doc_is_valid = true
	doc_defect_reason = ""

	if fake_document:
		doc_is_valid = false
		var defect: int = rng.randi() % 4
		if defect == 0:
			## Возраст < 18 (в 1998 году рождён в 1982–1984)
			doc_birth_year = rng.randi_range(1982, 1984)
			doc_defect_reason = "Возраст меньше 18 лет"
		elif defect == 1:
			## Просрочен (1995–1997)
			exp_year = rng.randi_range(1995, 1997)
			doc_defect_reason = "Документ просрочен"
		elif defect == 2:
			## Чужое фото
			doc_face_params["seed"] = seed_val + 999
			doc_face_params["skin"] = SKIN_TONES[(rng.randi() + 2) % SKIN_TONES.size()]
			doc_face_params["brow"] = HAIR_COLORS[(rng.randi() + 2) % HAIR_COLORS.size()]
			doc_defect_reason = "На фото другой человек"
		else:
			## Другой цвет глаз на фото
			var alt_iris: Color = Color(0.85, 0.25, 0.20) if iris_color.b > 0.3 else Color(0.15, 0.72, 0.88)
			doc_face_params["iris"] = alt_iris
			doc_face_params["big_pupils"] = true
			doc_defect_reason = "Глаза на фото не совпадают"

	doc_birth_str = "%02d.%02d.%04d" % [b_day, b_month, doc_birth_year]
	doc_expiry_str = "%02d.%04d" % [exp_month, exp_year]
