shader_type spatial;
// Kit del modelo del modo 2 (Newton del «Mocap Pack 05 Soccer», en baja poligonizacion). La zona de cada vertice
// (camiseta, short, medias, botines, piel, pelo) viene horneada en COLOR.r por build_mocap_character.gd (indice / 8,
// elegido por el hueso que mas lo mueve); los colores son los mismos parametros que player_kit.gdshader.
render_mode cull_back;

uniform vec3 jersey_color : source_color = vec3(0.72, 0.04, 0.05);
uniform vec3 shorts_color : source_color = vec3(0.05, 0.12, 0.62);
uniform vec3 socks_color : source_color = vec3(0.9, 0.9, 0.9);
uniform vec3 boots_color : source_color = vec3(0.03, 0.03, 0.035);
uniform vec3 skin_color : source_color = vec3(0.62, 0.40, 0.29);
uniform vec3 hair_color : source_color = vec3(0.12, 0.07, 0.04);

varying float region;

void vertex() {
	region = COLOR.r * 8.0;
}

void fragment() {
	int r = int(region + 0.5);
	vec3 c = jersey_color;
	if (r == 1) { c = shorts_color; }
	else if (r == 2) { c = socks_color; }
	else if (r == 3) { c = boots_color; }
	else if (r == 4) { c = skin_color; }
	else if (r == 5) { c = hair_color; }
	ALBEDO = c;
	ROUGHNESS = r == 3 ? 0.4 : 0.85;
	SPECULAR = 0.3;
}
