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

varying vec3 mpos;

void vertex() {
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

vec3 shorts_paint(vec3 base) {
	float lat1 = abs(dot(mpos, pattern_axis));
	if (shorts_pattern == 1 && lat1 > 0.085 && lat1 < 0.105) { return trim_color; }
	if (shorts_pattern == 2 && fract(mpos.y * 40.0) < 0.15) { return trim_color; }
	return base;
}

vec3 socks_paint(vec3 base) {
	if (sock_height == 1 && mpos.y > 0.24) { return skin_color; }
	if (sock_height == 2 && mpos.y > 0.16) { return skin_color; }
	if (socks_pattern == 1 && fract(mpos.y * 28.0) < 0.5) { return jersey_color2; }
	if (socks_pattern == 2 && mpos.y > 0.25) { return trim_color; }
	return base;
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
	vec3 tint = a.r * jersey_paint(jersey_color) * shade(lum, mean_luma_a.x)
		+ a.g * shorts_paint(shorts_color) * shade(lum, mean_luma_a.y)
		+ a.b * socks_paint(socks_color) * shade(lum, mean_luma_a.z)
		+ a.a * boots_color * shade(lum, mean_luma_a.w)
		+ b.r * skin_color * shade(lum, mean_luma_b.x)
		+ b.g * hair_color * shade(lum, mean_luma_b.y);
	float wsum = a.r + a.g + a.b + a.a + b.r + b.g;
	vec3 col = mix(base_lin, tint / max(wsum, 0.0001), clamp(wsum, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
}
