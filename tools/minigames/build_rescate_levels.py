#!/usr/bin/env python3
"""Niveles de mecanismos del Rescate (rediseño 2026-11-14, pedido del usuario: «todo debe ser activado con el balón… la
bola que liberó debe caer y desplazarse a la zona verde… girar el escenario… palancas, botones, meter el balón en un
hoyo, impactar»). Todo se activa a pelotazos y el escenario gira de a 45 grados alrededor de la torre (pivot).

Escribe los niveles en resources/minigames/minigames.json (juego "rescate"): conserva los 4 niveles de antes (de patear)
y agrega estos despues, de faciles a expertos. Cada nivel trae "solution": por cada tiro, el giro del escenario (rot, en
pasos de 45 grados) y a que se patea (hit: indice del mando; push: caja; domino), que la prueba
tests/test_rescate_mechs.gd ejecuta con la fisica del juego (tiros reales con ShotSolver) para verificar que se puede
resolver, y "wrong" (un orden equivocado que tiene que fallar).

Plantilla comun: torre en el centro (pivot 12, 0, 0; arriba en y 1,6) con la jaula de la dorada; el piso de la jaula se
inclina hacia la salida (+Z); un tobogan con barandas baja de la torre a la ZONA VERDE (con bordes y arena). Los mandos
van en las caras de la torre: adelante (-X, se ve sin girar), atras (+X, girar 180), izquierda (-Z, girar 90).

Ejes: X hacia el fondo (el jugador esta en x = 0), Y arriba, Z al costado. La pelota prisionera tiene radio 0,12 m.
Uso: python3 tools/minigames/build_rescate_levels.py
"""
import json
import math
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
PATH = os.path.join(ROOT, "resources", "minigames", "minigames.json")
KEEP_OLD = 4


def ramp(x_hi, y_hi, x_lo, y_lo, w=1.0, t=0.12, **extra):
    """Rampa (caja inclinada) cuya cara de arriba va de (x_hi, y_hi) a (x_lo, y_lo)."""
    dx, dy = x_lo - x_hi, y_lo - y_hi
    length = math.hypot(dx, dy)
    ang = math.degrees(math.atan2(y_hi - y_lo, x_hi - x_lo))
    cx, cy = (x_hi + x_lo) / 2.0, (y_hi + y_lo) / 2.0
    # La caja baja media altura en la direccion normal a la cara.
    nx, ny = -math.sin(math.radians(ang)), math.cos(math.radians(ang))
    d = {"pos": [round(cx - nx * t / 2, 4), round(cy - ny * t / 2, 4), 0.0], "size": [round(length, 4), t, w], "roll": round(ang, 3)}
    d.update(extra)
    return d


def ramp_part(x_hi, y_hi, x_lo, y_lo, w=1.0, t=0.12, **extra):
    """Rampa como pieza movil (hinge): la misma caja con rot en vez de roll."""
    r = ramp(x_hi, y_hi, x_lo, y_lo, w, t)
    d = {"type": "hinge", "pos": r["pos"], "size": r["size"], "rot": [0, 0, r["roll"]]}
    d.update(extra)
    return d


def chute_z(x0, x1, z_hi, y_hi, z_lo, y_lo, t=0.12):
    """Tobogan que baja hacia el costado (a lo largo de Z): cara de arriba de (z_hi, y_hi) a (z_lo, y_lo)."""
    dz = z_lo - z_hi
    length = math.hypot(dz, y_lo - y_hi)
    # Rotacion en X: +phi baja el lado +Z.
    phi = math.degrees(math.atan2(y_hi - y_lo, abs(dz))) * (1 if dz > 0 else -1)
    cz, cy = (z_hi + z_lo) / 2.0, (y_hi + y_lo) / 2.0
    return {"pos": [(x0 + x1) / 2.0, round(cy - t / 2, 4), round(cz, 4)], "size": [abs(x1 - x0), t, round(length, 4)], "pitch": round(phi, 3)}


