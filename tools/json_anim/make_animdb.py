"""Genera assets/animations/animdb.json: la base de datos de animaciones del juego (como animdb.adb de UCS).

Una entrada por cada clip del banco (los 2 022 JSON, mas los tramos partidos del inventario) con:
  - lo nuestro: ids en la libreria (jn_<rol>_<NNNN>, con su espejo «_mirror»), rol/accion, sistema que lo usa, si esta
    conectado (si / no / pendiente) y por que;
  - lo de UCS (registro de 104 bytes de animdb.adb, mismo orden que los .sat y que el numero NNNN de los JSON):
    cuadro del toque de pelota, pie del toque, destino de la pelota (m, adelante/izquierda en el marco del inicio del
    clip), giro (sector de 11.25 grados y medido; + = izquierda), ventana del joystick en la que UCS elige el clip y
    velocidades de entrada y salida (x10, unidades de UCS).
Y un indice «acciones»: para cada accion (rol), TODOS sus clips (conectados o no), para que ninguna animacion quede fuera.

Uso (el animdb.adb de UCS no se versiona; viene en paquete_recursos_analisis_movimiento/animaciones/):
  python3 tools/json_anim/make_animdb.py <animdb.adb> <index.json del banco> [salida]
El estado de conexion sale de docs/fases/E2_inventario_banco.csv y de los ajustes listados en CONNECTED_NOW.
"""
import csv
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INV = os.path.join(ROOT, "docs", "fases", "E2_inventario_banco.csv")
OUT = os.path.join(ROOT, "assets", "animations", "animdb.json")

# Clips conectados despues del inventario E2 (indice NNNN -> sistema que los usa ahora). Se completa con cada tanda.
CONNECTED_NOW = {}
# Toque orientado de JsonBallMove (2026-11-05): los clips de control con «dribble» que siguen en carrera.
STEER_POOL_SYSTEM = "toque orientado con clips de UCS (JsonBallMove, intencion steer)"
START_SYSTEM = "arranque con pelota desde parado (JsonBallMove, intencion start)"


def adb_records(path):
    d = open(path, "rb").read()
    n = struct.unpack_from("<I", d, 0)[0]
    return [struct.unpack_from("<52h", d, 4 + i * 104) for i in range(n)]


def ucs_fields(h):
    foot = "izq" if h[4] & 128 else ("der" if h[4] & 256 else "")
    return {
        "cuadros": h[2],
        "toque_cuadro": h[3],
        "toque_pie": foot,
        "giro_sector": h[9],
        "giro_medido": h[47],
        "ventana_joystick": [h[7], h[8]],
        "v_in_x10": h[5],
        "v_out_x10": h[6],
        # adb: -25 = adelante (mm); 27 lateral con + = izquierda en los datos del banco (comprobado con la punta del pie).
        "destino_m": [round(-h[25] / 1000.0, 3), round(h[27] / 1000.0, 3)],
    }


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    adb = adb_records(sys.argv[1])
    bank = json.load(open(sys.argv[2], encoding="utf-8"))["clips"]
    out_path = sys.argv[3] if len(sys.argv) > 3 else OUT
    inv = {}
    for r in csv.DictReader(open(INV, encoding="utf-8")):
        inv.setdefault(r["archivo"][:4], []).append(r)
    # Listas que escribe tools/json_anim/dump_ball_pools.tscn con lo que el juego usa de verdad.
    steer = set(json.load(open(os.path.join(ROOT, "tools", "json_anim", "steer_pool.json"), encoding="utf-8")))
    start_path = os.path.join(ROOT, "tools", "json_anim", "start_pool.json")
    start = set(json.load(open(start_path, encoding="utf-8"))) if os.path.exists(start_path) else set()
    clips = {}
    actions = {}
    for c in bank:
        key = c["file"][:4]
        i = int(key)
        rows = inv.get(key, [{}])
        entry = {
            "nombre": c["name"][4:] if c["name"].startswith("ANM_") else c["name"],
            "categoria": c.get("category", ""),
            "cuadros": c.get("frames", 0),
            "tramos": [],
            "ucs": ucs_fields(adb[i]) if i < len(adb) else {},
        }
        for r in rows:
            role = r.get("nueva", "")
            state = r.get("util", "")
            system = r.get("sistema", "")
            reason = r.get("motivo", "")
            cid = r.get("id", "")
            if key in CONNECTED_NOW:
                state, system, reason = "si", CONNECTED_NOW[key], "conectado despues del inventario E2"
            uses = [system] if system and system != "-" else []
            if cid in steer:
                uses.append(STEER_POOL_SYSTEM)
                if state != "si":
                    state, reason = "si", "conectado despues del inventario E2"
            # Arranque con pelota (JsonBallMove.start_pool).
            if cid in start:
                uses.append(START_SYSTEM)
                if state != "si":
                    state, reason = "si", "conectado despues del inventario E2"
            entry["tramos"].append({"id": cid, "accion": role, "conectada": state, "sistemas": uses, "motivo": reason})
            if role:
                actions.setdefault(role, []).append(cid)
        clips[key] = entry
    total = sum(len(e["tramos"]) for e in clips.values())
    conn = sum(1 for e in clips.values() for t in e["tramos"] if t["conectada"] == "si")
    db = {
        "version": 1,
        "descripcion": "Base de datos de animaciones del modo 4 (como animdb.adb de UCS): una entrada por clip del banco "
                       "(indice NNNN de los JSON) con su accion, sistema y estado, y los datos de UCS por clip. Los "
                       "espejos usan el mismo registro: id + «_mirror», giros, ventana y destino lateral con el signo "
                       "cambiado y el pie del toque cambiado.",
        "resumen": {"clips": len(clips), "tramos": total, "conectados": conn, "acciones": len(actions)},
        "acciones": {k: sorted(v) for k, v in sorted(actions.items())},
        "clips": clips,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        # Compacto: lo carga el juego (AnimDB); para leerlo, python3 -m json.tool assets/animations/animdb.json.
        json.dump(db, f, ensure_ascii=False, separators=(",", ":"))
    print("animdb:", out_path, db["resumen"])


if __name__ == "__main__":
    main()
