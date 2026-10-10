shader_type canvas_item;
// Draws the whole terrain in one pass on the GPU, in a gritty hand-painted style
// (think RimWorld): muted earthy colors, grain, grass tufts, oak and pine trees,
// hard-edged rock with a bevel and a cast shadow, shallow-to-deep water.
//
// The map arrives as two tiny textures instead of thousands of squares:
//   tile_data  one pixel per tile; red channel = index into the palette
//   palette    one column per tile type; row 0 = color, row 1 = (style, priority)
//
// Per pixel the shader works out which tile it is in, paints that tile's style,
// lets higher-priority neighbors bleed over the border (soft for ground, crisp for
// rock), and finally draws tree canopies on forest tiles. Light comes from the
// top-left. Everything is procedural noise, so there are no art files yet.

uniform sampler2D tile_data : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform ivec2 map_size = ivec2(1, 1);
uniform float tile_px = 32.0;
uniform vec3 foliage_tint = vec3(1.0);   // season color applied to grass, forest and leaves
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;  // fades fine texture when zoomed out

const vec2 LIGHT_DIR = vec2(-0.7071, -0.7071);  // points toward the light (top-left)

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

// --- surface details ---------------------------------------------------------------

// Plates of broken rock: x = random shade per plate, y = distance to the nearest crack.
vec2 rock(vec2 p) {
	vec2 g = p * 1.15;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float f1 = 8.0;
	float f2 = 8.0;
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 cell = gi + o;
			vec2 pt = o + vec2(hash21(cell + 2.3), hash21(cell + 8.1)) * 0.8 + 0.1;
			float d = length(pt - gf);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				shade = hash21(cell + 5.0);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(shade, f2 - f1);
}

// One small tuft of grass blades per half-tile cell, some cells empty.
// Returns x = blade highlight, y = dark root spot.
vec2 tufts(vec2 p) {
	vec2 cell = floor(p * 2.0);
	float h = hash21(cell + 4.4);
	if (h > 0.42) {
		return vec2(0.0);
	}
	vec2 c = (cell + 0.5 + (vec2(hash21(cell + 1.3), hash21(cell + 6.6)) - 0.5) * 0.35) * 0.5;
	vec2 d = p - c;
	float a = atan(d.y, d.x);
	float r = length(d);
	float reach = 0.04 + 0.095 * pow(abs(sin(a * 3.0 + h * 40.0)), 3.0);
	float light = 1.0 - smoothstep(reach - 0.014, reach, r);
	float root = 1.0 - smoothstep(0.016, 0.028, r);
	return vec2(light, root);
}

// Loose pebbles on bare ground: shaded lumps, lit from the top-left.
vec3 pebbles(vec2 p, vec3 col) {
	vec2 cell = floor(p * 3.0);
	float h = hash21(cell + 9.9);
	if (h > 0.30) {
		return col;
	}
	vec2 c = (cell + 0.5 + (vec2(hash21(cell + 2.2), hash21(cell + 5.5)) - 0.5) * 0.4) / 3.0;
	vec2 d = (p - c) * 3.0 * vec2(1.0, 1.25);
	float e = length(d);
	if (e > 0.24) {
		return col;
	}
	float lit = 0.5 + 0.5 * dot(normalize(d + 0.0001), LIGHT_DIR) * (e / 0.24 + 0.2);
	vec3 stone = vec3(0.55, 0.52, 0.48) * (0.7 + 0.6 * lit);
	return mix(col, stone, 1.0 - smoothstep(0.20, 0.24, e));
}

float snow_cover(vec2 p, float amount) {
	return clamp(snow * amount * smoothstep(0.30, 0.58, fbm(p * 0.8 + 11.0) + 0.3 * snow), 0.0, 1.0);
}

// --- surfaces --------------------------------------------------------------------
// Styles: 0 flat, 1 grass, 2 dirt, 3 water, 4 stone, 5 forest ground
// depth: 0 at the shore to 1 in open water (only used by water).

