#!/usr/bin/env python3
"""Perfiles de contacto de los 124 clips de recepcion y control del modo 4 (F3).

Lee los JSON ORIGINALES de las animaciones (carpeta con los nombres originales, p. ej. `0564_CONTROL_EXE189_...json`) y
escribe `scripts/player/receive_profiles.gd` (una constante GDScript: se exporta con el juego sin filtros de exportacion).

Por clip (id del juego `jn_<rol>_<indice>`), con la evidencia de la auditoria de F3:
  - part: parte del cuerpo del PRIMER contacto real (foot, foot_air, thigh, knee, chest, head; leg = pierna levantada sin
    parte distinguible; nada se inventa: si la cinematica y el nombre no lo resuelven, el clip queda pendiente).
  - t: instante estimado del primer contacto (pico de la pierna o inclinacion del tronco), -1 si desconocido. NO es el
    primer `ball_touches` (toques de pie registrados, que pueden ser posteriores a un control con otra parte) ni `key_frame`.
  - status: usable | conditional | pending | not_reception (auditoria de F3: 23 / 27 / 70 / 4; la verificacion visual de los
    70 pendientes (VISUAL) saca de pendientes los clips con contacto confirmado).
  - confidence: estimated (cinematica) | verified (contacto observado con la pelota en tools/json_anim/receive_view: VERIFIED
    de F3 y VISUAL) | pending.
  - conds: condiciones de uso (stick_turn: giro >= 45 grados, stick_out: sale a >= 1.5 m/s, post_action: pase o golpeo
    posterior, rival: control protegiendo la pelota, jump: salto).
  - post_t: instante del pase o golpeo posterior (toque registrado a >= 6.5 m/s; en los clips «PASS», su primer toque
    posterior), -1 si no hay, -2 si el nombre dice pase pero no hay toque registrado (se corta 0.25 s tras el contacto).
  - from_deg: direccion de LLEGADA de la pelota respecto al frente (+ izquierda) en NUESTROS datos, o null. Los nombres
    tienen el lado invertido respecto de los datos (verificado en el modelo del juego: los clips «R_THIGH», «R_FOOT» y
    «FROM_R_…» suben la pierna izquierda del modelo), asi que «FROM_R_45» -> +45 (por la izquierda).
  - v_in, v_out, turn (grados), root (m), height (altura de la pelota que indica el nombre, solo informativa).
Los espejos (`_mirror`) usan el mismo perfil con from_deg y turn cambiados de signo (JsonReceive.profile).

Uso: python3 tools/json_anim/make_receive_profiles.py <carpeta_json_originales> [--out scripts/player/receive_profiles.gd]
"""
import json, math, os, re, sys


# Diferencias de medida con la auditoria de F3 (que manda): indice -> (estado, motivo).
AUDIT_OVERRIDES = {
	1824: ("usable", "la auditoria midio el toque posterior con la velocidad convertida (ball_touches, 5.6 m/s < 6.5): no es un pase; el JSON original da 6.55 m/s"),
}

# Contactos observados con la pelota en el visor (tools/json_anim/receive_view.tscn) durante F3: indice -> nota.
VERIFIED = {
	1330: "visor: pelota rasante de frente y de costado, punta del pie animado a -0.02 m de la pelota en el contacto",
	3068: "visor: pelota rasante con joystick, punta del pie a 0.05 m en el contacto",
	584: "visor: pelota con bote a 0.52-0.56 m, pie en el aire a 0.05-0.07 m de la pelota en el contacto",
	580: "visor: pelota a 0.88 m, la pelota toca el muslo levantado y cae delante (tira de imagenes)",
	588: "visor: pelota a 1.02 m, la pelota toca el pecho y cae delante (tira de imagenes)",
	574: "visor: pelota rasante, punta del pie a 0.00 m en el contacto; el pase posterior lo da el sistema de pase",
	204: "visor (CLIP=jn_receive_0204): rodilla levantada (muslo 92 grados) a la pelota de 0.85 m, cae delante (0.91 m)",
}

