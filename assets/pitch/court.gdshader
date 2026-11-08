shader_type spatial;
// Superficie de juego: color base con franjas suaves y ruido muy sutil. Sin texturas.
render_mode diffuse_lambert, specular_disabled;

uniform vec3 color_a : source_color = vec3(0.09, 0.30, 0.15);
uniform vec3 color_b : source_color = vec3(0.11, 0.34, 0.17);
uniform float stripe_width = 2.5;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float stripe = step(0.5, fract(wpos.x / (stripe_width * 2.0)));
	vec3 c = mix(color_a, color_b, stripe);
	float n = hash(floor(wpos.xz * 6.0));
	c *= 0.97 + 0.03 * n;
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
