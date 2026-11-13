class_name BallSkins
extends RefCounted
## Diseños de balon (tienda y personalizacion; pedido del usuario: «el diseño del balon no debe alterar la fisica ni
## proporcionar ventajas ocultas»): solo cambian los parametros del shader del balon (assets/ball/ball.gdshader). La
## fisica (Ball: masa, radio, rozamiento, efecto) es la misma con cualquier diseño.
##
## Cada diseño: design (indice del shader), colores y brillo. Los objetos del catalogo (catalog_items, kind "ball") eligen
## el diseño con data.design; el elegido por el usuario es PlayerCustom.ball_item.

const DESIGNS := {
	"clasico": {"design": 0, "base": Color(0.96, 0.96, 0.93), "patch": Color(0.07, 0.07, 0.10), "accent": Color(0.1, 0.35, 0.9), "accent2": Color(0.95, 0.75, 0.15), "glow": 0.0},
	"moderno": {"design": 1, "base": Color(0.97, 0.97, 0.98), "patch": Color(0.07, 0.07, 0.10), "accent": Color(0.12, 0.38, 0.92), "accent2": Color(0.9, 0.15, 0.2), "glow": 0.0},
	"competicion": {"design": 2, "base": Color(0.97, 0.97, 0.96), "patch": Color(0.06, 0.06, 0.08), "accent": Color(0.1, 0.35, 0.9), "accent2": Color(0.95, 0.72, 0.12), "glow": 0.0},
	"noche": {"design": 3, "base": Color(0.05, 0.06, 0.15), "patch": Color(0.05, 0.05, 0.1), "accent": Color(0.2, 0.95, 1.0), "accent2": Color(0.9, 0.2, 0.9), "glow": 2.2},
	"llamas": {"design": 4, "base": Color(0.9, 0.3, 0.05), "patch": Color(0.1, 0.05, 0.05), "accent": Color(1.0, 0.6, 0.1), "accent2": Color(1.0, 0.9, 0.3), "glow": 1.4},
	"temporada_1": {"design": 5, "base": Color(0.35, 0.12, 0.55), "patch": Color(0.1, 0.05, 0.15), "accent": Color(0.38, 0.14, 0.62), "accent2": Color(1.0, 0.8, 0.25), "glow": 0.8},
	"oro_premium": {"design": 2, "base": Color(0.95, 0.76, 0.25), "patch": Color(0.05, 0.05, 0.06), "accent": Color(0.1, 0.1, 0.12), "accent2": Color(0.98, 0.98, 0.96), "glow": 0.3},
	"estrellas": {"design": 6, "base": Color(0.03, 0.04, 0.14), "patch": Color(0.03, 0.03, 0.1), "accent": Color(0.4, 0.6, 1.0), "accent2": Color(1.0, 0.95, 0.75), "glow": 2.5},
}

## Diseño de un objeto del catalogo (por su id y sus datos), o "clasico".
static func design_of(item_id: String, catalog: Array = []) -> String:
	for it in catalog:
		if String((it as Dictionary).get("id", "")) == item_id:
			var d: Variant = (it as Dictionary).get("data", {})
			if d is Dictionary and DESIGNS.has(String((d as Dictionary).get("design", ""))):
				return String(d["design"])
	var guess: String = item_id.trim_prefix("ball_")
	if guess == "t1":
		guess = "temporada_1"
	return guess if DESIGNS.has(guess) else "clasico"

## Aplica el diseño a un material del shader del balon.
static func apply_material(mat: ShaderMaterial, design: String) -> void:
	if mat == null:
		return
	var d: Dictionary = DESIGNS.get(design, DESIGNS["clasico"])
	mat.set_shader_parameter("design", int(d["design"]))
	mat.set_shader_parameter("base_color", d["base"])
	mat.set_shader_parameter("patch_color", d["patch"])
	mat.set_shader_parameter("accent", d["accent"])
	mat.set_shader_parameter("accent2", d["accent2"])
	mat.set_shader_parameter("glow", float(d["glow"]))

## Viste la pelota con el diseño elegido por el usuario (solo el material: la fisica no cambia).
static func apply_user(ball: Ball) -> void:
	if ball == null:
		return
	PlayerCustom.load_custom()
	ball.set_skin(design_of(PlayerCustom.ball_item))
