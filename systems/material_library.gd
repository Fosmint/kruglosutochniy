class_name MaterialLibrary
extends RefCounted

## Кеш процедурных материалов (triplanar-шум, одежда, стекло, фейковое AO, УФ-материалы)

static var _cache: Dictionary = {}
static var _noise_tex: NoiseTexture2D = null


static func clear_cache() -> void:
	_cache.clear()
	_noise_tex = null


static func _get_shared_noise() -> NoiseTexture2D:
	if _noise_tex != null:
		return _noise_tex
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	_noise_tex = tex
	return _noise_tex


static func get_triplanar_mat(key: String, color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.albedo_texture = _get_shared_noise()
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.7, 0.7, 0.7)
	_cache[key] = mat
	return mat


static func get_flat_mat(key: String, color: Color, roughness: float = 0.75, emission_energy: float = 0.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	_cache[key] = mat
	return mat


static func get_clothing_mat(seed_val: int, base_color: Color, pattern_type: int, is_wet: bool) -> StandardMaterial3D:
	## pattern_type: 0 = худи (шум), 1 = куртка с полосами, 2 = клетка
	var key: String = "cloth_%d_%d_%s" % [seed_val % 24, pattern_type, "w" if is_wet else "d"]
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var accent: Color = base_color.lightened(0.28) if base_color.get_luminance() < 0.45 else base_color.darkened(0.32)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in range(64):
		for x in range(64):
			var c: Color = base_color
			if pattern_type == 1:
				if (y >= 14 and y <= 20) or (y >= 42 and y <= 46):
					c = accent
			elif pattern_type == 2:
				if ((x / 8) + (y / 8)) % 2 == 0:
					c = base_color.lerp(accent, 0.45)
			var grain: float = (rng.randf() - 0.5) * 0.08
			c = Color(
				clampf(c.r + grain, 0.0, 1.0),
				clampf(c.g + grain, 0.0, 1.0),
				clampf(c.b + grain, 0.0, 1.0),
				1.0
			)
			if is_wet:
				c = c.darkened(0.28)
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.22 if is_wet else 0.88
	mat.metallic = 0.08 if is_wet else 0.0
	_cache[key] = mat
	return mat


static func get_shadow_blob_mat() -> StandardMaterial3D:
	if _cache.has("shadow_blob"):
		return _cache["shadow_blob"] as StandardMaterial3D
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx: float = (float(x) - 31.5) / 31.5
			var dy: float = (float(y) - 31.5) / 31.5
			var dist: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - smoothstep(0.25, 1.0, dist), 0.0, 1.0) * 0.65
			img.set_pixel(x, y, Color(0.02, 0.02, 0.03, a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_cache["shadow_blob"] = mat
	return mat


static func get_hair_mat(color: Color) -> StandardMaterial3D:
	var key: String = "hair_" + color.to_html(false)
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = _get_shared_noise()
	mat.roughness = 0.92
	_cache[key] = mat
	return mat


static func get_shadow_doppelganger_mat() -> StandardMaterial3D:
	if _cache.has("doppelganger"):
		return _cache["doppelganger"] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.03, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache["doppelganger"] = mat
	return mat
