shader_type canvas_item;
// Draws the whole terrain in one pass on the GPU.
//
// The map arrives as two tiny textures instead of thousands of squares:
//   tile_data  one pixel per tile; red channel = index into the palette
//   palette    one column per tile type; row 0 = color, row 1 = (style, priority)
//
// Per pixel the shader works out which tile it is in, paints that tile's style
// (grass, water, stone...), lets higher-priority neighbors bleed over the border
// with a ragged soft edge, and finally draws tree canopies on forest tiles.
// Everything is procedural noise, so there are no art files yet.

uniform sampler2D tile_data : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform ivec2 map_size = ivec2(1, 1);
uniform float tile_px = 32.0;
uniform vec3 foliage_tint = vec3(1.0);   // season color applied to grass, forest and leaves
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;  // fades fine texture when zoomed out

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

// --- noise ---------------------------------------------------------------------

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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

// --- map lookups -----------------------------------------------------------------

int tile_index(ivec2 c) {
	c = clamp(c, ivec2(0), map_size - ivec2(1));
	return int(round(texelFetch(tile_data, c, 0).r * 255.0));
}

vec3 tile_color(int idx) {
	return texelFetch(palette, ivec2(idx, 0), 0).rgb;
}

int tile_style(int idx) {
	return int(round(texelFetch(palette, ivec2(idx, 1), 0).r * 255.0));
}

float tile_priority(int idx) {
	return texelFetch(palette, ivec2(idx, 1), 0).g * 255.0;
}

// --- surfaces --------------------------------------------------------------------
// Styles: 0 flat, 1 grass, 2 dirt, 3 water, 4 stone, 5 forest ground

float snow_cover(vec2 p, float amount) {
	return clamp(snow * amount * smoothstep(0.30, 0.58, fbm(p * 0.8 + 11.0) + 0.3 * snow), 0.0, 1.0);
}

vec3 terrain(int style, vec3 base, vec2 p) {
	vec3 snow_color = vec3(0.92, 0.95, 1.0) * (0.9 + 0.1 * vnoise(p * 3.0));
	vec3 col = base;
	if (style == 1) {
		float n = fbm(p * 1.7);
		col = base * (0.80 + 0.40 * n);
		col *= 0.94 + 0.12 * vnoise(p * 6.0);
		float blades = vnoise(p * 28.0);
		col *= 1.0 + detail * (step(0.80, blades) * 0.16 - step(blades, 0.16) * 0.14);
		col *= foliage_tint;
		col = mix(col, snow_color, snow_cover(p, 1.0));
	} else if (style == 2) {
		col = base * (0.82 + 0.36 * fbm(p * 2.2));
		float pebble = vnoise(p * 20.0);
		col *= 1.0 + detail * (step(0.87, pebble) * 0.18 - step(pebble, 0.10) * 0.16);
		col = mix(col, snow_color, snow_cover(p, 0.45));
	} else if (style == 3) {
		vec2 q = p + vec2(sin(p.y * 1.6 + TIME * 0.5), cos(p.x * 1.5 + TIME * 0.45)) * 0.18;
		float w = fbm(q * 1.8 + vec2(TIME * 0.03, -TIME * 0.02));
		col = base * (0.72 + 0.56 * w);  // slow patches of deeper and shallower water
		// Thin wave crests that drift slowly across the surface.
		float crest = sin((q.x * 1.3 + q.y * 2.1 + fbm(q * 1.5) * 3.0) * 3.0 + TIME * 0.8) * 0.5 + 0.5;
		col += vec3(0.06, 0.09, 0.11) * smoothstep(0.82, 0.97, crest) * detail;
	} else if (style == 4) {
		col = base * (0.72 + 0.56 * fbm(p * 2.0));
		float crack = abs(fbm(p * 2.4 + 5.0) - 0.5);
		col *= mix(0.74, 1.0, smoothstep(0.0, 0.03, crack));
		col *= 1.0 + detail * (vnoise(p * 22.0) - 0.5) * 0.16;
		col = mix(col, snow_color, snow_cover(p, 0.35));
	} else if (style == 5) {
		col = base * 0.62 * (0.75 + 0.5 * fbm(p * 2.4));
		col *= foliage_tint;
		col = mix(col, snow_color, snow_cover(p, 0.7));
	}
	return col;
}

