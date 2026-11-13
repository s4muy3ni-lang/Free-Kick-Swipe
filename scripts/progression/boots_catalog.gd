class_name BootsCatalog
extends RefCounted
## Aspecto de cada par de botines de la tienda (pedido del usuario: «cada par debe contar con su modelo 3D o recurso
## visual… al seleccionarlo, debe cambiar realmente el calzado del jugador»): el diseño se pinta sobre los pies del
## modelo con el shader del uniforme (assets/characters/player/player_kit.gdshader: boots_model, boots_color2,
## boots_sole, boots_laces, boots_metal, boots_glow). Modelos: 0 clasico (talon de color), 1 moderno (puntera), 2 pro
## (franja lateral en diagonal). Solo se ve: no cambia la fisica ni el tiro.

const STYLES := {
	"boots_clasicos": {"model": 0, "main": Color(0.04, 0.04, 0.05), "color2": Color(0.95, 0.95, 0.95), "sole": Color(0.93, 0.93, 0.9), "laces": Color(0.95, 0.95, 0.95)},
	"boots_modernos": {"model": 1, "main": Color(0.95, 0.55, 0.08), "color2": Color(0.05, 0.05, 0.06), "sole": Color(0.05, 0.05, 0.06), "laces": Color(0.97, 0.97, 0.97)},
	"boots_pro": {"model": 2, "main": Color(0.12, 0.35, 0.9), "color2": Color(0.97, 0.97, 0.97), "sole": Color(0.95, 0.55, 0.1), "laces": Color(0.97, 0.97, 0.97)},
	"boots_relampago": {"model": 2, "main": Color(0.08, 0.6, 0.25), "color2": Color(1.0, 0.92, 0.15), "sole": Color(0.05, 0.05, 0.06), "laces": Color(1.0, 0.92, 0.15), "glow": 2.2},
	"boots_dorados": {"model": 2, "main": Color(0.95, 0.75, 0.25), "color2": Color(0.06, 0.06, 0.07), "sole": Color(0.95, 0.75, 0.25), "laces": Color(0.06, 0.06, 0.07), "metal": 0.85},
	"boots_cromados": {"model": 2, "main": Color(0.82, 0.84, 0.88), "color2": Color(0.15, 0.4, 0.95), "sole": Color(0.2, 0.2, 0.22), "laces": Color(0.95, 0.95, 0.95), "metal": 0.95},
	"boots_blanco_minimal": {"model": 1, "main": Color(0.96, 0.96, 0.96), "color2": Color(0.96, 0.96, 0.96), "sole": Color(0.85, 0.2, 0.2), "laces": Color(0.96, 0.96, 0.96)},
	"boots_neon_rosa": {"model": 2, "main": Color(1.0, 0.3, 0.65), "color2": Color(0.1, 0.1, 0.12), "sole": Color(1.0, 0.95, 0.3), "laces": Color(0.1, 0.1, 0.12), "glow": 0.8},
	"boots_retro_cuero": {"model": 0, "main": Color(0.18, 0.1, 0.06), "color2": Color(0.9, 0.86, 0.75), "sole": Color(0.1, 0.07, 0.05), "laces": Color(0.9, 0.86, 0.75)},
	"boots_premium_galaxia": {"model": 2, "main": Color(0.16, 0.08, 0.32), "color2": Color(0.3, 0.95, 1.0), "sole": Color(0.08, 0.06, 0.15), "laces": Color(0.3, 0.95, 1.0), "glow": 2.4},
	"boots_tricolor": {"model": 1, "main": Color(0.95, 0.95, 0.97), "color2": Color(0.1, 0.32, 0.86), "sole": Color(0.82, 0.08, 0.1), "laces": Color(0.1, 0.32, 0.86)},
}

## Parametros del shader para el par item_id (si no esta en la tabla: el color elegido, modelo clasico).
static func style(item_id: String, fallback_main: Color) -> Dictionary:
	var s: Dictionary = STYLES.get(item_id, {})
	if s.is_empty():
		return {"boots": fallback_main, "boots_model": 0, "boots_color2": Color(0.95, 0.95, 0.95), "boots_sole": Color(0.93, 0.93, 0.9),
			"boots_laces": Color(0.95, 0.95, 0.95), "boots_metal": 0.0, "boots_glow": 0.0}
	return {"boots": s["main"], "boots_model": int(s["model"]), "boots_color2": s["color2"], "boots_sole": s["sole"],
		"boots_laces": s["laces"], "boots_metal": float(s.get("metal", 0.0)), "boots_glow": float(s.get("glow", 0.0))}
