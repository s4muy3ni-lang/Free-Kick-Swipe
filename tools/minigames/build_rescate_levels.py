#!/usr/bin/env python3
"""Niveles nuevos del Rescate (rediseño 2026-11-13): mecanismos tactiles y acertijos con fisica real.

Escribe los niveles en resources/minigames/minigames.json (juego "rescate"): conserva los 4 niveles de antes (de patear)
y agrega estos despues, de faciles a expertos. Cada nivel trae "solution": los pasos que la prueba
tests/test_rescate_mechs.gd ejecuta con la fisica del juego para verificar que se puede resolver, y que sin tocar nada la
pelota no se libera sola.

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


LEVELS = []

# 5 — La palanca (aprender): la palanca levanta la compuerta.
LEVELS.append({
    "title": "La palanca",
    "objective": "Tocá la PALANCA: levanta la compuerta y la dorada rueda sola hasta la zona verde.",
    "hint": "Tocá la palanca amarilla (en este nivel no se patea)",
    "shots": 0, "time": 45,
    "prisoner": [13.0, 1.45, 0],
    "zone": [2.0, -3, 9.5, 3],
    "platforms": [{"pos": [12, 0.5, 0], "size": [3, 1, 3]}],
    "slopes": [{"pos": [11.85, 1.16, 0], "size": [3.0, 0.15, 1.2], "roll": 8}],
    "parts": [{"type": "slide", "pos": [10.42, 1.4, 0], "size": [0.1, 0.44, 1.2], "open": [0, 0.6, 0], "color": "#c8402e"}],
    "mechs": [{"type": "lever", "pos": [9.2, 0, -2.4], "targets": [0], "label": "PALANCA"}],
    "solution": [{"tap": 0}],
    "medals": [170, 200, 225],
})

# 6 — Puente levadizo (decision de orden): primero el puente, despues la rampa. Al reves, cae al pozo.
A = ramp(15.6, 2.1, 13.2, 1.95)
LEVELS.append({
    "title": "Puente levadizo",
    "objective": "Bajá el PUENTE y después inclina la RAMPA. Si la soltás antes, cae al pozo rojo.",
    "hint": "Hay dos palancas: pensá el orden",
    "shots": 0, "time": 60,
    "prisoner": [15.0, 2.3, 0],
    "zone": [1.0, -2.5, 7.6, 2.5],
    "platforms": [support(13.2, 15.6, 1.95), support(8.0, 10.9, 1.7)],
    "slopes": [ramp(10.95, 1.78, 8.0, 1.62)] + rails(15.6, 2.04, 13.2, 2.04) + rails(10.95, 1.78, 8.0, 1.62),
    "walls": [{"pos": [15.65, 2.35, 0], "size": [0.1, 0.5, 1.0]}],
    "parts": [
        # La rampa donde espera la dorada: plana hasta que la palanca la inclina (bisagra del lado del pozo).
        {"type": "hinge", "pos": [14.4, 2.04, 0], "size": [2.4, 0.1, 1.0], "hinge": [13.2, 2.04, 0], "axis": [0, 0, 1], "angle": 8, "speed": 0.6},
        # El puente: levantado (vertical) hasta que se baja con su palanca.
        dict(ramp_part(13.15, 1.97, 10.9, 1.82), hinge=[10.9, 1.82, 0], axis=[0, 0, 1], angle=88, invert=True, start=1, speed=0.7),
    ],
    "mechs": [
        {"type": "lever", "pos": [12.0, 0, -2.4], "targets": [1], "label": "PUENTE"},
        {"type": "lever", "pos": [14.6, 0, -2.4], "targets": [0], "label": "RAMPA"},
    ],
    "pits": [[10.95, -1.4, 13.15, 1.4]],
    "solution": [{"tap": 0}, {"wait": 2.2}, {"tap": 1}],
    "wrong": [{"tap": 1}],
    "medals": [170, 205, 235],
})

# 7 — Mantené apretado: las dos compuertas del canal se abren solo mientras se mantiene el boton azul.
LEVELS.append({
    "title": "Mantené apretado",
    "objective": "Mantené apretado el botón AZUL: las compuertas se abren mientras lo apretás. Si soltás antes, se cierran.",
    "hint": "Apoyá el dedo en el botón azul y no lo levantes hasta que pase",
    "shots": 0, "time": 60,
    "prisoner": [14.7, 2.35, 0],
    "zone": [1.5, -2.5, 8.4, 2.5],
    "platforms": [support(8.8, 15.2, 1.2)],
    "slopes": [ramp(15.2, 2.2, 8.8, 1.2)] + rails(15.2, 2.2, 8.8, 1.2, h=0.4),
    "walls": [{"pos": [15.25, 2.45, 0], "size": [0.1, 0.5, 1.0]}],
    "parts": [
        {"type": "slide", "pos": [14.1, 2.35, 0], "size": [0.1, 0.5, 1.06], "open": [0, 0.7, 0], "speed": 2.2, "color": "#2f6fe0"},
        {"type": "slide", "pos": [10.2, 1.72, 0], "size": [0.1, 0.5, 1.06], "open": [0, 0.7, 0], "speed": 2.2, "color": "#2f6fe0"},
    ],
    "mechs": [{"type": "button", "mode": "hold", "pos": [12.0, 0, -2.4], "targets": [0, 1], "label": "MANTENER"}],
    "solution": [{"hold": 0, "for": 6.5}],
    "wrong": [{"hold": 0, "for": 0.4}],
    "medals": [160, 195, 225],
})

# 8 — Secuencia de colores: los interruptores en el orden de las luces de la cerradura.
LEVELS.append({
    "title": "Secuencia de colores",
    "objective": "La cerradura muestra un orden de colores: tocá los interruptores en ese orden. Si te equivocás, se apaga todo.",
    "hint": "Mirá las luces de la cerradura (de izquierda a derecha)",
    "shots": 0, "time": 60,
    "prisoner": [13.0, 1.45, 0],
    "zone": [2.0, -3, 9.5, 3],
    "platforms": [{"pos": [12, 0.5, 0], "size": [3, 1, 3]}],
    "slopes": [{"pos": [11.85, 1.16, 0], "size": [3.0, 0.15, 1.2], "roll": 8}],
    "parts": [{"type": "slide", "pos": [10.42, 1.4, 0], "size": [0.1, 0.44, 1.2], "open": [0, 0.6, 0], "color": "#c8402e"}],
    "mechs": [
        {"type": "switch", "group": "s", "order": 3, "pos": [11.0, 0, -2.6], "color": "#2f6fe0"},
        {"type": "switch", "group": "s", "order": 1, "pos": [9.7, 0, -2.6], "color": "#e8c21e"},
        {"type": "switch", "group": "s", "order": 2, "pos": [8.4, 0, -2.6], "color": "#d33b3b"},
        {"type": "lock", "group": "s", "n": 3, "pos": [12.4, 1.4, -1.9], "yaw": -90, "colors": ["#e8c21e", "#d33b3b", "#2f6fe0"], "targets": [0]},
    ],
    "solution": [{"tap": 1}, {"tap": 2}, {"tap": 0}],
    "wrong": [{"tap": 0}, {"tap": 1}],
    "medals": [170, 200, 225],
})

# 9 — Contrapeso: el peso cuelga de una polea sobre una traba; hay que sacar la traba y soltar el peso, que al caer
# levanta la compuerta.
LEVELS.append({
    "title": "Contrapeso",
    "objective": "El contrapeso levanta la compuerta al caer. Sacá la traba con la PALANCA y soltá el PESO (tocá el bloque).",
    "hint": "Dos cosas: la traba que lo sostiene y la cuerda",
    "shots": 0, "time": 60,
    "prisoner": [13.0, 1.45, 0],
    "zone": [2.0, -3, 9.5, 3],
    "platforms": [{"pos": [12, 0.5, 0], "size": [3, 1, 3]}, {"pos": [11.0, 1.7, -2.3], "size": [0.3, 3.4, 0.3]}],
    "slopes": [{"pos": [11.85, 1.16, 0], "size": [3.0, 0.15, 1.2], "roll": 8}],
    "parts": [
        {"type": "slide", "pos": [10.42, 1.4, 0], "size": [0.1, 0.44, 1.2], "open": [0, 0.6, 0], "color": "#c8402e"},
        # Traba bajo el peso: la palanca la corre hacia atras.
        {"type": "slide", "pos": [11.0, 1.62, -1.75], "size": [0.6, 0.12, 0.6], "open": [0, 0, 0.9], "speed": 1.5, "color": "#e0a12f"},
    ],
    "mechs": [
        {"type": "weight", "pos": [11.0, 3.2, -1.75], "rope": 1.27, "fall": 1.2, "mass": 6.0, "targets": [0], "label": "PESO"},
        {"type": "lever", "pos": [9.0, 0, -2.6], "targets": [1], "label": "TRABA"},
    ],
    "solution": [{"tap": 1}, {"wait": 1.0}, {"tap": 0}],
    "wrong": [{"tap": 0}],
    "medals": [165, 195, 225],
})

# 10 — Engranajes: la manivela gira la jaula de a 60 grados; el hueco tiene que quedar abajo. Una compuerta del canal
# de salida solo se abre en ese paso (open_step).
LEVELS.append({
    "title": "Engranajes",
    "objective": "Girá la MANIVELA: cada toque mueve la jaula un diente. Cuando el hueco queda abajo, la dorada cae al canal.",
    "hint": "Contá los toques: si te pasás, la compuerta del canal se cierra",
    "shots": 0, "time": 60,
    "prisoner": [12.0, 2.2, 0],
    "zone": [1.5, -2.5, 8.6, 2.5],
    "platforms": [support(9.0, 11.8, 1.38), {"pos": [12.0, 1.3, 0.55], "size": [0.2, 2.6, 0.2]}],
    "slopes": [ramp(12.3, 1.55, 9.0, 1.3)] + rails(12.3, 1.55, 9.0, 1.3),
    "parts": [
        {"type": "rotor", "pos": [12.0, 2.2, 0], "axis": [0, 0, 1], "radius": 0.42, "bars": 12, "gap": 2, "depth": 0.6,
         "steps": 6, "phase": 75, "dir": -1, "speed": 1.4},
        {"type": "slide", "pos": [10.0, 1.65, 0], "size": [0.1, 0.45, 1.06], "open": [0, 0.7, 0], "speed": 2.0, "color": "#e0a12f"},
    ],
    "mechs": [{"type": "crank", "pos": [13.6, 0, -2.2], "steps": 6, "open_step": 3, "targets": [0, 1], "label": "MANIVELA"}],
    "solution": [{"tap": 0}, {"wait": 0.9}, {"tap": 0}, {"wait": 0.9}, {"tap": 0}],
    "medals": [165, 195, 225],
})

# 11 — Dos caminos y reloj: al final de la rampa, una plataforma que se inclina a un costado elige el tobogan (uno va al
# pozo); la compuerta de arriba se abre 3 segundos con el boton del reloj. Primero el camino, despues el reloj.
LEVELS.append({
    "title": "Dos caminos",
    "objective": "El DESVÍO inclina la plataforma del cruce hacia un tobogán: uno va al pozo. Elegí el camino y abrí la compuerta del RELOJ (3 s).",
    "hint": "Primero el camino, después el reloj",
    "shots": 0, "time": 70,
    "prisoner": [15.0, 2.3, 0],
    "zone": [9.4, 2.4, 12.6, 5.2],
    "platforms": [support(12.0, 15.6, 1.95, w=1.2), {"pos": [10.9, 0.85, 0], "size": [0.4, 1.7, 0.4]}],
    "slopes": [ramp(15.6, 2.22, 11.7, 1.95)] + rails(15.6, 2.22, 11.7, 1.95)
              + [chute_z(10.2, 11.6, 0.62, 1.7, 3.4, 0.05), chute_z(10.2, 11.6, -0.62, 1.7, -3.4, 0.05)],
    "walls": [{"pos": [15.65, 2.5, 0], "size": [0.1, 0.5, 1.0]}, {"pos": [10.15, 2.0, 0], "size": [0.1, 0.5, 1.3]},
              # Bordes al pie de los toboganes: la pelota se frena en la zona (o en el pozo) y no sigue de largo.
              {"pos": [11.0, 0.2, 5.3], "size": [3.6, 0.4, 0.15]}, {"pos": [11.0, 0.2, -5.3], "size": [3.6, 0.4, 0.15]},
              {"pos": [9.3, 0.2, 3.85], "size": [0.15, 0.4, 2.9]}, {"pos": [12.7, 0.2, 3.85], "size": [0.15, 0.4, 2.9]},
              {"pos": [9.3, 0.2, -3.85], "size": [0.15, 0.4, 2.9]}, {"pos": [12.7, 0.2, -3.85], "size": [0.15, 0.4, 2.9]}],
    "parts": [
        {"type": "slide", "pos": [13.8, 2.33, 0], "size": [0.1, 0.5, 1.06], "open": [0, 0.7, 0], "speed": 2.4, "color": "#e06a2f"},
        # Cruce: plataforma inclinada hacia el pozo (z < 0); el desvio la inclina hacia el tobogan de la zona (z > 0).
        {"type": "hinge", "pos": [10.9, 1.82, 0], "size": [1.4, 0.1, 1.24], "rot": [-9, 0, 0], "hinge": [10.9, 1.82, 0],
         "axis": [1, 0, 0], "angle": 18, "speed": 1.2, "color": "#2fb3c0"},
    ],
    "mechs": [
        {"type": "button", "mode": "timer", "time": 3.0, "pos": [14.6, 0, -2.0], "targets": [0], "label": "RELOJ"},
        {"type": "lever", "pos": [8.6, 0, -2.0], "targets": [1], "label": "DESVÍO"},
    ],
    "pits": [[9.4, -5.2, 12.6, -2.4]],
    "solution": [{"tap": 1}, {"wait": 1.3}, {"tap": 0}],
    "wrong": [{"tap": 0}],
    "medals": [170, 210, 240],
})

# 12 — Maestro: la secuencia abre la traba del peso, el peso levanta la compuerta y el puente hay que bajarlo antes.
LEVELS.append({
    "title": "Maestro",
    "objective": "Todo junto: la SECUENCIA saca la traba del peso, el PESO abre la compuerta y el PUENTE tiene que estar abajo.",
    "hint": "Puente, secuencia de la cerradura y recién después el peso",
    "shots": 0, "time": 90,
    "prisoner": [15.0, 2.3, 0],
    "zone": [1.0, -2.5, 7.6, 2.5],
    "platforms": [support(13.2, 15.6, 1.95), support(8.0, 10.9, 1.7), {"pos": [14.0, 1.9, -2.0], "size": [0.3, 3.8, 0.3]}],
    "slopes": [ramp(15.6, 2.12, 13.2, 1.98), ramp(10.95, 1.78, 8.0, 1.62)] + rails(15.6, 2.12, 13.2, 1.98) + rails(10.95, 1.78, 8.0, 1.62),
    "walls": [{"pos": [15.65, 2.35, 0], "size": [0.1, 0.5, 1.0]}],
    "parts": [
        {"type": "slide", "pos": [13.45, 2.24, 0], "size": [0.1, 0.44, 1.06], "open": [0, 0.65, 0], "color": "#c8402e"},
        dict(ramp_part(13.15, 1.97, 10.9, 1.82), hinge=[10.9, 1.82, 0], axis=[0, 0, 1], angle=88, invert=True, start=1, speed=0.7),
        {"type": "slide", "pos": [14.0, 1.82, -1.45], "size": [0.6, 0.12, 0.6], "open": [0, 0, 0.9], "speed": 1.5, "color": "#e0a12f"},
    ],
    "mechs": [
        {"type": "lever", "pos": [12.0, 0, -2.6], "targets": [1], "label": "PUENTE"},
        {"type": "switch", "group": "m", "order": 2, "pos": [8.4, 0, -2.6], "color": "#1f9d55"},
        {"type": "switch", "group": "m", "order": 1, "pos": [9.7, 0, -2.6], "color": "#9b3fb8"},
        {"type": "lock", "group": "m", "n": 2, "pos": [10.4, 1.4, -1.9], "yaw": -90, "colors": ["#9b3fb8", "#1f9d55"], "targets": [2]},
        {"type": "weight", "pos": [14.0, 3.4, -1.45], "rope": 1.27, "fall": 1.2, "mass": 6.0, "targets": [0], "label": "PESO"},
    ],
    "pits": [[10.95, -1.4, 13.15, 1.4]],
    "solution": [{"tap": 0}, {"wait": 2.2}, {"tap": 2}, {"tap": 1}, {"wait": 1.0}, {"tap": 4}],
    "wrong": [{"tap": 2}, {"tap": 1}, {"wait": 1.0}, {"tap": 4}],
    "medals": [160, 200, 235],
})


# Tiempo minimo posible de cada nivel (s): la fisica no deja resolverlo antes (lo usa el servidor online para rechazar
# tiempos imposibles). Medido con la solucion en tests/test_rescate_mechs.gd y con margen para toques mas rapidos.
MIN_TIME = {"La palanca": 2.5, "Puente levadizo": 8.0, "Mantené apretado": 4.0, "Secuencia de colores": 2.5, "Contrapeso": 2.5, "Engranajes": 5.0, "Dos caminos": 5.0, "Maestro": 8.0}


def main():
    for lv in LEVELS:
        lv["min_time"] = MIN_TIME[lv["title"]]
    with open(PATH, encoding="utf-8") as f:
        data = json.load(f)
    games = data["games"] if isinstance(data, dict) else data
    g = next(x for x in games if x["id"] == "rescate")
    g["levels"] = g["levels"][:KEEP_OLD] + LEVELS
    g["description"] = ("Una pelota dorada está atrapada: palancas, botones, secuencias, engranajes, contrapesos y puentes "
                        "(y en los primeros niveles, botones que se aprietan de un pelotazo) para llevarla a la zona verde.")
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("rescate: %d niveles (%d nuevos)" % (len(g["levels"]), len(LEVELS)))


if __name__ == "__main__":
    main()