def rails(x_hi, y_hi, x_lo=None, y_lo=None, z=0.56, h=0.3):
    """Barandas a los dos lados de un camino (paredes finas que siguen la pendiente; las devuelve como «slopes»)."""
    if x_lo is None:
        x_lo, y_lo = y_hi, y_hi
        x_hi, y_hi = x_hi, y_hi
    out = []
    for side in (1, -1):
        r = ramp(x_hi, y_hi + h, x_lo, y_lo + h, w=0.06, t=h)
        r["pos"][2] = side * z
        out.append(r)
    return out


def support(x0, x1, y_top, w=1.2):
    """Bloque que sostiene una rampa (solo apoyo, debajo de la cara)."""
    return {"pos": [(x0 + x1) / 2.0, max(y_top - 0.15, 0.05) / 2.0, 0.0], "size": [abs(x1 - x0), max(y_top - 0.15, 0.1), w]}


TOP = 1.6
SLOPE_END = 5.0
PIVOT = [12.0, 0.0, 0.0]
FRONT_X, BACK_X, LEFT_Z = 10.72, 13.28, -1.28


def y_chute(z):
    """Altura de la cara de arriba del tobogan (de la torre, z 1,2, al piso, z SLOPE_END)."""
    return round(TOP - (z - 1.2) * (TOP / (SLOPE_END - 1.2)), 4)


def tower(cage=True, rotor=False):
    """Torre, piso inclinado de la jaula, paredes de la jaula y del camino hasta el borde."""
    d = {"platforms": [{"pos": [12.0, TOP / 2.0, 0.0], "size": [2.4, TOP, 2.4], "color": "#4f4866"}],
         "slopes": [dict(chute_z(11.5, 12.5, -0.6, TOP + 0.1, 1.2, TOP + 0.01, t=0.06), color="#6d6590")],
         "walls": [{"pos": [11.46, TOP + 0.3, 0.3], "size": [0.08, 0.6, 1.8], "color": "#9aa0b4"},
                   {"pos": [12.54, TOP + 0.3, 0.3], "size": [0.08, 0.6, 1.8], "color": "#9aa0b4"}],
         "parts": [], "mechs": []}
    if cage:
        d["walls"].append({"pos": [12.0, TOP + 0.3, -0.62], "size": [1.16, 0.6, 0.08], "color": "#9aa0b4"})
        d["prisoner"] = [12.0, TOP + 0.24, -0.1]
    if rotor:
        # Jaula giratoria (engranaje) arriba de la torre, con lugar debajo para que la dorada caiga y ruede.
        d["parts"].append({"type": "rotor", "pos": [12.0, 2.4, -0.1], "rot": [0, 90, 0], "axis": [0, 0, 1], "radius": 0.42, "bars": 12,
                           "gap": 2, "depth": 0.9, "steps": 6, "phase": 75, "dir": -1, "speed": 1.4})
        d["walls"] += [{"pos": [11.35, 2.1, -0.1], "size": [0.1, 1.0, 0.1], "color": "#9aa0b4"},
                       {"pos": [12.65, 2.1, -0.1], "size": [0.1, 1.0, 0.1], "color": "#9aa0b4"}]
        d["prisoner"] = [12.0, 2.14, -0.1]
    return d


def gate():
    """Compuerta de la jaula (del lado del tobogan)."""
    return {"type": "slide", "pos": [12.0, TOP + 0.29, 0.58], "size": [1.0, 0.5, 0.08], "open": [0, 0.62, 0], "speed": 1.8,
            "color": "#c8402e"}