void fragment() {
	vec2 p = world_pos / tile_px;  // position in tile units

	// Warp the lookup a little so borders between tile types wander instead of running straight.
	vec2 warp = (vec2(fbm(p * 3.1), fbm(p * 3.1 + 17.3)) - 0.5) * 0.45;
	vec2 pw = p + warp;
	ivec2 tc = ivec2(floor(pw));

	int idx = tile_index(tc);
	int style = tile_style(idx);
	float prio = tile_priority(idx);
	vec3 col = terrain(style, tile_color(idx), p);

	// Neighbors with a higher priority bleed over this tile's edge with a ragged soft border.
	float edge_width = 0.12 + 0.28 * vnoise(p * 5.0 + 3.0);
	float foam = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			ivec2 nc = tc + ivec2(dx, dy);
			int nidx = tile_index(nc);
			if (nidx == idx) {
				continue;
			}
			float d = length(max(abs(pw - (vec2(nc) + 0.5)) - 0.5, 0.0));
			float nprio = tile_priority(nidx);
			int nstyle = tile_style(nidx);
			if (nprio > prio) {
				float infl = 1.0 - smoothstep(0.0, edge_width, d);
				if (infl > 0.0) {
					col = mix(col, terrain(nstyle, tile_color(nidx), p), infl);
					if (style == 3) {
						foam = max(foam, smoothstep(0.2, 0.5, infl) * (1.0 - smoothstep(0.5, 0.8, infl)));
					}
				}
			} else if (style == 4 && nstyle != 4) {
				col *= 1.0 - 0.38 * (1.0 - smoothstep(0.0, 0.10, d));  // dark rim along cliff edges
			}
		}
	}
	col = mix(col, vec3(0.86, 0.94, 1.0), foam * 0.4 * detail);

	// Trees: every forest tile near this pixel gets one canopy, drawn over the ground.
	ivec2 pc = ivec2(floor(p));
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 nc = pc + ivec2(dx, dy);
			int nidx = tile_index(nc);
			if (tile_style(nidx) != 5) {
				continue;
			}
			vec2 id = vec2(nc);
			vec2 c = id + 0.5 + (vec2(hash21(id + 1.7), hash21(id + 9.1)) - 0.5) * 0.42;
			float r = 0.40 + 0.14 * hash21(id + 3.3);
			float sd = length(p - (c + vec2(0.09, 0.13))) / r;
			col *= 1.0 - 0.38 * (1.0 - smoothstep(0.55, 1.05, sd));
		}
	}
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 nc = pc + ivec2(dx, dy);
			int nidx = tile_index(nc);
			if (tile_style(nidx) != 5) {
				continue;
			}
			vec2 id = vec2(nc);
			vec2 c = id + 0.5 + (vec2(hash21(id + 1.7), hash21(id + 9.1)) - 0.5) * 0.42;
			float r = 0.40 + 0.14 * hash21(id + 3.3);
			vec2 q = (p - c) / r;
			float d = length(q);
			if (d < 1.0) {
				float light = clamp(0.55 - 0.45 * dot(q, normalize(vec2(0.6, 0.8))), 0.0, 1.0);
				float leaf = vnoise(p * 15.0 + id);
				vec3 leaf_col = tile_color(nidx) * (0.85 + 0.75 * light) * (0.94 + 0.16 * leaf * detail);
				leaf_col *= foliage_tint;
				leaf_col = mix(leaf_col, vec3(0.95, 0.97, 1.0), snow * 0.55 * smoothstep(0.35, 0.65, vnoise(p * 7.0 + id)));
				leaf_col *= 1.0 - 0.40 * smoothstep(0.76, 1.0, d);
				col = mix(col, leaf_col, 1.0 - smoothstep(0.94, 1.0, d));
			}
		}
	}

	COLOR = vec4(col, 1.0);
}
