shader_type spatial;
// Red de arco: una sola malla con rejilla procedural (sin objetos fisicos por celda).
// UV expresada en metros; la rejilla se dibuja con antialiasing por derivadas.
render_mode cull_disabled, unshaded, depth_draw_never;

uniform vec4 net_color : source_color = vec4(0.95, 0.95, 0.95, 0.75);
uniform float cell = 0.16;
uniform float line_width = 0.012;

void fragment() {
	vec2 f = fract(UV / cell);
	vec2 d = min(f, 1.0 - f) * cell;
	vec2 aa = fwidth(UV) * 0.75 + vec2(0.0005);
	vec2 cov = 1.0 - smoothstep(vec2(line_width * 0.5) - aa, vec2(line_width * 0.5) + aa, d);
	float c = max(cov.x, cov.y);
	ALBEDO = net_color.rgb;
	ALPHA = c * net_color.a;
}
