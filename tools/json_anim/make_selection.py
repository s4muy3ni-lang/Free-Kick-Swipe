#!/usr/bin/env python3
"""Genera tools/json_anim/selection.json: TODOS los clips de animaciones_futbol5_JSON (2 022) pasan al modo Json, con su rol.

Uso: python3 tools/json_anim/make_selection.py <carpeta_de_los_JSON>
Primero las listas curadas a mano (marcha, conduccion, patadas medidas, celebraciones, arquero...); despues una pasada
automatica que clasifica el resto por categoria, por las palabras del nombre y por geometria medida en las articulaciones
(cuanto gira el cuerpo, hacia donde sale la pelota en el golpeo, como queda tendido al caer). Los nombres de giro del zip
(«_R», «_L») no siempre coinciden con el lado real de los datos: el lado se mide, no se lee del nombre. Cada entrada:
  file    prefijo numerico del archivo (0000-4043)         id      nombre en la libreria (jn_<rol>_<indice>)
  role    para que lo usa el juego (AnimationCatalog)       alias   nombres de clips del pack de Mixamo a los que sustituye en el modo Json
  loop / phase (bucle girado hasta un apoyo izquierdo) / cycle (ciclo recortado entre dos apoyos del mismo pie, 60 Hz)
  mirror  tambien la version espejo (<id>_mirror)           only_mirror  solo el espejo (el ciclo empieza con el pie izquierdo)
  kick    mide el contacto del golpeo                        root_driven  el juego mueve al cuerpo con la raiz del clip (caidas, barridas, saques)
  hi      claves a 60 Hz en vez de 30                        library  field | keeper | scenes (festejos, gestos, escenas)
  heading "turn": el juego gira al jugador con el rumbo del clip (heading_path) y lo mueve con su raiz (giros, giros con
          pelota, golpeos girando); move  accion de cuerpo entero con raiz y rumbo (ActionMotion)
  ball    toques de pelota del clip medidos (ball_touches: donde esta la punta del pie en cada toque)
  paths   guarda las trayectorias de pies/manos/cabeza (las usan los planificadores; sin ellas el clip pesa menos)
"""
import json, math, os, re, sys

src = sys.argv[1]
idx = json.load(open(os.path.join(src, "index.json")))
by_prefix = {c["file"][:4]: c for c in idx["clips"]}
clips = []
ids = set()


def add(prefix, role, **kw):
    c = by_prefix.get(prefix)
    if c is None:
        print("falta", prefix)
        return None
    cid = kw.pop("id", None) or "jn_%s_%s" % (role, prefix)
    if cid in ids:
        cid = cid + "b"
    ids.add(cid)
    e = {"file": prefix, "id": cid, "role": role}
    e.update(kw)
    clips.append(e)
    return e


def first_stride(c, foot):
    for fr, f in c["meta"]["strides"]:
        if f == foot:
            return fr
    return None


# --- Marcha en bucle (todos empiezan en un apoyo del pie izquierdo; el espejo, del derecho original) -------------------------
for p in ["0520", "1138", "1140", "1142"]:
    add(p, "idle", loop=True)
add("0524", "idle_ball", loop=True)
for role, plist in [("walk", ["0460", "1474", "2024", "3498"]), ("jog", ["1144", "2390"]), ("run", ["2392", "0190"]),
                    ("sprint", ["3022", "0072", "0074", "2036", "2034"])]:
    for p in plist:
        c = by_prefix[p]
        add(p, role, loop=True, phase=first_stride(c, "L"))

# Direcciones (BlendSpace2D del marcaje): la direccion de cada clip se mide en los datos; el espejo da el lado contrario.
for p, role in [("0486", "dir_back"), ("0480", "dir_back_diag"), ("0470", "dir_fwd_diag"), ("0186", "dir_side"), ("1482", "dir_back_walk"), ("1476", "dir_fwd_diag_walk")]:
    c = by_prefix[p]
    fl = first_stride(c, "L")
    fr_ = first_stride(c, "R")
    add(p, role, loop=True, mirror=True, phase=fl if fl is not None else 0, phase_mirror=fr_ if fr_ is not None else 0)


