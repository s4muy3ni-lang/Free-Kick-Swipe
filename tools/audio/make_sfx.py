#!/usr/bin/env python3
"""Genera los efectos de sonido del juego por sintesis (sin muestras de terceros): golpeos, toques, botes, poste, red,
silbato, guantes del arquero y la tribuna (ambiente, festejo y «ooh»). Salida: WAV mono 16 bits a
22050 Hz en assets/audio/.

2026-11-12 (pedido del usuario: «el ruido del poste es muy falso»; «el publico se calla, debe estar activo, festejar y
abuchear; el festejo mas vivo y largo»):
  - Poste: sintesis modal de un caño de aluminio hueco (modos de flexion inarmonicos y modos de la pared, cada uno en
    pareja levemente desafinada que «late» como un caño ovalado real, amortiguacion mayor en los agudos, el golpe seco de
    la pelota) y la reverberacion del estadio. Tres variantes (post, post2, post3).
  - Tribuna: voces sintetizadas (pulso glotal con su tono y entonacion, filtrado por las formantes de las vocales, silabas
    y frases), cientos de voces lejanas como textura, aplausos y un bombo lejano, todo con la reverberacion del estadio.
    Ambiente en bucle (charla y aliento), festejo de ~9 s (grito, aplausos, bombo; el mismo para goles y atajadas) y
    «ooh». Los silbidos y el abucheo (silbatina) se quitaron el mismo dia: al usuario no le gustaron.
Cada sonido usa su propia semilla: regenerar uno no cambia los demas.

Uso: python3 tools/audio/make_sfx.py [nombre ...]   (determinista; sin nombres, todos)
"""
import os
import struct
import sys
import wave
import zlib

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(20261029)


def seed(name):
    global rng
    rng = np.random.default_rng(zlib.crc32(name.encode()) + 20261029)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env_exp(t, tau, attack=0.002):
    a = np.clip(t / attack, 0.0, 1.0)
    return a * np.exp(-t / tau)


PAD = int(SR * 0.12)


def fft_filter(x, h_of_f, circular=False):
    """Aplica una respuesta en frecuencia (fase cero) por FFT. Sin circular, rellena con ceros: el filtro no «da la
    vuelta» (antes un ataque fuerte al principio dejaba un clic al final del sonido)."""
    n = len(x)
    m = n if circular else n + PAD
    f = np.fft.rfftfreq(m, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x, m) * h_of_f(f), m)[:n]


def bandpass(x, lo, hi, circular=False):
    """Filtro pasa banda por FFT (suave en los bordes)."""
    return fft_filter(x, lambda f: np.clip((f - lo * 0.7) / (lo * 0.3 + 1e-9), 0, 1) * np.clip((hi * 1.3 - f) / (hi * 0.3 + 1e-9), 0, 1), circular)


def lowpass(x, fc, order=2, circular=False):
    return fft_filter(x, lambda f: 1.0 / (1.0 + (f / fc) ** (2 * order)) ** 0.5, circular)


def highpass(x, fc, order=2, circular=False):
    return fft_filter(x, lambda f: ((f / fc) ** (2 * order) / (1.0 + (f / fc) ** (2 * order))) ** 0.5, circular)


def sweep(t, f0, f1, tau):
    """Seno con frecuencia que cae exponencialmente de f0 a f1 (cuerpo del golpe)."""
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def smooth_noise(n, rate_hz):
    """Ruido suave (variacion lenta) de media 0 y desvio ~1: interpolacion de valores al azar cada 1/rate s."""
    k = max(int(n / SR * rate_hz) + 3, 4)
    pts = rng.standard_normal(k)
    x = np.linspace(0, k - 3, n)
    i = np.floor(x).astype(int)
    fr = x - i
    w = 0.5 - 0.5 * np.cos(np.pi * fr)
    return pts[i] * (1 - w) + pts[i + 1] * w


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_out(x, sec=0.01):
    n = int(SR * sec)
    if n > 0 and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, peak=0.9, fade=0.01):
    x = norm(x, peak)
    if fade > 0:
        x = fade_out(x, fade)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(name, round(len(x) / SR, 2), "s")


# --- Espacio: reverberacion del estadio ------------------------------------------------------------------------------

