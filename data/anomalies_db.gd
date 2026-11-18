class_name AnomaliesDB
extends RefCounted

## Data-driven каталог всех 13 аномалий и безобидных чудаков

const ALL_ANOMALIES: Array[Dictionary] = [
	{
		"id": "no_reflection",
		"name": "Нет отражения",
		"clue": "Не отображается на мониторе CCTV и в выпуклом зеркале в углу.",
		"tool": "CCTV / Зеркало",
		"min_night": 1,
		"weight": 12,
	},
	{
		"id": "no_shadow",
		"name": "Нет тени",
		"clue": "Под ногами отсутствует тень на полу (проверьте зону «Ноги»).",
		"tool": "Осмотр (Ноги)",
		"min_night": 2,
		"weight": 10,
	},
	{
		"id": "uv_pupils",
		"name": "Светящиеся зрачки",
		"clue": "Слишком большие чёрные зрачки, ярко светятся под УФ-фонариком.",
		"tool": "УФ-фонарик + Осмотр (Лицо)",
		"min_night": 1,
		"weight": 10,
	},
	{
		"id": "extra_fingers",
		"name": "Лишние пальцы",
		"clue": "На кисти 6 пальцев или неестественно вытянутые фаланги (зона «Руки»).",
		"tool": "Осмотр (Руки)",
		"min_night": 2,
		"weight": 10,
	},
	{
		"id": "wide_smile",
		"name": "Широкая улыбка / двойные зубы",
		"clue": "Рот растянут до ушей с двойным рядом зубов (зона «Лицо»).",
		"tool": "Осмотр (Лицо)",
		"min_night": 1,
		"weight": 10,
	},
	{
		"id": "too_tall",
		"name": "Слишком высокий",
		"clue": "Неестественный рост — пригибается под потолком магазина.",
		"tool": "Визуально / Осмотр",
		"min_night": 4,
		"weight": 9,
	},
	{
		"id": "cctv_doppelganger",
		"name": "Двойник на камере",
		"clue": "На мониторе CCTV виден искажённый чёрный силуэт вместо покупателя.",
		"tool": "CCTV",
		"min_night": 4,
		"weight": 10,
	},
	{
		"id": "fake_document",
		"name": "Поддельный документ",
		"clue": "Несовпадение лица, глаз, возраста или просроченный паспорт в проверке ID.",
		"tool": "Проверка документа",
		"min_night": 3,
		"weight": 11,
	},
	{
		"id": "strange_payment",
		"name": "Странная оплата",
		"clue": "Ржавые монеты нестандартного номинала, листья или влажные купюры с УФ-метками.",
		"tool": "УФ-фонарик / Касса",
		"min_night": 3,
		"weight": 11,
	},
	{
		"id": "no_breathing",
		"name": "Не дышит",
		"clue": "Грудная клетка абсолютно неподвижна — нет анимации вдоха.",
		"tool": "Осмотр (Тело / Лицо)",
		"min_night": 4,
		"weight": 9,
	},
	{
		"id": "desync_speech",
		"name": "Рассинхрон речи",
		"clue": "Повторяет бессвязные фразы, бормотание идёт вразнобой с субтитрами.",
		"tool": "Слух + Субтитры",
		"min_night": 2,
		"weight": 9,
	},
	{
		"id": "weather_mismatch",
		"name": "Не по погоде",
		"clue": "На улице дождь, а одежда абсолютно сухая (или наоборот — мокрый в ясную ночь).",
		"tool": "Окно двери + Осмотр",
		"min_night": 3,
		"weight": 10,
	},
	{
		"id": "aggressive",
		"name": "Агрессивный",
		"clue": "После отказа не уходит и надвигается. Жмите ТРЕВОГУ или держите свет выключенным 3 с!",
		"tool": "Тревога / Выключатель света",
		"min_night": 4,
		"weight": 8,
	},
]

const HARMLESS_WEIRDOS: Array[Dictionary] = [
	{
		"id": "dino_suit",
		"name": "Парень в костюме динозавра",
		"desc": "Зелёный надувной костюм динозавра. Странный, но живой человек.",
	},
	{
		"id": "drunk",
		"name": "Подвыпивший дальнобойщик",
		"desc": "Шатается и бубнит, но все признаки человека в норме.",
	},
	{
		"id": "babushka_curlers",
		"name": "Бабушка в бигуди",
		"desc": "Пришла за молоком и солью в три ночи в халате и бигуди.",
	},
	{
		"id": "courier",
		"name": "Ночной курьер",
		"desc": "В жёлтой куртке и кепке, вечно торопится.",
	},
	{
		"id": "student_energy",
		"name": "Студент с энергетиками",
		"desc": "Трясётся от кофеина, красные глаза, но это не УФ-свечение.",
	},
]


static func get_available_for_night(night_num: int, endless: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var eff_night: int = 5 if endless else night_num
	for item: Dictionary in ALL_ANOMALIES:
		if int(item["min_night"]) <= eff_night:
			out.append(item)
	return out


static func pick_weighted_anomaly(night_num: int, endless: bool, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = get_available_for_night(night_num, endless)
	## В ночь 1 гарантируем приоритет базовых улик, включая «нет отражения»
	if night_num == 1 and not endless and rng.randf() < 0.5:
		return ALL_ANOMALIES[0]
	var total_w: int = 0
	for item: Dictionary in pool:
		total_w += int(item["weight"])
	var roll: int = rng.randi_range(0, maxi(0, total_w - 1))
	var acc: int = 0
	for item: Dictionary in pool:
		acc += int(item["weight"])
		if roll < acc:
			return item
	return pool[0]


static func get_by_id(anom_id: String) -> Dictionary:
	for item: Dictionary in ALL_ANOMALIES:
		if str(item["id"]) == anom_id:
			return item
	return {}
