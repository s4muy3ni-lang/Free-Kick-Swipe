# Programa maestro E1-E6 — informe final (2026-10-31)

Rama `respaldo-f3`. Modo de juego único: 4 (Json). Todas las cifras de este informe salen de ejecuciones reales con Godot
4.7.2 oficial (headless y con render por Xvfb) en el contenedor de desarrollo; lo que no se pudo verificar se dice.

## 1. Etapas

| Etapa | Estado | Qué se hizo |
|---|---|---|
| E1 Estabilización | hecha | Suite por defecto en el modo 4 (modo por prueba); franjas de altura de la recepción decididas con la geometría medida (1.06 m → muslo o pecho; 0.91 m → muslo, rodilla o pie en el aire); 0204 verificado; penalización a perfiles sin verificar; `docs/.gdignore` |
| E2 Banco completo | hecha | 2 022 JSON analizados (2 024 clips), inventario con motivo por clip, 67 reclasificaciones, 7 clips de balón parado excluidos por medición y 3 alias integrados en la selección real, esquivar barridas |
| E3 Conducción | hecha | Recuperar la pelota adelantada (`carry_catch_up_mag`), toque al alcanzarla al acelerar (`_catching_ball`), 8 pruebas de conducción del modo 4 (incluido el giro a la derecha) |
| E4 Pases, remates, regates | hecha | Batería de 50 golpeos con el esqueleto animado en el modo 4 (49 con contacto, 0 inválidos); `Soccer_Spin` investigado: no existe en el banco, el regate usa los 55 `ball_skill` |
| E5 Defensa, arquero, caídas | hecha | Caídas y trastabillones dirigidos por inercia y empujón; arquero con tasa de atajada realista usando solo la información de cada momento; planificador 4× más barato |
| E6 Integración | hecha | Predicción aérea fiel a la física (Magnus, arrastre, bote con giro); suite completa; workflow; APK por GitHub Actions (§9) |

## 2. Funcionalidades implementadas

- `ClipRolesOverlay` + `PackLibrary`: reclasificaciones y alias del banco aplicados al cargar el modo 4.
- `PlayerActions.avoid_tackle`: salto de una barrida fallida con un clip `avoid` (por el árbitro de acciones).
- `PlayerActions._directed_pick` / `push_dir_local`: caída y trastabillón elegidos por el recorrido de la raíz del clip
  frente a la inercia del cuerpo más el empujón del contacto (antes, al azar).
- `BallHandler.carry_catch_up_mag` y `_catching_ball`: el jugador se adapta a la pelota física (la alcanza sin pisarla;
  ningún teletransporte: la pelota solo cambia por impulsos).
- Arquero: percepción con error que decrece (`perception_*`), efecto leído al desviarse (`spin_read_time`), contacto
  continuo de las manos (`CONTACT_WINDOW`), clips a velocidad humana (`dive_speed_max`), límite humano de las manos
  (`hand_latency`, `hand_speed`), quedarse firme solo con tiempo (`CENTER_HOLD_TIME`), reintentos espaciados (`PLAN_RETRY`).
- `BallPredictor.trajectory(..., spin)`: arrastre completo en el aire, Magnus, bote con fricción por deslizamiento y giro.
- `JuggleController.available()`: sin clips de malabares, el botón se oculta (sin fallos de script).

## 3. Animaciones

Detalle por clip en [`E2_inventario_banco.csv`](E2_inventario_banco.csv); resumen en [`E2_auditoria_banco.md`](E2_auditoria_banco.md).

| | clips |
|---|---:|
| Examinados (2 022 archivos JSON originales, sin modificar) | 2 024 |
| Útiles e integrados en un sistema del juego | 1 682 |
| — reclasificados a otro rol (regates 32, giros desde parado 31, giros en carrera 2, espera del arquero 2) | 67 |
| — integrados con funcionalidad nueva (esquivar barrida) | 12 |
| — alias para nombres que el código pedía y no existían (`Idle_To_Sprint`, `Running_Tired`, `Defender_2`) | 3 |
| Descartados, con motivo | 317 |
| — de ellos, balón parado que no llega a la pelota o sin lanzamiento (medido en el juego) | 7 |
| Pendientes (recepciones sin verificación visual de F3) | 25 |

