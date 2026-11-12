#!/usr/bin/env python3
"""Genera la hoja de sprites del publico 2D de los minijuegos arcade (pedido del usuario: hinchas en PNG que se mueven y
festejan, en vez de cubos 3D; mas liviano para el telefono y para el navegador).

Salida: assets/arcade/crowd_atlas.png, una grilla de COLS x ROWS celdas de CELL_W x CELL_H pixeles.
  - Columnas (cuadros de animacion): 0 quieto, 1 aplaude, 2 brazos arriba, 3 salta con los brazos arriba,
    4 se lamenta (manos a la cabeza), 5 brazos cruzados (decepcion). Los dos ultimos se sumaron el 2026-11-12 (el publico
    de penales y tiros libres festeja y se lamenta; sin silbidos: al usuario no le gustaron).
  - Filas (variantes): camiseta, piel, pelo, gorro, bufanda.
El shader del publico (ArcadeLook.crowd_shader) elige la fila por instancia y el cuadro segun el tiempo y el festejo.

Uso: python3 tools/gen_crowd_sprites.py   (determinista: siempre produce la misma imagen)
"""
import os
from PIL import Image, ImageDraw

COLS, ROWS = 6, 12
CELL_W, CELL_H = 64, 96
SS = 4  # sobremuestreo para bordes suaves

SHIRTS = [(220, 50, 60), (45, 105, 230), (245, 205, 40), (240, 240, 245), (140, 60, 190), (40, 170, 90),
          (245, 130, 30), (110, 190, 245), (220, 50, 60), (45, 105, 230), (245, 205, 40), (30, 30, 40)]
SECOND = [(255, 255, 255), (255, 220, 40), (40, 60, 160), (45, 105, 230), (255, 255, 255), (255, 255, 255),
          (30, 30, 40), (255, 255, 255), (30, 30, 40), (255, 255, 255), (45, 105, 230), (245, 205, 40)]
SKINS = [(241, 200, 160), (198, 140, 95), (140, 90, 60), (90, 60, 40)]
HAIRS = [(30, 25, 25), (95, 60, 30), (230, 190, 100), (150, 70, 35), (170, 170, 170)]
# estilo de camiseta: 0 lisa, 1 rayas verticales, 2 banda horizontal
STYLE = [0, 1, 2, 0, 1, 0, 2, 1, 2, 0, 1, 0]
# accesorio: 0 nada, 1 gorro, 2 bufanda, 3 pelo largo
EXTRA = [0, 2, 1, 3, 0, 2, 3, 1, 0, 2, 3, 1]


def s(v):
    return int(round(v * SS))


