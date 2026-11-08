shader_type spatial;
// Publico de las tribunas: una sola malla por tribuna; cada butaca (celda de la UV, en metros) dibuja una persona con
// camiseta de colores de los dos equipos, cabeza y un leve movimiento (mas fuerte cuando `cheer` sube tras un gol).
render_mode unshaded, cull_disabled;

uniform vec3 team_a : source_color = vec3(0.10, 0.30, 0.85);
uniform vec3 team_b : source_color = vec3(0.85, 0.12, 0.12);
uniform vec3 seat : source_color = vec3(0.16, 0.18, 0.22);
uniform float cell = 0.55;
uniform float cheer = 0.0;
uniform float light = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 id = floor(UV / cell);
	vec2 f = fract(UV / cell);
	float h = hash(id);
	float h2 = hash(id + 17.3);
	float occupied = step(0.12, h2);
	float bob = sin(TIME * (3.0 + h * 4.0) + h * 30.0) * (0.03 + cheer * 0.18);
	f.y += bob;
	vec3 shirt = h < 0.45 ? team_a : (h < 0.85 ? team_b : vec3(0.85 + 0.1 * h2));
	shirt *= 0.75 + 0.35 * h2;
	vec3 skin = mix(vec3(0.95, 0.75, 0.6), vec3(0.35, 0.22, 0.15), hash(id + 3.1));
	// Cuerpo (rectangulo) y cabeza (circulo) dentro de la celda.
	float body = step(0.22, f.x) * step(f.x, 0.78) * step(0.08, f.y) * step(f.y, 0.55);
	float head = 1.0 - step(0.13, length(f - vec2(0.5, 0.68)));
	// Brazos arriba al festejar.
	float arms = cheer * step(0.5, h) * (step(0.12, f.x) * step(f.x, 0.22) + step(0.78, f.x) * step(f.x, 0.88)) * step(0.4, f.y) * step(f.y, 0.9);
	vec3 c = seat;
	c = mix(c, shirt, clamp(body + arms, 0.0, 1.0) * occupied);
	c = mix(c, skin, head * occupied);
	// Las filas de atras un poco mas oscuras.
	ALBEDO = c * light * (0.82 + 0.18 * hash(vec2(id.y, 1.0)));
}
