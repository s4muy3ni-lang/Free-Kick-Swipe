"""Genera docs/transferencia_integracion_completa/INVENTARIO_ANIMACIONES.csv: UNA fila por animacion del banco (2 024 tramos
de los 2 022 JSON), con lo que usa el juego (metadata de la libreria convertida) y lo que dice UCS (animdb.adb).

Entradas (rutas por argumento; el banco JSON y el animdb.adb de UCS no estan en el repositorio):
  1. index.json del banco (animaciones_futbol5_conectadas_y_sin_conectar/index.json o el del pack original)
  2. animdb.adb de UCS (paquete_recursos_analisis_movimiento/animaciones/animdb.adb)
  3. library_meta.json: lo escribe tools/transfer/dump_library_meta.tscn (OUT=...)
Ademas lee docs/fases/E2_inventario_banco.csv y assets/animations/animdb.json del repositorio.

Uso: python3 tools/transfer/make_inventory.py <index.json> <animdb.adb> <library_meta.json> [salida.csv]
"""
import csv
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "transferencia_integracion_completa", "INVENTARIO_ANIMACIONES.csv")

# Sistema que elige y ejecuta cada accion (rol) y sus condiciones de entrada/salida, segun el codigo (ver MAPA_ANIMACIONES.md).
ROLE_RULES = {
    "kick_pass": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates (scripts/animation/json_catalog.gd)", "golpeo pass: carga < 0.35 (con kick_pass_soft), 0.35-0.8 (solo kick_pass), >= 0.8 (con kick_shot); centro (cross, con kick_cross y kick_lob); solo contactos limpios (contact.clean)", "BallHandler._finish_clip_kick: la marcha sigue con la velocidad previa"),
    "kick_pass_soft": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo pass con carga < 0.35; contacto limpio", "idem kick_pass"),
    "kick_shot": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo shot (cualquier carga) y pass con carga >= 0.8; contacto limpio", "idem kick_pass"),
    "kick_shot_hard": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo shot con carga >= 0.45; contacto limpio", "idem kick_pass"),
    "kick_lob": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo lob, y cross; contacto limpio", "idem kick_pass"),
    "kick_cross": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo cross (unico rol admitido sin contacto limpio)", "idem kick_pass"),
    "kick_turn": ("BallHandler.plan_turn_kick (golpeo girando)", "destino del golpe a >= 50 grados del frente; pelota sale hacia alli (+-40)", "cuerpo con raiz y rumbo del clip hasta el contacto"),
    "kick_back": ("BallHandler.plan_turn_kick (golpeo girando)", "destino del golpe detras", "idem"),
    "header": ("BallHandler golpeo aereo (plan aereo, header/volley)", "pelota alta que llega; orden de golpeo", "segun clip"),
    "volley": ("BallHandler golpeo aereo (plan aereo, header/volley)", "pelota a media altura que llega; orden de golpeo", "segun clip"),
    "ball_turn": ("JsonBallMove (intencion turn; y steer si es de control con dribble)", "joystick a >= 50 grados del frente (IA >= 110); |v_in - v| <= 1.5 m/s; la pelota llega al primer toque", "ultima salida: pelota delante del rumbo de salida; marcha con v_out"),
    "ball_turn_stop": ("JsonBallMove (turn_for_kick, drag)", "giro antes de golpear hacia atras; REGATE + atras", "pelota quieta delante del pie"),
    "ball_skill": ("JsonBallMove (intencion skill; y steer si es de control con dribble)", "boton REGATE", "idem ball_turn"),
    "ball_stop": ("JsonBallMove (intencion stop)", "soltar el joystick a 2.6-4.6 m/s conduciendo", "pelota quieta delante"),
    "ball_start": ("JsonBallMove (intencion start, si v_out >= 1)", "jugador de la persona casi quieto (< 0.6 m/s), joystick >= 0.6 a < 50 grados, sin sprint", "clip entero; marcha con v_out"),
    "receive": ("JsonReceive (recepcion con clip)", "pelota que llega; perfil ReceiveProfiles con contacto verificado", "pelota con la respuesta de la parte del cuerpo"),
    "receive_turn": ("JsonReceive (recepcion con clip)", "idem con giro", "idem"),
    "receive_foot": ("JsonReceive (recepcion con clip)", "idem pie", "idem"),
    "control_stand": ("JsonReceive (recepcion con clip)", "idem parado", "idem"),
    "jostle_ball": ("JsonReceive (recepcion con clip)", "idem protegiendo", "idem"),
    "dribble_walk": ("Marcha con pelota (JsonCatalog.CARRY, FootballerVisual)", "escalon de velocidad del BlendSpace Carry", "ciclo"),
    "dribble_jog": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "dribble_run": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "dribble_fast": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "dribble_sprint": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "idle_ball": ("Marcha con pelota (JsonCatalog.CARRY, reposo)", "velocidad 0 con pelota", "ciclo"),
    "walk": ("Marcha (JsonCatalog.GAIT)", "escalon del BlendSpace", "ciclo"),
    "jog": ("Marcha (JsonCatalog.GAIT)", "idem", "ciclo"),
    "run": ("Marcha (JsonCatalog.GAIT)", "idem", "ciclo"),
    "sprint": ("Marcha (JsonCatalog.GAIT)", "idem", "ciclo"),
    "idle": ("Marcha (JsonCatalog.GAIT, reposo)", "velocidad 0", "ciclo"),
    "turn_start": ("Footballer._json_turn_move (giro sin pelota)", "sin pelota, < 1.3 m/s, joystick a >= 100 grados, pelota a >= 6 m", "raiz y rumbo del clip; marcha"),
    "turn_run": ("Footballer._json_turn_move (giro sin pelota, solo persona)", "sin pelota, 2.2-5.6 m/s, joystick a >= 100 grados", "idem"),
    "slide": ("PlayerActions.try_slide_tackle (barrida)", "planificador de barrida: pie llega a la pelota", "caida/levantarse segun resultado"),
    "tackle_stand": ("PlayerActions (entrada de pie)", "entrada con boton o IA", "segun clip"),
    "shove": ("PlayerActions.shoulder_charge (carga)", "carga junto al portador", "segun clip"),
    "fall": ("PlayerActions._json_fall (caida)", "choque/entrada sufrida", "levantarse (_json_getup)"),
    "getup": ("PlayerActions._json_getup", "tras caida, misma postura (lie)", "marcha"),
    "gk_dive": ("Goalkeeper + KeeperPlanner.plan_save", "tiro a puerta; plan de atajada", "levantarse del arquero"),
    "gk_catch": ("Goalkeeper + KeeperPlanner", "idem blocaje", "arquero con pelota"),
}


