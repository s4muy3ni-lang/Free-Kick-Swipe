shader_type spatial;
// Equipamiento del futbolista: recolorea por regiones (camiseta, short, medias, botines, piel, pelo)
// usando mascaras precalculadas (tools/make_player_textures.py) y conserva el sombreado original
// de la textura de Tripo mediante la luminancia relativa a la media de cada region.
// Sin normal map ni ORM: coste minimo para gama baja.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_a : filter_linear_mipmap, repeat_disable;  // camiseta, short, medias, botines
uniform sampler2D mask_b : filter_linear_mipmap, repeat_disable;  // piel, pelo

uniform vec3 jersey_color : source_color = vec3(0.72, 0.04, 0.05);
uniform vec3 shorts_color : source_color = vec3(0.05, 0.12, 0.62);
uniform vec3 socks_color : source_color = vec3(0.9, 0.9, 0.9);
uniform vec3 boots_color : source_color = vec3(0.03, 0.03, 0.035);
uniform vec3 skin_color : source_color = vec3(0.62, 0.40, 0.29);
uniform vec3 hair_color : source_color = vec3(0.12, 0.07, 0.04);

// Luminancia media (espacio gamma) de cada region en la textura original.
uniform vec4 mean_luma_a = vec4(0.203, 0.286, 0.785, 0.088);
uniform vec2 mean_luma_b = vec2(0.492, 0.18);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.78;
// Diseños de la personalizacion (los mismos que json_kit.gdshader, en el espacio del modelo: 1,0 = 1,75 m).
uniform vec3 trim_color : source_color = vec3(0.92, 0.92, 0.92);
uniform vec3 jersey_color2 : source_color = vec3(0.95, 0.95, 0.95);
uniform int jersey_pattern = 0;
uniform int shorts_pattern = 0;
uniform int socks_pattern = 0;
uniform int sock_height = 0;
uniform vec3 pattern_axis = vec3(0.0, 0.0, 1.0);
// Botines (tienda y personalizacion): modelo 0 clasico (talon de color y suela), 1 moderno (puntera de color), 2 pro
// (franja lateral en diagonal), con suela, cordones, metal y brillo propios. Medidas en la posicion de reposo del modelo
// Tripo (rest_space): pies de x -0.07 a 0.09 (punta hacia +x), alto 0.07, centrados en z = +-0.1025.
uniform int boots_model = 0;
uniform vec3 boots_color2 : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 boots_sole : source_color = vec3(0.92, 0.92, 0.9);
uniform vec3 boots_laces : source_color = vec3(0.95, 0.95, 0.95);
uniform float boots_metal = 0.0;
uniform float boots_glow = 0.0;
// Numero de la espalda IMPRESO en la tela (pedido 2026-11-12: el numero quedaba separado de la camiseta). El cuerpo de
// Tripo (tools/json_anim/build_tripo_body) trae en CUSTOM0 la posicion de cada vertice en REPOSO (xyz, en el espacio
// del modelo: adelante = +X, costado = Z) y en w la componente X de su normal en reposo: el numero se proyecta sobre la
// espalda en ese espacio, asi que se dobla y se mueve con la piel. number_atlas: cifras 0..9 en fila (R relleno, G borde).
uniform sampler2D number_atlas : filter_linear_mipmap, repeat_disable;
uniform int back_number = 0;
uniform vec3 number_color : source_color = vec3(0.97, 0.97, 0.98);
uniform vec3 number_edge : source_color = vec3(0.05, 0.05, 0.1);
// Centro (z, y) de la celda de una cifra y su alto, en el espacio de reposo (1,0 = 1,75 m); paso entre dos cifras.
uniform vec3 number_box = vec3(-0.0096, 0.665, 0.16);
uniform float number_step = 0.072;
// Malla con la posicion de reposo en CUSTOM0 (el cuerpo de Tripo del juego; la pone AnimBankCatalog.kit_material): los
// diseños tambien usan esa posicion (no se corren cuando el jugador se mueve) y se puede imprimir el numero.
uniform bool rest_space = false;

varying vec3 mpos;
varying vec4 rpos;

void vertex() {
	rpos = CUSTOM0;
	mpos = rest_space ? CUSTOM0.xyz : VERTEX;
}

// Tinta del numero en este punto: x = relleno, y = relleno + borde (0 fuera del numero). g: derivadas de la UV de una celda.
vec2 number_ink(vec4 gxy) {
	if (!rest_space || back_number <= 0 || rpos.w > -0.25 || rpos.x > -0.02) { return vec2(0.0); }
	float cw = number_box.z * 0.6;
	float v = (number_box.y + number_box.z * 0.5 - rpos.y) / number_box.z;
	if (v < 0.0 || v > 1.0) { return vec2(0.0); }
	int tens = back_number / 10;
	int ones = back_number - tens * 10;
	vec2 ink = vec2(0.0);
	for (int k = 0; k < 2; k++) {
		int digit = k == 0 ? ones : tens;
		if (k == 1 && tens == 0) { break; }
		float cz = number_box.x + (tens > 0 ? (k == 0 ? number_step * 0.5 : -number_step * 0.5) : 0.0);
		float u = (rpos.z - cz) / cw + 0.5;
		if (u < 0.0 || u > 1.0) { continue; }
		vec2 auv = vec2((float(digit) + u) / 10.0, v);
		ink = max(ink, textureGrad(number_atlas, auv, gxy.xy, gxy.zw).rg);
	}
	return ink;
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
	// Cuadros, diagonales, mangas de otro color, cuello y puños, geometrica (chevrones). Medidas en reposo: el torso va de
	// z -0.12 a 0.12 (las mangas mas afuera) y el cuello esta arriba de y 0.8.
	if (jersey_pattern == 7) { return mod(floor(lat * 11.0) + floor(h * 11.0), 2.0) < 0.5 ? base : jersey_color2; }
	if (jersey_pattern == 8) { return fract((lat - h) * 6.0) < 0.5 ? base : jersey_color2; }
	if (jersey_pattern == 9) { return abs(lat) > 0.125 ? jersey_color2 : base; }
	if (jersey_pattern == 10) { return (h > 0.8 || abs(lat) > 0.165) ? jersey_color2 : base; }
	if (jersey_pattern == 11) { return fract(h * 7.0 + abs(lat) * 7.0) < 0.42 ? jersey_color2 : base; }
	return base;
}

