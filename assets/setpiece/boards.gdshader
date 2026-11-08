shader_type spatial;
// Carteles de publicidad LED alrededor de la cancha: franjas de color que se desplazan (sin marcas reales).
render_mode unshaded;

uniform vec3 color_a : source_color = vec3(0.05, 0.35, 0.95);
uniform vec3 color_b : source_color = vec3(0.95, 0.85, 0.10);
uniform vec3 color_c : source_color = vec3(0.95, 0.20, 0.35);
uniform float speed = 0.6;

void fragment() {
	float x = UV.x * 0.25 + TIME * speed;
	float k = fract(x);
	vec3 c = k < 0.33 ? color_a : (k < 0.66 ? color_b : color_c);
	float stripe = smoothstep(0.0, 0.04, fract(UV.x * 1.5 - TIME * 0.4)) * 0.25 + 0.75;
	float band = step(0.15, UV.y) * step(UV.y, 0.85);
	c = mix(c * 0.4, c, band) * stripe;
	ALBEDO = c * 1.15;
}