def adb(path):
    d = open(path, "rb").read()
    n = struct.unpack_from("<I", d, 0)[0]
    return [struct.unpack_from("<52h", d, 4 + i * 104) for i in range(n)]


def fmt_v(v):
    return "(%s)" % ", ".join("%.3f" % float(x) for x in v) if isinstance(v, list) else ""


# Recurso del juego segun tools/json_anim/selection.json (campo «library»; sin campo = field).
RES_PATH = {"field": "res://assets/animations/json_clips.res", "scenes": "res://assets/animations/json_scenes.res",
            "keeper": "res://assets/animations/json_keeper.res"}
# Ciclos de marcha (JsonCatalog.GAIT / CARRY, scripts/animation/json_catalog.gd).
GAIT = ["jn_idle_0520", "jn_walk_0460", "jn_jog_1144", "jn_jog_2390", "jn_sprint_3022"]
CARRY = ["jn_idle_ball_0524", "jn_dribble_walk_0234", "jn_dribble_jog_1574", "jn_dribble_run_3186",
         "jn_dribble_fast_0548", "jn_dribble_sprint_1582"]
# Diferencia maxima de velocidad (m/s) entre la del jugador y la v_in del clip con la que el sistema que lo elige lo
# acepta (constantes del codigo): JsonBallMove.MAX_DV_STICK / MAX_DV_BUTTON / STEER_MAX_DV / START_MAX_DV,
# JsonReceive.MAX_DV, Footballer._json_turn_move (1.6). Los golpeos no tienen tope: penalizan la diferencia
# (BallHandler.JSON_PLANT_MISMATCH_COST).
DV_RULE = {"ball_turn": (1.5, "JsonBallMove.MAX_DV_STICK"), "ball_skill": (3.0, "JsonBallMove.MAX_DV_BUTTON"),
           "ball_turn_stop": (3.0, "JsonBallMove.MAX_DV_BUTTON"), "ball_start": (1.2, "JsonBallMove.START_MAX_DV"),
           "ball_dribble": (1.6, "JsonBallMove.STEER_MAX_DV"), "receive": (1.2, "JsonReceive.MAX_DV"),
           "receive_turn": (1.2, "JsonReceive.MAX_DV"), "control_stand": (1.2, "JsonReceive.MAX_DV"),
           "jostle_ball": (1.2, "JsonReceive.MAX_DV"), "turn_start": (1.6, "Footballer._json_turn_move"),
           "turn_run": (1.6, "Footballer._json_turn_move")}
