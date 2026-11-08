#!/usr/bin/env python3
"""Auditoria y reclasificacion del banco completo de animaciones JSON (2 022 clips) del modo 4.

Lee los JSON ORIGINALES (carpeta con los nombres originales, sin modificarlos), `tools/json_anim/selection.json` (rol
anterior de cada clip), `scripts/player/receive_profiles.gd` (estado de las recepciones) y el codigo del juego (que roles se
usan de verdad). Por clip mide la cinematica de las 19 articulaciones (no se fia del nombre: el nombre es una pista):
  giro del cuerpo, recorrido y velocidad de la raiz, altura minima de la cadera (tendido / agachado), salto (los dos pies en
  el aire), pico de rodilla y de punta de pie, inclinacion del tronco hacia atras, munecas por encima de la cabeza, palmas que
  se juntan varias veces (aplauso), toques de pelota registrados (`meta.touches`).
y decide una clasificacion nueva con su funcion futbolistica, si sirve para el juego, en que sistema va y el motivo.

Salidas (nada de esto toca los JSON ni las librerias .res):
  - docs/fases/E2_inventario_banco.csv: inventario de los 2 022 clips (nombre original, clasificacion anterior, nueva,
    funcion, util, sistema, motivo, medidas).
  - scripts/animation/clip_roles_overlay.gd: reasignaciones de rol y alias que PackLibrary aplica al cargar (anotaciones
    separadas de los datos; regenerar con este script).

Uso: python3 tools/json_anim/analyze_bank.py <carpeta_json_originales>
"""
import csv, json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

