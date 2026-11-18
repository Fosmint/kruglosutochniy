shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float vhs_strength : hint_range(0.2, 1.5) = 1.0;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform float signal_lost : hint_range(0.0, 1.0) = 0.0;
uniform float sanity_ratio : hint_range(0.0, 1.0) = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float intensity = vhs_strength * (0.55 + (1.0 - sanity_ratio) * 0.65 + glitch * 1.15);

	// Бегущая полоса tracking
	float track_pos = fract(t * 0.14);
	float track_band = smoothstep(0.06, 0.0, abs(uv.y - track_pos));

	// Горизонтальные сбои ленты
	float line_id = floor(uv.y * 160.0);
	float line_rnd = hash12(vec2(line_id, floor(t * 14.0)));
	float tear = step(0.96 - glitch * 0.14, line_rnd) * (line_rnd - 0.5) * 0.055 * intensity;
	uv.x += tear + track_band * sin(uv.y * 90.0 + t * 25.0) * 0.008 * intensity;

	// Лёгкое горизонтальное размытие (5 сэмплов, без тяжёлых циклов) + автофокус
	float blur_px = (0.0011 * vhs_strength + blur_amount * 0.0045 + track_band * 0.002);
	float ca = (0.0014 + glitch * 0.0055 + track_band * 0.0025) * vhs_strength;

	vec3 col = vec3(0.0);
	for (int i = -2; i <= 2; i++) {
		float fi = float(i);
		vec2 off = vec2(fi * blur_px, 0.0);
		float r = texture(screen_tex, clamp(uv + off + vec2(ca, 0.0), vec2(0.001), vec2(0.999))).r;
		float g = texture(screen_tex, clamp(uv + off, vec2(0.001), vec2(0.999))).g;
		float b = texture(screen_tex, clamp(uv + off - vec2(ca, 0.0), vec2(0.001), vec2(0.999))).b;
		col += vec3(r, g, b);
	}
	col *= 0.2;

	// Плавающая экспозиция дешёвой камеры
	float auto_exp = 1.0 + sin(t * 0.7) * 0.035 + sin(t * 2.1) * 0.02;
	col *= auto_exp;

	// Пониженная насыщенность + зелёно-жёлтая цветокоррекция
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, clamp(0.72 - (1.0 - sanity_ratio) * 0.25, 0.3, 0.85));
	col *= vec3(0.96, 1.03, 0.86);

	// Scanlines
	float scan = sin(uv.y * 420.0) * 0.5 + 0.5;
	col *= 1.0 - (0.09 * vhs_strength) * scan;

	// Зерно / шум
	float grain = hash12(uv * vec2(320.0, 180.0) + vec2(fract(t * 17.3) * 100.0, fract(t * 29.1) * 100.0));
	col += (grain - 0.5) * (0.085 * intensity + track_band * 0.12);

	// Виньетка
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vig_uv, vig_uv) * (0.34 + (1.0 - sanity_ratio) * 0.18);
	col *= clamp(vig, 0.22, 1.0);

	// Кратковременный SIGNAL LOST со статикой при скримере
	if (signal_lost > 0.01) {
		float static_noise = hash12(floor(uv * vec2(180.0, 100.0)) + vec2(t * 61.0, t * 37.0));
		vec3 lost_col = vec3(static_noise * 0.85, static_noise * 0.9, static_noise * 0.82);
		col = mix(col, lost_col, clamp(signal_lost, 0.0, 1.0));
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