# Verificacion visual de los 70 pendientes (continuacion de F3): CLIP=<id> en tools/json_anim/receive_view.tscn, pelota
# lanzada a la parte del cuerpo supuesta en el instante supuesto, tiras de imagenes antes/durante/despues del contacto y
# medida del esqueleto vivo (informe: docs/fases/F3_verificacion_visual_70.md). Contacto confirmado: indice -> (parte,
# instante, confianza, nota). La parte y el instante sustituyen a los de la cinematica y el clip deja de estar pendiente
# (su estado sale de sus condiciones como el de los demas).
VISUAL = {
	604: ("thigh", 0.333, "media-alta", "muslo izquierdo levantado (76 grados) bajo la pelota de 45 grados; la pelota cae por el muslo y queda delante (0.41 m)"),
	608: ("thigh", 0.267, "media", "pierna izquierda extendida (muslo 91 grados) bajo la pelota de 45 grados; cae por la pierna (0.65 m) y luego gira"),
	614: ("foot_air", 0.333, "media", "hipotesis alternativa coherente con el nombre (LOW_HEIGHT): con el muslo levantado, el pie amortigua la pelota baja (0.37 m) y queda a sus pies (0.45 m)"),
	618: ("thigh", 0.433, "media-baja", "pelota de costado (90 grados) al muslo izquierdo (58 grados) en marcha; la pelota queda a sus pies (0.70 m); vista en parte tapada"),
	622: ("thigh", 0.367, "media", "muslo izquierdo (56 grados) con salto corto; la pelota de costado cae delante (0.66 m)"),
	1800: ("foot", 0.167, "media", "hipotesis alternativa (el nombre dice pelota rasante: GROUND): el pie izquierdo para la pelota rodando en marcha y queda a sus pies (0.32 m); con el muslo (pasada 2) no habia gesto"),
	1820: ("thigh", 0.333, "media-alta", "muslo derecho levantado (75 grados) con brazos abiertos, la pelota cae delante (0.53 m)"),
	1822: ("chest", 0.233, "alta", "pecho con brazos abiertos, la pelota cae delante (1.02 m)"),
	1830: ("thigh", 0.333, "media-alta", "muslo derecho levantado (76 grados), brazos abiertos, pelota de frente amortiguada (0.32 m); la llegada a 90 grados del nombre no se comprobo"),
	1834: ("thigh", 0.3, "media-alta", "muslo derecho (74 grados) en carrera (1.86 m/s), pelota amortiguada (0.29 m); llegada a 90 grados del nombre no comprobada"),
	2130: ("chest", 0.333, "media", "la pelota da en la parte alta del pecho con la rodilla izquierda levantada (salto corto) y brazos adelante; sale hacia delante (0.98 m)"),
	2134: ("chest", 0.333, "media-alta", "pecho con el tronco algo atras, la pelota cae delante (0.84 m)"),
	2136: ("chest", 0.267, "alta", "pecho adelantado con brazos abiertos, la pelota cae delante (0.82 m); el giro (-98 grados) viene despues"),
	2144: ("chest", 0.267, "alta", "tronco muy echado atras con brazos abiertos: pecho a la pelota, cae delante (0.50 m)"),
	2150: ("chest", 0.333, "media", "la pelota da en el lado izquierdo del pecho con el tronco algo girado y sale hacia delante (1.28 m); el giro de 69 grados viene despues"),
	2152: ("chest", 0.3, "alta", "pecho con rodillas flexionadas, la pelota muere a sus pies (0.36 m)"),
	2156: ("chest", 0.367, "media", "la pelota da en la parte alta del pecho mientras el cuerpo gira (96 grados); queda a 0.79 m"),
	2158: ("chest", 0.333, "media-alta", "pecho con brazos abiertos en carrera (2.34 m/s), la pelota cae delante; despues hay un golpeo (post_action)"),
	2160: ("chest", 0.333, "alta", "pecho con brazos abiertos, la pelota cae delante (0.66 m) y despues empieza el giro (-182 grados)"),
	2162: ("chest", 0.4, "alta", "pecho con brazos abiertos, la pelota cae delante (1.08 m)"),
	2164: ("foot_air", 0.3, "media-alta", "hipotesis alternativa: pie levantado por encima de la rodilla (tibia 105 grados, punta a 0.81 m) recibe la pelota alta (nombre OVERHEAD) y la deja a sus pies (0.29 m)"),
	2428: ("foot", 0.3, "media-alta", "hipotesis alternativa: el pie izquierdo adelantado para la pelota rodando (queda a 0.56 m, quieta); con el muslo no habia gesto"),
	2430: ("foot_air", 0.333, "media", "hipotesis alternativa: el pie izquierdo adelantado amortigua una pelota con bote bajo (0.22 m), queda quieta a 0.54 m"),
	2432: ("foot", 0.267, "media", "hipotesis alternativa: el pie derecho para la pelota rodando (0.75 m, casi quieta); con el muslo no habia gesto"),
	2442: ("thigh", 0.267, "media-baja", "muslo izquierdo algo levantado (56 grados), la pelota da encima y cae a sus pies"),
	2448: ("foot", 0.133, "media", "hipotesis alternativa: el pie derecho para la pelota rodando en marcha (0.37 m); con el muslo (39 grados) no habia gesto"),
	2450: ("thigh", 0.167, "media", "muslo derecho levantado (66 grados), la pelota cae delante (0.38 m)"),
	2474: ("thigh", 0.4, "media", "muslo izquierdo (59 grados) bajo la pelota tras adelantar el pie; cae delante (0.42 m)"),
	2476: ("thigh", 0.333, "media", "muslo izquierdo levantado (85 grados) con el pie adelantado; la pelota cae por la pierna (0.44 m)"),
	2478: ("thigh", 0.3, "media-alta", "muslo izquierdo horizontal (90 grados), la pelota cae delante (0.31 m)"),
	2482: ("chest", 0.3, "alta", "tronco arqueado hacia atras y pecho a la pelota, cae delante (0.62 m)"),
	2486: ("chest", 0.267, "alta", "pecho adelantado con rodillas flexionadas, la pelota cae delante (0.73 m)"),
	2488: ("chest", 0.333, "media-alta", "tronco atras y pecho a la pelota, rebota poco y cae delante (0.82 m)"),
	3066: ("foot_air", 0.2, "media", "hipotesis alternativa: el pie derecho amortigua una pelota con bote bajo (0.22 m) y muere a sus pies (0.18 m); con el muslo no habia gesto"),
	3072: ("foot_air", 0.333, "media", "hipotesis alternativa: el pie derecho amortigua una pelota con bote bajo (0.24 m), queda a 0.42 m; con el muslo no habia gesto claro"),
	3090: ("thigh", 0.333, "media-alta", "muslo izquierdo horizontal (86 grados) bajo la pelota, cae a sus pies"),
	3092: ("thigh", 0.267, "media-alta", "muslo izquierdo horizontal (87 grados) bajo la pelota, cae por la pierna (0.56 m)"),
	3094: ("foot_air", 0.4, "media", "hipotesis alternativa: el pie derecho levantado amortigua una pelota a 0.31 m, cae delante (0.71 m)"),
	3148: ("thigh", 0.333, "media", "muslo izquierdo (66 grados), la pelota cae delante (0.17 m)"),
	3150: ("foot_air", 0.333, "media", "hipotesis alternativa: el pie derecho amortigua una pelota con bote bajo (0.26 m), queda a 0.45 m"),
	3154: ("thigh", 0.167, "media-baja", "muslo izquierdo levantado (51 grados) con brazos abiertos, la pelota cae (0.56 m) y gira"),
	3162: ("thigh", 0.4, "media-alta", "muslo izquierdo horizontal (89 grados), la pelota cae delante (0.26 m)"),
	3164: ("thigh", 0.4, "media-alta", "muslo izquierdo horizontal (87 grados), la pelota cae delante (0.34 m)"),
	3166: ("chest", 0.333, "media-alta", "hipotesis alternativa: tronco echado atras con brazos adelante (salto corto), la pelota da en el pecho y cae delante (0.71 m); con el muslo (20 grados) no habia gesto"),
	3168: ("thigh", 0.333, "media", "pierna izquierda extendida (muslo 80 grados, tibia 50 grados) como en 0586 (verificado en F3); la pelota cae por la pierna (0.38 m)"),
}

