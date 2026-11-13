shader_type spatial;
// Balon procedural: parches oscuros sobre los 12 vertices de un icosaedro
// (patron de pentagonos). Sin texturas: coste minimo en gama baja.

uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.93);
uniform vec3 patch_color : source_color = vec3(0.07, 0.07, 0.10);
uniform float patch_threshold = 0.90;
// Diseño del balon (BallSkins, tienda y personalizacion; solo se ve, no cambia la fisica): 0 clasico, 1 moderno,
// 2 competicion, 3 noche, 4 llamas, 5 temporada, 6 estrellas. accent / accent2 = colores del diseño, glow = brillo propio.
uniform int design = 0;
uniform vec3 accent : source_color = vec3(0.1, 0.35, 0.9);
uniform vec3 accent2 : source_color = vec3(0.95, 0.75, 0.15);
uniform float glow = 0.0;
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

// Color del diseño en la direccion n (rgb) y cuanto brilla (a, se multiplica por glow).
vec4 paint(vec3 n, float w) {
	if (design == 1) {
		// Moderno: blanco con dos bandas curvas de color que se cruzan.
		float b1 = abs(dot(n, normalize(vec3(0.3, 0.9, 0.3))));
		float b2 = abs(dot(n, normalize(vec3(0.9, -0.2, 0.4))));
		vec3 c = base_color;
		c = mix(c, accent, smoothstep(0.24 + w, 0.22 - w, b1));
		c = mix(c, accent2, smoothstep(0.1 + w, 0.08 - w, b2));
		return vec4(c, 0.0);
	}
	if (design == 2) {
		// Competicion: triangulos dorados y negros alrededor de los vertices del icosaedro.
		float m = -1.0;
		int k = 0;
		for (int i = 0; i < 12; i++) {
			float d = dot(n, DIRS[i]);
			if (d > m) { m = d; k = i; }
		}
		vec3 c = (k % 3 == 0) ? accent2 : ((k % 3 == 1) ? patch_color : base_color);
		return vec4(mix(base_color, c, smoothstep(0.82 - w, 0.86 + w, m)), 0.0);
	}
	if (design == 3) {
		// Noche: azul oscuro con lineas de neon (tres circulos maximos) que brillan.
		float l = min(min(abs(n.x), abs(n.y)), abs(n.z));
		float line = smoothstep(0.05 + w, 0.03 - w, l);
		return vec4(mix(vec3(0.03, 0.04, 0.12), accent, line), line);
	}
	if (design == 4) {
		// Llamas: lenguas de fuego que suben desde abajo.
		float ang = atan(n.z, n.x);
		float f = n.y + 0.25 * sin(ang * 5.0 + n.y * 6.0) + 0.12 * sin(ang * 11.0);
		vec3 c = mix(vec3(0.95, 0.85, 0.2), vec3(0.85, 0.12, 0.05), smoothstep(-0.3, 0.35, f));
		c = mix(c, vec3(0.08, 0.05, 0.05), smoothstep(0.35, 0.6, f));
		return vec4(c, 1.0 - smoothstep(-0.2, 0.4, f));
	}
	if (design == 5) {
		// Temporada: violeta con costuras doradas.
		float s1 = abs(dot(n, normalize(vec3(1.0, 0.0, 0.6))));
		float s2 = abs(dot(n, normalize(vec3(-0.4, 1.0, 0.3))));
		float seam = max(smoothstep(0.05 + w, 0.03 - w, s1), smoothstep(0.05 + w, 0.03 - w, s2));
		return vec4(mix(accent, accent2, seam), seam * 0.6);
	}
	if (design == 6) {
		// Estrellas: azul noche con puntos de luz.
		float m = -1.0;
		for (int i = 0; i < 12; i++) { m = max(m, dot(n, DIRS[i])); m = max(m, dot(n, -normalize(DIRS[i] + DIRS[(i + 5) % 12]))); }
		float star = smoothstep(0.985 - w, 0.995, m);
		return vec4(mix(vec3(0.02, 0.03, 0.12), vec3(1.0, 0.95, 0.75), star), star);
	}
	// Clasico: pentagonos oscuros.
	return vec4(mix(base_color, patch_color, patch_mask(n, w)), 0.0);
}

void fragment() {
	vec4 c;
	if (spin_arc < 0.03) {
		c = paint(local_n, 0.01);
	} else {
		// 8 muestras repartidas en el arco (formula de Rodrigues); el borde se suaviza algo con el arco.
		float w = 0.01 + 0.03 * min(spin_arc, 1.0);
		c = vec4(0.0);
		for (int s = 0; s < 8; s++) {
			float a = spin_arc * ((float(s) + 0.5) / 8.0 - 0.5);
			vec3 r = local_n * cos(a) + cross(spin_axis, local_n) * sin(a) + spin_axis * dot(spin_axis, local_n) * (1.0 - cos(a));
			c += paint(r, w);
		}
		c /= 8.0;
	}
	ALBEDO = c.rgb;
	EMISSION = c.rgb * c.a * glow;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
