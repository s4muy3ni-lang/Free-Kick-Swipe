extends Node
## Inventario por rol de una biblioteca (ACTUAL o MIXAMO): clips sin espejo y con espejo, duracion total y clips con
## contacto con la pelota. Salida JSON en INV_OUT. Uso:
##   INV_BANK=actual|mixamo INV_OUT=<archivo.json> godot --headless --path . res://tools/mixamo/dump_inventory.tscn
func _ready() -> void:
	var bank: int = AnimBank.Bank.MIXAMO if OS.get_environment("INV_BANK") == "mixamo" else AnimBank.Bank.ACTUAL
	var libs: Dictionary = SpClips.MIXAMO_LIBS if bank == AnimBank.Bank.MIXAMO else SpClips.LIBS
	var roles := {}
	var total := 0
	var with_mirror := 0
	for key in libs:
		var lib: AnimationLibrary = load(libs[key]) as AnimationLibrary
		for id in lib.get_animation_list():
			with_mirror += 1
			if String(id).ends_with("_mirror"):
				continue
			total += 1
			var a: Animation = lib.get_animation(id)
			var m: Dictionary = a.get_meta("pack", {})
			var role: String = String(m.get("role", ""))
			var base := StringName(String(id))
			if ClipRolesOverlay.ROLE.has(base):
				role = String(ClipRolesOverlay.ROLE[base])
			if not roles.has(role):
				roles[role] = {"clips": 0, "seconds": 0.0, "contact": 0, "library": String(key)}
			roles[role]["clips"] += 1
			roles[role]["seconds"] += a.length
			if m.has("contact"):
				roles[role]["contact"] += 1
	var f := FileAccess.open(OS.get_environment("INV_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"bank": AnimBank.NAMES[bank], "clips": total, "with_mirrors": with_mirror, "roles": roles}, "\t"))
	f.close()
	print("INVENTARIO %s: %d clips (%d con espejos), %d roles" % [AnimBank.NAMES[bank], total, with_mirror, roles.size()])
	get_tree().quit()
