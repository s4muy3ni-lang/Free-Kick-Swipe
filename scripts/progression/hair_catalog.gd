class_name HairCatalog
extends RefCounted
## Peinados, barbas y forma del cuerpo (pedido del usuario: «peinados, cortes de pelo, longitud, colores, barbas,
## bigotes… altura y complexion dentro de limites compatibles con el esqueleto… no deformar el modelo de forma que rompa
## las animaciones… que no den ventajas»).
##
## El cuerpo de Tripo trae el pelo pintado en la textura (mascara de pelo: «Natural»). Los demas peinados y las barbas
## son piezas simples (elipsoides) colgadas del hueso de la cabeza con BoneAttachment3D, como los accesorios: siguen la
## animacion sin tocar el esqueleto. «Rapado» no agrega piezas: el shader mezcla el color del pelo con la piel
## (hair_buzz). Medidas en el espacio del esqueleto en reposo (el cuerpo mide ~1; la cara mira a +X), tomadas de la malla:
## cabeza de y 0,86 a 1,0, de x -0,05 (nuca) a 0,08 (nariz), z +-0,054; boca a y ~0,875.
##
## Altura y complexion: escala del modelo (SpActor.set_body_shape) en rangos chicos. Es solo visual: el alcance del
## arquero, la barrera y el tiro no la usan, y el arquero del usuario no la lleva (sus manos tienen que coincidir con las
## atajadas planificadas).

## Pieza: [centro (reposo), semiejes, rotacion en grados (x, y, z)] y, opcional, el tono: "buzz" (pelo mezclado con la
## piel: rapado) o "gold". El pelo de la textura es un jopo con volumen (llega a y 1,0 y sale adelante hasta x 0,082 a y
## 0,97): todos los peinados salvo «Natural» llevan el casco CAP, que lo envuelve y deja ver la frente, y sobre el casco
## sus piezas propias.
const CAP := [Vector3(0.012, 0.968, 0.0), Vector3(0.075, 0.041, 0.059), Vector3.ZERO]
const HAIRCUTS := {
	"hair_natural": {"parts": []},
	"hair_rapado": {"parts": [CAP + ["buzz"]], "buzz": 0.6},
	"hair_rulos": {"parts": [CAP, [Vector3(0.04, 1.0, 0.0), Vector3(0.024, 0.022, 0.024), Vector3.ZERO],
		[Vector3(0.008, 1.004, 0.026), Vector3(0.024, 0.022, 0.024), Vector3.ZERO],
		[Vector3(0.008, 1.004, -0.026), Vector3(0.024, 0.022, 0.024), Vector3.ZERO],
		[Vector3(-0.03, 0.995, 0.0), Vector3(0.024, 0.022, 0.024), Vector3.ZERO],
		[Vector3(0.062, 0.985, 0.025), Vector3(0.02, 0.02, 0.02), Vector3.ZERO],
		[Vector3(0.062, 0.985, -0.025), Vector3(0.02, 0.02, 0.02), Vector3.ZERO],
		[Vector3(-0.045, 0.97, 0.034), Vector3(0.02, 0.022, 0.02), Vector3.ZERO],
		[Vector3(-0.045, 0.97, -0.034), Vector3(0.02, 0.022, 0.02), Vector3.ZERO]]},
	"hair_jopo": {"parts": [CAP, [Vector3(0.066, 0.998, 0.0), Vector3(0.036, 0.024, 0.042), Vector3(0, 0, 25)]]},
	"hair_cresta": {"parts": [CAP + ["buzz"], [Vector3(0.014, 1.006, 0.0), Vector3(0.072, 0.034, 0.012), Vector3.ZERO]], "buzz": 0.6},
	"hair_rodete": {"parts": [CAP, [Vector3(-0.064, 0.995, 0.0), Vector3(0.025, 0.025, 0.025), Vector3.ZERO]]},
	"hair_melena": {"parts": [CAP, [Vector3(-0.046, 0.912, 0.0), Vector3(0.026, 0.07, 0.06), Vector3(0, 0, -6)],
		[Vector3(0.0, 0.93, 0.05), Vector3(0.04, 0.045, 0.014), Vector3.ZERO],
		[Vector3(0.0, 0.93, -0.05), Vector3(0.04, 0.045, 0.014), Vector3.ZERO]]},
	"hair_afro": {"parts": [[Vector3(-0.004, 0.978, 0.0), Vector3(0.088, 0.064, 0.082), Vector3.ZERO]]},
	"hair_estrella": {"parts": [CAP + ["buzz"], [Vector3(0.014, 1.006, 0.0), Vector3(0.072, 0.034, 0.012), Vector3.ZERO, "gold"]], "buzz": 0.6},
}