def exit_path(start_z=1.2):
    """Tobogan (con barandas) desde start_z hasta el piso y la zona verde con bordes."""
    y0 = y_chute(start_z)
    d = {"slopes": [dict(chute_z(11.5, 12.5, start_z, y0, SLOPE_END, 0.0), color="#8c80a6"),
                    dict(chute_z(11.42, 11.5, start_z, y0 + 0.3, SLOPE_END, 0.3, t=0.3), color="#9aa0b4"),
                    dict(chute_z(12.5, 12.58, start_z, y0 + 0.3, SLOPE_END, 0.3, t=0.3), color="#9aa0b4")],
         "walls": [{"pos": [12.0, 0.15, SLOPE_END + 1.65], "size": [1.8, 0.3, 0.1], "bounce": 0.0, "color": "#2fbf5a"},
                   {"pos": [11.15, 0.15, SLOPE_END + 0.82], "size": [0.1, 0.3, 1.7], "bounce": 0.0, "color": "#2fbf5a"},
                   {"pos": [12.85, 0.15, SLOPE_END + 0.82], "size": [0.1, 0.3, 1.7], "bounce": 0.0, "color": "#2fbf5a"}],
         "zone": [11.2, SLOPE_END, 12.8, SLOPE_END + 1.6]}
    return d


def bridge():
    """Puente levadizo entre el borde de la torre y el tobogan (levantado hasta que se baja) y el pozo de abajo."""
    z0, z1 = 1.2, 2.1
    y0, y1 = y_chute(z0), y_chute(z1)
    r = chute_z(11.5, 12.5, z0, y0, z1, y1)
    part = {"type": "hinge", "pos": r["pos"], "size": r["size"], "rot": [r["pitch"], 0, 0], "hinge": [12.0, y1, z1],
            "axis": [1, 0, 0], "angle": 80, "invert": True, "start": 1, "speed": 0.8, "color": "#2fb3c0"}
    return part, [[11.3, 1.22, 12.7, 2.1]]


def merge(*ds):
    out = {}
    for d in ds:
        for k, v in d.items():
            if isinstance(v, list) and k in out and k not in ("zone", "prisoner"):
                out[k] = out[k] + v
            else:
                out[k] = v
    return out


def front(y=0.9, z=0.0, **kw):
    return dict({"pos": [FRONT_X, y, z], "yaw": 0}, **kw)


def back(y=0.9, z=0.0, **kw):
    return dict({"pos": [BACK_X, y, z], "yaw": 180}, **kw)


def left(y=0.9, x=12.0, **kw):
    return dict({"pos": [x, y, LEFT_Z], "yaw": -90}, **kw)


LEVELS = []

# 5 — Primer pelotazo: la palanca abre la compuerta.
L = merge(tower(), exit_path())
L["parts"].append(gate())
L["mechs"].append({"type": "lever", "pos": [10.0, 0, 0.0], "yaw": 0, "targets": [0], "label": "PALANCA"})
L.update({"title": "Primer pelotazo", "objective": "Pegale a la PALANCA amarilla: abre la compuerta y la dorada rueda por el tobogán hasta la zona verde.",
          "hint": "Apuntá a la paleta amarilla de la palanca", "shots": 3, "time": 90,
          "solution": [{"rot": 0, "hit": 0, "speed": 17}], "medals": [170, 260, 330]})
LEVELS.append(L)

# 6 — Del otro lado: el blanco esta atras de la torre; hay que girar el escenario.
L = merge(tower(), exit_path())
L["parts"].append(gate())
L["mechs"].append(dict(back(), type="button", targets=[0], label="BOTÓN"))
L.update({"title": "Del otro lado", "objective": "El botón que abre la compuerta está ATRÁS de la torre. Girá el escenario y pegale.",
          "hint": "Usá «Girar» hasta ver el botón rojo", "shots": 3, "time": 90,
          "solution": [{"rot": 4, "hit": 0, "speed": 18}], "medals": [170, 255, 325]})
LEVELS.append(L)