# Funcion futbolistica y sistema de cada rol que el juego YA usa (verificado contra el codigo: ver roles_in_code).
ROLE_INFO = {
	"idle": ("reposo", "locomocion"), "idle_ready": ("reposo atento", "locomocion"), "idle_fidget": ("espera con gesto", "locomocion (gestos de espera)"),
	"idle_ball": ("reposo con pelota", "conduccion"), "walk": ("caminar", "locomocion"), "jog": ("trotar", "locomocion"), "run": ("correr", "locomocion"),
	"sprint": ("sprint", "locomocion"), "sidestep": ("paso lateral", "locomocion"), "dir_back": ("marcha atras", "locomocion direccional"),
	"dir_back_diag": ("marcha atras en diagonal", "locomocion direccional"), "dir_fwd_diag": ("marcha en diagonal", "locomocion direccional"),
	"dir_side": ("marcha lateral", "locomocion direccional"), "dir_back_walk": ("caminar hacia atras", "locomocion direccional"),
	"dir_fwd_diag_walk": ("caminar en diagonal", "locomocion direccional"), "stop": ("frenada", "locomocion"),
	"dribble_walk": ("conducir caminando", "conduccion"), "dribble_jog": ("conducir trotando", "conduccion"), "dribble_run": ("conducir corriendo", "conduccion"),
	"dribble_fast": ("conducir rapido", "conduccion"), "dribble_sprint": ("conducir a sprint", "conduccion"),
	"ball_turn": ("giro con pelota", "movimiento con pelota (JsonBallMove)"), "ball_turn_stop": ("giro con pelota frenando", "movimiento con pelota (JsonBallMove)"),
	"ball_skill": ("regate", "movimiento con pelota (JsonBallMove)"), "ball_stop": ("frenar con pelota", "movimiento con pelota (JsonBallMove)"),
	"ball_start": ("arranque con pelota / control", "recepcion (JsonReceive)"), "receive": ("recepcion", "recepcion (JsonReceive)"),
	"receive_turn": ("recepcion orientada con giro", "recepcion (JsonReceive)"), "control_stand": ("control parado", "recepcion (JsonReceive)"),
	"receive_foot": ("recepcion con el pie", "recepcion (JsonReceive)"), "receive_chest": ("recepcion de pecho (gesto)", "reacciones (Receive)"),
	"jostle_ball": ("control protegiendo la pelota", "recepcion (JsonReceive)"), "jostle": ("forcejeo / amago al presionar", "presion (PlayerActions)"),
	"kick_pass": ("pase", "golpeo (kick_candidates)"), "kick_pass_soft": ("pase suave", "golpeo (kick_candidates)"), "kick_shot": ("tiro", "golpeo (kick_candidates)"),
	"kick_shot_hard": ("tiro potente", "golpeo (kick_candidates)"), "kick_lob": ("globo / vaselina", "golpeo (kick_candidates)"), "kick_cross": ("centro", "golpeo (kick_candidates)"),
	"kick_turn": ("golpeo girando", "golpeo girando (BallHandler)"), "kick_back": ("golpeo hacia atras", "golpeo girando (BallHandler)"),
	"volley": ("volea", "golpeo aereo (BallHandler)"), "header": ("cabezazo", "golpeo aereo (BallHandler)"),
	"setpiece_shot": ("tiro de balon parado", "balon parado"), "setpiece_pass": ("pase de balon parado", "balon parado"), "setpiece_lob": ("centro de balon parado", "balon parado"),
	"throw_in": ("saque de banda", "balon parado"), "wall": ("barrera", "balon parado"),
	"turn_start": ("giro sin pelota desde parado", "giros sin pelota (Footballer)"), "turn_run": ("giro sin pelota en carrera", "giros sin pelota (Footballer)"),
	"slide": ("barrida", "entrada (PlayerActions)"), "tackle_stand": ("entrada de pie", "entrada (PlayerActions)"), "shove": ("carga", "entrada (PlayerActions)"),
	"fall": ("caida", "caidas (PlayerActions)"), "fall_hit": ("caida por golpe", "caidas (PlayerActions)"), "trip": ("zancadilla sufrida", "caidas (PlayerActions)"),
	"stumble": ("trastabillar", "caidas (PlayerActions)"), "avoid": ("saltar una barrida (esquivar)", "esquivar barrida (PlayerActions.avoid_tackle)"), "stumble_light": ("trastabillar leve", "caidas (PlayerActions)"), "lie": ("tendido", "caidas (PlayerActions)"),
	"getup": ("levantarse", "caidas (PlayerActions)"), "jump": ("salto / bloqueo", "reacciones (Footballer)"),
	"celebrate": ("festejo", "reacciones de gol"), "celebrate_team": ("festejo en grupo", "reacciones de gol"), "celebrate_scorer": ("festejo del goleador", "reacciones de gol"),
	"dejected": ("lamento", "reacciones de gol"), "angry": ("enojo / protesta", "reacciones"), "clap": ("aplauso", "reacciones"), "gesture": ("gesto / indicacion", "reacciones"),
	"thumbs_up": ("pulgar arriba", "reacciones"), "defeat_end": ("lamento final", "reacciones"), "warmup": ("calentamiento", "reacciones (gestos de espera)"),
	"nis_idle": ("espera de escena", "reacciones (gestos de espera)"),
	"gk_dive": ("estirada del arquero", "arquero"), "gk_catch": ("blocaje", "arquero"), "gk_scoop": ("recoger rasante", "arquero"), "gk_block": ("bloqueo del arquero", "arquero"),
	"gk_sidestep": ("desplazamiento lateral del arquero", "arquero"), "gk_getup": ("arquero se levanta", "arquero"), "gk_gesture": ("gesto del arquero", "arquero"),
	"gk_idle": ("arquero atento", "arquero"), "gk_idle_var": ("arquero espera", "arquero"), "gk_idle_ball": ("arquero con pelota", "arquero"), "gk_kick": ("saque de puerta", "arquero"),
	"gk_throw": ("saque con la mano", "arquero"), "gk_roll": ("saque rodando", "arquero"), "gk_place": ("deja la pelota", "arquero"), "gk_direct": ("dirige a la defensa", "arquero"),
	"gk_miss": ("arquero no llega", "arquero"), "referee": ("arbitro", "arbitro"), "ball_sole": ("pisar la pelota", "movimiento con pelota (JsonBallMove)"),
	"kick_flick": ("taco / sombrero", "movimiento con pelota (JsonBallMove)"), "step_stand": ("paso de colocacion", "giros sin pelota (Footballer)"),
	"start": ("arranque", "transiciones de marcha (Footballer)"), "turn_stop": ("giro y frenada", "giros sin pelota (Footballer)"), "run_change": ("cambio de ritmo", "giros sin pelota (Footballer)"),
}

