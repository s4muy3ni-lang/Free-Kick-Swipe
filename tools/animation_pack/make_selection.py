#!/usr/bin/env python3
"""Genera tools/animation_pack/selection.json con los 133 clips del pack a partir de pack/indice_futbol.json.
Los criterios (bucle, espejo, tipo de contacto, rol) son datos curados a mano aqui.
Uso: python3 tools/animation_pack/make_selection.py
"""
import json, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
idx = json.load(open(os.path.join(ROOT, "pack", "indice_futbol.json"), encoding="utf-8"))
old = {c["id"]: c for c in json.load(open(os.path.join(ROOT, "tools/animation_pack/selection.json")))["clips"]}

LOOP = {"offensive_idle", "Soccer_Idle", "goalkeeper_idle", "goalkeeper_idle_2", "fallen_idle", "Writhing_In_Pain", "Dribble_2",
        "Walking_7", "Walking_7_inplace", "Jogging", "Jogging_inplace", "Running", "Running_inplace", "Sprint", "Sprint_inplace",
        "Two_Cycle_Sprint", "Two_Cycle_Sprint_inplace", "Strafe_3", "Strafe_3_inplace"}
LOOP |= {n for n in [i["archivo_en_zip"].split("/")[-1][:-4] for i in idx] if n.startswith("jog_")}
MIRROR = {"Soccer_Pass", "strike_foward_jog_inplace", "strike_foward_jog", "Chip", "soccer_penalty_kick", "scissor_kick",
          "Flying_Bicycle_Kick", "soccer_tackle", "soccer_tackle_2", "soccer_tackle_3", "soccer_trip", "Shoulder_Hit_And_Fall",
          "Shove_Reaction", "Shove_Reaction_2", "Jogging_Stumble", "Jogging_Stumble_inplace", "Sweep_Fall", "Falling_Down",
          "Fall_Flat", "throw_in", "Header", "Soccer_Header", "header_soccerball", "header_soccerball_2"}
MIRROR |= {"goalkeeper_catch", "goalkeeper_catch_2", "goalkeeper_catch_3", "goalkeeper_catch_4", "goalkeeper_body_block",
           "goalkeeper_body_block_2", "goalkeeper_body_block_3", "goalkeeper_scoop", "goalkeeper_miss", "goalkeeper_overhand_throw",
           "Goalie_Throw", "goalkeeper_pass", "goalkeeper_drop_kick", "goalkeeper_placing_ball"}
FOOT = {"Soccer_Pass", "strike_foward_jog_inplace", "strike_foward_jog", "Chip", "soccer_penalty_kick", "scissor_kick",
        "Flying_Bicycle_Kick", "kick_soccerball", "kick_soccerball_2", "kick_up_soccerball", "soccer_tackle", "soccer_tackle_2",
        "soccer_tackle_3", "soccer_trip", "Defender", "Soccer_Spin", "transition"}
HEAD = {"Header", "Soccer_Header", "header_soccerball", "header_soccerball_2", "Jumping_Up", "Defender_2", "Jump_4", "Jump_2"}
ROLE = {}
def role(names, r):
    for n in names: ROLE[n] = r
role(["offensive_idle", "Walking_7_inplace", "Jogging_inplace", "jog_forward_inplace", "Running_inplace", "Sprint_inplace", "Two_Cycle_Sprint_inplace"], "marcha")
role(["Soccer_Idle", "Dribble_2"], "marcha_con_balon")
role([n for n in LOOP if n.startswith("jog_") and n.endswith("_inplace")] + ["Strafe_3_inplace"], "direccional")
role(["Soccer_Pass", "strike_foward_jog_inplace"], "pase_tiro")
role(["kick_soccerball", "kick_soccerball_2", "scissor_kick", "Flying_Bicycle_Kick"], "volea")
role(["Header", "Soccer_Header", "header_soccerball", "header_soccerball_2"], "cabezazo")
role(["Receive"], "recepcion")
role(["Soccer_Spin", "Sprint_Turn", "Idle_To_Sprint", "Sprint_To_Backslide_inplace"], "habilidad")
role(["soccer_tackle", "soccer_tackle_2", "soccer_tackle_3", "Defender"], "entrada")
role(["soccer_trip", "Shoulder_Hit_And_Fall", "Falling_Down", "Fall_Flat", "Sweep_Fall", "Jogging_Stumble_inplace", "Shove_Reaction", "Shove_Reaction_2", "Defender_2"], "contacto_caida")
role(["fallen_idle", "Writhing_In_Pain", "Getting_Up_3", "standing_up"], "suelo")
role(["Running_Tired"], "cansancio")
role(["Jump_2", "Jump_4", "Jumping_Up"], "salto")
role(["Cheering", "Cheering_2", "Excited", "Fist_Pump", "Fist_Pump_3", "Standing_Fist_Pump", "Victory", "Taunt", "Pointing_2", "Waving", "Waving_3", "Yell"], "festejo")
role(["Clapping", "Standing_Thumbs_Up"], "felicitar")
role(["Crying", "Defeat", "Defeat_Idle_2", "Defeated", "Disappointed", "Loser", "Sad_Idle_3", "Angry", "Angry_Gesture_2", "Standing_Yell_2", "Yelling_While_Standing"], "lamento")
role(["Arm_Stretching", "Neck_Stretching"], "calentamiento")
role(["Counting", "Pointing_Forward"], "arbitro")
role(["kick_up_soccerball", "kneeing_soccerball", "kneeing_soccerball_2", "stall_soccerball", "stall_soccerball_2", "stall_soccerball_3", "stall_soccerball_4", "transition"], "malabares")
role(["throw_in", "soccer_penalty_kick", "Chip", "receive_soccerball"], "practica")


