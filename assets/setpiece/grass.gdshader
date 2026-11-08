shader_type spatial;
// Cesped de la cancha de futbol 11: franjas de corte (a lo largo y a lo ancho), ruido de briznas y oscurecimiento fuera de
// la cancha. Sin texturas (Android, GL Compatibility).
render_mode diffuse_lambert, specular_disabled;

uniform vec3 color_a : source_color = vec3(0.075, 0.215, 0.075);
uniform vec3 color_b : source_color = vec3(0.095, 0.255, 0.09);
uniform vec3 color_out : source_color = vec3(0.06, 0.17, 0.065);
uniform float stripe = 5.25;
uniform vec2 half_size = vec2(52.5, 34.0);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = step(0.5, fract(wpos.x / (stripe * 2.0)));
	vec3 c = mix(color_a, color_b, s);
	// Franjas cruzadas muy suaves (corte en dos direcciones).
	float s2 = step(0.5, fract(wpos.z / (stripe * 2.0)));
	c *= 0.985 + 0.03 * s2;
	float n = vnoise(wpos.xz * 1.7) * 0.6 + vnoise(wpos.xz * 9.0) * 0.4;
	c *= 0.9 + 0.16 * n;
	float fine = hash(floor(wpos.xz * 40.0));
	c *= 0.96 + 0.06 * fine;
	vec2 outside = max(abs(wpos.xz) - half_size, vec2(0.0));
	float out_k = clamp(max(outside.x, outside.y) * 2.0, 0.0, 1.0);
	c = mix(c, color_out * (0.92 + 0.12 * n), out_k);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
