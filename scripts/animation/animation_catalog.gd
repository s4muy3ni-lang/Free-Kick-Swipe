class_name AnimationCatalog
extends RefCounted
## Catalogo UNICO que decide que clip se reproduce para cada situacion del juego. Un solo sistema:
## cada situacion lista primero los clips del pack de Mixamo (si la libreria local existe) y despues los de Tripo
## (respaldo). Nadie mas elige clips: Footballer / BallHandler piden la situacion, no el nombre del clip.
##
## "pack" -> clips de assets/animations/pack_clips.res (restringido, no versionado; ver PackLibrary)
## "tripo" -> clips de assets/animations/footballer_clips.res (siempre disponibles)

## Situaciones de campo. max_seconds: duracion util maxima (el resto se recorta con un fundido).
const FIELD := {
	&"celebrate": {"pack": [&"Fist_Pump_3", &"Cheering_2", &"Fist_Pump", &"Standing_Fist_Pump"], "tripo": [&"celebrate_goal"]},
	&"celebrate_scorer": {"pack": [&"Excited", &"Victory", &"Taunt", &"Fist_Pump_3", &"Jump_4", &"Cheering"], "tripo": [&"celebrate_goal"]},
	&"celebrate_team": {"pack": [&"Cheering_2", &"Clapping", &"Waving_3", &"Fist_Pump", &"Standing_Fist_Pump", &"Pointing_2"], "tripo": [&"celebrate_goal"]},
	&"thumbs_up": {"pack": [&"Standing_Thumbs_Up", &"Clapping"], "tripo": [&"celebrate_goal"]},
	&"dejected": {"pack": [&"Defeat_Idle_2", &"Disappointed", &"Sad_Idle_3", &"Crying", &"Defeated", &"Loser"], "tripo": [&"dejected"]},
	&"angry": {"pack": [&"Angry_Gesture_2", &"Standing_Yell_2", &"Yelling_While_Standing", &"Angry"], "tripo": [&"frustrated"]},
	&"victory_end": {"pack": [&"Victory", &"Cheering", &"Excited", &"Fist_Pump", &"Standing_Fist_Pump"], "tripo": [&"celebrate_goal"]},
	&"defeat_end": {"pack": [&"Defeat", &"Defeated", &"Crying", &"Loser", &"Disappointed"], "tripo": [&"dejected"]},
	&"draw_end": {"pack": [&"Clapping", &"Waving_3", &"Standing_Thumbs_Up"], "tripo": []},
	&"warmup": {"pack": [&"Arm_Stretching", &"Neck_Stretching"], "tripo": []},
	&"referee_count": {"pack": [&"Counting"], "tripo": []},
	&"referee_point": {"pack": [&"Pointing_Forward"], "tripo": []},
	&"referee_foul": {"pack": [&"Pointing_Forward"], "tripo": []},
	&"referee_wave": {"pack": [&"Waving_3", &"Waving"], "tripo": []},
	&"frustrated": {"pack": [&"Angry_Gesture_2"], "tripo": [&"frustrated"]},
	&"fall": {"pack": [&"Falling_Down", &"Sweep_Fall", &"Fall_Flat"], "tripo": [&"fall"]},
	&"getup": {"pack": [&"standing_up", &"Getting_Up_3"], "tripo": []},
	&"slide_tackle": {"pack": [&"soccer_tackle"], "tripo": []},
	&"trip": {"pack": [&"soccer_trip"], "tripo": [&"fall"]},
	&"receive": {"pack": [&"Receive", &"receive_soccerball"], "tripo": []},
	&"jump": {"pack": [&"Jumping_Up", &"Jump_4"], "tripo": [&"jump"]},
	&"jump_running": {"pack": [&"Jump_2"], "tripo": [&"jump"]},
	# Solo modo 4 (roles de los clips JSON, JsonCatalog.SITUATION_ROLES): barrera en un tiro libre en contra.
	&"wall": {"pack": [], "tripo": []},
}

## Patadas conectadas: SOLO clips "en el sitio" (desplazamiento de raiz < ROOT_MAX), porque el pie de contacto medido
## esta referido al cuerpo y el juego no mueve al jugador siguiendo la raiz del clip.
## soccer_penalty_kick (2.5 m de carrera) y Chip (4.4 m) quedan CONVERTIDOS pero sin conectar.
const KICKS := {
	&"pass": [&"Soccer_Pass", &"strike_foward_jog_inplace"],
	&"shot": [&"strike_foward_jog_inplace", &"Soccer_Pass"],
	&"lob": [&"strike_foward_jog_inplace"],
	&"through": [&"Soccer_Pass", &"strike_foward_jog_inplace"],
	&"cross": [&"strike_foward_jog_inplace", &"Soccer_Pass"],
}
const ROOT_MAX := 0.30

## Modo 2 de jugabilidad (Tuning.gameplay_mode = 2): golpeos y festejos del «Mocap Pack 05 Soccer» (mocap_clips.res).
## Los golpeos de mocap traen su carrera recortada alrededor del contacto con las trayectorias de los pies SIN la raiz
## (meta paths_root = false): el cuerpo sigue al pie de apoyo, por eso no se filtran por ROOT_MAX.
const MOCAP_KICKS := {
	&"pass": [&"mc_side_foot_pass"],
	&"through": [&"mc_side_foot_pass"],
	&"shot": [&"mc_power_kick"],
	&"lob": [&"mc_power_kick"],
	&"cross": [&"mc_power_kick", &"mc_side_foot_pass"],
}
const MOCAP_FIELD := {
	&"celebrate": [&"mc_celebration_2", &"mc_celebration_3"],
	&"celebrate_scorer": [&"mc_celebration_1", &"mc_celebration_2", &"mc_celebration_3"],
	&"celebrate_team": [&"mc_celebration_2", &"mc_celebration_3"],
	&"victory_end": [&"mc_celebration_1", &"mc_celebration_3"],
	&"referee_foul": [&"mc_yellow_card"],
}