BALL_ROLES = {"ball_turn", "ball_skill", "ball_turn_stop", "ball_start", "ball_dribble", "ball_stop", "receive",
              "receive_turn", "control_stand", "jostle_ball"}


def _cycle_near(lib, ids, v, tol=None):
    """Ciclos (id y velocidad natural) a menos de tol m/s de v; sin tol, el mas cercano."""
    pts = [(i, float(lib.get(i, {}).get("natural_speed", 0.0))) for i in ids if i in lib]
    if not pts:
        return []
    if tol is None:
        best = min(pts, key=lambda p: abs(p[1] - v))
        return [best]
    return [p for p in pts if abs(p[1] - v) <= tol]


def transitions(role, m, lib):
    """(entrada, salida): animaciones con las que el clip puede encadenarse segun las reglas del codigo."""
    if not m:
        return "", ""
    if role in [r for r in ("idle", "walk", "jog", "run", "sprint")] or role.startswith("dribble_") or role == "idle_ball":
        return ("BlendSpace de marcha: se mezcla con los escalones vecinos (JsonCatalog.GAIT/CARRY, FootballerVisual)",
                "idem")
    v_in = float(m.get("v_in", 0.0) or 0.0)
    v_out = float(m.get("v_out", 0.0) or 0.0)
    cycles = CARRY if role in BALL_ROLES else GAIT
    if role in DV_RULE:
        tol, src = DV_RULE[role]
        ins = _cycle_near(lib, GAIT + CARRY if role.startswith("receive") or role in ("control_stand", "jostle_ball") else cycles, v_in, tol)
        ent = "desde marcha a %.2f m/s +-%.1f (%s): %s" % (v_in, tol, src, ", ".join("%s (%.2f)" % p for p in ins) or "ningun ciclo")
    elif role.startswith("kick") or role in ("header", "volley"):
        ins = _cycle_near(lib, GAIT + CARRY, v_in)
        ent = "desde marcha (sin tope; penaliza |v_in - v|, BallHandler.JSON_PLANT_MISMATCH_COST); ciclo mas cercano a v_in %.2f: %s" % (v_in, ", ".join("%s (%.2f)" % p for p in ins))
    elif role == "ball_stop":
        ent = "desde conduccion a 2.6-4.6 m/s (JsonBallMove.STOP_MIN_SPEED/STOP_MAX_SPEED): jn_dribble_jog_1574, jn_dribble_run_3186"
    elif role in ("getup", "gk_getup"):
        ent = "tras una caida con la misma postura (PlayerActions._json_getup / Goalkeeper._json_getup)"
    elif role in ("fall", "stumble", "slide", "tackle_stand", "shove"):
        ent = "interrumpe la marcha o la accion vigente con nivel mayor (ActionArbiter.Level)"
    elif m.get("loop"):
        ent = "ciclo"
    else:
        ent = "pose en el sitio si el cuerpo no corre mas que el clip + 1.8 m/s (ActionArbiter.IN_PLACE_SLACK)" if (role not in DV_RULE) else ""
    if role in ("fall",):
        sal = "levantarse (rol getup, misma postura)"
    elif role == "slide":
        sal = "levantarse o caida segun el resultado (PlayerActions._resolve_slide)"
    elif m.get("loop"):
        sal = "ciclo"
    else:
        outs = _cycle_near(lib, cycles, v_out)
        sal = "marcha a v_out %.2f m/s; ciclo mas cercano: %s" % (v_out, ", ".join("%s (%.2f)" % p for p in outs))
    return ent, sal


def load_profiles():
    """Perfiles de recepcion (scripts/player/receive_profiles.gd): id -> (parte, t, estado)."""
    import re
    out = {}
    path = os.path.join(ROOT, "scripts", "player", "receive_profiles.gd")
    for m in re.finditer(r'&"([a-z0-9_]+)": \{"name": "[^"]*", "part": "([a-z_]+)", "t": (-?[0-9.]+), "status": "([a-z_]+)"', open(path, encoding="utf-8").read()):
        out[m.group(1)] = (m.group(2), float(m.group(3)), m.group(4))
    return out


