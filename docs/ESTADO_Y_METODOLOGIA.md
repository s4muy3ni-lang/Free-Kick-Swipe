# Estado del proyecto y metodología de trabajo (traspaso entre chats)

> **Actualización 2026-11-07 — reforma a tiros libres y penales (prioridad):** rama `reforma-tiros-penales`; estado y próximos pasos en [`docs/reforma/ESTADO_REFORMA.md`](reforma/ESTADO_REFORMA.md).
>
> **Actualización 2026-11-07 — guía maestra de animaciones (en pausa):** el trabajo en curso está en la rama `integracion-openai` (no tocar `respaldo-f3`). Para continuar leer primero [`docs/integration/CONTINUAR_GUIA_ANIMACIONES.md`](integration/CONTINUAR_GUIA_ANIMACIONES.md).

> Leer esto ANTES de tocar nada, junto con [`START_HERE.md`](START_HERE.md) y el índice técnico. Última actualización:
> programa maestro E1-E6 (estabilización, auditoría del banco completo, conducción, golpeo, defensa y arquero, predicción
> aérea, APK por GitHub Actions), 2026-10-31. Informe: [`fases/E_programa_maestro_informe.md`](fases/E_programa_maestro_informe.md).

## 1. Ramas

| Rama | Uso |
|---|---|
| `respaldo-f3` | **Rama de trabajo actual.** Todo se desarrolla y se guarda aquí (commits y push en esta rama). |
| `ccr-a6c53cd2-uoxpk0` | **Rama principal** (la rama por defecto del repositorio en GitHub; no existe `main`). **No se toca** hasta que el usuario dé por terminado el trabajo; entonces se sube todo de una vez. |
| `ccr-7a7dba29-jfbum5` | Rama de una sesión anterior (F0–F3); su contenido ya está en `respaldo-f3`. No se usa más. |

Historial de `respaldo-f3` (de más nuevo a más viejo): programa maestro E1-E6 (ver el informe), continuación de F3 (`7c3a622`),
traspaso (`a977fb3`), F3 corregido (`ff6124b`), F3 en curso (`895b3f8`), F2 árbitro de acciones
(`3e035b4`), F0 cambios preservados (`9980f2b`), base `a86f623`.

## 2. Metodología (reglas acordadas con el usuario)

1. **Por fases** (F0…F8, ver §4). Cada fase empieza con una autorización escrita del usuario que dice qué se puede tocar y qué
   no; al terminar se entrega un **informe** y **se detiene**: no se avanza a la fase siguiente sin aprobación expresa.
2. **Commits, push, APK:** solo cuando el usuario lo autoriza en esa fase. El usuario pidió guardar el trabajo en `respaldo-f3`
   para que otros chats continúen; los APK se generan solo si el usuario lo pide (workflow de GitHub Actions, ver START_HERE).
3. **Solo existe el modo de juego 4 (JSON).** Los modos 1, 2 y 3 están descartados: no se recuperan, no se reintroducen ni se usan
   como respaldo. (El código antiguo sigue ahí: no se borra por suposición sin autorización.) Desde el 2026-10-30 el juego
   arranca siempre en el 4 (`Tuning.DEFAULT_GAMEPLAY_MODE`, `PLAYABLE_MODES = [4]`) y el menú no ofrece los otros.
4. **No inventar resultados.** No declarar aprobada una prueba que no se ejecutó; informar fallos con la salida real. Clasificar
   cada fallo: nuevo de la fase / preexistente (F0/F2) / modos descartados / prueba mal diseñada / no determinista. No modificar
   pruebas para ocultar fallos (si una prueba propia estaba mal planteada, corregirla y decirlo).
5. **Verificación visual obligatoria** para animación y contacto (render con Xvfb): tiras de imágenes antes, durante y después
   del contacto. Una prueba numérica no basta. Decir siempre qué se vio y qué no (no se prueba en Android).
6. **Distinguir verificado / medido / estimado / supuesto.** Una estimación cinemática no es una certeza.
7. **Archivos auxiliares** de análisis fuera del repositorio (directorio temporal); al repositorio solo lo que el usuario necesita.
8. **Documentación en el mismo cambio:** `python3 tools/docs_index.py sync`, ajustar a mano, `check` sin errores, entrada en
   `docs/technical-index/CHANGELOG.md`.