# Vistos en el visor sin contacto confirmable (siguen pendientes): indice -> motivo.
VISUAL_NOT = {
	590: "sin instante medible (cabeza sin senal); con t=0.40 elegido a mano la pelota da en la cara del jugador agachado; ademas la cabeza no tiene respuesta fisica en el juego",
	596: "t estimado = final del clip (0.80 de 0.817 s): la pelota llega al pecho en el ultimo fotograma, sin gesto de control despues",
	616: "la rodilla sube a la pelota en t pero el nombre dice que la pelota pasa por encima y gira 180 grados: el gesto supuesto contradice el clip",
	620: "la pelota llega por detras (sobre el hombro): el contacto con el muslo no se distingue y el juego exige llegada por delante para el muslo",
	1326: "pierna extendida muy alta (muslo 119 grados): con muslo o rodilla la pelota rebota lejos (1.42 m); parece mas un golpeo que un control",
	1840: "muslo derecho poco levantado (56 grados) y la pelota da en la cadera: gesto de control no claro (criterio: muslo visiblemente levantado bajo la pelota)",
	2132: "t estimado = final del clip (0.80 de 0.817 s): la pelota pasa junto al pecho con el jugador erguido, sin gesto",
	2140: "la pelota llega al hombro/cabeza con el tronco girado; el pecho no se presenta a la pelota",
	2142: "t estimado = final del clip (0.90 de 0.917 s)",
	2146: "t estimado = final del clip (0.80 de 0.80 s): el clip termina antes de la ventana de contacto",
	2148: "t estimado = final del clip (1.033 de 1.05 s): la pelota llega cuando el jugador ya camina erguido",
	2480: "t estimado = final del clip (1.00 de 1.00 s)",
	2484: "salto con los brazos arriba antes del contacto: la pelota original parece ir a la cabeza; ni el muslo (pasada 2, 30 grados) ni el pecho son concluyentes",
	2496: "arranque de conduccion en carrera: la pelota pasa bajo la zancada, no se ve un control",
	3100: "t al empezar el clip (0.067 s): la pierna no ha subido y la pelota no toca el muslo (0.21 m)",
	3102: "pico tardio (1.00 s, zancada): la recepcion se corta porque la pelota choca con el cuerpo antes de la ventana; no se ve un control",
	3146: "sin instante medido (ningun pie se levanta): con t=0.40 elegido a mano el pie toca la pelota en plena zancada; no se distingue de un paso",
	3152: "en t la pierna esta casi vertical (muslo 32 grados): no hay gesto de control; la pelota solo choca con la cadera",
	3156: "muslo poco levantado (41 grados): la pelota da en la parte alta del muslo sin gesto claro de control",
	3158: "t estimado = final del clip (0.80 de 0.817 s); el pie no esta en la pelota (punta a 0.23 m)",
	3160: "t estimado = final del clip (0.867 de 0.883 s)",
	3170: "t estimado (0.767 s) posterior al final del clip (0.733 s)",
	3172: "el pie toca la pelota en plena zancada (pico tardio): no se distingue de un paso; el nombre dice pelota alta",
	3174: "t estimado = final del clip (1.233 de 1.233 s)",
	3178: "t estimado = final del clip (0.70 de 0.717 s)",
}