# --- Conduccion: ciclos entre dos apoyos del mismo pie (con el pie izquierdo primero) -----------------------------------------
def dribble_cycle(prefix, role):
    c = by_prefix[prefix]
    st = c["meta"]["strides"]
    if len(st) < 3 or st[0][1] != st[2][1]:
        print("sin ciclo", prefix, st)
        return
    kw = {"cycle": [st[0][0], st[2][0]], "dribble": True, "hi": True}
    if st[0][1] == "R":
        kw["only_mirror"] = True
    add(prefix, role, **kw)


c = by_prefix["0234"]
st = c["meta"]["strides"]
add("0234", "dribble_walk", cycle=[st[0][0], st[2][0]], dribble=True, hi=True, only_mirror=(st[0][1] == "R"))
for p in ["1574", "2106"]:
    dribble_cycle(p, "dribble_jog")
for p in ["1288", "3186", "3184"]:
    dribble_cycle(p, "dribble_run")
for p in ["0194", "2092", "0548"]:
    dribble_cycle(p, "dribble_fast")
for p in ["1582", "3190", "1584"]:
    dribble_cycle(p, "dribble_sprint")

# --- Patadas: pase / tiro / vaselina / centro (pierna que patea la de los datos; mirror da la otra) --------------------------
KICK_PASS_SOFT = ["0626", "1608", "1616", "2462", "3052", "1600", "2458"]
KICK_PASS = ["0636", "3056", "3086", "2194", "3652", "3654", "3660", "1204", "1208", "0672", "0668", "3238"]
# Tiros: con la carrera de entrada de cada clip (v_in) desde parado (0.0-1.2 m/s) hasta sprint (4 m/s), para que el pie de apoyo no patine.
KICK_SHOT = ["0656", "2520", "2524", "2988", "3246", "3598", "3588", "3580", "3666", "2202", "2200", "2204", "0694", "0748", "1752", "1754", "1756", "1758", "2528", "2522", "3584"]
KICK_SHOT_HARD = ["2548", "2550", "2544", "3254", "3256", "3260", "3264", "3780", "3610", "3618"]
KICK_LOB = ["0646", "0666", "0654", "0652"]
KICK_CROSS = ["0666"]
for p in KICK_PASS_SOFT:
    add(p, "kick_pass_soft", kick=True, hi=True, mirror=True, paths=True)
for p in KICK_PASS:
    add(p, "kick_pass", kick=True, hi=True, mirror=True, paths=True, alias=["Soccer_Pass"] if p == "0636" else [])
for p in KICK_SHOT:
    add(p, "kick_shot", kick=True, hi=True, mirror=True, paths=True)
for p in KICK_SHOT_HARD:
    add(p, "kick_shot_hard", kick=True, hi=True, mirror=True, paths=True)
for p in KICK_LOB:
    add(p, "kick_lob", kick=True, hi=True, mirror=True, paths=True)

# Pelota en el aire: cabezazos y voleas (el planificador aereo busca el instante en que la cabeza / el pie coincide con la pelota).
for p in ["1844", "1846", "2232", "0832", "1858", "2628", "2652", "1848"]:
    add(p, "header", hi=True, mirror=True, paths=True)
for p in ["0732", "0734", "2562", "2570", "2572", "3284", "3294"]:
    add(p, "volley", kick=True, hi=True, mirror=True, paths=True)

# --- Control de balon / recepcion -------------------------------------------------------------------------------------------
add("0582", "receive_chest", alias=["Receive"])
add("0564", "receive_foot", alias=["receive_soccerball"], mirror=True)
add("0576", "receive_foot", mirror=True)
add("0578", "receive_foot")

