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
	vec3 tint = a.r * jersey_color * shade(lum, mean_luma_a.x)
		+ a.g * shorts_color * shade(lum, mean_luma_a.y)
		+ a.b * socks_color * shade(lum, mean_luma_a.z)
		+ a.a * boots_color * shade(lum, mean_luma_a.w)
		+ b.r * skin_color * shade(lum, mean_luma_b.x)
		+ b.g * hair_color * shade(lum, mean_luma_b.y);
	float wsum = a.r + a.g + a.b + a.a + b.r + b.g;
	vec3 col = mix(base_lin, tint / max(wsum, 0.0001), clamp(wsum, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
}