def stadium_ir(rt60=1.5, pre=0.018, sec=None):
    """Respuesta al impulso de un estadio abierto: reflexiones tempranas (tribunas, techo) y una cola difusa que decae
    con RT60, mas rapido en los agudos."""
    sec = sec or rt60 * 1.1
    t = t_axis(sec)
    n = len(t)
    tail = rng.standard_normal(n) * np.exp(-6.9 * t / rt60)
    # estadio abierto: el aire y la gente absorben los agudos; ademas se apagan antes que los graves
    bright = lowpass(tail, 4200)
    dark = lowpass(tail, 1400)
    k = np.clip(t / (rt60 * 0.35), 0, 1)
    tail = bright * (1 - k) + dark * k
    tail *= np.clip((t - pre) / 0.02, 0, 1)
    for d, g in [(0.031, 0.5), (0.047, 0.38), (0.068, 0.3), (0.089, 0.22), (0.12, 0.16)]:
        i = int(d * SR)
        if i < n:
            tail[i] += g * rng.choice([-1, 1]) * 6
    return tail / (np.sqrt(np.sum(tail ** 2)) + 1e-9)


def reverb(x, wet=0.35, rt60=1.5, tail_sec=None):
    """Mezcla el sonido seco con su reverberacion (convolucion por FFT). La salida se alarga con la cola si tail_sec."""
    ir = stadium_ir(rt60)
    n = len(x) + len(ir)
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    dry = np.zeros(n)
    dry[:len(x)] = x
    out = dry * (1 - wet) + y * wet * (np.std(x) / (np.std(y) + 1e-9))
    keep = len(x) + int(SR * (tail_sec if tail_sec is not None else 0))
    return out[:keep]


def loop_reverb(x, wet=0.4, rt60=1.5):
    """Reverberacion circular (convolucion ciclica): el bucle sigue sin corte en el punto de union."""
    ir = stadium_ir(rt60)
    n = len(x)
    irp = np.zeros(n)
    irp[:min(len(ir), n)] = ir[:n]
    y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), n)
    return x * (1 - wet) + y * wet * (np.std(x) / (np.std(y) + 1e-9))


# --- Voces de la tribuna ----------------------------------------------------------------------------------------------

# Formantes (Hz) de las vocales del castellano y su ancho de banda.
VOWELS = {"a": (750, 1250, 2550), "e": (450, 1850, 2550), "i": (300, 2200, 2950), "o": (500, 880, 2450),
          "u": (330, 740, 2350)}
BW = (110, 140, 190)


def formant_filter(x, vowel, shift=1.0):
    def h_of_f(f):
        h = np.zeros_like(f)
        for fk, bk, g in zip(VOWELS[vowel], BW, (1.0, 0.7, 0.35)):
            h += g / (1.0 + ((f - fk * shift) / bk) ** 2)
        # caida del espectro glotal (el diente de sierra ya cae 6 dB por octava; la voz cae unos 12)
        return h / np.sqrt(1.0 + (f / 600.0) ** 2)
    return fft_filter(x, h_of_f)


def glottal(n, f0):
    """Fuente de la voz: diente de sierra con el tono f0 (arreglo, Hz) y un poco de aire (soplo)."""
    ph = np.cumsum(f0) / SR
    saw = 2.0 * (ph % 1.0) - 1.0
    return saw + 0.12 * rng.standard_normal(n)


def voice(sec, f0_base, mode, vowels="aeiou", shift=1.0, start=0.0, length=None):
    """Una voz de la tribuna.
    mode 'talk': habla (silabas de 0,1-0,3 s a ~4,5 por segundo, en frases con pausas);
    mode 'shout': grito sostenido (una vocal larga, con temblor), desde start durante length s."""
    n = int(SR * sec)
    t = np.arange(n) / SR
    drift = smooth_noise(n, 1.2)
    if mode == "talk":
        f0 = f0_base * (1.0 + 0.07 * drift)
    else:
        f0 = f0_base * (1.0 + 0.035 * drift + 0.015 * np.sin(2 * np.pi * rng.uniform(4.5, 6.5) * t))
    src = glottal(n, f0)
    filt = {v: formant_filter(src, v, shift) for v in set(vowels)}
    out = np.zeros(n)
    if mode == "talk":
        tt = rng.uniform(-1.0, 0.5)
        while tt < sec:
            phrase = rng.uniform(0.8, 3.2)
            end = tt + phrase
            while tt < end:
                d = rng.uniform(0.09, 0.28)
                i0, i1 = int(max(tt, 0) * SR), int(min(tt + d, sec) * SR)
                if i1 > i0:
                    seg = np.arange(i1 - i0) / max(i1 - i0 - 1, 1)
                    w = np.sin(np.pi * seg) ** 0.7 * rng.uniform(0.5, 1.0)
                    out[i0:i1] += filt[rng.choice(list(vowels))][i0:i1] * w
                tt += d + rng.uniform(0.02, 0.09)
            tt = end + rng.uniform(0.3, 2.0)
    else:
        length = length if length is not None else sec - start
        e = np.clip((t - start) / rng.uniform(0.08, 0.25), 0, 1) * np.clip((start + length - t) / (0.35 * length), 0, 1)
        e *= 1.0 + 0.25 * smooth_noise(n, 3.0)
        v0 = rng.choice(list(vowels))
        out = filt[v0] * np.clip(e, 0, None)
    return out / (np.std(out) + 1e-9) * np.sqrt(np.mean(out != 0) + 1e-3)