# --- Entradas, caidas, levantarse (el juego mueve al cuerpo con la raiz) -------------------------------------------------------
add("0220", "slide", root_driven=True, mirror=True, hi=True, alias=["soccer_tackle"])
add("0086", "slide", root_driven=True, mirror=True, hi=True, alias=["soccer_tackle_2"])
add("3542", "slide", root_driven=True, mirror=True, hi=True, alias=["soccer_tackle_3"])
add("2746", "slide", root_driven=True, mirror=True, hi=True)
add("0860", "trip", root_driven=True, mirror=True, alias=["soccer_trip"])
add("2352", "fall_hit", root_driven=True, mirror=True, alias=["Shoulder_Hit_And_Fall", "Sprint_To_Backslide"])
add("3514", "fall", root_driven=True, mirror=True, alias=["Falling_Down"])
add("3512", "fall", root_driven=True, mirror=True, alias=["Sweep_Fall"])
add("0980", "fall", root_driven=True, mirror=True)
add("0856", "lie", loop=True, root_driven=True, alias=["fallen_idle"])
add("0810", "getup", root_driven=True, alias=["standing_up"])
add("0806", "getup", root_driven=True, alias=["Getting_Up_3"])
add("0808", "getup", root_driven=True)
add("2238", "getup", root_driven=True)
add("2418", "shove", root_driven=True, alias=["Shove_Reaction"])
add("2420", "shove", root_driven=True, alias=["Shove_Reaction_2"])
add("1440", "stumble", root_driven=True, mirror=True, alias=["Jogging_Stumble"])
add("1260", "stumble_light", alias=["Jogging_Stumble_inplace"])
add("0336", "jump", alias=["Jumping_Up", "Jump_4", "Jump_2"])

# --- Celebraciones y gestos (NIS) -----------------------------------------------------------------------------------------------
add("0090", "celebrate", alias=["Fist_Pump_3"])
add("0092", "celebrate", alias=["Cheering_2"])
add("0338", "celebrate", alias=["Fist_Pump"])
add("1954", "celebrate", alias=["Standing_Fist_Pump"])
add("0874", "celebrate_scorer", alias=["Excited"])
add("0942", "celebrate_scorer", alias=["Victory"])
add("1950", "celebrate_scorer", alias=["Taunt"])
add("1952", "celebrate_scorer", alias=["Cheering"])
add("0298", "celebrate_team", alias=["Clapping"])
add("2014", "celebrate_team", alias=["Waving_3", "Waving"])
add("2020", "celebrate_team", alias=["Pointing_2"])
add("1462", "thumbs_up", alias=["Standing_Thumbs_Up"])
add("1968", "dejected", alias=["Defeat_Idle_2"])
add("1974", "dejected", alias=["Disappointed"])
add("0102", "dejected", alias=["Sad_Idle_3"])
add("0104", "dejected", alias=["Crying"])
add("0112", "dejected", alias=["Defeated"])
add("1418", "dejected", alias=["Loser"])
add("0956", "defeat_end", alias=["Defeat"])
add("0356", "angry", alias=["Angry_Gesture_2", "Angry"])
add("0366", "angry", alias=["Standing_Yell_2"])
add("0368", "angry", alias=["Yelling_While_Standing"])
add("0320", "warmup", alias=["Arm_Stretching"])
add("0322", "warmup", alias=["Neck_Stretching"])
add("0360", "referee", alias=["Counting"])
add("0362", "referee", alias=["Pointing_Forward"])
add("0364", "referee")

# --- Saques: banda y balon parado ---------------------------------------------------------------------------------------------------
add("2508", "throw_in", throw=True, root_driven=True, alias=["throw_in"])
add("2506", "throw_in", throw=True, root_driven=True)
add("3446", "throw_in", throw=True, root_driven=True)
for p, al in [("3744", ["strike_foward_jog"]), ("3738", []), ("3732", [])]:
    add(p, "setpiece_pass", kick=True, root_driven=True, hi=True, mirror=True, alias=al)