def samp(d, j, f):
	ts = d["times"]; J = d["joints"]; k = 0
	while k < len(ts) - 2 and ts[k + 1] < f:
		k += 1
	t0, t1 = ts[k], ts[k + 1]
	u = 0 if t1 == t0 else max(0, min(1, (f - t0) / (t1 - t0)))
	return [J[k][j][i] + (J[k + 1][j][i] - J[k][j][i]) * u for i in range(3)]

def kinematics(d):
	jn = d["joint_names"]; fps = d["fps"]; tend = d["times"][-1]
	J = lambda n: jn.index(n)
	rows = []
	for f in range(0, tend + 1, 2):
		g = lambda n: samp(d, J(n), f)
		P = g("pelvis"); C = g("chest"); H = g("head"); hl = g("l_hip"); hr = g("r_hip")
		rx, rz = hr[0] - hl[0], hr[2] - hl[2]; n = math.hypot(rx, rz) or 1; rx, rz = rx / n, rz / n
		fx, fz = -rz, rx
		tr = g("r_toe"); ar = g("r_ankle"); tl = g("l_toe"); al = g("l_ankle")
		if (tr[0] - ar[0] + tl[0] - al[0]) * fx + (tr[2] - ar[2] + tl[2] - al[2]) * fz < 0:
			fx, fz = -fx, -fz
		kl = g("l_knee"); kr = g("r_knee")
		rows.append(dict(t=f / fps, P=P[1], lean=(C[0] - P[0]) * fx + (C[2] - P[2]) * fz, kL=kl[1], kR=kr[1],
			toeL=tl[1], toeR=tr[1], ankL=al[1], ankR=ar[1]))
	return rows