PARTS = {"foot", "foot_air", "thigh", "knee", "chest"}           # JsonReceive.PARTS
SITUATION = {"celebrate", "clap", "celebrate_scorer", "celebrate_team", "thumbs_up", "gesture", "dejected", "angry",
             "defeat_end", "nis_idle", "warmup", "idle_fidget", "idle_ready", "tackle_stand", "jostle", "wall"}  # JsonCatalog.SITUATION_ROLES
GK_ROLES = {"gk_catch", "gk_dive", "gk_scoop", "gk_sidestep", "gk_block"}  # KeeperPlanner.JSON_ROLE_RADIUS


def system_filter(state, role, cid, m, profiles, steer, start):
    """Si el clip pasa el filtro del sistema que lo elige (estado real en el juego, no solo el rol)."""
    if state != "si":
        return "no conectado"
    if not m:
        return "sin metadatos en la libreria"
    base = cid
    if base in steer:
        return "pasa: toque orientado (JsonBallMove.steer_pool)"
    if base in start:
        return "pasa: arranque con pelota (JsonBallMove.start_pool)"
    if role in ("kick_pass", "kick_pass_soft", "kick_shot", "kick_shot_hard", "kick_lob", "kick_cross"):
        ct = m.get("contact")
        if not isinstance(ct, dict):
            return "no pasa: sin contacto medido (JsonCatalog.kick_candidates)"
        if role != "kick_cross" and not ct.get("clean", True):
            return "no pasa: contacto no limpio (JsonCatalog.kick_candidates exige clean)"
        return "pasa: candidato de golpeo (JsonCatalog.kick_candidates)"
    if role in ("kick_turn", "kick_back"):
        ct = m.get("contact")
        if not isinstance(ct, dict):
            return "no pasa: sin contacto medido (BallHandler.plan_turn_kick)"
        pos = ct.get("pos", [0, 0, 0])
        if float(pos[1]) > 0.35:
            return "no pasa: punta a mas de 0.35 m de altura en el contacto (BallHandler.plan_turn_kick)"
        return "pasa: golpeo girando (BallHandler.plan_turn_kick; filtro de giro y, en tiros, pie >= 7 m/s, en cada plan)"
    if role in ("header", "volley"):
        return "planificador por trayectoria de cabeza / punta (meta paths; no se comprueba en este inventario)"
    if role in ("ball_turn", "ball_skill", "ball_turn_stop", "ball_stop", "ball_dribble", "ball_start"):
        if not m.get("ball_touches"):
            return "no pasa: sin toques de pelota medidos (JsonBallMove.plan_ids los exige)"
        return "pasa: movimiento con pelota (JsonBallMove.plan_move / plan_ids)"
    if role in ("receive", "receive_turn", "control_stand", "jostle_ball"):
        pr = profiles.get(base)
        if pr is None:
            return "no pasa: sin perfil de recepcion (ReceiveProfiles)"
        part, t, st = pr
        if st in ("usable", "conditional") and t > 0 and part in PARTS:
            return "pasa: recepcion %s (%s, parte %s)" % (st, "ReceiveProfiles", part)
        return "no pasa: perfil %s, parte %s (JsonReceive.selectable)" % (st, part)
    if role in SITUATION:
        rt = m.get("root_total", [0, 0])
        d = (float(rt[0]) ** 2 + float(rt[1]) ** 2) ** 0.5 if isinstance(rt, list) else 0.0
        if d > 1.0 or float(m.get("duration", 0.0)) < 0.6:
            return "no pasa: recorrido de raiz > 1 m o duracion < 0.6 s (JsonCatalog.situation_clip)"
        return "pasa: situacion de presentacion (JsonCatalog.situation_clip)"
    if role in GK_ROLES:
        return "pasa: candidato de atajada (KeeperPlanner.candidates)"
    return "rol conectado; sin filtro adicional comprobado en este inventario"


def describe(role, m, ucs_name):
    """Movimiento del jugador, con los datos medidos del clip en el juego (giro + = izquierda, raiz adelante/derecha)."""
    if not m:
        return ""
    parts = []
    turn = float(m.get("turn_deg", 0.0) or 0.0)
    if abs(turn) >= 5.0:
        parts.append("gira %.0f grados a la %s" % (abs(turn), "izquierda" if turn > 0 else "derecha"))
    rt = m.get("root_total")
    if isinstance(rt, list) and len(rt) == 2:
        d = (rt[0] ** 2 + rt[1] ** 2) ** 0.5
        if d >= 0.15:
            parts.append("se desplaza %.2f m (%.2f adelante, %.2f a la derecha)" % (d, rt[0], rt[1]))
        else:
            parts.append("en el sitio")
    parts.append("entra a %s m/s y sale a %s m/s" % (m.get("v_in", "?"), m.get("v_out", "?")))
    bt = m.get("ball_touches", [])
    if bt:
        parts.append("%d toque(s) de pelota: %s" % (len(bt), " ".join("%s@%.2fs" % ("der" if int(x[1]) > 0 else "izq", float(x[0])) for x in bt)))
    ct = m.get("contact")
    if isinstance(ct, dict) and "foot" in ct:
        parts.append("golpeo con el pie %s a %.2f s" % ("der" if int(ct["foot"]) > 0 else "izq", float(ct.get("time", 0.0))))
    if m.get("loop"):
        parts.append("ciclo")
    return "; ".join(parts)


