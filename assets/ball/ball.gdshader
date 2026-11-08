shader_type spatial;
// Balon procedural: parches oscuros sobre los 12 vertices de un icosaedro
// (patron de pentagonos). Sin texturas: coste minimo en gama baja.

uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.93);
uniform vec3 patch_color : source_color = vec3(0.07, 0.07, 0.10);
uniform float patch_threshold = 0.90;
// Desenfoque de movimiento del giro (Ball._process): el patron se promedia a lo largo del arco que la pelota gira con el
// obturador abierto, alrededor del eje real del giro (en el espacio del balon). Como en una camara de television: rapido,
// el ecuador del giro queda en bandas grises y los polos del eje se siguen viendo; despacio, nitido.
uniform vec3 spin_axis = vec3(0.0, 1.0, 0.0);
uniform float spin_arc = 0.0;

varying vec3 local_n;

const vec3 DIRS[12] = vec3[12](
	vec3(0.0, 0.5257, 0.8507), vec3(0.0, 0.5257, -0.8507),
	vec3(0.0, -0.5257, 0.8507), vec3(0.0, -0.5257, -0.8507),
	vec3(0.5257, 0.8507, 0.0), vec3(0.5257, -0.8507, 0.0),
	vec3(-0.5257, 0.8507, 0.0), vec3(-0.5257, -0.8507, 0.0),
	vec3(0.8507, 0.0, 0.5257), vec3(0.8507, 0.0, -0.5257),
	vec3(-0.8507, 0.0, 0.5257), vec3(-0.8507, 0.0, -0.5257)
);

void vertex() {
	local_n = normalize(VERTEX);
}

float patch_mask(vec3 n, float w) {
	float m = -1.0;
	for (int i = 0; i < 12; i++) {
		m = max(m, dot(n, DIRS[i]));
	}
	return smoothstep(patch_threshold - w, patch_threshold + w, m);
}

void fragment() {
	float p;
	if (spin_arc < 0.03) {
		p = patch_mask(local_n, 0.01);
	} else {
		// 8 muestras repartidas en el arco (formula de Rodrigues); el borde se suaviza algo con el arco.
		float w = 0.01 + 0.03 * min(spin_arc, 1.0);
		p = 0.0;
		for (int s = 0; s < 8; s++) {
			float a = spin_arc * ((float(s) + 0.5) / 8.0 - 0.5);
			vec3 r = local_n * cos(a) + cross(spin_axis, local_n) * sin(a) + spin_axis * dot(spin_axis, local_n) * (1.0 - cos(a));
			p += patch_mask(r, w);
		}
		p /= 8.0;
	}
	ALBEDO = mix(base_color, patch_color, p);
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