for p, al in [("3856", ["soccer_penalty_kick"]), ("3850", []), ("3846", []), ("3840", [])]:
    add(p, "setpiece_shot", kick=True, root_driven=True, hi=True, mirror=True, alias=al)
for p, al in [("3742", ["Chip"]), ("3746", [])]:
    add(p, "setpiece_lob", kick=True, root_driven=True, hi=True, mirror=True, alias=al)

# --- Arquero (libreria aparte) ----------------------------------------------------------------------------------------------------------
K = {"library": "keeper"}
add("0884", "gk_idle", loop=True, alias=["goalkeeper_idle"], **K)
add("3548", "gk_idle", loop=True, **K)
add("3552", "gk_idle", loop=True, **K)
add("0496", "gk_idle_ball", loop=True, alias=["goalkeeper_idle_2"], **K)
# Estiradas (laterales: el espejo da el otro lado), con la raiz del clip.
for p, al in [("0000", ["goalkeeper_diving_save"]), ("0002", []), ("0010", ["goalkeeper_diving_save_2"]), ("0012", []), ("0014", []),
              ("0006", []), ("0008", []), ("0028", []), ("0030", []), ("0034", []), ("0038", []), ("0020", []), ("0024", []),
              ("3796", []), ("3798", []), ("3804", []), ("2632", []), ("2634", []), ("3928", []), ("3930", []), ("1688", []), ("1690", []),
              ("1694", []), ("1698", []), ("0910", []), ("0912", []), ("0914", []), ("0920", []), ("0924", []), ("0926", [])]:
    add(p, "gk_dive", mirror=True, root_driven=True, hi=True, alias=al, **K)
for p, al in [("0888", ["goalkeeper_catch_2"]), ("0892", []), ("0894", []), ("0900", []), ("0896", ["goalkeeper_catch_4"]), ("1742", ["goalkeeper_catch_3"]),
              ("1746", []), ("1748", []), ("1750", []), ("2678", []), ("2680", []), ("2682", []), ("2684", []), ("2686", []), ("2690", []),
              ("2692", []), ("2698", []), ("2704", []), ("0930", []), ("0932", [])]:
    add(p, "gk_catch", mirror=True, root_driven=True, hi=True, alias=al, **K)
for p, al in [("0898", ["goalkeeper_scoop"]), ("1722", []), ("1726", []), ("1728", []), ("1732", []), ("1736", []), ("1740", ["goalkeeper_catch"]), ("2658", []), ("2660", [])]:
    add(p, "gk_scoop", mirror=True, root_driven=True, hi=True, alias=al, **K)
add("0184", "gk_sidestep", mirror=True, loop=True, root_driven=True, alias=["goalkeeper_sidestep", "goalkeeper_sidestep_2"], **K)
for p, al in [("0054", ["goalkeeper_body_block"]), ("0928", ["goalkeeper_body_block_2"]), ("0044", ["goalkeeper_body_block_3"]), ("0052", [])]:
    add(p, "gk_block", mirror=True, root_driven=True, alias=al, **K)
add("0046", "gk_miss", mirror=True, root_driven=True, alias=["goalkeeper_miss"], **K)
add("0068", "gk_throw", throw=True, root_driven=True, alias=["goalkeeper_overhand_throw", "Goalie_Throw"], **K)
add("1874", "gk_throw", throw=True, root_driven=True, **K)
add("1878", "gk_throw", throw=True, root_driven=True, **K)
add("0066", "gk_roll", throw=True, root_driven=True, alias=["goalkeeper_pass"], **K)
add("1876", "gk_roll", throw=True, root_driven=True, **K)
for p, al in [("1884", ["goalkeeper_drop_kick"]), ("2706", []), ("2708", []), ("2710", []), ("3412", []), ("3410", [])]:
    add(p, "gk_kick", kick=True, root_driven=True, mirror=True, hi=True, alias=al, **K)