vec3 terrain(int style, vec3 base, vec2 p, float depth) {
	vec3 snow_color = vec3(0.90, 0.93, 0.96) * (0.92 + 0.08 * vnoise(p * 3.0));
	vec3 col = base;
	float grain = hash21(floor(world_pos / (tile_px / 16.0))) - 0.5;  // chunky grain, 1/16 of a tile
	if (style == 1) {
		col = base * (0.86 + 0.28 * fbm(p * 1.4));
		col *= 0.93 + 0.14 * vnoise(p * 5.0);
		col *= foliage_tint;
		vec2 t = tufts(p) * detail;
		col = mix(col, base * foliage_tint * vec3(1.22, 1.2, 0.95), t.x * 0.6);
		col = mix(col, base * foliage_tint * 0.62, t.y * 0.7);
		col *= 1.0 + grain * 0.10 * detail;
		col = mix(col, snow_color, snow_cover(p, 1.0));
	} else if (style == 2) {
		col = base * (0.84 + 0.32 * fbm(p * 2.0));
		float speck = vnoise(p * 24.0);
		col *= 1.0 + detail * (step(0.86, speck) * 0.12 - step(speck, 0.12) * 0.14);
		col = pebbles(p, col) * 1.0;
		col *= 1.0 + grain * 0.12 * detail;
		col = mix(col, snow_color, snow_cover(p, 0.45));
	} else if (style == 3) {
		vec3 deep = base * 0.80;
		vec3 shallow = mix(base, vec3(0.40, 0.64, 0.66), 0.65);
		col = mix(shallow, deep, smoothstep(0.0, 1.0, depth));
		vec2 q = p + vec2(sin(p.y * 1.6 + TIME * 0.5), cos(p.x * 1.5 + TIME * 0.45)) * 0.18;
		col *= 0.93 + 0.14 * fbm(q * 1.8 + vec2(TIME * 0.03, -TIME * 0.02));
		float crest = sin((q.x * 1.3 + q.y * 2.1 + fbm(q * 1.5) * 3.0) * 3.0 + TIME * 0.8) * 0.5 + 0.5;
		col += vec3(0.05, 0.07, 0.08) * smoothstep(0.86, 0.98, crest) * detail * (1.0 - 0.5 * depth);
		col *= 1.0 + grain * 0.04 * detail;
	} else if (style == 4) {
		vec2 r = rock(p);
		col = base * (0.80 + 0.34 * r.x);
		col *= 0.80 + 0.40 * fbm(p * 3.2);
		col *= mix(0.74, 1.0, smoothstep(0.0, 0.05, r.y));  // dark cracks between plates
		col *= 1.0 + 0.10 * smoothstep(0.07, 0.16, r.y) * (r.x - 0.5);
		col *= 1.0 + grain * 0.14 * detail;
		col = mix(col, snow_color, snow_cover(p, 0.40));
	} else if (style == 5) {
		col = base * 0.55 * (0.80 + 0.40 * fbm(p * 2.4));
		col *= foliage_tint;
		float litter = vnoise(p * 16.0);
		col *= 1.0 + detail * (step(0.84, litter) * 0.30 - step(litter, 0.14) * 0.22);
		col *= 1.0 + grain * 0.10 * detail;
		col = mix(col, snow_color, snow_cover(p, 0.7));
	}
	return col;
}

// --- trees -----------------------------------------------------------------------
// Every forest tile near a pixel holds one tree: a lobed oak or a spiky pine.

void tree_shape(ivec2 nc, out vec2 center, out float radius, out float pine, out float h) {
	vec2 id = vec2(nc);
	h = hash21(id + 3.3);
	center = id + 0.5 + (vec2(hash21(id + 1.7), hash21(id + 9.1)) - 0.5) * 0.42;
	pine = step(0.62, hash21(id + 5.5));
	radius = (0.40 + 0.14 * h) * (1.0 + 0.06 * pine);
}