def far_crowd(sec, level_curve=None, center=900, width=1.0):
    """Miles de voces lejanas: ruido con el espectro medio de la voz, con oleaje lento."""
    n = int(SR * sec)
    x = rng.standard_normal(n)
    x = formant_filter(x, "a", 1.0) * 0.5 + formant_filter(x, "o", 1.0) * 0.5
    x = bandpass(x, 150 * width, 3500)
    sw = 1.0 + 0.3 * smooth_noise(n, 0.6) + 0.15 * smooth_noise(n, 3.0)
    if level_curve is not None:
        sw *= level_curve
    return x / (np.std(x) + 1e-9) * sw


def clap(n_len=0.03):
    t = t_axis(n_len)
    return bandpass(rng.standard_normal(len(t)), 700, 3800) * env_exp(t, 0.006, 0.0006)


def claps(sec, people, rate_lo, rate_hi, curve=None):
    """Aplausos: cada persona aplaude a su ritmo (con su propio color), en rafagas."""
    n = int(SR * sec)
    out = np.zeros(n)
    for _ in range(people):
        rate = rng.uniform(rate_lo, rate_hi)
        tt = rng.uniform(0, 1.0 / rate)
        c = clap(rng.uniform(0.02, 0.04)) * rng.uniform(0.4, 1.0)
        c = bandpass(c, rng.uniform(500, 1200), rng.uniform(2500, 5000))
        while tt < sec:
            i = int(tt * SR)
            if curve is None or rng.uniform() < curve[min(i, n - 1)]:
                j = min(n, i + len(c))
                out[i:j] += c[:j - i]
            tt += 1.0 / rate * rng.uniform(0.9, 1.1)
    return out


def bombo(sec, pattern, bpm, start=0.0):
    """Bombo lejano: parche grave con su golpe, a tiempo (pattern: golpes en corcheas de un compas)."""
    n = int(SR * sec)
    out = np.zeros(n)
    beat = 60.0 / bpm / 2
    hit_t = t_axis(0.5)
    hit = sweep(hit_t, 110, 52, 0.04) * env_exp(hit_t, 0.16, 0.003)
    hit += bandpass(rng.standard_normal(len(hit_t)), 200, 1500) * env_exp(hit_t, 0.015) * 0.4
    tt = start
    k = 0
    while tt < sec:
        if pattern[k % len(pattern)]:
            i = int(tt * SR)
            j = min(n, i + len(hit))
            out[i:j] += hit[:j - i] * (1.0 if k % len(pattern) == 0 else 0.8)
        tt += beat
        k += 1
    return out


# --- Golpes de la pelota (sin cambios) --------------------------------------------------------------------------------

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


# --- Poste ------------------------------------------------------------------------------------------------------------