Motivos de descarte: 139 secuencias de presentación (`nis_*`, el juego no tiene escenas de presentación); 111 personajes
fuera de la cancha (público, mascota, técnicos: entorno quitado por decisión del usuario); 11 giros del arquero (se orienta
con su locomoción y su planificador); variantes de marcha y conducción ya cubiertas por ciclos medidos; 2 centros con el
contacto a 0.59-0.68 m al costado del cuerpo; 14 giros fuera de las franjas medidas; sombrero, giro del saque de banda,
variante del árbitro, gesto sin función y pisada sin toques. Sin equivalente en el banco: ruleta (`Soccer_Spin`),
`Sprint_Turn`, malabares.

## 4. Errores corregidos

| Error | Causa | Arreglo |
|---|---|---|
| El arquero ataja el 91-96 % de los tiros colocados de 11 m | estiradas a 1.4× la velocidad humana, clips que empiezan con la estirada lanzada (manos a 1.4 m en 0.2 s), giro de la pelota conocido exacto | `dive_speed_max`, límite humano de las manos, efecto percibido; resultado §5 |
| Atajadas que fallaban pelotas a las que había llegado | contacto medido en un instante, 1-2 pasos tarde (0.3-0.6 m a 19 m/s) | contacto continuo en una ventana de ±0.05 s |
| Tiros bajos al cuerpo del arquero entraban | se quedaba firme leyendo el tiro aunque ya no le quedara tiempo | solo espera si le quedan 0.4 s tras la lectura |
| Predicción aérea con 1.4-5.3 m de error | medio arrastre en el aire, sin Magnus, bote aproximado | modelo físico con giro: 0.06-0.19 m |
| Goles fantasma en `test_shot_keeper` y `test_shooting` | `Ball.reset_at` se aplica en el paso siguiente: con el cerrojo del arco reiniciado, la pelota del gol anterior contaba otra vez | contadores tomados con la pelota recolocada (el partido no tenía el problema) |
| Al acelerar con la pelota el jugador pasaba por encima (5 % del tiempo) | la cadencia del toque era la de la velocidad anterior | toque al alcanzar la pelota (`_catching_ball`): 0 % |
| Al frenar la pelota quedaba a 1.79 m | nada pedía alcanzarla | `carry_catch_up_mag`: ~0.7 m |
| Caídas al azar (golpeado de frente caía hacia el rival) | el clip no dependía del contacto | caída dirigida |
| `KeeperPlanner.plan_save` 42 ms por llamada y hasta 2 por paso | recorrido completo de 362 clips; reintento en cada paso | cajas por muestra y segmento (mismo plan), caché de roles, `PLAN_RETRY`: 11 ms |
| Sin persona, la IA dejaba la pelota suelta quieta 7-9 s junto al jugador «controlado» | el cerebro no daba órdenes al controlado aunque lo llevara un `AIInput` | `TeamBrain.person_drives`: 0 de 20 (antes 1 de 14); lo destapó GitHub Actions |
| `test_player_actions::test_fall…` fallaba a veces | comprobaba la caída a los 0.5 s; las del banco duran 0.67-1.85 s | se comprueba al empezar |
| El corner fallaba ~1 de 9 veces y el saque de banda ~2 de 6 (`test_set_pieces`, tomado por no determinista) | 5 clips de balón parado cuyo pie nunca llega a la pelota y 2 saques de banda sin lanzamiento, elegidos al azar por `vary_aliases` | excluidos (`setpiece_miss`) y alias redirigido: 6 de 6 |
| Tiro libre que no se ejecutaba a tiempo (falló en GitHub Actions) | un compañero de la IA se metía en la carrerilla (apoyo corto sin distancia mínima e inercia durante la preparación) y un rival la cruzaba camino de su marca; el ejecutor se desviaba y el pie no llegaba | zona libre de 4 m alrededor de la pelota para todos salvo el ejecutor, y nadie la atraviesa: 0 de 38 clips fallan, sin atajos |
| Una caída dirigida junto a la banda podía sacar al jugador de la cancha | la elección solo miraba el sitio por delante | `_lands_inside`: 0 de 40 (sin filtro 17 de 40); probable causa de un fallo de `test_ai_match` en GitHub Actions |
| `test_training_mode` «hay pases» fallaba con muchos goles | contaba sobre 150 s; cada gol quita repetición + festejo + saque (en juego quedan 81-96 s) | pases por minuto en juego (2/min, el mismo listón) |
| `test_action_arbiter`, `test_practice` (malabares) | nombres que ya tienen clip; banco sin malabares | lista actualizada; prueba omitida con motivo |
| Godot importaba el inventario CSV como traducción | CSV dentro de `docs/` | `docs/.gdignore` |

