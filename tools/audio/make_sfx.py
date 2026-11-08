#!/usr/bin/env python3
"""Genera los efectos de sonido del juego por sintesis (sin muestras de terceros): golpeos, toques, botes, poste, red,
silbato, guantes del arquero, ambiente de publico y festejo. Salida: WAV mono 16 bits a 22050 Hz en assets/audio/.

Uso: python3 tools/audio/make_sfx.py   (determinista: misma semilla, mismos archivos)
"""
import os
import struct
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(20261029)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env_exp(t, tau, attack=0.002):
    a = np.clip(t / attack, 0.0, 1.0)
    return a * np.exp(-t / tau)


def bandpass(x, lo, hi):
    """Filtro pasa banda por FFT (suave en los bordes)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    X = np.fft.rfft(x)
    w = np.clip((f - lo * 0.7) / (lo * 0.3 + 1e-9), 0, 1) * np.clip((hi * 1.3 - f) / (hi * 0.3 + 1e-9), 0, 1)
    return np.fft.irfft(X * w, n)


def sweep(t, f0, f1, tau):
    """Seno con frecuencia que cae exponencialmente de f0 a f1 (cuerpo del golpe)."""
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_out(x, sec=0.01):
    n = int(SR * sec)
    if n > 0 and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, peak=0.9):
    x = fade_out(norm(x, peak))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in x))
    print(name, len(x) / SR, "s")


def kick(hard):
    sec = 0.32 if hard else 0.2
    t = t_axis(sec)
    body = sweep(t, 190 if hard else 230, 55 if hard else 80, 0.035) * env_exp(t, 0.07 if hard else 0.045)
    click = bandpass(rng.standard_normal(len(t)), 2500, 7000) * env_exp(t, 0.003, 0.0005)
    slap = bandpass(rng.standard_normal(len(t)), 700, 3200) * env_exp(t, 0.022 if hard else 0.012)
    return body * 1.0 + click * (0.6 if hard else 0.35) + slap * (0.9 if hard else 0.45)


def touch():
    t = t_axis(0.12)
    body = sweep(t, 260, 130, 0.02) * env_exp(t, 0.025)
    slap = bandpass(rng.standard_normal(len(t)), 900, 3000) * env_exp(t, 0.008)
    return body + slap * 0.4


def bounce():
    t = t_axis(0.22)
    body = sweep(t, 150, 70, 0.03) * env_exp(t, 0.055)
    noise = bandpass(rng.standard_normal(len(t)), 200, 1500) * env_exp(t, 0.02)
    return body + noise * 0.5


def post():
    t = t_axis(1.1)
    parts = [(523, 0.55, 1.0), (1312, 0.42, 0.7), (2217, 0.3, 0.5), (3175, 0.22, 0.35), (4290, 0.15, 0.25), (887, 0.6, 0.5)]
    x = np.zeros(len(t))
    for f, tau, a in parts:
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * env_exp(t, tau, 0.0008)
    click = bandpass(rng.standard_normal(len(t)), 1500, 8000) * env_exp(t, 0.004, 0.0003)
    thud = sweep(t, 160, 80, 0.03) * env_exp(t, 0.05)
    return x * 0.8 + click * 0.8 + thud * 0.6


def net():
    t = t_axis(0.7)
    n = bandpass(rng.standard_normal(len(t)), 1800, 7500)
    rustle = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t + 1.3) * np.sin(2 * np.pi * 7 * t)
    e = np.clip(t / 0.015, 0, 1) * np.exp(-t / 0.22)
    low = bandpass(rng.standard_normal(len(t)), 120, 600) * np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.08)
    return n * rustle * e + low * 0.5


def whistle(sec):
    t = t_axis(sec)
    trill = 0.65 + 0.35 * np.sign(np.sin(2 * np.pi * 34 * t))      # la bolita del silbato
    f = 2950 + 60 * np.sin(2 * np.pi * 5 * t)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.25 * np.sin(2 * 2 * np.pi * np.cumsum(f) / SR)
    breath = bandpass(rng.standard_normal(len(t)), 2000, 6000) * 0.15
    e = np.clip(t / 0.02, 0, 1) * np.clip((sec - t) / 0.06, 0, 1)
    return (tone * trill + breath) * e


def glove():
    t = t_axis(0.18)
    slap = bandpass(rng.standard_normal(len(t)), 500, 2600) * env_exp(t, 0.03, 0.001)
    body = sweep(t, 200, 90, 0.02) * env_exp(t, 0.04)
    return slap + body * 0.7


def crowd_loop(sec=8.0):
    """Murmullo de publico en bucle: muchas 'voces' (ruido formateado en vocales) con ondulaciones lentas."""
    t = t_axis(sec)
    x = np.zeros(len(t))
    for i in range(40):
        f1 = rng.uniform(450, 900)
        band = bandpass(rng.standard_normal(len(t)), f1 * 0.7, f1 * 1.6)
        mod = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.15, 0.9) * t + rng.uniform(0, 6.28))
        x += band * mod * rng.uniform(0.4, 1.0)
    x += bandpass(rng.standard_normal(len(t)), 150, 400) * 2.0
    # bucle sin corte: el final se funde con el principio
    n = int(SR * 0.5)
    x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return x[:-n]


def cheer(sec=4.0):
    t = t_axis(sec)
    x = np.zeros(len(t))
    for i in range(60):
        f1 = rng.uniform(600, 1300)                     # vocal "aaah" de muchas voces
        band = bandpass(rng.standard_normal(len(t)), f1 * 0.8, f1 * 1.5)
        start = rng.uniform(0.0, 0.35)
        e = np.clip((t - start) / 0.25, 0, 1) * np.clip((sec - t) / 1.6, 0, 1)
        x += band * e * rng.uniform(0.5, 1.0)
    x += bandpass(rng.standard_normal(len(t)), 2500, 6000) * np.clip(t / 0.3, 0, 1) * np.clip((sec - t) / 1.6, 0, 1) * 3.0
    return x


def ooh(sec=1.6):
    t = t_axis(sec)
    x = np.zeros(len(t))
    for i in range(40):
        f1 = rng.uniform(350, 650)                      # "ooh" grave de la tribuna
        band = bandpass(rng.standard_normal(len(t)), f1 * 0.8, f1 * 1.4)
        e = np.clip(t / 0.12, 0, 1) * np.clip((sec - t) / 0.9, 0, 1)
        x += band * e * rng.uniform(0.5, 1.0)
    return x


if __name__ == "__main__":
    save("kick_hard", kick(True))
    save("kick_soft", kick(False), 0.75)
    save("touch", touch(), 0.5)
    save("bounce", bounce(), 0.6)
    save("post", post())
    save("net", net(), 0.8)
    save("whistle_short", whistle(0.38))
    save("whistle_long", whistle(1.3))
    save("glove", glove(), 0.8)
    save("crowd_loop", crowd_loop(), 0.5)
    save("cheer", cheer(), 0.85)
    save("ooh", ooh(), 0.7)