def post(variant=0):
    """Pelotazo en el poste: caño de aluminio de 12 cm (pared de ~3,5 mm) empotrado, con la red colgada.
    - Modos de flexion del caño (cociente ~ (2n+1)^2 de una viga) entre 120 y 900 Hz: el «tong» grave.
    - Modos de la pared (ovalizacion) entre 900 y 4500 Hz: el brillo metalico, que se apaga rapido.
    - Cada modo en pareja levemente desafinada (el caño no es redondo perfecto): late, como el real.
    - Excitacion: un contacto de ~6 ms (la pelota es blanda) que pesa mas en los graves; el golpe seco de la pelota.
    - Reverberacion del estadio."""
    sec = 1.6
    t = t_axis(sec)
    n = len(t)
    x = np.zeros(n)
    base = [148.0, 161.0, 139.0][variant] * rng.uniform(0.98, 1.02)
    bend = [base * ((2 * k + 1) / 3.0) ** 2 for k in range(1, 9)]
    bend = [f for f in bend if f < 1100]
    shell = list(rng.uniform(900, 4500, 26))
    for f in bend + shell:
        f *= rng.uniform(0.985, 1.015)
        # amplitud: espectro del contacto blando (cae con la frecuencia) y peso de cada familia
        contact = 1.0 / (1.0 + (f / 1400.0) ** 2)
        a = contact * (1.0 if f < 1100 else 0.55) * rng.uniform(0.5, 1.0)
        tau = 0.42 * (500.0 / f) ** 0.55 * rng.uniform(0.8, 1.2)     # mas amortiguado en los agudos
        tau = min(tau, 0.75)
        d = f * rng.uniform(0.002, 0.006)                              # pareja desafinada: latido
        ph = rng.uniform(0, 6.28)
        x += a * (np.sin(2 * np.pi * f * t + ph) + 0.7 * np.sin(2 * np.pi * (f + d) * t + ph * 1.3)) * env_exp(t, tau, 0.0006)
    # transitorio del impacto (metal + cuero) y golpe de la pelota
    click = highpass(rng.standard_normal(n), 2500) * env_exp(t, 0.0025, 0.0002)
    thud = sweep(t, 210, 95, 0.012) * env_exp(t, 0.03, 0.0008)
    slap = bandpass(rng.standard_normal(n), 400, 2500) * env_exp(t, 0.01, 0.0005)
    dry = x / (np.max(np.abs(x)) + 1e-9) + click * 0.3 + thud * 0.55 + slap * 0.45
    return reverb(dry, wet=0.16, rt60=1.2)


# --- Tribuna ----------------------------------------------------------------------------------------------------------

def crowd_loop(sec=14.0):
    """Ambiente en bucle: charla de la tribuna (voces cercanas y miles lejanas con oleaje), algunos aplausos
    sueltos, gritos de aliento y un bombo lejano. Se escucha siempre (pedido: «en calma el publico se debe escuchar»)."""
    ov = 1.5
    tot = sec + ov
    n = int(SR * tot)
    talk = np.zeros(n)
    for i in range(46):
        male = rng.uniform() < 0.8
        f0 = rng.uniform(95, 145) if male else rng.uniform(175, 240)
        talk += voice(tot, f0, "talk", shift=1.0 if male else 1.12) * rng.uniform(0.4, 1.0) * rng.uniform(0.6, 1.0)
    far = far_crowd(tot)
    x = talk / (np.std(talk) + 1e-9) * 0.6 + far * 0.75
    # gritos de aliento sueltos
    for _ in range(7):
        st = rng.uniform(0, tot - 1.5)
        x += voice(tot, rng.uniform(170, 260), "shout", vowels="aeo", start=st, length=rng.uniform(0.5, 1.1)) * 0.9
    # aplausos sueltos
    x += claps(tot, 10, 2.0, 3.2, curve=np.clip(0.4 + 0.6 * smooth_noise(n, 0.3), 0, 1)) * 0.5
    x += bombo(tot, [1, 0, 0, 1, 0, 1, 1, 0], 112, start=0.2) * 0.9
    x = lowpass(x, 5500)
    # bucle sin corte: el final se funde con el principio, y la reverberacion es circular
    m = int(SR * ov)
    x[:m] = x[:m] * np.linspace(0, 1, m) + x[-m:] * np.linspace(1, 0, m)
    x = x[:-m]
    return loop_reverb(x, wet=0.45, rt60=1.6)


def cheer(sec=9.5):
    """Festejo de gol (y de atajada: el mismo): el estadio explota en un grito (cientos de voces en «o»/«a», agudas de la
    euforia), aplausos y el bombo; se sostiene unos segundos con oleadas y baja de a poco. Sin silbidos (2026-11-12)."""
    n = int(SR * sec)
    t = np.arange(n) / SR
    swell = np.clip(t / 0.35, 0, 1) * (1.0 + 0.25 * np.exp(-((t - 1.2) / 0.8) ** 2)) * np.clip((sec - t) / 5.5, 0, 1) ** 1.3
    x = np.zeros(n)
    for i in range(70):
        f0 = rng.uniform(170, 330)
        st = rng.uniform(0.0, 0.45)
        x += voice(sec, f0, "shout", vowels="oa", start=st, length=rng.uniform(2.5, 6.0)) * rng.uniform(0.5, 1.0)
    for i in range(40):
        f0 = rng.uniform(150, 280)
        st = rng.uniform(2.0, 6.5)
        x += voice(sec, f0, "shout", vowels="aeo", start=st, length=rng.uniform(0.6, 1.8)) * rng.uniform(0.4, 0.8)
    x = x / (np.std(x) + 1e-9)
    x += far_crowd(sec, swell, width=1.2) * 0.9
    x *= swell
    x += claps(sec, 120, 3.0, 5.5, curve=np.clip(swell * 1.2 * np.clip((t - 0.6) / 0.6, 0, 1), 0, 1)) * 0.45
    x += bombo(sec, [1, 0, 1, 1, 0, 1, 1, 0], 128, start=1.5) * 0.7 * np.clip((t - 1.5) / 0.3, 0, 1) * np.clip((sec - t) / 3.0, 0, 1)
    x = lowpass(x, 6500)
    return reverb(x, wet=0.38, rt60=1.6)