vec3 shorts_paint(vec3 base) {
	float lat1 = abs(dot(mpos, pattern_axis));
	if (shorts_pattern == 1 && lat1 > 0.085 && lat1 < 0.105) { return trim_color; }
	if (shorts_pattern == 2 && fract(mpos.y * 40.0) < 0.15) { return trim_color; }
	if (shorts_pattern == 3 && ((lat1 > 0.072 && lat1 < 0.082) || (lat1 > 0.096 && lat1 < 0.106))) { return trim_color; }
	if (shorts_pattern == 4 && mpos.y < 0.372) { return jersey_color2; }
	return base;
}

vec3 socks_paint(vec3 base) {
	if (sock_height == 1 && mpos.y > 0.24) { return skin_color; }
	if (sock_height == 2 && mpos.y > 0.16) { return skin_color; }
	if (socks_pattern == 1 && fract(mpos.y * 28.0) < 0.5) { return jersey_color2; }
	if (socks_pattern == 2 && mpos.y > 0.25) { return trim_color; }
	if (socks_pattern == 3 && ((mpos.y > 0.2 && mpos.y < 0.213) || (mpos.y > 0.226 && mpos.y < 0.239))) { return jersey_color2; }
	if (socks_pattern == 4 && fract(mpos.x * 45.0) < 0.5) { return jersey_color2; }
	return base;
}

// Devuelve el color del botin y en .a si esa parte es la del segundo color (para el brillo).
vec4 boots_paint(vec3 base) {
	if (!rest_space) { return vec4(base, 0.0); }
	vec3 p = mpos;
	float zc = sign(p.z) * 0.1025;
	if (p.y < 0.010) { return vec4(boots_sole, 0.0); }
	if (p.y > 0.047 && abs(p.z - zc) < 0.013 && p.x > -0.012 && p.x < 0.05 && fract(p.x * 110.0) < 0.45) {
		return vec4(boots_laces, 0.0);
	}
	if (boots_model == 0 && p.x < -0.045) { return vec4(boots_color2, 1.0); }
	if (boots_model == 1 && p.x > 0.045) { return vec4(boots_color2, 1.0); }
	if (boots_model == 2 && p.x > -0.055 && p.x < 0.07 && abs(p.y - (0.022 + 0.18 * (p.x + 0.05))) < 0.0065) {
		return vec4(boots_color2, 1.0);
	}
	return vec4(base, 0.0);
}

float shade(float lum_gamma, float mean_gamma) {
	float ratio = clamp(lum_gamma / max(mean_gamma, 0.02), 0.45, 1.6);
	return pow(ratio, 2.2);
}

void fragment() {
	vec3 base_lin = texture(albedo_tex, UV).rgb;
	vec3 base_gamma = pow(base_lin, vec3(1.0 / 2.2));
	float lum = dot(base_gamma, vec3(0.2126, 0.7152, 0.0722));
	vec4 a = texture(mask_a, UV);
	vec4 b = texture(mask_b, UV);
	vec4 bp = boots_paint(boots_color);
	vec3 tint = a.r * jersey_paint(jersey_color) * shade(lum, mean_luma_a.x)
		+ a.g * shorts_paint(shorts_color) * shade(lum, mean_luma_a.y)
		+ a.b * socks_paint(socks_color) * shade(lum, mean_luma_a.z)
		+ a.a * bp.rgb * shade(lum, mean_luma_a.w)
		+ b.r * skin_color * shade(lum, mean_luma_b.x)
		+ b.g * hair_color * shade(lum, mean_luma_b.y);
	float wsum = a.r + a.g + a.b + a.a + b.r + b.g;
	vec3 col = mix(base_lin, tint / max(wsum, 0.0001), clamp(wsum, 0.0, 1.0));
	// Numero: derivadas tomadas fuera de las ramas (la UV de la celda es continua dentro de una cifra).
	vec2 cell_uv = vec2(rpos.z / (number_box.z * 6.0), -rpos.y / number_box.z);
	vec4 gxy = vec4(dFdx(cell_uv), dFdy(cell_uv));
	vec2 ink = number_ink(gxy) * a.r;
	float cloth = shade(lum, mean_luma_a.x);
	col = mix(col, number_edge * cloth, ink.y);
	col = mix(col, number_color * cloth, ink.x);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_value, 0.25, a.a * boots_metal);
	METALLIC = a.a * boots_metal;
	EMISSION = a.a * bp.a * boots_color2 * boots_glow;
	SPECULAR = 0.25;
}