def samp(d, j, f):
	ts = d["times"]; J = d["joints"]; k = 0
	while k < len(ts) - 2 and ts[k + 1] < f:
		k += 1
	t0, t1 = ts[k], ts[k + 1]
	u = 0 if t1 == t0 else max(0, min(1, (f - t0) / (t1 - t0)))
	return [J[k][j][i] + (J[k + 1][j][i] - J[k][j][i]) * u for i in range(3)]

def kin(d):
	jn = d["joint_names"]; fps = d["fps"]; tend = d["times"][-1]
	J = {n: i for i, n in enumerate(jn)}
	g = lambda n, f: samp(d, J[n], f)
	knee = toe = 0.0; pel_min = 9.0; pel0 = g("pelvis", 0)[1]; air = 0; wrist_up = 0; lean = 0.0; claps = 0; prev_close = False
	n = 0
	for f in range(0, tend + 1, 2):
		n += 1
		P = g("pelvis", f); C = g("chest", f); H = g("head", f)
		knee = max(knee, g("l_knee", f)[1], g("r_knee", f)[1])
		toe = max(toe, g("l_toe", f)[1], g("r_toe", f)[1])
		pel_min = min(pel_min, P[1])
		if min(g("l_toe", f)[1], g("l_ankle", f)[1]) > 0.12 and min(g("r_toe", f)[1], g("r_ankle", f)[1]) > 0.12:
			air += 1
		lw, rw = g("l_wrist", f), g("r_wrist", f)
		if lw[1] > H[1] and rw[1] > H[1]:
			wrist_up += 1
		close = math.dist(lw, rw) < 0.12 and lw[1] > 0.9
		if close and not prev_close:
			claps += 1
		prev_close = close
		lean = max(lean, math.hypot(C[0] - P[0], C[2] - P[2]))
	return dict(knee=round(knee, 2), toe=round(toe, 2), pel0=round(pel0, 2), pel_min=round(pel_min, 2), air=round(air / max(n, 1), 2),
		arms_up=round(wrist_up / max(n, 1), 2), lean=round(lean, 2), claps=claps)

def roles_in_code():
	code = ""
	for root, _, fs in os.walk(os.path.join(ROOT, "scripts")):
		for f in fs:
			if f.endswith(".gd") and f not in ("practice_scene.gd", "receive_profiles.gd", "clip_roles_overlay.gd"):
				code += open(os.path.join(root, f)).read()
	return code

def has(name, *toks):
	return any(t in name for t in toks)

# Nuevos destinos (rol que el juego ya usa o que se conecta en este cambio) para los clips de roles sin uso, decididos con la
# cinematica (giro, carrera, toques) y no solo con el nombre.
# Clips de balon parado que, medidos en el juego, no sirven: el pie nunca llega a la pelota (corner o penal forzando el
# clip, 2 de 2 intentos fallan; los demas de su rol conectan siempre) o el saque de banda no tiene lanzamiento (suelta
# medida en t = 0 s a menos de 0.5 m/s: la pelota sale de las manos a 0.87 m). Se sacan de la seleccion con un rol que
# nadie usa.
_FOOT = "medido en el juego: en el %s, forzando este clip, el pie no llega a la pelota (2 de 2 intentos; los demas de su rol conectan)"
_THROW = "medido: la suelta del saque de banda queda en t = 0 s a %.2f m/s (no hay lanzamiento); la pelota salia de las manos a 0.87 m"
SETPIECE_MISS = {
	"jn_setpiece_pass_3330": _FOOT % "corner", "jn_setpiece_pass_3342": _FOOT % "corner", "jn_setpiece_pass_3346": _FOOT % "corner",
	"jn_setpiece_shot_3354": _FOOT % "penal", "jn_setpiece_shot_3856": _FOOT % "penal",
	"jn_throw_in_2280": _THROW % 0.16, "jn_throw_in_2506": _THROW % 0.47,
}