def classify(idx, d, role):
	name = d["name"].replace("ANM_", ""); up = name.upper(); meta = d["meta"]
	rows = kinematics(d)
	pk = lambda key: max(rows, key=lambda x: x[key])
	kL, kR, tL, tR = pk("kL"), pk("kR"), pk("toeL"), pk("toeR")
	knee, kt = (kL["kL"], kL["t"]) if kL["kL"] >= kR["kR"] else (kR["kR"], kR["t"])
	toe, tt = (tL["toeL"], tL["t"]) if tL["toeL"] >= tR["toeR"] else (tR["toeR"], tR["t"])
	lean0 = rows[0]["lean"]; lmin = min(rows, key=lambda x: x["lean"]); lb = lean0 - lmin["lean"]; lbt = lmin["t"]
	air = [x["t"] for x in rows if min(x["toeL"], x["ankL"]) > 0.12 and min(x["toeR"], x["ankR"]) > 0.12]
	jump = bool(air) or max(x["P"] for x in rows) - rows[0]["P"] >= 0.15
	part_name = None
	if "CHEST" in up: part_name = "chest"
	elif "THIGH" in up: part_name = "thigh"
	elif re.search(r"(^|_)KNEE(_CONTROL|_STAND|_FORWARD|$)", up) and "KNEE_HIGH" not in up: part_name = "knee"
	elif "RECEIVE_HEAD" in up: part_name = "head"
	elif "FOOT" in up: part_name = "foot"
	leg_lift = knee >= 0.58 or toe >= 0.08
	high_foot = toe >= 0.45 and knee >= 0.85
	chest_sig = lb >= 0.12
	part = None; t_c = None; pend = []
	if part_name == "chest":
		part = "chest"; t_c = lbt if chest_sig else None
		if not chest_sig: pend.append("CHEST sin inclinacion del tronco")
		if leg_lift and (not chest_sig or kt > lbt + 0.05):
			pend.append("sube tambien la pierna"); t_c = t_c if t_c is not None else kt
	elif part_name == "thigh": part = "thigh"; t_c = kt
	elif part_name == "knee": part = "knee"; t_c = kt
	elif part_name == "head": part = "head"; pend.append("cabeza sin senal medible")
	elif part_name == "foot": part = "foot_air" if toe >= 0.30 else "foot"; t_c = tt if toe >= 0.08 else kt
	elif high_foot: part = "foot_air"; t_c = tt
	elif toe < 0.20 and knee < 0.62 and toe >= 0.08: part = "foot"; t_c = tt
	elif leg_lift:
		part = "leg"; t_c = kt; pend.append("pie, muslo o rodilla no se distinguen")
	elif chest_sig: part = "chest"; t_c = lbt; pend.append("solo inclina el tronco")
	else: part = "foot"; pend.append("ningun pie se levanta")
	leg_based = part in ("foot", "foot_air", "thigh", "knee", "leg")
	if t_c is not None and t_c > 0.75 and leg_based:
		pend.append("pico tardio (zancada)")
	if idx in VISUAL:
		part, t_c = VISUAL[idx][0], VISUAL[idx][1]
		pend = []
	elif idx in VISUAL_NOT:
		pend.append("visor: " + VISUAL_NOT[idx])
	fps = d["fps"]
	touches = sorted([[float(t[0]) / fps, t[1], float(t[2]), float(t[3])] for t in meta.get("touches", [])])
	after = [t for t in touches if t_c is None or t[0] > t_c + 0.05]
	strong = [t for t in after if t[3] >= 6.5]
	turn = float(meta.get("yaw_end", 0.0)) - float(meta.get("yaw_start", 0.0))
	v_in = float(meta.get("v_in", 0.0)); v_out = float(meta.get("v_out", 0.0))
	root = math.hypot(*meta.get("root_end", [0.0, 0.0]))
	conds = []
	if abs(turn) >= 45: conds.append("stick_turn")
	if v_out >= 1.5: conds.append("stick_out")
	if "PASS" in up or strong: conds.append("post_action")
	if jump: conds.append("jump")
	if role == "jostle_ball": conds.append("rival")
	if re.search(r"STAND_TO_(WALKING|JOGGING)_DRIBBLE|STAND_TO_45_R_FORWARDS_JOGGING_DRIBBLE", up):
		status = "not_reception"
	elif role == "jostle_ball":
		status = "conditional"
	elif pend:
		status = "pending"
	elif "post_action" in conds or "stick_turn" in conds or "stick_out" in conds or "jump" in conds:
		status = "conditional"
	else:
		status = "usable"
	note_extra = ""
	if idx in VISUAL:
		note_extra = "visor (confianza %s): %s" % (VISUAL[idx][2], VISUAL[idx][3])
	if idx in AUDIT_OVERRIDES:
		status, note_extra = AUDIT_OVERRIDES[idx]
		conds = [c for c in conds if c != "post_action"]; strong = []
	from_deg = None
	m = re.search(r"FROM_(R|L)_(\d+)", up)
	if m: from_deg = float(m.group(2)) * (1.0 if m.group(1) == "R" else -1.0)
	elif "FROM_FORWARD" in up: from_deg = 0.0
	elif "OVER_L_SHOULDER" in up: from_deg = -150.0
	elif "FROM_R_SHOULDER" in up: from_deg = 90.0
	elif "FWD" in up: from_deg = 0.0
	height = None
	for tok in ("KNEE_HIGH", "WAIST_HIGH", "SHOULDER_HEIGHT", "LOW_HEIGHT", "_LOW", "_HIGH_", "MEDIUM", "_AIR_", "OVERHEAD"):
		if tok in up:
			height = tok.strip("_").lower(); break
	return dict(name=name, part=part, t=round(t_c, 3) if t_c is not None else -1.0, status=status,
		confidence=("verified" if idx in VERIFIED or idx in VISUAL else ("pending" if status == "pending" else "estimated")),
		conds=conds, post_t=round(strong[0][0], 3) if strong else ((round(after[0][0], 3) if after else -2.0) if "PASS" in up else -1.0),
		from_deg=from_deg, v_in=round(v_in, 2), v_out=round(v_out, 2), turn=round(turn, 1), root=round(root, 2),
		height=height, touches_after=[round(t[0], 3) for t in after], note="; ".join(pend + ([note_extra] if note_extra else [])))