add("0178", "gk_place", root_driven=True, alias=["goalkeeper_placing_ball"], **K)
add("0312", "gk_place", root_driven=True, alias=["goalkeeper_placing_ball_2"], **K)
add("0362", "gk_direct", alias=["goalkeeper_directing"], id="jn_gk_direct_0362", **K)
add("0364", "gk_direct", alias=["goalkeeper_directing_2"], id="jn_gk_direct_0364", **K)


# =====================================================================================================================
# Pasada automatica: todo lo que no esta en las listas curadas.
# =====================================================================================================================
files = {}
for fn in os.listdir(src):
    if fn[:4].isdigit() and fn.endswith(".json"):
        files[fn[:4]] = os.path.join(src, fn)


class Geo:
    """Medidas sobre las articulaciones de un clip (adelante = -z de los datos, derecha = +x)."""

    def __init__(self, prefix):
        d = json.load(open(files[prefix]))
        self.d = d
        self.ix = {n: i for i, n in enumerate(d["joint_names"])}
        self.times = d["times"]
        self.frames = d["frames"]

    def _seg(self, f):
        t = self.times
        f = max(t[0], min(t[-1], f))
        i = 0
        while i < len(t) - 2 and f > t[i + 1]:
            i += 1
        u = 0.0 if t[i + 1] <= t[i] else (f - t[i]) / (t[i + 1] - t[i])
        return i, u

    def joint(self, f, n):
        i, u = self._seg(f)
        a = self.d["joints"][i][self.ix[n]]
        b = self.d["joints"][i + 1][self.ix[n]]
        g = [a[k] + (b[k] - a[k]) * u for k in range(3)]
        return (-g[2], g[1], g[0])

    def yaw(self, f):
        l = self.joint(f, "l_hip")
        r = self.joint(f, "r_hip")
        return math.atan2(r[0] - l[0], r[2] - l[2])   # + = izquierda

    def turn(self, f1):
        """Giro acumulado (grados, + izquierda) del cuerpo entre el inicio y el fotograma f1."""
        acc = 0.0
        last = self.yaw(0)
        n = max(2, int(f1 / 2) + 1)
        for i in range(1, n + 1):
            y = self.yaw(f1 * i / n)
            dd = y - last
            while dd > math.pi:
                dd -= 2 * math.pi
            while dd < -math.pi:
                dd += 2 * math.pi
            acc += dd
            last = y
        return math.degrees(acc)

    def lie(self, f):
        """Como queda tendido: 'back' (boca arriba), 'front' (boca abajo), 'side' o 'up' (de pie)."""
        p = self.joint(f, "pelvis")
        c = self.joint(f, "chest")
        h = self.joint(f, "head")
        if h[1] > 1.0:
            return "up"
        lc = self.joint(f, "l_clavicle")
        rc = self.joint(f, "r_clavicle")
        sp = (c[0] - p[0], c[1] - p[1], c[2] - p[2])
        lat = (rc[0] - lc[0], rc[1] - lc[1], rc[2] - lc[2])
        # Normal del pecho (hacia delante del cuerpo) = columna x lateral; arriba = boca arriba.
        nrm = (sp[1] * lat[2] - sp[2] * lat[1], sp[2] * lat[0] - sp[0] * lat[2], sp[0] * lat[1] - sp[1] * lat[0])
        ln = math.sqrt(sum(v * v for v in nrm)) or 1.0
        ny = nrm[1] / ln
        if ny > 0.45:
            return "back"
        if ny < -0.45:
            return "front"
        return "side"


def toks(c):
    n = c["name"]
    return set(t for t in re.split(r"[_ ]+", n.upper()) if t)


def has(c, *words):
    n = c["name"].upper()
    return any(w in n for w in words)


auto_count = {}


def auto(prefix, role, **kw):
    kw.setdefault("paths", False)
    e = add(prefix, role, **kw)
    if e is not None:
        auto_count[role] = auto_count.get(role, 0) + 1
    return e


