class_name NightsDB
extends RefCounted

## Конфигурация 5 ночей кампании и бесконечного режима

const NIGHTS: Array[Dictionary] = [
	{
		"night": 1,
		"title": "Ночь 1 — Стажировка",
		"quota": 160,
		"weather": 0, # CLEAR
		"spawn_min": 32.0,
		"spawn_max": 48.0,
		"anomaly_chance": 0.38,
		"weirdo_chance": 0.20,
		"blackouts": false,
		"intro_radio": "Алло, стажёр? Смена с 22:00 до 06:00. Прочитай «Книгу правил» на планшете. Если кого-то нет на камере или в зеркале — гони в шею!",
	},
	{
		"night": 2,
		"title": "Ночь 2 — Пальцы и тени",
		"quota": 220,
		"weather": 0, # CLEAR
		"spawn_min": 28.0,
		"spawn_max": 44.0,
		"anomaly_chance": 0.45,
		"weirdo_chance": 0.22,
		"blackouts": false,
		"intro_radio": "Вторая ночь. Теперь смотри ещё и под ноги — нет тени, значит не человек. И считай пальцы на руках. Удачи.",
	},
	{
		"night": 3,
		"title": "Ночь 3 — Ливень на трассе",
		"quota": 280,
		"weather": 1, # RAIN
		"spawn_min": 26.0,
		"spawn_max": 40.0,
		"anomaly_chance": 0.50,
		"weirdo_chance": 0.20,
		"blackouts": false,
		"intro_radio": "На трассе льёт как из ведра. Кто зайдёт абсолютно сухим — сразу отказ! Плюс проверяй паспорта и просвечивай крупные купюры УФ-лампой.",
	},
	{
		"night": 4,
		"title": "Ночь 4 — Кто в мониторе?",
		"quota": 340,
		"weather": 1, # RAIN
		"spawn_min": 25.0,
		"spawn_max": 38.0,
		"anomaly_chance": 0.55,
		"weirdo_chance": 0.18,
		"blackouts": false,
		"intro_radio": "Осторожно, сегодня ходят агрессивные. Если после отказа стоит и пялится — жми ТРЕВОГУ или держи свет выключенным 3 секунды! Следи за дыханием и двойниками на CCTV.",
	},
	{
		"night": 5,
		"title": "Ночь 5 — Последняя смена",
		"quota": 400,
		"weather": 1, # RAIN
		"spawn_min": 24.0,
		"spawn_max": 35.0,
		"anomaly_chance": 0.62,
		"weirdo_chance": 0.18,
		"blackouts": true,
		"intro_radio": "Проводка в подсобке искрит, свет может вырубаться — бегай к щитку. И... не читай последнюю страницу в планшете, понял? Просто отработай до шести.",
	},
]


static func get_night_config(night_num: int, endless: bool) -> Dictionary:
	if endless:
		return {
			"night": night_num,
			"title": "Бесконечная смена",
			"quota": 0,
			"weather": 1 if (night_num % 2 == 1) else 0,
			"spawn_min": 24.0,
			"spawn_max": 36.0,
			"anomaly_chance": 0.55,
			"weirdo_chance": 0.22,
			"blackouts": true,
			"intro_radio": "Бесконечная смена. Все 13 аномалий активны. Держись сколько сможешь!",
		}
	var idx: int = clampi(night_num - 1, 0, NIGHTS.size() - 1)
	return NIGHTS[idx]
