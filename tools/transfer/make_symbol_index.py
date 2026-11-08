"""Indice de simbolos para docs/transferencia_integracion_completa: por clase, sus funciones (linea y primera linea del
comentario ##), constantes y variables exportadas con su valor, y que archivos la usan. Lo lee la persona; se regenera con
el codigo actual (las lineas cambian con cada edicion).

Uso: python3 tools/transfer/make_symbol_index.py > salida.md
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLASSES = [
    ("Ball", "scripts/ball/ball.gd", []),
    ("BallTuning", "scripts/ball/ball_tuning.gd", ["Tuning.ball"]),
    ("BallHandler", "scripts/player/ball_handler.gd", ["ball_handler.", "handler."]),
    ("JsonBallMove", "scripts/player/json_ball_move.gd", ["json_move."]),
    ("JsonReceive", "scripts/player/json_receive.gd", ["receive."]),
    ("ReceiveProfiles", "scripts/player/receive_profiles.gd", []),
    ("BallTurn", "scripts/player/ball_turn.gd", ["ball_turn."]),
    ("DragBack", "scripts/player/drag_back.gd", ["drag_back."]),
    ("Locomotion", "scripts/player/locomotion.gd", ["locomotion.", "loco."]),
    ("PlayerTuning", "scripts/player/player_tuning.gd", ["Tuning.player"]),
    ("Footballer", "scripts/player/footballer.gd", []),
    ("FootballerVisual", "scripts/player/footballer_visual.gd", ["visual."]),
    ("PlayerActions", "scripts/player/player_actions.gd", ["actions."]),
    ("ActionArbiter", "scripts/player/action_arbiter.gd", ["arbiter."]),
    ("ActionMotion", "scripts/animation/action_motion.gd", ["motion."]),
    ("TouchFootIK", "scripts/animation/touch_foot_ik.gd", ["touch_ik."]),
    ("JsonCatalog", "scripts/animation/json_catalog.gd", []),
    ("PackLibrary", "scripts/animation/pack_library.gd", []),
    ("AnimDB", "scripts/animation/anim_db.gd", []),
    ("KickModel", "scripts/assistance/kick_model.gd", []),
    ("PassAssist", "scripts/assistance/pass_assist.gd", []),
    ("ShotAssist", "scripts/assistance/shot_assist.gd", []),
    ("CrossAssist", "scripts/assistance/cross_assist.gd", []),
    ("TeamBrain", "scripts/ai/team_brain.gd", []),
    ("AIInput", "scripts/ai/ai_input.gd", []),
    ("UcsParams", "scripts/ai/ucs_params.gd", []),
    ("Goalkeeper", "scripts/goalkeeper/goalkeeper.gd", []),
    ("KeeperPlanner", "scripts/goalkeeper/keeper_planner.gd", []),
    ("KeeperTuning", "scripts/goalkeeper/keeper_tuning.gd", []),
    ("MatchContext", "scripts/gameplay/match_context.gd", ["ctx."]),
]

RE_FUNC = re.compile(r"^(static )?func ([A-Za-z_0-9]+)\(")
RE_CONST = re.compile(r"^const ([A-Z_0-9]+)\s*(?::[^=]*)?:?=\s*(.+)$")
RE_EXPORT = re.compile(r"^@export var ([a-z_0-9]+)\s*:\s*[A-Za-z0-9]+\s*=\s*(.+)$")


def all_gd():
    out = []
    for base in ("scripts", "tools", "tests"):
        for dp, _, fs in os.walk(os.path.join(ROOT, base)):
            for f in fs:
                if f.endswith(".gd"):
                    out.append(os.path.relpath(os.path.join(dp, f), ROOT))
    return sorted(out)


def main():
    files = all_gd()
    texts = {f: open(os.path.join(ROOT, f), encoding="utf-8").read() for f in files}
    print("# Indice de simbolos (generado por tools/transfer/make_symbol_index.py)\n")
    for cls, path, aliases in CLASSES:
        lines = open(os.path.join(ROOT, path), encoding="utf-8").read().split("\n")
        users = []
        for f, t in texts.items():
            if f == path:
                continue
            if re.search(r"\b%s\b" % cls, t) or any(a in t for a in aliases if a not in ("handler.", "loco.", "motion.", "receive.", "ctx.")):
                users.append(f)
        prod = [u for u in users if u.startswith("scripts/")]
        print("## %s (`%s`, %d lineas)\n" % (cls, path, len(lines)))
        print("Lo usan (scripts): %s\n" % (", ".join("`%s`" % u for u in prod) if prod else "-"))
        other = [u for u in users if not u.startswith("scripts/")]
        if other:
            print("Lo usan (pruebas y herramientas): %d archivos\n" % len(other))
        consts = []
        funcs = []
        for i, l in enumerate(lines, 1):
            m = RE_FUNC.match(l)
            if m:
                doc = ""
                j = i - 2
                block = []
                while j >= 0 and lines[j].startswith("##"):
                    block.insert(0, lines[j][2:].strip())
                    j -= 1
                doc = block[0] if block else ""
                funcs.append((i, m.group(2), doc[:150]))
                continue
            m = RE_CONST.match(l)
            if m and not m.group(2).startswith("preload"):
                consts.append((i, m.group(1), m.group(2).strip()[:70]))
                continue
            m = RE_EXPORT.match(l)
            if m:
                consts.append((i, m.group(1), m.group(2).strip()[:70]))
        if consts:
            print("| linea | constante / parametro | valor |\n|---:|---|---|")
            for i, n, v in consts:
                print("| %d | `%s` | `%s` |" % (i, n, v.replace("|", "\\|")))
            print()
        print("| linea | funcion | que hace (comentario del codigo) |\n|---:|---|---|")
        for i, n, d in funcs:
            print("| %d | `%s.%s` | %s |" % (i, cls, n, d.replace("|", "\\|")))
        print()


if __name__ == "__main__":
    main()
