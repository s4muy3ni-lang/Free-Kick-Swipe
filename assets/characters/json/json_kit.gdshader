shader_type spatial;
// Kit del humanoide del modo Json (assets/characters/json/json_human.scn). La zona de cada vertice viene horneada en COLOR.r
// (indice / 10: 0 camiseta, 1 short, 2 medias, 3 botines, 4 piel, 5 pelo, 6 ojos, 7 suela, 8 ribete, 9 labios) y un sombreado
// de oclusion en COLOR.g. Los colores son los mismos parametros que player_kit.gdshader (+ ribete, que sale del short).
render_mode cull_back;

uniform vec3 jersey_color : source_color = vec3(0.72, 0.04, 0.05);
uniform vec3 shorts_color : source_color = vec3(0.05, 0.12, 0.62);
uniform vec3 socks_color : source_color = vec3(0.9, 0.9, 0.9);
uniform vec3 boots_color : source_color = vec3(0.03, 0.03, 0.035);
uniform vec3 skin_color : source_color = vec3(0.62, 0.40, 0.29);
uniform vec3 hair_color : source_color = vec3(0.12, 0.07, 0.04);
uniform vec3 trim_color : source_color = vec3(0.92, 0.92, 0.92);
// Diseños (personalizacion): se calculan en el espacio del modelo, sin texturas. Camiseta: 0 lisa, 1 rayas, 2 banda,
// 3 aros, 4 mitad, 5 degrade, 6 rayas finas (segundo color jersey_color2). Short: 0 liso, 1 franja lateral, 2 ribete.
// Medias: 0 lisas, 1 rayas, 2 ribete; sock_height 0 altas, 1 medias, 2 bajas (la parte de arriba muestra la pierna).
uniform vec3 jersey_color2 : source_color = vec3(0.95, 0.95, 0.95);
uniform int jersey_pattern = 0;
uniform int shorts_pattern = 0;
uniform int socks_pattern = 0;
uniform int sock_height = 0;
uniform vec3 pattern_axis = vec3(0.0, 0.0, 1.0);

varying flat float region;
varying float occl;
varying vec3 mpos;

void vertex() {
	region = COLOR.r * 10.0;
	occl = COLOR.g;
	mpos = VERTEX;
}

vec3 jersey_paint(vec3 base) {
	float lat = dot(mpos, pattern_axis);
	float h = mpos.y;
	if (jersey_pattern == 1) { return fract(lat * 14.0) < 0.5 ? base : jersey_color2; }
	if (jersey_pattern == 2) { float d = fract((lat + h) * 3.2); return (d > 0.42 && d < 0.62) ? jersey_color2 : base; }
	if (jersey_pattern == 3) { return fract(h * 16.0) < 0.5 ? base : jersey_color2; }
	if (jersey_pattern == 4) { return lat < 0.0 ? base : jersey_color2; }
	if (jersey_pattern == 5) { return mix(jersey_color2, base, smoothstep(0.55, 0.85, h)); }
	if (jersey_pattern == 6) { return fract(lat * 30.0) < 0.78 ? base : jersey_color2; }
	return base;
}

void fragment() {
	int r = int(region + 0.5);
	vec3 c = jersey_paint(jersey_color);
	float rough = 0.82;
	float spec = 0.25;
	if (r == 1) {
		c = shorts_color; rough = 0.78;
		float lat1 = abs(dot(mpos, pattern_axis));
		if (shorts_pattern == 1 && lat1 > 0.085 && lat1 < 0.105) { c = trim_color; }
		if (shorts_pattern == 2 && fract(mpos.y * 40.0) < 0.15) { c = trim_color; }
	}
	else if (r == 2) {
		c = socks_color; rough = 0.9;
		if (socks_pattern == 1 && fract(mpos.y * 28.0) < 0.5) { c = jersey_color2; }
		if (socks_pattern == 2 && mpos.y > 0.25) { c = trim_color; }
		if (sock_height == 1 && mpos.y > 0.24) { c = skin_color; rough = 0.62; }
		if (sock_height == 2 && mpos.y > 0.16) { c = skin_color; rough = 0.62; }
	}
	else if (r == 3) { c = boots_color; rough = 0.38; spec = 0.5; }
	else if (r == 4) { c = skin_color; rough = 0.62; spec = 0.35; }
	else if (r == 5) { c = hair_color; rough = 0.55; spec = 0.4; }
	else if (r == 6) { c = vec3(0.03, 0.025, 0.025); rough = 0.2; spec = 0.8; }
	else if (r == 7) { c = vec3(0.10, 0.10, 0.11); rough = 0.9; }
	else if (r == 8) { c = trim_color; rough = 0.8; }
	else if (r == 9) { c = skin_color * vec3(0.72, 0.55, 0.55); rough = 0.5; }
	ALBEDO = c * mix(0.55, 1.0, occl);
	ROUGHNESS = rough;
	SPECULAR = spec;
	RIM = 0.25;
	RIM_TINT = 0.35;
}