## true si se juega con las animaciones de mocap (modo 2 elegido y la libreria convertida presente).
static func mocap_mode() -> bool:
	return Tuning.gameplay_mode == 2 and PackLibrary.has_clip(&"mc_side_foot_pass")

## Arquero (libreria pack_keeper.res): nombres de situacion de los clips del arquero (Goalkeeper elige entre ellos).
const KEEPER := {
	&"keeper_idle": [&"goalkeeper_idle"], &"keeper_idle_ball": [&"goalkeeper_idle_2"],
	&"keeper_dive_left": [&"goalkeeper_diving_save"], &"keeper_dive_right": [&"goalkeeper_diving_save_2"],
	&"keeper_catch_low": [&"goalkeeper_catch"], &"keeper_catch_mid": [&"goalkeeper_catch_2"],
	&"keeper_catch_high_run": [&"goalkeeper_catch_3"], &"keeper_catch_high": [&"goalkeeper_catch_4"],
	&"keeper_scoop": [&"goalkeeper_scoop"], &"keeper_sidestep_left": [&"goalkeeper_sidestep"], &"keeper_sidestep_right": [&"goalkeeper_sidestep_2"],
	&"keeper_block": [&"goalkeeper_body_block", &"goalkeeper_body_block_2", &"goalkeeper_body_block_3"],
	&"keeper_miss": [&"goalkeeper_miss"], &"keeper_throw": [&"goalkeeper_overhand_throw", &"Goalie_Throw"],
	&"keeper_kick": [&"goalkeeper_drop_kick"], &"keeper_roll": [&"goalkeeper_pass"],
	&"keeper_place_short": [&"goalkeeper_placing_ball"], &"keeper_place_long": [&"goalkeeper_placing_ball_2"],
	&"keeper_direct_attack": [&"goalkeeper_directing"], &"keeper_direct_defense": [&"goalkeeper_directing_2"],
}

## Resuelve una situacion de campo a un clip concreto.
## Devuelve {} si no hay clip, o {"source": &"pack"|&"tripo", "clip": StringName}.
static func resolve(situation: StringName, use_pack: bool, pick: int = 0) -> Dictionary:
	if not FIELD.has(situation):
		return {}
	var entry: Dictionary = FIELD[situation]
	if use_pack and mocap_mode() and MOCAP_FIELD.has(situation):
		var mc: Array = (MOCAP_FIELD[situation] as Array).filter(func(c: StringName) -> bool: return PackLibrary.has_clip(c))
		if mc.size() > 0:
			return {"source": &"pack", "clip": mc[absi(pick) % mc.size()]}
	if use_pack and PackLibrary.json_mode():
		# Modo 4: entre todos los clips JSON del rol de la situacion (festejos, lamentos, gestos...).
		var jc: StringName = JsonCatalog.situation_clip(situation, pick)
		if jc != &"":
			return {"source": &"pack", "clip": jc}
	if use_pack:
		var packs: Array = (entry["pack"] as Array).filter(func(c: StringName) -> bool: return PackLibrary.has_clip(c))
		if packs.size() > 0:
			return {"source": &"pack", "clip": packs[absi(pick) % packs.size()]}
	# Modo 4 (Json): los clips de Tripo no sirven en su esqueleto; lo que no tiene clip JSON simplemente no se anima.
	if PackLibrary.json_mode():
		return {}
	var tripo: Array = entry["tripo"]
	if tripo.size() > 0:
		return {"source": &"tripo", "clip": tripo[absi(pick) % tripo.size()]}
	return {}

## Clips de patada disponibles (con su version izquierda "_mirror") para una accion: [{clip, foot}].
## charge (0..1): en el modo 4 elige la clase de potencia de los clips (JsonCatalog.kick_candidates).
static func kick_candidates(kind: StringName, charge: float = 0.5) -> Array:
	if PackLibrary.json_mode():
		return JsonCatalog.kick_candidates(kind, charge)
	var out: Array = []
	var mocap: bool = mocap_mode() and MOCAP_KICKS.has(kind)
	for c in (MOCAP_KICKS if mocap else KICKS).get(kind, []):
		for id in [c, StringName(String(c) + "_mirror")]:
			var m: Dictionary = PackLibrary.meta(id)
			if m.is_empty() or not m.has("contact"):
				continue
			if (m["root_total"] as Vector2).length() > ROOT_MAX and m.get("paths_root", true):
				continue
			out.append({"clip": id, "foot": m["contact"]["foot"], "contact": m["contact"]})
	return out

## Segundos entre apoyos de la marcha activa a una velocidad (con la cadencia con la que se reproduce). -1 si no hay datos.
static func step_interval(speed: float) -> float:
	return FootballerVisual.step_interval_for(speed)

## Velocidad (adelante, derecha) en m/s del desplazamiento raiz del clip en el instante t (para acciones con raiz).
static func root_velocity(clip: StringName, t: float) -> Vector2:
	var m: Dictionary = PackLibrary.meta(clip)
	if m.is_empty():
		return Vector2.ZERO
	var path: PackedVector2Array = m["root_path"]
	if path.size() < 2:
		return Vector2.ZERO
	var f: float = clampf(t * 30.0, 0.0, float(path.size() - 2))
	var i: int = int(f)
	return (path[i + 1] - path[i]) * 30.0