# 7 — El buzon: hay que meter la pelota por la boca del buzon (costado izquierdo).
L = merge(tower(), exit_path())
L["parts"].append(gate())
L["mechs"].append(dict(left(y=0.75, x=12.0), type="hole", targets=[0], label="BUZÓN"))
L["mechs"][0]["pos"][2] = -1.75
L.update({"title": "El buzón", "objective": "Meté la pelota ADENTRO del buzón azul: abre la compuerta. Está al costado: girá el escenario.",
          "hint": "Apuntá al centro de la boca del buzón", "shots": 4, "time": 90,
          "solution": [{"rot": 2, "hit": 0, "speed": 16}], "medals": [170, 270, 340]})
LEVELS.append(L)

# 8 — Puente y compuerta: primero el puente (palanca), despues la compuerta (boton del costado). Al reves, al pozo.
L = merge(tower(), exit_path(start_z=2.1))
bp, pits = bridge()
L["parts"] += [bp, gate()]
L["pits"] = pits
L["mechs"] += [{"type": "lever", "pos": [10.0, 0, -0.7], "yaw": 0, "targets": [0], "label": "PUENTE"},
               dict(left(), type="button", targets=[1], label="COMPUERTA")]
L.update({"title": "Puente y compuerta", "objective": "Bajá el PUENTE con la palanca y después abrí la COMPUERTA (botón del costado). Si la abrís antes, cae al pozo.",
          "hint": "Pensá el orden: primero el puente", "shots": 4, "time": 100,
          "solution": [{"rot": 0, "hit": 0, "speed": 17}, {"rot": 2, "hit": 1, "speed": 18}],
          "wrong": [{"rot": 2, "hit": 1, "speed": 18}], "medals": [170, 270, 345]})
LEVELS.append(L)

# 9 — Rueda dentada: cada pelotazo gira la jaula un diente; al tercero el hueco queda abajo.
L = merge(tower(cage=False, rotor=True), exit_path())
L["mechs"].append(dict(front(y=0.85), type="wheel", steps=6, open_step=3, targets=[0], label="RUEDA"))
L.update({"title": "Rueda dentada", "objective": "Cada pelotazo a la RUEDA gira la jaula un diente. Cuando el hueco queda abajo, la dorada cae y rueda.",
          "hint": "Contá los dientes: hacen falta varios pelotazos", "shots": 5, "time": 110,
          "solution": [{"rot": 0, "hit": 0, "speed": 17}] * 3, "medals": [170, 280, 350]})
LEVELS.append(L)

# 10 — Colores: tres blancos de colores en tres caras; el panel muestra el orden.
L = merge(tower(), exit_path())
L["parts"].append(gate())
L["mechs"] += [dict(front(y=0.8), type="switch", group="c", order=2, color="#e8c21e"),
               dict(back(y=0.8), type="switch", group="c", order=1, color="#d33b3b"),
               dict(left(y=0.8), type="switch", group="c", order=3, color="#2f6fe0"),
               {"type": "lock", "group": "c", "n": 3, "pos": [FRONT_X, 2.25, 0.0], "yaw": 0,
                "colors": ["#d33b3b", "#e8c21e", "#2f6fe0"], "targets": [0]}]
L.update({"title": "Colores", "objective": "El panel de luces muestra un orden de colores. Pegale a los blancos en ese orden (están en tres caras). Si te equivocás, se apaga todo.",
          "hint": "Mirá el panel: rojo, amarillo, azul", "shots": 6, "time": 120,
          "solution": [{"rot": 4, "hit": 1, "speed": 18}, {"rot": 0, "hit": 0, "speed": 18}, {"rot": 2, "hit": 2, "speed": 18}],
          "wrong": [{"rot": 0, "hit": 0, "speed": 18}], "medals": [170, 290, 360]})
LEVELS.append(L)

# 11 — Contrapeso: el buzon de atras baja el puente; el contrapeso, al caer, levanta la compuerta.
L = merge(tower(), exit_path(start_z=2.1))
bp, pits = bridge()
L["parts"] += [bp, gate()]
L["pits"] = pits
L["platforms"].append({"pos": [12.0, 1.65, -2.6], "size": [0.2, 3.3, 0.2], "color": "#9aa0b4"})
L["platforms"].append({"pos": [12.0, 3.35, -2.3], "size": [0.2, 0.1, 0.8], "color": "#9aa0b4"})
L["mechs"] += [dict(back(y=0.75), type="hole", targets=[0], label="BUZÓN"),
               {"type": "weight", "pos": [12.0, 3.3, -2.0], "rope": 1.0, "fall": 1.3, "mass": 6.0, "targets": [1], "label": "CONTRAPESO"}]
