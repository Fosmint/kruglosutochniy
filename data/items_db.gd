class_name ItemsDB
extends RefCounted

## Каталог товаров магазина: обычные, требующие ID (18+), и запрещённые правилами ночи

const NORMAL_ITEMS: Array[Dictionary] = [
	{"id": "chips", "name": "Чипсы «Хруст»", "price": 45, "color": Color(0.85, 0.25, 0.18), "needs_id": false, "banned_min_night": 99},
	{"id": "soda", "name": "Газировка «Кола-98»", "price": 35, "color": Color(0.65, 0.12, 0.14), "needs_id": false, "banned_min_night": 99},
	{"id": "bread", "name": "Батон нарезной", "price": 22, "color": Color(0.76, 0.58, 0.34), "needs_id": false, "banned_min_night": 99},
	{"id": "milk", "name": "Молоко 3.2%", "price": 38, "color": Color(0.86, 0.89, 0.92), "needs_id": false, "banned_min_night": 99},
	{"id": "energy", "name": "Энергетик «Вольт»", "price": 60, "color": Color(0.22, 0.78, 0.32), "needs_id": false, "banned_min_night": 99},
	{"id": "noodles", "name": "Лапша быстрого пригот.", "price": 28, "color": Color(0.9, 0.72, 0.18), "needs_id": false, "banned_min_night": 99},
	{"id": "salt_small", "name": "Соль поваренная 1 кг", "price": 18, "color": Color(0.78, 0.82, 0.88), "needs_id": false, "banned_min_night": 99},
	{"id": "beer", "name": "Пиво «Дорожное» (18+)", "price": 75, "color": Color(0.22, 0.45, 0.20), "needs_id": true, "banned_min_night": 99},
	{"id": "cigarettes", "name": "Сигареты «Дым» (18+)", "price": 65, "color": Color(0.82, 0.78, 0.65), "needs_id": true, "banned_min_night": 99},
]

const STRANGE_ITEMS: Array[Dictionary] = [
	{"id": "salt_5kg", "name": "Соль 5 кг (МЕШОК)", "price": 90, "color": Color(0.72, 0.74, 0.80), "needs_id": false, "banned_min_night": 1, "rule_hint": "Соль > 1 кг НЕ ПРОДАВАТЬ"},
	{"id": "ritual_candle", "name": "Свеча для ритуала", "price": 120, "color": Color(0.18, 0.08, 0.14), "needs_id": false, "banned_min_night": 2, "rule_hint": "Ритуальные свечи НЕ ПРОДАВАТЬ"},
	{"id": "jar_of_shadow", "name": "Банка с тенью", "price": 0, "color": Color(0.08, 0.09, 0.12), "needs_id": false, "banned_min_night": 1, "rule_hint": "«Банку с тенью» СБРАСЫВАТЬ с ленты"},
]


static func build_basket(night_num: int, needs_id_check: bool, include_strange: bool, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var count: int = rng.randi_range(3, 5)
	var basket: Array[Dictionary] = []
	if needs_id_check:
		var id_item: Dictionary = NORMAL_ITEMS[7] if rng.randf() < 0.5 else NORMAL_ITEMS[8]
		basket.append(id_item.duplicate())
	if include_strange:
		var valid_strange: Array[Dictionary] = []
		for si: Dictionary in STRANGE_ITEMS:
			if int(si["banned_min_night"]) <= night_num:
				valid_strange.append(si)
		if valid_strange.size() > 0:
			basket.append(valid_strange[rng.randi() % valid_strange.size()].duplicate())
	while basket.size() < count:
		var idx: int = rng.randi() % 7
		basket.append(NORMAL_ITEMS[idx].duplicate())
	return basket
