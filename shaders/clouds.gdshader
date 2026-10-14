shader_type canvas_item;
render_mode unshaded;
// Shadows of clouds passing over the town: billowy noise drifting with the wind, cut off at
// a level set by how cloudy the sky is. Drawn as one rectangle over the whole map.

uniform float tile_px = 48.0;
uniform vec2 drift = vec2(0.0);                         // how far the wind has carried the clouds
uniform float coverage : hint_range(0.0, 1.0) = 0.25;   // share of the sky under cloud
uniform float strength : hint_range(0.0, 1.0) = 0.25;   // darkness of a shadow

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = world_pos / tile_px / 14.0 - drift;              // a cloud is several houses across
	p += 0.35 * vec2(vnoise(p * 1.7 + 3.1), vnoise(p * 1.7 + 8.4));  // warp for soft, billowy edges
	float n = fbm(p);
	float edge = mix(0.68, 0.30, coverage);
	float shade = smoothstep(edge - 0.06, edge + 0.12, n);
	COLOR = vec4(0.02, 0.03, 0.08, shade * strength);
}