L["mechs"][0]["pos"][0] = 13.75
L.update({"title": "Contrapeso", "objective": "El BUZÓN de atrás baja el puente. El CONTRAPESO, al caer de un pelotazo, levanta la compuerta. Pensá el orden.",
          "hint": "Primero el puente (girá y metela en el buzón)", "shots": 5, "time": 110,
          "solution": [{"rot": 4, "hit": 0, "speed": 17}, {"rot": 0, "hit": 1, "speed": 18}],
          "wrong": [{"rot": 0, "hit": 1, "speed": 18}], "medals": [170, 285, 355]})
LEVELS.append(L)

# 12 — Caja a la placa: empujar la caja hasta la placa (baja el puente mientras este encima); la palanca de atras abre.
L = merge(tower(), exit_path(start_z=2.1))
bp, pits = bridge()
L["parts"] += [bp, gate()]
L["pits"] = pits
L["crates"] = [{"pos": [8.2, 0.28, -0.6], "size": [0.56, 0.56, 0.56], "mass": 1.0}]
L["mechs"] += [{"type": "plate", "pos": [10.1, 0.0, -0.6], "size": [1.3, 0.06, 1.3], "targets": [0], "label": "PLACA"},
               {"type": "lever", "pos": [14.0, 0, 0.0], "yaw": 180, "targets": [1], "label": "PALANCA"}]
L.update({"title": "Caja a la placa", "objective": "Empujá la CAJA de un pelotazo hasta la PLACA azul: mientras esté encima, el puente queda abajo. Después, la palanca de atrás abre la compuerta.",
          "hint": "Pegale fuerte a la caja, derecho hacia la torre", "shots": 5, "time": 110,
          "solution": [{"rot": 0, "push": 0, "speed": 16}, {"rot": 4, "hit": 1, "speed": 17}],
          "wrong": [{"rot": 4, "hit": 1, "speed": 17}], "medals": [170, 285, 355]})
LEVELS.append(L)

# 13 — Domino: la fila de fichas cae y la ultima aprieta el boton del puente; el buzon del costado abre la compuerta.
L = merge(tower(), exit_path(start_z=2.1))
bp, pits = bridge()
L["parts"] += [bp, gate()]
L["pits"] = pits
L["dominoes"] = [{"pos": [7.4, 0.0, 0.0], "n": 6, "step": [0.55, 0, 0], "size": [0.12, 0.9, 0.5]}]
L["mechs"] += [dict(front(y=0.75), type="button", bodies=True, targets=[0], label="PUENTE"),
               dict(left(y=0.75, x=12.0), type="hole", targets=[1], label="BUZÓN")]
L["mechs"][1]["pos"][2] = -1.75
L.update({"title": "Dominó", "objective": "Tirá la primera ficha: la fila cae y la última aprieta el botón del PUENTE. Después metela en el BUZÓN del costado.",
          "hint": "Un toque a la primera ficha alcanza", "shots": 5, "time": 110,
          "solution": [{"rot": 0, "domino": 0, "speed": 12}, {"rot": 2, "hit": 1, "speed": 16}],
          "wrong": [{"rot": 2, "hit": 1, "speed": 16}], "medals": [170, 285, 355]})
LEVELS.append(L)

