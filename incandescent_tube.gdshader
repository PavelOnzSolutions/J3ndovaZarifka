// Incandescent gas-filled tube light — core + halo in ONE shader.
//
// Attached to a single box mesh (the light's volume). The shader marches the view
// ray through the box and accumulates emission from the distance to the tube's
// centre line:
//   * Near the line   -> a bright, near-white filament core (the "tube").
//   * Further out      -> a coloured halo that fades off quickly through the air.
// So the halo is part of the light shader itself, not a separate object. The box
// is invisible: where there's no glow, the shader contributes nothing.
//
// Temporal flicker + travelling gas bands give the unstable gas-tube feel.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_back;

// --- Look -------------------------------------------------------------------
uniform vec3 halo_color : source_color = vec3(0.6, 0.85, 1.0); // outer glow tint
uniform vec3 core_color : source_color = vec3(0.92, 0.97, 1.0); // hot filament
uniform float intensity = 4.0;          // HDR brightness -> drives bloom
uniform float gain = 2.6;               // overall halo opacity

// --- Geometry of the glow ---------------------------------------------------
uniform float tube_radius = 0.09;       // filament half-thickness
uniform float density_falloff = 11.0;   // higher = halo fades faster with distance
uniform float core_boost = 7.0;         // how much brighter the filament core is
uniform vec3 box_half = vec3(2.85, 0.6, 0.6); // half-size of the box mesh (local)
uniform float seg_half = 2.5;           // half-length of the filament (local X)
uniform int steps : hint_range(8, 64) = 28;

// --- Temporal flicker -------------------------------------------------------
uniform float flicker_speed = 11.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.18;
uniform float blink_chance : hint_range(0.0, 1.0) = 0.04;

// --- Travelling gas bands ---------------------------------------------------
uniform float instability : hint_range(0.0, 1.0) = 0.45;
uniform float band_scale = 5.0;
uniform float band_speed = 0.9;

varying vec3 v_local;

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

void vertex() {
	v_local = VERTEX; // object-space entry point on the box
}

void fragment() {
	float t = TIME;

	// Set up the view ray through the box, in local space.
	vec3 cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 entry = v_local;
	vec3 dir = normalize(entry - cam_local);

	// Ray/box exit distance (slab method).
	vec3 inv = 1.0 / (dir + 1e-6);
	vec3 ta = (-box_half - entry) * inv;
	vec3 tb = ( box_half - entry) * inv;
	vec3 tmax = max(ta, tb);
	float t_far = max(min(min(tmax.x, tmax.y), tmax.z), 0.0);

	float step_len = t_far / float(steps);
	vec3 col_acc = vec3(0.0);
	float a_acc = 0.0;

	for (int i = 0; i < steps; i++) {
		vec3 p = entry + dir * (float(i) + 0.5) * step_len;

		// Distance to the filament centre line.
		float sx = clamp(p.x, -seg_half, seg_half);
		float d = length(p - vec3(sx, 0.0, 0.0));

		float core = 1.0 - smoothstep(tube_radius * 0.7, tube_radius * 1.3, d);
		float halo = exp(-max(d - tube_radius, 0.0) * density_falloff);

		// Travelling gas bands along the length.
		float u = clamp(p.x / seg_half * 0.5 + 0.5, 0.0, 1.0);
		float bands = vnoise(u * band_scale - t * band_speed);
		bands = mix(bands, vnoise(u * band_scale * 1.9 + t * band_speed * 0.6), 0.5);
		float spatial = mix(1.0, bands, instability);

		// Fade density to zero before the box faces so the bounding box can
		// never show its silhouette, no matter the view angle.
		vec3 q = abs(p) / box_half;
		float edge = 1.0 - smoothstep(0.6, 1.0, max(q.x, max(q.y, q.z)));

		float dens = (core * core_boost + halo) * spatial * edge;
		vec3 c = mix(halo_color, core_color, core);
		col_acc += c * dens;
		a_acc += dens;
	}
	col_acc *= step_len;
	a_acc *= step_len;
	vec3 avg = col_acc / max(a_acc, 1e-4);

	// Temporal flicker.
	float f1 = sin(t * flicker_speed);
	float f2 = sin(t * flicker_speed * 2.73 + 1.3);
	float f3 = sin(t * flicker_speed * 0.41 + 4.1);
	float n  = vnoise(t * flicker_speed * 0.7) * 2.0 - 1.0;
	float wobble = 0.45 * f1 + 0.20 * f2 + 0.15 * f3 + 0.55 * n;
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * wobble);
	float blink = smoothstep(1.0 - blink_chance, 1.0, vnoise(t * 6.0));
	flicker *= 1.0 - 0.6 * blink;

	ALBEDO = avg * intensity * flicker;             // HDR colour -> bloom
	ALPHA = clamp(a_acc * gain * flicker, 0.0, 1.0); // coverage
}
