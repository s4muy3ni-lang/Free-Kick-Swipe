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

varying flat float region;
varying float occl;

void vertex() {
	region = COLOR.r * 10.0;
	occl = COLOR.g;
}

void fragment() {
	int r = int(region + 0.5);
	vec3 c = jersey_color;
	float rough = 0.82;
	float spec = 0.25;
	if (r == 1) { c = shorts_color; rough = 0.78; }
	else if (r == 2) { c = socks_color; rough = 0.9; }
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