def _triggered_ids() -> set:
    """Clips citados por el codigo de juego (disparadores en partido, arquero, malabares); el resto solo esta en la galeria."""
    import glob, re
    text = ""
    for f in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        if f.endswith("practice_scene.gd"):
            continue
        t = open(f, encoding="utf-8").read()
        if f.endswith("animation_catalog.gd"):
            t = re.sub(r"const KEEPER := \{.*?\n\}\n", "", t, flags=re.S)
        text += t
    return set(re.findall(r'&?"([A-Za-z0-9_]+)"', text))

TRIGGERED = _triggered_ids()
clips = []
by_stem = {i["archivo_en_zip"].split("animaciones/")[1][:-4].split("/")[1]: i["archivo_en_zip"].split("animaciones/")[1] for i in idx}
for i in idx:
    rel = i["archivo_en_zip"].split("animaciones/")[1]
    grp, stem = rel[:-4].split("/")
    keeper = grp.startswith("01")
    twin = stem[: -len("_inplace")] if stem.endswith("_inplace") else ""
    speed_from = by_stem[twin] if twin in by_stem and stem in LOOP else ""
    # Los clips que ya traen raiz propia (p. ej. Sprint_inplace) miden su velocidad con la suya.
    if stem in ("Sprint_inplace", "jog_backward_diagonal_2_inplace"):
        speed_from = ""
    r = ROLE.get(stem, "arquero" if keeper else "practica")
    if keeper:
        r = "arquero"
    elif stem + "_inplace" in by_stem:
        r = "gemelo_raiz"   # version con raiz del clip _inplace: sirve para medir la velocidad natural y el desplazamiento
    clips.append({
        "id": stem, "source": rel, "library": "keeper" if keeper else "field", "loop": stem in LOOP,
        "mirror": stem in MIRROR, "kick": stem in FOOT and stem in {"Soccer_Pass", "strike_foward_jog_inplace", "strike_foward_jog", "Chip", "soccer_penalty_kick", "scissor_kick", "Flying_Bicycle_Kick", "kick_soccerball", "kick_soccerball_2", "kick_up_soccerball"},
        "paths": (["toe_l", "toe_r"] if (stem in FOOT or stem in ("goalkeeper_drop_kick", "stall_soccerball", "stall_soccerball_2")) else [])
                 + (["knee_l"] if stem in ("kneeing_soccerball", "stall_soccerball_3") else []) + (["knee_r"] if stem in ("kneeing_soccerball_2", "stall_soccerball_4") else []) + (["head"] if stem in HEAD else []) + (["hands"] if keeper else []),
        "calibrate": old.get(stem, {}).get("calibrate", False), "speed_from": speed_from, "role": r, "state": "integrated" if stem in TRIGGERED else "gallery",
    })
out = {"comentario": "Los 133 clips del pack (generado por make_selection.py). library: field -> assets/animations/pack_clips.res; keeper -> pack_keeper.res. mirror: genera <id>_mirror (lado opuesto). kick: detecta el contacto del pie. paths: trayectorias (30 Hz, con la raiz) de punta de pie, cabeza y manos para planificar contactos. role: situacion del juego que lo usa.", "clips": clips}
json.dump(out, open(os.path.join(ROOT, "tools/animation_pack/selection.json"), "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
import collections
print(len(clips), collections.Counter(c["role"] for c in clips))