def reclassify(e, name, meta, k):
	role = e["role"]
	turn = float(meta.get("yaw_end", 0.0)) - float(meta.get("yaw_start", 0.0))
	v_in = float(meta.get("v_in", 0.0)); v_out = float(meta.get("v_out", 0.0))
	touches = len(meta.get("touches", []))
	if role == "ball_dribble":
		if touches == 0:
			return None, "sin toques de pelota medidos: no se puede sincronizar la pelota con el pie", "conduccion"
		if abs(turn) >= 40:
			return "ball_turn", "toques de pelota y giro de %.0f grados: giro con pelota" % turn, "movimiento con pelota (JsonBallMove)"
		if v_in > 1.0 and v_out < 0.6:
			return "ball_stop", "toques de pelota y frena de %.1f a %.1f m/s: frenar con pelota" % (v_in, v_out), "movimiento con pelota (JsonBallMove)"
		return "ball_skill", "toques de pelota sin giro grande (%.0f grados): regate / cambio de ritmo con pelota" % turn, "movimiento con pelota (JsonBallMove)"
	if role in ("turn_stand", "step_stand", "start", "turn_stop", "run_change"):
		if abs(turn) >= 40 and v_in < 1.3:
			return "turn_start", "giro de %.0f grados desde parado (entra a %.1f m/s)" % (turn, v_in), "giros sin pelota (Footballer)"
		if abs(turn) >= 40 and 2.0 <= v_in <= 5.6:
			return "turn_run", "giro de %.0f grados en carrera (entra a %.1f m/s)" % (turn, v_in), "giros sin pelota (Footballer)"
		if v_in < 0.6 and v_out > 2.5:
			return "start", "arranque: de %.1f a %.1f m/s sin girar" % (v_in, v_out), "transiciones de marcha (Footballer)"
		return None, "giro de %.0f grados entrando a %.1f m/s: fuera de las franjas de giro (parado < 1.3 m/s, carrera 2-5.6 m/s)" % (turn, v_in), "giros sin pelota"
	if role == "ball_sole" and touches > 0:
		return "ball_stop", "pone la planta sobre la pelota y la para (toques medidos): frenar con pelota", "movimiento con pelota (JsonBallMove)"
	if role == "gk_idle":
		return "gk_idle_var", "reposo atento del arquero (bucle): variante del reposo", "arquero"
	return False, "", ""