## Perfil de la cara en reposo (medido en la linea media y ajustado mirando las imagenes): boca ~0,893 (x 0,078), menton
## ~0,87, mandibula hasta ~0,855; ancho de la cara z +-0,05. Las barbas son elipsoides centrados atras de la cara: solo
## asoma la parte de adelante, pegada a la mandibula.
const MUSTACHE := [Vector3(0.073, 0.902, 0.0), Vector3(0.007, 0.0055, 0.022), Vector3.ZERO]
const BEARDS := {
	"beard_none": {"parts": []},
	"beard_bigote": {"parts": [MUSTACHE]},
	"beard_candado": {"parts": [MUSTACHE, [Vector3(0.064, 0.868, 0.0), Vector3(0.011, 0.014, 0.016), Vector3.ZERO]]},
	"beard_corta": {"parts": [[Vector3(0.02, 0.875, 0.0), Vector3(0.053, 0.026, 0.052), Vector3.ZERO]]},
	"beard_completa": {"parts": [[Vector3(0.022, 0.874, 0.0), Vector3(0.055, 0.031, 0.054), Vector3.ZERO], MUSTACHE]},
	"beard_vikinga": {"parts": [[Vector3(0.022, 0.871, 0.0), Vector3(0.056, 0.035, 0.055), Vector3.ZERO],
		[Vector3(0.058, 0.836, 0.0), Vector3(0.016, 0.03, 0.022), Vector3(0, 0, -15)], MUSTACHE]},
}

## Altura (escala vertical) y complexion (escala de ancho y profundidad): rangos chicos para no romper las animaciones.
const HEIGHTS := [0.97, 0.985, 1.0, 1.015, 1.03]
const HEIGHT_NAMES := ["Bajo", "Medio bajo", "Medio", "Medio alto", "Alto"]
const BUILDS := [0.94, 1.0, 1.04, 1.08]
const BUILD_NAMES := ["Delgado", "Normal", "Atlético", "Robusto"]
const DEFAULT_HEIGHT := 2
const DEFAULT_BUILD := 1

## Colores de los detalles de los botines (secundario, suela, cordones).
const BOOT_DETAIL_NAMES := ["Blanco", "Negro", "Gris", "Rojo", "Azul", "Amarillo", "Verde", "Naranja", "Dorado", "Rosa"]
const BOOT_DETAILS: Array[Color] = [Color(0.95, 0.95, 0.95), Color(0.05, 0.05, 0.06), Color(0.55, 0.56, 0.6),
	Color(0.85, 0.1, 0.12), Color(0.12, 0.35, 0.9), Color(1.0, 0.85, 0.1), Color(0.15, 0.7, 0.3), Color(1.0, 0.5, 0.08),
	Color(0.92, 0.72, 0.25), Color(1.0, 0.45, 0.7)]

static func haircut(id: String) -> Dictionary:
	return HAIRCUTS.get(id, HAIRCUTS["hair_natural"])

static func beard(id: String) -> Dictionary:
	return BEARDS.get(id, BEARDS["beard_none"])

## Escala del modelo (multiplica la escala base del cuerpo): x y z = complexion, y = altura.
static func body_scale(height_i: int, build_i: int) -> Vector3:
	var h: float = HEIGHTS[clampi(height_i, 0, HEIGHTS.size() - 1)]
	var b: float = BUILDS[clampi(build_i, 0, BUILDS.size() - 1)]
	return Vector3(b, h, b)
