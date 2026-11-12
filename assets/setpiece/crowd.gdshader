shader_type spatial;
// Tribunas del estadio de penales y tiros libres: las butacas vacias (filas de colores por sectores, escalones con
// sombra). El publico va encima: los hinchas 2D animados de ArcadeLook.crowd (los mismos de los minijuegos arcade).
// La UV de la malla esta en metros: x a lo largo de la tribuna, y subiendo por la pendiente.
render_mode unshaded, cull_disabled;

uniform vec3 seat_a : source_color = vec3(0.12, 0.26, 0.62);
uniform vec3 seat_b : source_color = vec3(0.62, 0.12, 0.14);
uniform vec3 step_col : source_color = vec3(0.10, 0.11, 0.14);
uniform float row = 1.05;
uniform float sector = 14.0;
uniform float light = 0.8;

void fragment() {
	float r = fract(UV.y / row);
	float s = mod(floor(UV.x / sector), 2.0);
	vec3 seat = mix(seat_a, seat_b, s);
	// Respaldo de la butaca (franja de color) y escalon (oscuro) en cada fila.
	vec3 c = r < 0.38 ? seat * (0.8 + 0.2 * r / 0.38) : step_col * (1.0 + 0.4 * (r - 0.38));
	ALBEDO = c * light;
}