# 14 — Gran mecanismo: la secuencia de dos colores baja el puente; la rueda (dos dientes) suelta la jaula.
L = merge(tower(cage=False, rotor=True), exit_path(start_z=2.1))
L["parts"][0].update({"steps": 4})
bp, pits = bridge()
L["parts"].append(bp)
L["pits"] = pits
L["mechs"] += [dict(left(y=0.85), type="wheel", steps=4, open_step=2, targets=[0], label="RUEDA"),
               dict(front(y=0.8), type="switch", group="g", order=2, color="#1f9d55"),
               dict(back(y=0.8), type="switch", group="g", order=1, color="#9b3fb8"),
               {"type": "lock", "group": "g", "n": 2, "pos": [FRONT_X, 2.25, 0.0], "yaw": 0, "colors": ["#9b3fb8", "#1f9d55"], "targets": [1]}]
L.update({"title": "Gran mecanismo", "objective": "La secuencia del panel (violeta y verde) baja el PUENTE. La RUEDA del costado gira la jaula: con dos dientes se abre. Si la soltás antes del puente, cae al pozo.",
          "hint": "Puente primero (secuencia), rueda al final", "shots": 7, "time": 140,
          "solution": [{"rot": 4, "hit": 2, "speed": 18}, {"rot": 0, "hit": 1, "speed": 18}, {"rot": 2, "hit": 0, "speed": 17}, {"rot": 2, "hit": 0, "speed": 17}],
          "wrong": [{"rot": 2, "hit": 0, "speed": 17}, {"rot": 2, "hit": 0, "speed": 17}], "medals": [170, 300, 380]})
LEVELS.append(L)

# El escenario se arma alrededor de x = 12 y se acerca al jugador (SHIFT_X): la torre queda a 9 m y llena el cuadro.
SHIFT_X = -3.0


def shift_x(L, dx):
    """Corre en X todo el nivel (posiciones, bisagras, zona, pozos, centro)."""
    def mv(v):
        return [round(float(v[0]) + dx, 4)] + list(v[1:])
    for key in ("platforms", "slopes", "walls", "crates", "dominoes"):
        for e in L.get(key, []):
            e["pos"] = mv(e["pos"])
    for e in L.get("parts", []):
        e["pos"] = mv(e["pos"])
        if "hinge" in e:
            e["hinge"] = mv(e["hinge"])
    for e in L.get("mechs", []):
        e["pos"] = mv(e["pos"])
    L["prisoner"] = mv(L["prisoner"])
    L["zone"] = [L["zone"][0] + dx, L["zone"][1], L["zone"][2] + dx, L["zone"][3]]
    L["pits"] = [[p[0] + dx, p[1], p[2] + dx, p[3]] for p in L.get("pits", [])]
    L["pivot"] = mv(PIVOT)


for L in LEVELS:
    shift_x(L, SHIFT_X)


# Tiempo minimo posible de cada nivel (s): la fisica no deja resolverlo antes (lo usa el servidor online para rechazar
# tiempos imposibles). Se completa con la medicion de tests/test_rescate_mechs.gd (con margen).
MIN_TIME = {"Primer pelotazo": 3.5, "Del otro lado": 3.5, "El buzón": 3.5, "Puente y compuerta": 7.5, "Rueda dentada": 13.0,
            "Colores": 11.0, "Contrapeso": 7.5, "Caja a la placa": 7.5, "Dominó": 5.0, "Gran mecanismo": 17.0}


def main():
    for lv in LEVELS:
        lv["min_time"] = MIN_TIME.get(lv["title"], 2.0)
    with open(PATH, encoding="utf-8") as f:
        data = json.load(f)
    games = data["games"] if isinstance(data, dict) else data
    g = next(x for x in games if x["id"] == "rescate")
    g["levels"] = g["levels"][:KEEP_OLD] + LEVELS
    g["description"] = ("Una pelota dorada está atrapada. Todo se activa a pelotazos: palancas, botones, buzones, colores, "
                        "ruedas dentadas, contrapesos, cajas y dominós. Girá el escenario para encontrar el ángulo.")
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("rescate: %d niveles (%d nuevos)" % (len(g["levels"]), len(LEVELS)))


if __name__ == "__main__":
    main()
