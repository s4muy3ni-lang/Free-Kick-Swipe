class_name AccessoryCatalog
extends RefCounted
## Accesorios del jugador (pedido del usuario: «muñequeras, cintas para el pelo, vendas, mangas deportivas… todos deben
## poder activarse y desactivarse; evitar accesorios que interfieran con el esqueleto o las animaciones»). Son piezas
## simples (cilindros y aros) colgadas de los huesos con BoneAttachment3D: siguen la animacion sin tocar el esqueleto ni
## la fisica. Medidas en unidades del esqueleto en reposo (el cuerpo mide ~1).
##
## slot: wrists (las dos muñecas), head (vincha), ankles (vendas en los tobillos), sleeves (mangas largas en los
## antebrazos), armband (brazalete en el brazo izquierdo).

const STYLES := {
	"acc_munequeras": {"slot": "wrists", "color": Color(0.95, 0.95, 0.97)},
	"acc_cinta": {"slot": "head", "color": Color(0.9, 0.15, 0.15)},
	"acc_vendas": {"slot": "ankles", "color": Color(0.93, 0.9, 0.82)},
	"acc_mangas": {"slot": "sleeves", "color": Color(0.08, 0.08, 0.1)},
	"acc_capitan": {"slot": "armband", "color": Color(0.98, 0.78, 0.15)},
}

## Piezas de un accesorio: [hueso, hueso hijo (para el largo, o ""), desde (fraccion del largo), hasta, radio].
static func pieces(slot: String) -> Array:
	match slot:
		"wrists":
			return [["mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.78, 0.97, 0.03], ["mixamorig_RightForeArm", "mixamorig_RightHand", 0.78, 0.97, 0.03]]
		"head":
			# La cabeza no tiene hueso de punta: la vincha va a la altura de la frente, centrada en la cabeza (medida en la
			# malla en reposo: centro x 0,016, frente a y 0,95), vertical.
			return [["mixamorig_Head", "", 0.0, 0.0, 0.061, {"center": Vector3(0.016, 0.951, 0.0), "height": 0.024}]]
		"ankles":
			return [["mixamorig_LeftLeg", "mixamorig_LeftFoot", 0.78, 0.98, 0.034], ["mixamorig_RightLeg", "mixamorig_RightFoot", 0.78, 0.98, 0.034]]
		"sleeves":
			return [["mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.02, 0.95, 0.032], ["mixamorig_RightForeArm", "mixamorig_RightHand", 0.02, 0.95, 0.032]]
		"armband":
			return [["mixamorig_LeftArm", "mixamorig_LeftForeArm", 0.35, 0.52, 0.042]]
	return []
