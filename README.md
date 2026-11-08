# Fútbol 5

Juego de fútbol 5 / futsal para Android hecho con **Godot 4.7.2** (GDScript, renderer GL Compatibility, física Jolt a 60 Hz).
4 contra 4 con arquero en cada equipo, IA, pases y tiros asistidos, conducción con pelota física y toques dados por el
pie animado, pases filtrados, centros, tiros con chanfle, entradas, reglas con bandas y balón parado, repetición de
los goles, árbitro que sigue la jugada y una sala de práctica con las 133 animaciones (todas usadas en el juego).
Inspiración de jugabilidad: eFootball PES 2021 (ver [`docs/technical-index/GAMEPLAY_PES.md`](docs/technical-index/GAMEPLAY_PES.md)).

> **Para otro chat de Claude / quien edite el juego:** empezar por [`docs/START_HERE.md`](docs/START_HERE.md).

## Probar el juego (APK de Android)

1. En este repositorio: **Actions → Android APK → Run workflow**, activando **publish_release**.
2. Al terminar (unos 10 minutos) aparece una *pre-release* `apk-prueba-N` en **Releases** con el APK adjunto: cualquiera puede
   descargarlo desde ahí, sin cuenta de GitHub.
3. En el teléfono, permitir «instalar apps desconocidas» para el navegador e instalar el `.apk`. Si había una versión anterior,
   desinstalarla primero (cada APK de prueba se firma con una clave de depuración distinta).

El APK es de **prueba** (arm64, firma de depuración, sin permisos). Sin `publish_release`, el APK queda como artefacto de la ejecución.

## Cómo se juega

El control es cercano: la pelota vive junto al pie y se aleja solo cuando tú la empujas. Al soltar el joystick el
jugador **para la pelota**; con un rival encima **la protege** con el cuerpo; un empuje de costado a poca velocidad
la **desplaza de lado** sin girar el cuerpo; a sprint el toque es más largo y un defensor bien colocado puede
robártela. El arquero propio se puede **manejar** (CAMBIO con la jugada en tu área): obedece el joystick, no se
lanza solo, atrapa o despeja con el botón y saca cuando se lo pides; una cedida tuya la recibe con el pie, no se
tira como si fuera un disparo. Un cono cian marca a quien controlas y uno ámbar a quien pasarías con CAMBIO.

## Controles

Joystick flotante a la izquierda; a la derecha: **TIRO**, **PASE**, **FILTRADO** (al espacio), **CENTRO** (desde la
banda; con ALTO sale raso, con carga alta sale tenso), **SPRINT**, **ALTO** (pase/tiro elevado), **PRESIÓN** (cierra y
contiene, no roba sola), **ENTRADA** (de pie, carga con el hombro o barrida según la situación), **REGATE** (ruleta) y
**CAMBIO**. Con un pase, el control pasa al compañero que recibe.

**Chanfle:** pulsa TIRO (o CENTRO) apuntando con el joystick y, antes de soltar, gíralo hacia el lado al que quieres que
se curve la pelota.

PC: WASD mover, J pase, K tiro, O filtrado, H centro, I alto, L presión, N entrada, U regate, Q cambio, Shift sprint,
Esc pausa. Mando: A pase/presión, X tiro/entrada, Y filtrado, B centro, RB sprint, LB alto, LT cambio, RT regate,
Start pausa. En la pausa: duración del partido (3, 5, 7 o 10 min), tamaño de los botones, sensibilidad del joystick,
asistencias, gráficos y la **sala de práctica**.

## Desarrollo

- Abrir la carpeta con Godot 4.7.2; la escena principal es `scenes/main/match.tscn`.
- Pruebas: `tools/run_tests.sh` (suite headless; `tools/run_tests.sh <filtro>` para una parte). Incluye partidos completos
  de 3, 5, 7 y 10 minutos. Las pruebas que necesitan el esqueleto animado se ejecutan con
  `xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter live_feet`.
- Documentación técnica: [`docs/technical-index/INDEX.md`](docs/technical-index/INDEX.md) (sistemas, archivos, parámetros, historial).
- Las animaciones (Mixamo) están convertidas dentro del juego en `assets/animations/pack_clips.res` y `pack_keeper.res`.
  Para reconvertirlas hace falta el pack original en `pack/` (no se sube), ver
  [`tools/animation_pack/README.md`](tools/animation_pack/README.md).
