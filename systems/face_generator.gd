class_name FaceGenerator
extends RefCounted

## Процедурный генератор текстур лиц в рантайме через Image (96x96).
## Используется и на 3D face plate покупателя, и на фото в мини-игре «Документ».

const SIZE: int = 96


static func generate_face_texture(params: Dictionary) -> ImageTexture:
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var seed_val: int = int(params.get("seed", 1))
	var skin: Color = params.get("skin", Color(0.84, 0.69, 0.58))
	var iris: Color = params.get("iris", Color(0.24, 0.36, 0.45))
	var brow: Color = params.get("brow", Color(0.18, 0.13, 0.10))
	var big_pupils: bool = bool(params.get("big_pupils", false))
	var uv_glow_eyes: bool = bool(params.get("uv_glow_eyes", false))
	var wide_smile: bool = bool(params.get("wide_smile", false))
	var red_eyes: bool = bool(params.get("red_eyes", false))
	var freckles: bool = bool(params.get("freckles", false))
	var wrinkles: bool = bool(params.get("wrinkles", false))
	var for_id_card: bool = bool(params.get("for_id_card", false))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val * 7919 + 17

	var cx: float = float(SIZE) * 0.5
	var cy: float = float(SIZE) * 0.5

	for y in range(SIZE):
		for x in range(SIZE):
			var nx: float = (float(x) - cx) / (float(SIZE) * 0.46)
			var ny: float = (float(y) - cy) / (float(SIZE) * 0.48)
			var oval: float = nx * nx + ny * ny
			if not for_id_card and oval > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var alpha: float = 1.0
			if not for_id_card:
				alpha = clampf((1.0 - oval) * 4.5, 0.0, 1.0)
			elif oval > 0.92:
				## Фон для фото на документе
				img.set_pixel(x, y, Color(0.76, 0.80, 0.82, 1.0))
				continue

			var n_val: float = (rng.randf() - 0.5) * 0.055
			var shade: float = clampf(1.0 - oval * 0.18, 0.72, 1.05)
			var c: Color = Color(
				clampf(skin.r * shade + n_val, 0.0, 1.0),
				clampf(skin.g * shade + n_val, 0.0, 1.0),
				clampf(skin.b * shade + n_val, 0.0, 1.0),
				alpha
			)
			img.set_pixel(x, y, c)

	## Веснушки
	if freckles:
		for _i in range(28):
			var fx: int = rng.randi_range(24, 72)
			var fy: int = rng.randi_range(46, 62)
			_blend_pixel(img, fx, fy, skin.darkened(0.28), 0.65)

	## Морщины
	if wrinkles:
		for wx in range(30, 66):
			_blend_pixel(img, wx, 24, skin.darkened(0.24), 0.55)
			_blend_pixel(img, wx, 28, skin.darkened(0.20), 0.45)

	## Тень носа
	for ny_i in range(42, 60):
		var w: int = 2 if ny_i < 54 else 5
		for nx_i in range(48 - w, 48 + w):
			_blend_pixel(img, nx_i, ny_i, skin.darkened(0.22), 0.45)

	## Брови
	var brow_y: int = 33
	for bx in range(24, 42):
		for dy in range(-2, 2):
			_blend_pixel(img, bx, brow_y + dy, brow, 0.85)
	for bx in range(54, 72):
		for dy in range(-2, 2):
			_blend_pixel(img, bx, brow_y + dy, brow, 0.85)

	## Глаза
	_draw_eye(img, 33, 43, iris, big_pupils, uv_glow_eyes, red_eyes)
	_draw_eye(img, 63, 43, iris, big_pupils, uv_glow_eyes, red_eyes)

	## Рот (обычный или аномально широкая улыбка с двойным рядом зубов)
	if wide_smile:
		for mx in range(18, 78):
			var curve: float = pow((float(mx) - 48.0) / 30.0, 2.0) * 9.0
			var my_center: int = int(73.0 - curve)
			for dy in range(-6, 7):
				var py: int = my_center + dy
				if abs(dy) >= 5:
					_blend_pixel(img, mx, py, Color(0.28, 0.05, 0.06), 0.95)
				elif dy == 0:
					_blend_pixel(img, mx, py, Color(0.05, 0.02, 0.02), 1.0)
				else:
					## Двойной ряд зубов (верхний + нижний разделены тёмной линией и полосками)
					var tooth_gap: bool = (mx % 5 == 0) or (abs(dy) == 3)
					var tc: Color = Color(0.12, 0.04, 0.04) if tooth_gap else Color(0.92, 0.90, 0.80)
					_blend_pixel(img, mx, py, tc, 0.96)
	else:
		for mx in range(36, 60):
			var curve: float = pow((float(mx) - 48.0) / 14.0, 2.0) * 2.0
			var my_c: int = int(71.0 - curve)
			for dy in range(-2, 3):
				var lip_col: Color = skin.darkened(0.32) if dy != 0 else Color(0.24, 0.12, 0.12)
				_blend_pixel(img, mx, my_c + dy, lip_col, 0.88)

	return ImageTexture.create_from_image(img)


static func _draw_eye(img: Image, ex: int, ey: int, iris: Color, big_pupils: bool, uv_glow: bool, red_eyes: bool) -> void:
	var sclera: Color = Color(0.94, 0.82, 0.82) if red_eyes else Color(0.92, 0.91, 0.88)
	for dy in range(-6, 7):
		for dx in range(-9, 10):
			var e_dist: float = (float(dx) * float(dx)) / 81.0 + (float(dy) * float(dy)) / 32.0
			if e_dist > 1.0:
				continue
			var r: float = sqrt(float(dx * dx + dy * dy))
			var col: Color = sclera
			var iris_r: float = 5.6 if big_pupils else 4.2
			var pupil_r: float = 4.6 if big_pupils else 2.2
			if r <= pupil_r:
				col = Color(0.25, 0.98, 0.85) if uv_glow else Color(0.03, 0.03, 0.04)
			elif r <= iris_r:
				col = Color(0.15, 0.72, 0.65) if uv_glow else iris
			elif dy == -5 or dy == 5:
				col = Color(0.15, 0.10, 0.10)
			_blend_pixel(img, ex + dx, ey + dy, col, 1.0)


static func _blend_pixel(img: Image, x: int, y: int, col: Color, weight: float) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	var dst: Color = img.get_pixel(x, y)
	if dst.a <= 0.01:
		return
	var out: Color = dst.lerp(col, weight)
	out.a = dst.a
	img.set_pixel(x, y, out)