// Distance to the canopy edge as a fraction of its outline: below 1 is inside.
float tree_outline(vec2 q, float pine, float h) {
	float a = atan(q.y, q.x);
	float lobes;
	if (pine > 0.5) {
		lobes = mix(0.76, 1.0, pow(abs(cos(a * 5.0 + h * 6.28)), 1.3));
	} else {
		lobes = 1.0 + 0.11 * sin(a * 6.0 + h * 6.28) + 0.05 * sin(a * 11.0 + h * 3.0);
	}
	return length(q) / lobes;
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

	// Water gets deeper with the distance from the nearest shore.
	float depth = 1.0;
	if (style == 3) {
		float shore = 1.6;
		for (int dy = -2; dy <= 2; dy++) {
			for (int dx = -2; dx <= 2; dx++) {
				ivec2 nc = tc + ivec2(dx, dy);
				if (tile_style(tile_index(nc)) != 3) {
					shore = min(shore, length(max(abs(pw - (vec2(nc) + 0.5)) - 0.5, 0.0)));
				}
			}
		}
		depth = shore / 1.6;
	}

	vec3 col = terrain(style, tile_color(idx), p, depth);

	// Neighbors with a higher priority bleed over this tile's edge: softly for ground,
	// crisply for rock (which also gets a lit rim and throws a shadow).
	float soft_width = 0.12 + 0.28 * vnoise(p * 5.0 + 3.0);
	float rock_width = 0.035 + 0.07 * vnoise(p * 9.0 + 7.0);
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
			vec2 toward = normalize(vec2(float(dx), float(dy)));
			if (nprio > prio) {
				float w = nstyle == 4 ? rock_width : soft_width;
				float infl = 1.0 - smoothstep(0.0, w, d);
				if (infl > 0.0) {
					vec3 other = terrain(nstyle, tile_color(nidx), p, 1.0);
					if (nstyle == 4) {
						// The rock face turns toward us: lit if it faces the light.
						other *= 1.0 + 0.40 * dot(-toward, LIGHT_DIR);
					}
					col = mix(col, other, infl);
					if (style == 3) {
						foam = max(foam, smoothstep(0.2, 0.5, infl) * (1.0 - smoothstep(0.5, 0.8, infl)));
					}
				}
				if (nstyle == 4) {
					// Rock throws a shadow away from the light.
					float side = max(dot(toward, LIGHT_DIR), 0.0);
					col *= 1.0 - 0.42 * side * (1.0 - smoothstep(0.0, 0.42, d));
				}
			} else if (style == 4 && nstyle != 4) {
				// Bevel along the rim of the rock: bright where it faces the light, dark where it does not.
				float band = 1.0 - smoothstep(0.0, 0.16, d);
				col *= 1.0 + 0.40 * band * dot(toward, LIGHT_DIR);
				col *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.03, d));
			}
		}
	}
	col = mix(col, vec3(0.86, 0.94, 1.0), foam * 0.35 * detail);

	// Trees: shadows first, then the canopies from north to south so southern trees overlap.
	ivec2 pc = ivec2(floor(p));
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 nc = pc + ivec2(dx, dy);
			if (tile_style(tile_index(nc)) != 5) {
				continue;
			}
			vec2 c;
			float r;
			float pine;
			float h;
			tree_shape(nc, c, r, pine, h);
			float sd = length(p - (c + vec2(0.11, 0.14))) / r;
			col *= 1.0 - 0.36 * (1.0 - smoothstep(0.62, 1.02, sd));
		}
	}
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 nc = pc + ivec2(dx, dy);
			int nidx = tile_index(nc);
			if (tile_style(nidx) != 5) {
				continue;
			}
			vec2 c;
			float r;
			float pine;
			float h;
			tree_shape(nc, c, r, pine, h);
			vec2 q = (p - c) / r;
			float d = tree_outline(q, pine, h);
			if (d >= 1.0) {
				continue;
			}
			vec3 leaf = tile_color(nidx);
			float lit = clamp(0.5 + 0.5 * dot(q, LIGHT_DIR), 0.0, 1.0);
			if (pine > 0.5) {
				leaf *= vec3(0.74, 0.98, 0.94);
				leaf *= 0.65 + 0.80 * lit;
				leaf *= 1.0 + 0.40 * (1.0 - smoothstep(0.0, 0.8, d));       // bright tip in the middle
				leaf *= 0.95 + 0.05 * sin(atan(q.y, q.x) * 16.0 + h * 9.0);  // needle streaks
			} else {
				leaf *= vec3(1.10, 1.08, 0.82);
				float clump = vnoise((p - c) * 9.0 + h * 20.0);               // leaf clusters
				leaf *= 0.62 + 0.75 * lit;
				leaf *= 0.84 + 0.36 * clump * mix(0.4, 1.0, detail);
				leaf *= 1.0 - 0.30 * smoothstep(0.78, 1.0, d);               // dark underside of the rim
			}
			leaf *= foliage_tint;
			leaf = mix(leaf, vec3(0.92, 0.95, 0.98), snow * 0.55 * smoothstep(0.35, 0.65, vnoise(p * 7.0 + vec2(nc))));
			col = mix(col, leaf, 1.0 - smoothstep(0.93, 1.0, d));
		}
	}

	COLOR = vec4(col, 1.0);
}