def gd_value(v):
	if v is None: return "null"
	if isinstance(v, bool): return "true" if v else "false"
	if isinstance(v, (int, float)): return repr(float(v))
	if isinstance(v, str): return '"%s"' % v.replace('"', "'")
	if isinstance(v, list): return "[" + ", ".join(gd_value(x) for x in v) + "]"
	raise TypeError(v)

def main():
	if len(sys.argv) < 2:
		print(__doc__); sys.exit(1)
	src = sys.argv[1]
	out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "scripts/player/receive_profiles.gd"
	here = os.path.dirname(os.path.abspath(__file__))
	sel = json.load(open(os.path.join(here, "selection.json")))["clips"]
	roles = ("receive", "receive_turn", "control_stand", "ball_start", "jostle_ball", "receive_foot")
	files = {int(f[:4]): f for f in os.listdir(src) if f[:4].isdigit() and f.endswith(".json")}
	prof = {}
	for e in sel:
		cid = e["id"]; role = cid[3:].rsplit("_", 1)[0]
		if role not in roles or cid.endswith("_mirror"):
			continue
		idx = int(e["file"])
		d = json.load(open(os.path.join(src, files[idx])))
		prof[cid] = classify(idx, d, role)
	counts = {}
	for p in prof.values():
		counts[p["status"]] = counts.get(p["status"], 0) + 1
	lines = ["class_name ReceiveProfiles", "extends RefCounted",
		"## GENERADO por tools/json_anim/make_receive_profiles.py (no editar a mano): perfiles de contacto de los %d clips de" % len(prof),
		"## recepcion y control del modo 4 (auditoria de F3). Estados: %s." % ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts)),
		"## Campos y criterios: ver la cabecera del generador.", "", "const PROFILES := {"]
	for cid in sorted(prof):
		p = prof[cid]
		lines.append("\t&\"%s\": {%s}," % (cid, ", ".join('"%s": %s' % (k, gd_value(v)) for k, v in p.items())))
	lines.append("}")
	open(out, "w").write("\n".join(lines) + "\n")
	print("%d perfiles -> %s %s" % (len(prof), out, counts))

if __name__ == "__main__":
	main()