def draw_fan(d: ImageDraw.ImageDraw, ox: int, oy: int, row: int, frame: int) -> None:
    shirt, second = SHIRTS[row], SECOND[row]
    skin = SKINS[(row * 3) % len(SKINS)]
    hair = HAIRS[(row * 2 + 1) % len(HAIRS)]
    jump = -4 if frame == 3 else 0

    def P(x, y):
        return (s(ox + x), s(oy + y + jump))

    def box(x0, y0, x1, y1, c, r=0):
        d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=s(r), fill=c + (255,))

    def circ(x, y, r, c):
        d.ellipse([P(x - r, y - r), P(x + r, y + r)], fill=c + (255,))

    def line(a, b, w, c):
        d.line([P(*a), P(*b)], fill=c + (255,), width=s(w))
        circ(b[0], b[1], w * 0.5, c)
        circ(a[0], a[1], w * 0.5, c)

    # brazos (detras del torso cuando estan abajo)
    sh_l, sh_r = (19, 57), (45, 57)
    if frame == 0:
        hands = [(17, 88), (47, 88)]
        elbows = [(14, 72), (50, 72)]
    elif frame == 1:
        hands = [(30, 64), (34, 64)]
        elbows = [(10, 70), (54, 70)]
    elif frame == 2:
        hands = [(8, 16), (56, 16)]
        elbows = [(11, 38), (53, 38)]
    elif frame == 3:
        hands = [(15, 10), (49, 10)]
        elbows = [(14, 33), (50, 33)]
    elif frame == 4:
        # manos a la cabeza
        hands = [(23, 25), (41, 25)]
        elbows = [(6, 34), (58, 34)]
    else:
        # brazos cruzados sobre el pecho
        hands = [(44, 70), (20, 66)]
        elbows = [(12, 74), (52, 70)]
    behind = frame == 0
    if behind:
        for sh, el, ha in zip((sh_l, sh_r), elbows, hands):
            line(sh, el, 8, shirt)
            line(el, ha, 7, skin)
    # torso
    box(15, 52, 49, 104, shirt, 9)
    st = STYLE[row]
    if st == 1:
        for x in (21, 30, 39):
            box(x, 54, x + 4, 104, second)
    elif st == 2:
        box(15, 66, 49, 74, second)
    # cuello y cabeza
    box(28, 44, 36, 56, skin, 2)
    circ(32, 36, 12, skin)
    ex = EXTRA[row]
    if ex == 3:
        box(19, 28, 25, 52, hair, 3)
        box(39, 28, 45, 52, hair, 3)
    if ex == 1:
        d.pieslice([P(19, 18), P(45, 44)], 180, 360, fill=shirt + (255,))
        box(19, 30, 45, 33, second)
        circ(32, 18, 3, second)
    else:
        d.pieslice([P(20, 22), P(44, 46)], 180, 360, fill=hair + (255,))
    # cara: ojos y boca (abierta al festejar)
    circ(27.5, 37, 1.6, (25, 20, 20))
    circ(36.5, 37, 1.6, (25, 20, 20))
    if frame == 4:
        # boca abierta de lamento y cejas caidas
        d.ellipse([P(29.5, 42), P(34.5, 47)], fill=(120, 20, 30, 255))
        d.line([P(24.5, 33), P(29.5, 34.5)], fill=(40, 30, 30, 255), width=s(1.2))
        d.line([P(39.5, 33), P(34.5, 34.5)], fill=(40, 30, 30, 255), width=s(1.2))
    elif frame == 5:
        # boca torcida y cejas fruncidas (decepcion)
        d.arc([P(28.5, 42), P(35.5, 48)], 200, 340, fill=(110, 40, 40, 255), width=s(1.4))
        d.line([P(24.5, 32), P(29.5, 34)], fill=(40, 30, 30, 255), width=s(1.4))
        d.line([P(39.5, 32), P(34.5, 34)], fill=(40, 30, 30, 255), width=s(1.4))
    elif frame >= 2:
        d.ellipse([P(28.5, 41), P(35.5, 47)], fill=(120, 20, 30, 255))
    else:
        d.line([P(29, 43), P(35, 43)], fill=(110, 40, 40, 255), width=s(1.4))
    if ex == 2 and (frame < 2 or frame >= 4):
        box(22, 50, 42, 56, second, 2)
        box(23, 56, 28, 70, shirt, 1)
    if not behind:
        for sh, el, ha in zip((sh_l, sh_r), elbows, hands):
            line(sh, el, 8, shirt)
            line(el, ha, 7, skin)
        for ha in hands:
            circ(ha[0], ha[1], 4.2, skin)
    if ex == 2 and frame in (2, 3):
        # bufanda estirada entre las manos
        a, b = hands
        top = min(a[1], b[1]) - 2
        box(a[0] + 2, top, b[0] - 2, top + 7, second, 1)
        for k in range(int(a[0]) + 6, int(b[0]) - 4, 8):
            box(k, top, k + 4, top + 7, shirt)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "arcade", "crowd_atlas.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    big = Image.new("RGBA", (COLS * CELL_W * SS, ROWS * CELL_H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for r in range(ROWS):
        for f in range(COLS):
            # recorte por celda: dibujar en una capa aparte para que nada invada la vecina
            layer = Image.new("RGBA", (CELL_W * SS, CELL_H * SS), (0, 0, 0, 0))
            draw_fan(ImageDraw.Draw(layer), 0, 0, r, f)
            big.alpha_composite(layer, (f * CELL_W * SS, r * CELL_H * SS))
    img = big.resize((COLS * CELL_W, ROWS * CELL_H), Image.LANCZOS)
    img.save(out, optimize=True)
    print("escrito", out, img.size)


if __name__ == "__main__":
    main()