## 5. Pruebas y resultados

| Suite | Resultado |
|---|---|
| `tools/run_tests.sh` (headless, modo 4) | **277 pruebas, 0 fallos**, 25 omitidas, 1 621 comprobaciones, 0 SCRIPT ERROR. Tras el último ajuste (toque al alcanzar solo en conducción) se repitió: 277 / 1 fallo no determinista (`test_set_pieces::…corner…`, ver abajo; pasa 3 de 3 al repetirla). Ver §9 para la ejecución de GitHub Actions |
| Con render (Xvfb) | `live_kicks` 4 / 0 (50 golpeos: 49 con contacto, 0 inválidos, 0 bloqueos), `live_feet` 7 / 0, `pack_motion` 2 / 0, `json_mode` 9 / 0 (1 omitida) |
| Nuevas | `test_bank_integration` 5, `test_mode4_dribble` 8, `test_ball_prediction` 7, `test_falls_direction` 4 |
| `test_shot_keeper` (80 tiros por caso, arquero de 60) | palos 66-71 % atajado, al arquero 89 %, con rival encima 0 goles, 18 m potente 96 %, tirador de 85: 32-37 % |
| `test_goalkeeper` | por velocidad: 9 m/s 100 %, 15 m/s 67 %, 24 m/s 57 % |

No deterministas (partidos de IA sin semilla fija): `test_ai_match` (en GitHub Actions falló una vez por pocos tiros y
otra por un jugador 1 m fuera de la cancha en una muestra; pasa en las ejecuciones locales), `test_training_mode`
(pases), comparaciones entre casos de `test_shot_keeper`. Dos que parecían no deterministas eran fallos reales y se
corrigieron: `test_set_pieces` (clips de balón parado que no llegaban a la pelota) y
`test_pass_receiver_control::test_ai_teams_still_play_without_a_human` (la IA no daba órdenes al controlado sin persona).

## 6. Rendimiento (medido, headless, 4 núcleos)

Partido 4+1 contra 4+1 con IA, 60 s: media 3.1 ms por paso, p99 16.7 ms, 35 pasos > 16.7 ms. Picos: planificación del
arquero durante un disparo (20-56 ms) y acciones de giro, balón parado y movimiento con pelota (17-30 ms).
`plan_save` 42 → 11 ms; `BallPredictor.trajectory` 0.2 ms. Sin medición en Android.

## 7. Limitaciones

- Sin prueba en un teléfono real (rendimiento y control táctil sin medir en Android).
- Picos de 20-56 ms al planificar el arquero y de 17-30 ms en algunas acciones (GDScript): en un teléfono serán mayores.
- 25 recepciones sin verificar; rodilla y cabeza sin clip verificado.
- La curva de los tiros es pequeña (0.05-0.17 m en 11 m): el palo «del que el empeine la aleja» no es más difícil para el
  arquero; cambiarlo es mecánica de tiro (decisión del usuario).
- Sin ruleta, `Sprint_Turn` ni malabares en el banco.
- Pruebas estadísticas sin semilla fija (§5).

## 8. Decisiones tomadas