done = set(e["file"] for e in clips)
for prefix in sorted(by_prefix):
    if prefix in done:
        continue
    c = by_prefix[prefix]
    cat = c["category"]
    m = c["meta"]
    g = Geo(prefix)
    last = max(g.frames - 1, 1)
    dyaw = g.turn(last)
    vin = float(m.get("v_in", 0.0))
    vout = float(m.get("v_out", 0.0))
    gk = has(c, "_GK", "GK_", "KEEPER", "GOALKEEPER", "GOALIE")
    loop = bool(m.get("loop", False))
    if cat == "GKSAVE":
        reach = m.get("reach", [0.0, 0.5, 0.0])
        side = abs(float(reach[0]))
        hy = float(reach[1])
        if has(c, "BLOCK", "SMOTHER", "SPREAD"):
            role = "gk_block"
        elif has(c, "PICKUP", "COLLECT", "SCOOP", "GATHER") and hy < 0.8:
            role = "gk_scoop"
        elif side >= 0.85 or has(c, "DIVE"):
            role = "gk_dive"
        elif hy < 0.45 and side < 0.7:
            role = "gk_scoop"
        else:
            role = "gk_catch"
        auto(prefix, role, mirror=True, root_driven=True, hi=True, paths=True, library="keeper")
    elif cat == "GKTHROW":
        auto(prefix, "gk_roll" if has(c, "ROLL") else "gk_throw", throw=True, root_driven=True, paths=True, library="keeper")
    elif cat == "GKKICK":
        auto(prefix, "gk_kick", kick=True, root_driven=True, mirror=True, hi=True, paths=True, library="keeper")
    elif gk and cat in ("GETUP", "STAND", "TURN", "LOCO", "NIS", "FALL"):
        role = {"GETUP": "gk_getup", "STAND": "gk_idle_var", "TURN": "gk_turn", "LOCO": "gk_loco", "NIS": "gk_gesture", "FALL": "gk_fall"}[cat]
        kw = {"library": "keeper", "root_driven": cat in ("GETUP", "FALL", "NIS"), "paths": cat == "GETUP"}
        if cat == "TURN":
            kw = {"library": "keeper", "move": True, "heading": "turn", "mirror": True}
        if cat in ("STAND", "LOCO") and loop:
            kw["loop"] = True
        auto(prefix, role, **kw)
    elif cat == "LOCO":
        if has(c, "JOSTLE"):
            role = "jostle"
        elif has(c, "BACKWARD"):
            role = "loco_back"
        elif has(c, "STRAFE", "SIDESTEP", "SS"):
            role = "loco_side"
        elif has(c, "SPRINT"):
            role = "loco_sprint"
        elif has(c, "JOG", "RUN"):
            role = "loco_jog"
        elif has(c, "WALK"):
            role = "loco_walk"
        else:
            role = "loco_misc"
        st = m.get("strides", [])
        fl = next((f for f, ft in st if ft == "L"), None)
        kw = {"loop": True, "phase": fl or 0} if loop else {"move": True, "heading": "turn"}
        auto(prefix, role, **kw)
    elif cat == "SIDESTEP":
        auto(prefix, "sidestep", move=True, heading="turn", mirror=True)
    elif cat == "TURN":
        if has(c, "WITH_BALL"):
            auto(prefix, "ball_turn", move=True, heading="turn", ball=True, mirror=True, hi=True)
            continue
        if has(c, "THROW"):
            auto(prefix, "throw_prep", move=True, heading="turn")
            continue
        if vin < 1.0 and vout < 1.0:
            role = "turn_stand" if abs(dyaw) >= 30 else "step_stand"
        elif vin < 1.0:
            role = "turn_start" if abs(dyaw) >= 30 else "start"
        elif vout < 0.7:
            role = "turn_stop" if abs(dyaw) >= 30 else "stop"
        else:
            role = "turn_run" if abs(dyaw) >= 30 else "run_change"
        auto(prefix, role, move=True, heading="turn", mirror=True, hi=True)
    elif cat == "CONTROL":
        nt = len(m.get("touches", []))
        if has(c, "JOSTLE"):
            role = "jostle_ball"
        elif has(c, "PUT_R_FOOT_ON_BALL", "FOOT_ON_BALL"):
            role = "ball_sole"
        elif has(c, "DEEK", "SPECIAL", "FLICK", "HEELCHOP", "SKILL"):
            role = "ball_skill"
        elif has(c, "RECEIVE", "CHEST", "THIGH", "HEAD", "KNEE", "HIGH", "AIR", "MEDIUM", "OVERHEAD", "BALL_IN", "BALL_COMES"):
            role = "receive_turn" if abs(dyaw) >= 40 else "receive"
        elif abs(dyaw) >= 35 and vout >= 0.6:
            role = "ball_turn"
        elif vin >= 1.2 and vout < 0.6:
            role = "ball_stop"
        elif vin < 0.9 and vout >= 1.2:
            role = "ball_start"
        elif abs(dyaw) >= 35:
            role = "ball_turn_stop"
        elif vin >= 1.0:
            role = "ball_dribble"
        else:
            role = "control_stand"
        auto(prefix, role, move=True, heading="turn", ball=True, mirror=True, hi=True)
    elif cat == "KICK":
        ct = int(m.get("contact", 0))
        strike = m.get("strike", "foot")
        kind = m.get("kind", "")
        power = m.get("power", "")
        ch = float(m.get("contact_h", 0.0))
        kick_turn = -float(m.get("kick_dir", 0.0))
        spd = float(m.get("kick_speed", 0.0))
        if strike == "head" or kind in ("header", "head"):
            auto(prefix, "header", hi=True, mirror=True, paths=True)
            continue
        if kind == "volley" or ch > 0.45 or m.get("airborne", False):
            auto(prefix, "volley", kick=True, hi=True, mirror=True, paths=True)
            continue
        if abs(kick_turn) >= 45.0:
            # Golpeo hacia un costado o hacia atras (girando el cuerpo, de taco, de rabona...): el juego lo usa cuando el
            # destino queda lejos del frente del jugador (no patea de espaldas).
            role = "kick_turn" if abs(kick_turn) < 140.0 else "kick_back"
            auto(prefix, role, kick=True, hi=True, mirror=True, paths=True, heading="turn")
            continue
        if kind in ("lob", "chip"):
            role = "kick_lob"
        elif kind == "cross":
            role = "kick_cross"
        elif kind == "shot":
            role = "kick_shot_hard" if (power == "hard" or spd >= 15.0) else "kick_shot"
        elif kind == "pass":
            role = "kick_pass_soft" if (power == "soft" or spd < 7.0) else "kick_pass"
        elif kind in ("heel", "flick"):
            role = "kick_flick"
        else:
            if power == "soft" or spd < 7.0:
                role = "kick_pass_soft"
            elif spd < 11.0:
                role = "kick_pass"
            elif spd < 15.0 and power != "hard":
                role = "kick_shot"
            else:
                role = "kick_shot_hard"
        auto(prefix, role, kick=True, hi=True, mirror=True, paths=True)
    elif cat == "KICKSETPIECE":
        spd = float(m.get("kick_speed", 0.0))
        role = "setpiece_shot" if spd >= 13.0 else "setpiece_pass"
        auto(prefix, role, kick=True, root_driven=True, hi=True, mirror=True, paths=True)
    elif cat == "THROW":
        auto(prefix, "throw_in", throw=True, root_driven=True, paths=True)
    elif cat == "TACKLESLIDE":
        auto(prefix, "slide", root_driven=True, mirror=True, hi=True, paths=True)
    elif cat == "TACKLE":
        auto(prefix, "tackle_stand", root_driven=True, mirror=True, hi=True, paths=True)
    elif cat == "FALL":
        auto(prefix, "fall", root_driven=True, mirror=True, lie=g.lie(last))
    elif cat == "STUMBLE":
        if has(c, "AVOID", "JUMP", "DUMMY", "FLINCH"):
            role = "avoid"
        else:
            role = "stumble"
        auto(prefix, role, root_driven=True, mirror=True)
    elif cat == "GETUP":
        start_pose = g.lie(0)
        auto(prefix, "getup", root_driven=True, lie=start_pose if start_pose != "up" else "side")
    elif cat == "STAND":
        if has(c, "WALL"):
            role = "wall"
        elif has(c, "JOSTLE"):
            role = "jostle"
        elif has(c, "DRIB", "BALL"):
            role = "idle_ball_var"
        elif has(c, "READY", "KICKOFF", "INTRO"):
            role = "idle_ready"
        else:
            role = "idle_fidget"
        auto(prefix, role, loop=True, library="scenes") if loop else auto(prefix, role, library="scenes")
    elif cat == "NIS":
        # Escenas (festejos, lamentos, gestos, tecnicos, mascotas, publico...): el rol sale del nombre.
        if has(c, "MANAGER", "COACH"):
            role = "manager"
        elif has(c, "MASCOT"):
            role = "mascot"
        elif has(c, "CROWD", "FAN"):
            role = "crowd"
        elif has(c, "REF"):
            role = "referee"
        elif has(c, "UNHAPPY", "UPSET", "SUBDUED", "SAD", "DEJECT", "DISAPPOINT", "LOSE", "LOST"):
            role = "dejected"
        elif has(c, "ANGRY", "ARGU", "PROTEST", "SHOUT"):
            role = "angry"
        elif has(c, "2MAN", "TWO_MAN", "HUG", "TEAM", "GROUP"):
            role = "celebrate_team"
        elif has(c, "CLAP", "APPLAU"):
            role = "clap"
        elif has(c, "CELEB", "HAPPY", "EXCITED", "SCORE", "GOAL", "CHEER", "FIST"):
            role = "celebrate_scorer" if has(c, "SCORE", "GOAL", "SLIDE", "KNEE", "RUN") else "celebrate"
        elif has(c, "WARMUP", "WARM_UP", "STRETCH"):
            role = "warmup"
        elif has(c, "WALK", "LOCO", "INTRO", "RUN", "JOG"):
            role = "nis_walk"
        elif has(c, "SIT"):
            role = "nis_sit"
        elif has(c, "POINT", "GESTURE", "WAVE", "SIGNAL", "INSTRUCT"):
            role = "gesture"
        elif has(c, "IDLE", "FIDGET", "LOOK", "ARMFOLD", "STAND", "WAIT"):
            role = "nis_idle"
        else:
            role = "nis_misc"
        auto(prefix, role, root_driven=True, library="scenes")
    else:
        auto(prefix, "misc", root_driven=True)

# Postura tendida de caidas (al terminar) y de levantarse / quedar tendido (al empezar), tambien en las curadas: el juego
# encadena la caida con un levantarse que empieza en la misma postura (boca arriba, boca abajo o de costado).
for e in clips:
    if e["role"] in ("fall", "fall_hit", "trip", "lie", "getup", "gk_getup", "gk_dive", "gk_catch", "gk_scoop", "gk_block") and "lie" not in e:
        g = Geo(e["file"])
        f = 0 if e["role"] in ("getup", "lie", "gk_getup") else max(g.frames - 1, 1)
        pose = g.lie(f)
        e["lie"] = pose if pose != "up" else "side"

print("automaticos:", sum(auto_count.values()), auto_count)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "selection.json")
json.dump({"clips": clips}, open(out, "w"), indent=1)
roles = {}
for e in clips:
    roles[e["role"]] = roles.get(e["role"], 0) + (2 if e.get("mirror") else 1)
print(len(clips), "entradas,", sum(roles.values()), "clips con espejos")
print(roles)
