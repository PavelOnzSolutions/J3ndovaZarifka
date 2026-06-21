// Incandescent gas-filled tube light.
//
// Emulates the look of a glowing incandescent / gas-discharge tube:
//   * Warm, filament-like emission colour.
//   * Temporal flicker built from several uncorrelated frequencies plus value
//     noise, so it never reads as a clean sine wave (gas tubes wobble irregularly).
//   * Spatial instability: the glow is not uniform along the tube. Slow-moving
//     hot/cold bands travel along its length, mimicking uneven gas ionisation.
//   * Occasional brief dips ("blink") for that unstable-tube feel.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

// --- Look -------------------------------------------------------------------
uniform vec3 base_color : source_color = vec3(1.0, 0.82, 0.55); // warm incandescent
uniform vec3 hot_color  : source_color = vec3(1.0, 0.95, 0.85); // brighter hot spots
uniform float emission_strength = 6.0;

// --- Temporal flicker -------------------------------------------------------
uniform float flicker_speed  = 11.0;   // base flicker frequency
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.18;
uniform float blink_chance   : hint_range(0.0, 1.0) = 0.04; // brief deep dips

// --- Spatial instability ----------------------------------------------------
uniform float instability : hint_range(0.0, 1.0) = 0.45; // how uneven along length
uniform float band_scale = 5.0;   // number of glow bands along the tube
uniform float band_speed = 0.9;   // how fast bands drift

// 1D hash + value noise -------------------------------------------------------
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

void fragment() {
	float t = TIME;

	// --- Temporal flicker: stack a few incommensurate frequencies + noise ---
	float f1 = sin(t * flicker_speed);
	float f2 = sin(t * flicker_speed * 2.73 + 1.3);
	float f3 = sin(t * flicker_speed * 0.41 + 4.1);
	float n  = vnoise(t * flicker_speed * 0.7) * 2.0 - 1.0;

	float wobble = 0.45 * f1 + 0.20 * f2 + 0.15 * f3 + 0.55 * n;
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * wobble);

	// Occasional brief deep dip (an unstable-tube "blink").
	float blink_seed = vnoise(t * 6.0);
	float blink = smoothstep(1.0 - blink_chance, 1.0, blink_seed);
	flicker *= 1.0 - 0.6 * blink;

	// --- Spatial instability along the tube length (UV.x) -------------------
	// Two drifting noise fields so bands don't repeat predictably.
	float bands = vnoise(UV.x * band_scale - t * band_speed);
	bands = mix(bands, vnoise(UV.x * band_scale * 1.9 + t * band_speed * 0.6), 0.5);
	float spatial = mix(1.0, bands, instability);

	// Hotter where the glow is locally stronger.
	float heat = clamp(spatial * flicker, 0.0, 1.5);
	vec3 col = mix(base_color, hot_color, smoothstep(0.6, 1.2, heat));

	float glow = emission_strength * flicker * spatial;

	ALBEDO = col;
	EMISSION = col * glow;
}