9. **Respetar F2:** `ActionArbiter` es la única autoridad sobre cuerpo y pose (niveles, testigos, interrupción). No crear
   mecanismos paralelos ni cambiar su contrato sin proponerlo antes.
10. Informes en español, con tablas y ejemplos; sin conclusiones sin evidencia.

## 3. Estado por fase

| Fase | Estado | Documento |
|---|---|---|
| Auditoría inicial modo JSON + Ultimate Clash | hecha | [`fases/00_auditoria_modo_json.md`](fases/00_auditoria_modo_json.md) |
| F0 protección y diagnóstico | hecha (commit `9980f2b`) | resumen en el CHANGELOG |
| F1 cobertura del catálogo JSON (2 024 clips) | hecha (solo análisis) | [`fases/F1_informe_cobertura.md`](fases/F1_informe_cobertura.md) |
| F2 árbitro de acciones | hecha (commit `3e035b4`) | [`technical-index/SYSTEMS/PLAYER.md`](technical-index/SYSTEMS/PLAYER.md) (sección «Árbitro de acciones») |
| F3 recepción y control | hecha (`7c3a622`; franjas de altura decididas en E1) | [`fases/F3_auditoria_124_clips.md`](fases/F3_auditoria_124_clips.md), [`fases/F3_verificacion_visual_70.md`](fases/F3_verificacion_visual_70.md) |
| Programa maestro E1-E6 (sustituye a F4-F8, autorizado en un solo mensaje del usuario) | hecho | [`fases/E_programa_maestro_informe.md`](fases/E_programa_maestro_informe.md), [`fases/E2_auditoria_banco.md`](fases/E2_auditoria_banco.md), inventario [`fases/E2_inventario_banco.csv`](fases/E2_inventario_banco.csv) |
| Corrección 2026-11-05 (conducción física sin «hilo», golpeos en todas direcciones con el banco, cancha de fútbol 7, 60 fps) | hecha | CHANGELOG 2026-11-05, [`technical-index/SYSTEMS/PLAYER.md`](technical-index/SYSTEMS/PLAYER.md), [`technical-index/SYSTEMS/JSON_MODE.md`](technical-index/SYSTEMS/JSON_MODE.md) |
| Rendimiento (tirones de CPU de la recepción y del arquero, opciones de rendimiento, diagnóstico por sistema) y joystick suelto: el jugador va a la pelota (2026-11-05, segunda entrega) | hecha; **sin medir en un teléfono** | CHANGELOG «Tirones de CPU…», [`technical-index/SYSTEMS/PERFORMANCE.md`](technical-index/SYSTEMS/PERFORMANCE.md), [`fases/joystick_suelto_antes_despues.jpg`](fases/joystick_suelto_antes_despues.jpg) |
| Conducción como UCS (toque orientado con los 41 clips de conducción de UCS (82 con espejos), arranque con pelota, animdb propio, datos de `animdb.adb`, video cuadro por cuadro) y botines proporcionados (2026-11-05, tercera entrega) | hecha; **sin probar en un teléfono**; APK de prueba 0.1.50 (GitHub Actions #50, commit `d57e650`, compilada sin la suite en CI: la suite local se corrió antes, ver CHANGELOG) | [`fases/E3_conduccion_ucs.md`](fases/E3_conduccion_ucs.md), CHANGELOG 2026-11-05 |
| E4: integración al nivel de UCS (IA con los parámetros de UCS leídos de `libMPX.so`, golpeo de primera sincronizado con el pie animado, ajustes del toque orientado) (2026-11-06) | hecha; **sin probar en un teléfono**; suite 290/0; APK de prueba 0.1.51 (GitHub Actions #51, commit `4558173`, compilada sin la suite en CI: la suite se corrió local) | [`fases/E4_integracion_ucs.md`](fases/E4_integracion_ucs.md), CHANGELOG 2026-11-06 |

## 4. Lo que queda abierto

- 25 clips de recepción siguen `pending` (sin verificación visual); rodilla y cabeza sin clip verificado.
- Sin clips en el banco: ruleta (`Soccer_Spin`), `Sprint_Turn`, malabares (el botón de la práctica se oculta).
- Curva de los tiros pequeña (0.05-0.17 m en 11 m): el palo «del que el empeine la aleja» ya no es más difícil para el
  arquero (antes lo era por un error de predicción). Cambiar el efecto del tiro es mecánica: decisión del usuario.
- Pruebas estadísticas sin semilla fija que a veces fallan (ver §6).
- Sin prueba en Android real: la APK se genera y verifica en GitHub Actions.
- La IA no usa el toque orientado (solo el jugador de la persona). Mallas de UCS (`models.pak`) sin decodificar.
- Subida a la rama principal `ccr-a6c53cd2-uoxpk0`: pendiente de la orden del usuario.

## 5. Cómo regenerar los datos del banco

- Perfiles de recepción: `python3 tools/json_anim/make_receive_profiles.py <carpeta_json>` (veredictos en `VISUAL` /
  `VISUAL_NOT`).
- Auditoría del banco: `python3 tools/json_anim/analyze_bank.py <carpeta_json>` → `docs/fases/E2_inventario_banco.csv` y
  `scripts/animation/clip_roles_overlay.gd`.
- Los JSON originales (zip «animaciones_futbol5_nombres_originales») están fuera del repositorio; no se modifican.

## 6. Resultados de pruebas de referencia (para comparar)

Medidos el 2026-10-31 con Godot 4.7.2 oficial al cerrar el programa maestro. La suite por defecto corre en el modo 4 (cada
prueba elige su modo con `TestCase.gameplay_mode()`; las del pack heredado fijan el 1).

| Suite | Resultado | Fallos y clasificación |
|---|---|---|
| `tools/run_tests.sh` | **289 pruebas, 0 fallos**, 32 omitidas, 1 693 comprobaciones, 0 SCRIPT ERROR (local, 2026-11-05, `2cacc4f` + reglas de parada solo para el jugador de la persona) | Pruebas de partidos de IA inestables también con el código anterior (medido: `test_json_mode::test_ai_match_in_json_mode` y `test_training_mode::test_teammates_do_not_crowd_the_dribbler` fallan 1 de 4 con `0baf375` y con el nuevo); hicieron fallar GitHub Actions #47-#48 |
| APK | `futbol5-v0.1.49.apk`, pre-release `apk-prueba-49` de GitHub Actions #49 (commit `ff23991`, compilado con `skip_tests`: suite headless local 289 / 0 sobre el mismo commit; #46-#48 cayeron por pruebas de partidos de IA inestables, ver TESTING) | |
| Con render (xvfb), modo 4 | `physical_dribble` 5 / 0, `live_feet` 7 / 0, `pack_motion` 2 / 0, `json_mode` 10 / 0 (1 omitida), `directional_kicks` 3 / 0, `ball_turn` 4 / 0, `drag_back` 4 / 0, `dribble_reference` 2 / 0, `kick_reach` 2 / 0, `mode4_dribble` 8 / 0, `receive` 34 / 0, `pack_dribble_metrics` 2 / 0 (2026-11-05, segunda entrega) | `live_kicks` 3 / 1 en 2 de 4 corridas: «pase bajo presión en carrera» con el pie a 0.42 m; repetido 16 veces, 9 de 16 a más de 0.3 m con el código anterior y con el nuevo (defecto previo, pendiente) |
| `test_shot_keeper` (80 tiros por caso) | 1 / 0 | palo derecho ataja 69 %, izquierdo 76 %, al arquero 84 %, rival encima 0 goles, tirador de 85 ataja 32-36 % |
| No deterministas conocidas | `test_training_mode` (pases y compañeros), `test_ai_match`, `test_shot_keeper` (comparaciones entre casos). Ya no: `test_set_pieces` (eran clips de balón parado que no llegaban a la pelota, excluidos), `test_player_actions::test_fall…` (comprobaba un instante fijo) | |

Comandos: ver [`START_HERE.md`](START_HERE.md). Render: `TEST_GAMEPLAY_MODE=4 xvfb-run -a godot --rendering-driver opengl3
--fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <archivo>`; visor de recepción: `ANGLE=0 SPEED=12 [ARRIVE_Y=0.6]
[PASS=1] OUT=/ruta.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn`;
auditar un clip: `CLIP=<id> [PART=…] [T=…]` con el mismo visor (ver `tools/json_anim/README.md`).

## Misión de integración — 2026-11-07

Para esta misión prevalece la orden actual del usuario: **trabajar en `integracion-openai`**, conservar `respaldo-f3`
intacta y avanzar con implementación, pruebas, commits y APK sin solicitar aprobaciones de fase adicionales.
Los nombres de rama y restricciones por fases de las secciones históricas anteriores describen sesiones previas.
Estado comprobado y limitaciones actuales: [`integration/INFORME.md`](integration/INFORME.md).
