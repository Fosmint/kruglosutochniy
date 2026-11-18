shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float rain_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.03, 0.05, 0.07, 0.22);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV * vec2(10.0, 4.0);
	float t = TIME * 1.4;
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float rnd = hash21(cell);
	float y_drop = fract(t * (0.5 + rnd * 0.5) + rnd) - 0.5;
	float d = length(vec2(f.x * 1.8, (f.y + y_drop) * 0.6));
	float drop = smoothstep(0.16, 0.04, d) * rain_amount;
	float streak = smoothstep(0.08, 0.01, abs(f.x)) * smoothstep(0.5, -0.5, f.y + y_drop) * 0.25 * rain_amount;

	ALBEDO = tint_color.rgb + vec3(0.45, 0.58, 0.68) * (drop + streak);
	ALPHA = clamp(tint_color.a + (drop + streak) * 0.45, 0.14, 0.78);
}