1. Recepción: en las franjas donde dos partes se solapan según la geometría medida (pecho agachado ~1.0 m y muslo
   horizontal ~0.96-1.07 m; muslo y rodilla ~0.9 m) se aceptan ambas.
2. Clips que faltan: alternativas medidas del banco (`Running_Tired` → manos en la cintura; `Defender_2` → salto de
   barrera; `Idle_To_Sprint` → mejor arranque); ruleta y malabares sin sustituto inventado.
3. Arquero: realismo por capacidades humanas (velocidad de las manos, velocidad de los clips, lectura del tiro) en lugar
   de bajar radios o meter azar; los valores son `KeeperTuning` (ajustables).
4. La comparación de `test_shot_keeper` sobre el palo lejano se reformuló con la curva medida (no se bajó un umbral para
   que pase: su premisa venía de un error del predictor).
5. El toque al alcanzar la pelota se limita a la conducción (con un golpeo pedido, la preparación mantiene sus reglas).
6. Para ejecutar el workflow (la APK se construye solo en GitHub Actions, por indicación del usuario) hubo que subir
   `respaldo-f3` a GitHub: es la única subida remota y no toca la rama principal.

## 9. APK (GitHub Actions)

Construida **solo** en GitHub Actions (workflow `.github/workflows/android.yml`, lanzado a mano sobre `respaldo-f3`), sin
compilación local. El workflow instala Godot 4.7.2 y su plantilla Android (con verificación SHA-512), Android SDK
(cmdline-tools, `platforms;android-35`, `build-tools;35.0.1`), Java 21, ejecuta la suite headless y las pruebas con render
(Xvfb), exporta, firma con un keystore de depuración creado en la propia ejecución (sin secretos en el repositorio) y
verifica firma, paquete, arquitectura, permisos y que las librerías de animación dentro de la APK sean idénticas a las del
repositorio.

| | |
|---|---|
| Ejecución correcta | #43, commit `30eeec2` — https://github.com/roldanhr98-byte/Futbol5/actions/runs/41209278077 (la #42, `edb5d84`, también fue correcta, antes de la zona libre del saque) |
| Pruebas en el runner | headless 280 / 0 fallos (en la #42, 279 / 0) (25 omitidas); con render: `live_feet` 7 / 0, `live_kicks` 4 / 0 (50 golpeos: 49 con contacto, 0 inválidos), `pack_motion` 2 / 0, `json_mode` 9 / 0 (1 omitida) |
| APK | `futbol5-v0.1.43.apk` — paquete `com.webmaletin.futbol5`, versionCode 43, versionName 0.1.43, `arm64-v8a`, sin permisos, firma v2 verificada (`apksigner verify`) |
| Artefacto descargable | `futbol5-apk` (57.8 MB comprimido) — https://github.com/roldanhr98-byte/Futbol5/actions/runs/41209278077/artifacts/13046316355 (caduca el 2026-11-14) |
| Firma | de depuración, distinta en cada ejecución: hay que desinstalar la versión anterior antes de instalar esta |

Ejecuciones previas que fallaron y por qué (cada una destapó un fallo real que se corrigió, salvo donde se dice):

| Ejecución | Fallo | Qué se hizo |
|---|---|---|
| #36 (intento 1) | `test_ai_match`: pocos tiros en 120 s | aleatorio; se relanzó |
| #36 (intento 2) | IA sin persona con la pelota quieta 8.8 s; caída comprobada en instante fijo; jugador 1 m fuera | `TeamBrain.person_drives`; prueba de caída; `_lands_inside` |
| #37 | corner con un clip que no llega a la pelota | 7 clips de balón parado excluidos por medición |
| #40 | tiro libre: un jugador en la carrera desviaba al ejecutor | zona libre del saque (primero se probó quitar las colisiones del ejecutor; se retiró porque escondía el error) |
| #41 | `test_training_mode` «hay pases» contado sobre 150 s con muchos goles | pases por minuto en juego |

Subir `respaldo-f3` a GitHub fue necesario para ejecutar el workflow (es la única subida remota; la rama principal
`ccr-a6c53cd2-uoxpk0` no se tocó).
