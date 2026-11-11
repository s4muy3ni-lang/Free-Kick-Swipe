class_name DevFlags
extends RefCounted
## Herramientas de desarrollo segun la build (pedido del usuario: en la version publica no se ven el boton «Diag.», la
## linea amarilla de destino ni el banco de animaciones; el jugador solo ve el rastro de su dedo o raton).
## La build publica es la que se exporta con la caracteristica «public» (export_presets.cfg, custom_features); en el
## editor, las pruebas y las builds de desarrollo, las herramientas siguen disponibles. El codigo no se borra.

static var force_public: bool = false

static func tools_enabled() -> bool:
	return not (force_public or OS.has_feature("public"))