def ooh(sec=2.0):
    """«Uuuh» de la tribuna en una ocasion errada: voces en «o»/«u» que suben y caen."""
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i in range(55):
        f0 = rng.uniform(110, 230)
        x += voice(sec, f0, "shout", vowels="ou", start=rng.uniform(0.0, 0.15), length=rng.uniform(1.2, 1.8)) * rng.uniform(0.5, 1.0)
    curve = np.clip(t / 0.25, 0, 1) * np.clip((sec - t) / 1.1, 0, 1)
    x = x / (np.std(x) + 1e-9) * curve + far_crowd(sec, curve) * 0.5
    return reverb(lowpass(x, 5000), wet=0.4, rt60=1.6)


# --- Mecanismos del Rescate ------------------------------------------------------------------------------------------

def mech_click():
    """Palanca o interruptor: clic metalico corto (dos golpecitos del trinquete) con un cuerpo grave chico."""
    t = t_axis(0.16)
    tick = bandpass(rng.standard_normal(len(t)), 2500, 7000) * env_exp(t, 0.006, 0.0005)
    tick2 = np.roll(tick, int(0.035 * SR)) * 0.6
    body = sweep(t, 420, 260, 0.01) * env_exp(t, 0.03)
    return tick + tick2 + body * 0.5


def mech_gate():
    """Compuerta o puente que se mueve: roce grave de metal con el tableteo de los dientes de un engranaje."""
    sec = 0.75
    t = t_axis(sec)
    rumble = bandpass(rng.standard_normal(len(t)), 80, 420) * 0.8
    teeth = np.zeros(len(t))
    step = int(SR / 18)
    for i in range(0, len(t), step):
        n = min(int(0.012 * SR), len(t) - i)
        teeth[i:i + n] += bandpass(rng.standard_normal(n + 64), 900, 3500)[:n] * np.exp(-np.arange(n) / (0.003 * SR))
    e = np.clip(t / 0.05, 0, 1) * np.clip((sec - t) / 0.12, 0, 1)
    return (rumble + teeth * 0.5) * e


def mech_release():
    """Traba que se suelta: golpe metalico seco y el resorte que vibra (tono que cae)."""
    t = t_axis(0.5)
    clank = bandpass(rng.standard_normal(len(t)), 600, 4500) * env_exp(t, 0.02, 0.001)
    spring = np.sin(2 * np.pi * np.cumsum(330 * np.exp(-t / 0.4) + 140) / SR) * env_exp(t, 0.18) * 0.35
    return clank + spring


def mech_error():
    """Secuencia equivocada: zumbido grave corto, dos veces."""
    t = t_axis(0.42)
    buzz = np.sign(np.sin(2 * np.pi * 110 * t)) * 0.5 + np.sin(2 * np.pi * 220 * t) * 0.3
    gate = ((t % 0.21) < 0.15).astype(float)
    return lowpass(buzz * gate, 1600) * np.clip((0.42 - t) / 0.05, 0, 1)


SOUNDS = {
    "kick_hard": (lambda: kick(True), 0.9),
    "kick_soft": (lambda: kick(False), 0.75),
    "touch": (touch, 0.5),
    "bounce": (bounce, 0.6),
    "post": (lambda: post(0), 0.95),
    "post2": (lambda: post(1), 0.95),
    "post3": (lambda: post(2), 0.95),
    "net": (net, 0.8),
    "whistle_short": (lambda: whistle(0.38), 0.9),
    "whistle_long": (lambda: whistle(1.3), 0.9),
    "glove": (glove, 0.8),
    "crowd_loop": (crowd_loop, 0.6),
    "cheer": (cheer, 0.92),
    "ooh": (ooh, 0.75),
    "mech_click": (mech_click, 0.7),
    "mech_gate": (mech_gate, 0.6),
    "mech_release": (mech_release, 0.8),
    "mech_error": (mech_error, 0.55),
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(SOUNDS.keys())
    for name in names:
        fn, peak = SOUNDS[name]
        seed(name)
        save(name, fn(), peak, fade=0.0 if name == "crowd_loop" else 0.01)