def ball_at_contact(m):
    """Donde planifica el juego la pelota en el contacto (marco del inicio del clip: adelante, arriba, derecha)."""
    if not m:
        return ""
    bt = m.get("ball_touches", [])
    out = []
    if bt:
        p = bt[0][2]
        v = bt[0][3]
        n = (v[0] ** 2 + v[1] ** 2) ** 0.5
        lead = (v[0] / n * 0.12, v[1] / n * 0.12) if n > 0.3 else (0.0, 0.0)
        out.append("primer toque: (%.3f, %.3f, %.3f) = punta + 0.12 m en la direccion del pie (JsonBallMove.BALL_LEAD)" % (p[0] + lead[0], p[1], p[2] + lead[1]))
    ct = m.get("contact")
    if isinstance(ct, dict) and "pos" in ct:
        out.append("golpeo: centro de la pelota en la punta (residuo planificado <= 0.18 m, PlayerTuning.kick_start_residual; valido si <= 0.65 m, json_kick_reach)")
    return "; ".join(out)


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    bank = json.load(open(sys.argv[1], encoding="utf-8"))["clips"]
    recs = adb(sys.argv[2])
    lib = json.load(open(sys.argv[3], encoding="utf-8"))
    out_path = sys.argv[4] if len(sys.argv) > 4 else OUT
    e2 = {}
    for r in csv.DictReader(open(os.path.join(ROOT, "docs", "fases", "E2_inventario_banco.csv"), encoding="utf-8")):
        e2.setdefault(r["archivo"][:4], []).append(r)
    adb_json = json.load(open(os.path.join(ROOT, "assets", "animations", "animdb.json"), encoding="utf-8"))
    profiles = load_profiles()
    steer = set(json.load(open(os.path.join(ROOT, "tools", "json_anim", "steer_pool.json"), encoding="utf-8")))
    start = set(json.load(open(os.path.join(ROOT, "tools", "json_anim", "start_pool.json"), encoding="utf-8")))
    sel = {e["id"]: e.get("library", "field") for e in json.load(open(os.path.join(ROOT, "tools", "json_anim", "selection.json"), encoding="utf-8"))["clips"]}
    pkg_dir = os.path.dirname(os.path.abspath(sys.argv[1]))
    pkg_name = os.path.basename(pkg_dir)
    folder = {}
    pkg_inv = os.path.join(pkg_dir, "INVENTARIO.csv")
    if os.path.exists(pkg_inv):
        for r in csv.DictReader(open(pkg_inv, encoding="utf-8")):
            folder[r["archivo"]] = r["carpeta"]
    rows = []
    for c in bank:
        key = c["file"][:4]
        i = int(key)
        h = recs[i] if i < len(recs) else None
        tramos = adb_json["clips"].get(key, {}).get("tramos", [])
        for k, r in enumerate(e2.get(key, [{}])):
            cid = r.get("id", "")
            t = tramos[k] if k < len(tramos) else {}
            m = lib.get(cid, {})
            mirror = cid + "_mirror" if (cid + "_mirror") in lib else ""
            role = r.get("nueva", "")
            rule = ROLE_RULES.get(role, ("ver MAPA_ANIMACIONES.md (rol %s)" % role, "", ""))
            bt = m.get("ball_touches", [])
            touches = "; ".join("t=%.3f pie=%s punta=%s" % (float(x[0]), "der" if int(x[1]) > 0 else "izq", fmt_v(x[2])) for x in bt)
            ct = m.get("contact", {}) if isinstance(m.get("contact", {}), dict) else {}
            ucs = {}
            if h is not None:
                # Significado por campo y familia: DATOS_UCS.md. El campo 3 NO es el cuadro del toque: es el byte 2 de la
                # cabecera del .sat (1832/1832); el cuadro de contacto de los golpeos es el campo 24 (+-2 cuadros en 310/447).
                ucs = {
                    "ucs_campo3_byte_cabecera_sat": h[3],
                    "ucs_campo24_cuadro_evento_pelota": h[24],
                    "ucs_t_evento_pelota_s": round(h[24] / 60.0, 3) if h[24] else "",
                    "ucs_pie_toque": "izq" if h[4] & 128 else ("der" if h[4] & 256 else ""),
                    "ucs_giro_sector_grados": h[9],
                    "ucs_giro_medido_grados_campo47": h[47],
                    "ucs_giro_turn_campo46": h[46],
                    "ucs_ventana_joystick_min": h[7],
                    "ucs_ventana_joystick_max": h[8],
                    "ucs_campo5_x10": h[5],
                    "ucs_campo6_x10": h[6],
                    "ucs_campo40": h[40],
                    "ucs_campo49": h[49],
                    "ucs_destino_adelante_m": round(-h[25] / 1000.0, 3),
                    "ucs_destino_izquierda_m": round(h[27] / 1000.0, 3),
                    "ucs_destino_altura_m": round(h[26] / 1000.0, 3),
                    "ucs_cuadros": h[2],
                }
            meta = c.get("meta", {})
            ent, sal = transitions(role, m, lib)
            row = {
                "indice": key,
                "archivo_json_banco": c["file"],
                "ruta_json_paquete": "%s/%s/%s" % (pkg_name, folder[c["file"]], c["file"]) if c["file"] in folder else "",
                "recurso_juego": ("%s :: %s" % (RES_PATH[sel[cid]], cid)) if cid in sel else "",
                "nombre_ucs": c["name"],
                "categoria": c.get("category", ""),
                "cuadros_60fps": c.get("frames", ""),
                "duracion_s": c.get("duration", ""),
                "tramo": k,
                "id_juego": cid,
                "id_espejo": mirror,
                "libreria": m.get("library", ""),
                "fuente_libreria": m.get("source", ""),
                "accion_rol": role,
                "rol_antes_de_E2": r.get("anterior", ""),
                "estado_conexion": t.get("conectada", r.get("util", "")),
                "filtro_del_sistema": system_filter(t.get("conectada", r.get("util", "")), role, cid, m, profiles, steer, start),
                "sistemas": " | ".join(t.get("sistemas", [])) or r.get("sistema", ""),
                "motivo_estado": t.get("motivo", r.get("motivo", "")),
                "sistema_que_selecciona": rule[0],
                "condicion_entrada": rule[1],
                "condicion_salida": rule[2],
                "movimiento_descripcion": describe(role, m, c["name"]),
                "transicion_entrada_compatible": ent,
                "transicion_salida_compatible": sal,
                "balon_en_contacto_m_adelante_arriba_derecha": ball_at_contact(m),
                "movimiento_heading_mode": m.get("heading_mode", ""),
                "bucle": m.get("loop", ""),
                "giro_cuerpo_juego_grados": round(float(m.get("turn_deg", 0.0)), 1) if m else "",
                "raiz_total_m_adelante_derecha": fmt_v(m.get("root_total")) if m else "",
                "v_in_juego_m_s": m.get("v_in", ""),
                "v_out_juego_m_s": m.get("v_out", ""),
                "toques_pelota_juego": touches,
                "contacto_golpe_t_s": ct.get("time", ""),
                "contacto_golpe_pie": ("der" if int(ct["foot"]) > 0 else "izq") if "foot" in ct else "",
                "contacto_golpe_punta_m_adelante_arriba_derecha": fmt_v(ct.get("pos")),
                "contacto_golpe_vel_pie_m_s": ct.get("speed", ""),
                "contacto_golpe_limpio": ct.get("clean", ""),
                "contacto_golpe_giro_salida_grados": ct.get("kick_turn", ""),
                "json_toques_cuadro_pie": " ".join("%s%s" % (x[0], x[1]) for x in meta.get("touches", [])),
                "json_dir_out_grados": meta.get("dir_out", ""),
                "json_yaw_end_grados": meta.get("yaw_end", ""),
            }
            row.update(ucs)
            rows.append(row)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    keys = list(rows[0].keys())
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    w = csv.DictWriter(open(out_path, "w", newline="", encoding="utf-8"), fieldnames=keys)
    w.writeheader()
    w.writerows(rows)
    print("inventario:", out_path, len(rows), "filas,", len(keys), "columnas")


if __name__ == "__main__":
    main()