def main():
	src = sys.argv[1]
	sel = json.load(open(os.path.join(HERE, "selection.json")))["clips"]
	files = {f[:4]: f for f in os.listdir(src) if f[:4].isdigit() and f.endswith(".json")}
	prof = open(os.path.join(ROOT, "scripts", "player", "receive_profiles.gd")).read()
	rstat = {m.group(1): m.group(2) for m in re.finditer(r'&"(\w+)": \{.*?"status": "(\w+)"', prof)}
	code = roles_in_code()
	used = {}
	rows = []; overlay_role = {}; overlay_alias = {}
	by_file = {}
	for e in sel:
		by_file.setdefault(e["file"], []).append(e)
	for pre in sorted(files):
		d = json.load(open(os.path.join(src, files[pre])))
		name = d["name"].replace("ANM_", ""); meta = d["meta"]; k = kin(d)
		for e in by_file.get(pre, []):
			role = e["role"]
			if role not in used:
				used[role] = bool(re.search(r'[&"]%s"' % re.escape(role), code))
			referenced = used[role] or bool(e.get("alias")) or bool(re.search(r'[&"]%s(_mirror)?"' % re.escape(e["id"]), code))
			turn = float(meta.get("yaw_end", 0.0)) - float(meta.get("yaw_start", 0.0))
			new = role; useful = "si"; system = ROLE_INFO.get(role, ("", ""))[1]; func = ROLE_INFO.get(role, ("", ""))[0]; why = "rol que el juego usa"
			if e["id"] in SETPIECE_MISS:
				new = "setpiece_miss"; useful = "no"; system = "-"; overlay_role[e["id"]] = "setpiece_miss"
				why = SETPIECE_MISS[e["id"]] + "; fuera de la seleccion del balon parado"
			elif e["id"] in rstat:
				st = rstat[e["id"]]
				if st == "pending":
					useful = "pendiente"; why = "recepcion sin contacto confirmado en la verificacion visual (F3_verificacion_visual_70.md)"
				elif st == "not_reception":
					useful = "no"; why = "arranque de conduccion, no recepcion (auditoria F3); sin sistema de arranque con pelota"
				else:
					why = "recepcion con perfil %s (receive_profiles.gd)" % st
			elif not referenced:
				r2, reason, sys2 = reclassify(e, name, meta, k)
				if r2:
					new = r2; system = sys2; func = ROLE_INFO.get(r2, ("", ""))[0]; why = reason + "; se conecta en clip_roles_overlay.gd"
					if r2 != role:
						overlay_role[e["id"]] = r2
				elif r2 is None:
					useful = "no"; why = reason; func = ROLE_INFO.get(role, (role, ""))[0]
				else:
					useful = "no"; system = "-"
					if role in ("crowd", "mascot", "manager"):
						func = {"crowd": "publico", "mascot": "mascota", "manager": "tecnico"}[role]
						why = "personaje fuera de la cancha: el entorno (gradas, bancos, publico) se quito del modo 4 por decision del usuario"
					elif role.startswith("nis_"):
						func = "escena de presentacion"
						why = "secuencia de presentacion (tunel, himno, escenas): el juego no tiene escenas de presentacion"
						if has(name, "BALL", "KICK", "HEAD", "CONTROL", "CATCH") and k["toe"] > 0.25:
							why += "; tiene gesto con pelota pero sin toques medidos ni contexto de juego"
					elif role in ("loco_sprint", "loco_walk", "loco_jog", "loco_side", "gk_loco"):
						func = {"gk_loco": "carrera del arquero con pelota"}.get(role, "ciclo de marcha alternativo")
						why = "variante de marcha: la locomocion usa ciclos ya elegidos y medidos (velocidad natural); otro ciclo cambiaria la mezcla sin ganar nada"
					elif role.startswith("dribble_"):
						func = "ciclo de conduccion alternativo"; why = "variante: la conduccion usa un ciclo por velocidad (JsonCatalog), ya elegido"
					elif role == "avoid":
						func = "esquivar / saltar una entrada o pelota"; useful = "si"; system = "entrada (PlayerActions: esquivar barrida)"
						why = "salto para esquivar: se usa cuando una barrida rival falla cerca del jugador (avoid_tackle)"
					elif role == "kick_cross":
						func = "centro tras girar 45 grados"; why = "golpeo no limpio: el contacto medido queda a 0.59-0.68 m al costado del cuerpo (clean=false); el golpeo exige el pie delante y la pelota llegaria lejos del pie"
					elif role == "gk_turn":
						func = "giro del arquero"; why = "el arquero se orienta con su locomocion y su planificador de atajadas; no tiene giros de clip"
					elif role == "kick_flick":
						func = "sombrero / taco por encima"; why = "la pelota de un movimiento con pelota va de toque a toque por el suelo: un sombrero necesita una trayectoria aerea que ese sistema no hace"
					elif role == "referee":
						func = "arbitro (variante)"; why = "el arbitro usa sus dos clips con alias; variante sin momento propio"
					elif role in ("idle_ball_var",):
						func = "gesto sin futbol (rascarse)"; why = "gesto sin funcion futbolistica"
					elif role == "throw_prep":
						func = "giro para sacar de banda"; why = "el saque de banda usa sus clips y su colocacion; este giro no tiene momento en la secuencia"
					else:
						why = "rol sin sistema en el juego"
			rows.append(dict(archivo=files[pre], nombre=name, id=e["id"], anterior=role, nueva=new, funcion=func, util=useful,
				sistema=system, motivo=why, giro=round(turn, 1), v_in=meta.get("v_in", ""), v_out=meta.get("v_out", ""),
				toques=len(meta.get("touches", [])), **k))
	# Alias de las transiciones del pack que el codigo pide y que no tenian clip (Idle_To_Sprint), elegidos por la medida.
	starts = [r for r in rows if r["nueva"] == "start" and float(r["v_in"] or 0) < 0.6]
	if starts:
		best = max(starts, key=lambda r: float(r["v_out"] or 0))
		overlay_alias["Idle_To_Sprint"] = best["id"]
	# Sin clip propio en el banco (no hay animacion de cansancio ni de bloqueo de tiro): alternativa compatible con la misma
	# postura, por id (la medida y el nombre lo confirman; el clip conserva su rol).
	ALTERNATIVES = {
		"Running_Tired": ("jn_nis_idle_0954", "parada agotado: de pie con las manos en la cintura mirando arriba (NIS_EXE741_STAND_TO_HANDS_ON_HIPS_LOOK_TO_THE_SKY)"),
		"Defender_2": ("jn_wall_0538", "salto para bloquear un tiro: salto con los brazos cubriendo (STAND_EXE145_WALL_JUMP)"),
	}
	ids = {r["id"] for r in rows}
	for alias, (cid, why) in ALTERNATIVES.items():
		if cid in ids:
			overlay_alias[alias] = cid
			for r in rows:
				if r["id"] == cid:
					r["motivo"] += "; tambien es el clip de «%s» (%s)" % (alias, why)
	out_csv = os.path.join(ROOT, "docs", "fases", "E2_inventario_banco.csv")
	with open(out_csv, "w", newline="") as f:
		w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
		w.writeheader(); w.writerows(rows)
	lines = ["class_name ClipRolesOverlay", "extends RefCounted",
		"## GENERADO por tools/json_anim/analyze_bank.py (no editar a mano): reasignaciones de la auditoria del banco completo",
		"## (docs/fases/E2_inventario_banco.csv). PackLibrary las aplica al cargar las librerias JSON: los datos (.res, JSON) no cambian.", "",
		"## Clip -> rol nuevo (el juego ya usa ese rol: el clip entra en su seleccion; setpiece_miss no lo usa nadie: saca de",
		"## la seleccion del balon parado los clips cuyo pie no llega a la pelota).", "const ROLE := {"]
	for cid in sorted(overlay_role):
		lines.append('\t&"%s": &"%s",' % (cid, overlay_role[cid]))
	lines += ["}", "", "## Nombre del pack -> clip (transiciones que el codigo pide y no tenian clip).", "const ALIAS := {"]
	for a in sorted(overlay_alias):
		lines.append('\t&"%s": &"%s",' % (a, overlay_alias[a]))
	lines.append("}")
	open(os.path.join(ROOT, "scripts", "animation", "clip_roles_overlay.gd"), "w").write("\n".join(lines) + "\n")
	from collections import Counter
	print(len(rows), "entradas;", Counter(r["util"] for r in rows), "; reasignados", len(overlay_role), Counter(overlay_role.values()), "; alias", overlay_alias)

if __name__ == "__main__":
	main()
