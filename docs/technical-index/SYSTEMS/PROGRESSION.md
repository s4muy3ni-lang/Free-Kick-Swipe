# PROGRESSION — Atributos, progresión del jugador, personalización y logros

## Identificación

- **Responsabilidad exacta (lo implementado):**
  - **Progresión del jugador de penales y tiros libres (2026-11-13):** nivel y experiencia del perfil del servidor, puntos
    de mejora, 9 atributos (6 de tirador y 3 de arquero, de 1 a 10) con efecto real y acotado en el gesto del tiro y en
    el alcance del arquero (`ProgressionRules`, `AttributeEffects`), redistribución con reglas, historial, estilo de
    juego y la pantalla «MI JUGADOR — PROGRESIÓN» (`MenuScreens.open_progression`). Ver la sección de abajo.
  - `PlayerAttributes` (`Resource`, el modo de partido de fútbol 5 de las pruebas de mecánica): 23 atributos de campo y
    8 de arquero en escala 1–100. Escalan parámetros, tolerancias y errores dentro de límites (`factor(clave, spread)`
    → 1.0 con valor 50; `norm(clave)` → 0..1). No se usa en penales ni tiros libres.
  - Personalización (`PlayerCustom` y catálogos) y logros (`Achievements`): ver sus secciones.
- **Estado real:** la progresión está implementada y probada con el servidor local (`LocalBackend`) y con PostgreSQL 16
  local (`supabase/tests/test_server.sql`). La migración `20261113000009_progression.sql` **no está aplicada en ningún
  proyecto de Supabase**. No hay pagos reales: nada deportivo se compra.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-13
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/progression/player_attributes.gd` | Clase `PlayerAttributes`: valores, claves válidas, `factor`, `norm`, `overall`, serialización validada (`to_dict`/`from_dict`) | `PlayerAttributes.factor`, `PlayerAttributes.norm`, `PlayerAttributes.set_value`, `PlayerAttributes.from_dict`, `PlayerAttributes.FIELD_ATTRIBUTES`, `PlayerAttributes.KEEPER_ATTRIBUTES` | — |
| `scripts/gameplay/match_scene.gd` | Crea los atributos de cada futbolista: `reset_to(55)` | `MatchScene._make_footballer` | `PlayerAttributes` |
| `scripts/player/locomotion.gd`, `ball_handler.gd`, `scripts/assistance/*` | Consumen los atributos | ver tabla de uso | `PlayerAttributes` |

## Atributos y su uso real

<!-- AUTO:attrs -->
| Atributo (clave) | Nombre visible | Grupo | Consumido en (código) |
|---|---|---|---|
| `speed` | Velocidad | campo | `scripts/player/locomotion.gd:57`, `scripts/player/locomotion.gd:60` |
| `acceleration` | Aceleración | campo | `scripts/player/ball_handler.gd:2114`, `scripts/player/ball_handler.gd:2115`, `scripts/player/ball_handler.gd:2460`, `scripts/player/ball_handler.gd:2554`, `scripts/player/ball_turn.gd:182`, `scripts/player/ball_turn.gd:219`, `scripts/player/ball_turn.gd:301`, `scripts/player/drag_back.gd:197`, `scripts/player/drag_back.gd:293`, `scripts/player/locomotion.gd:73`, `scripts/player/locomotion.gd:189` |
| `stamina` | Resistencia | campo | `scripts/player/locomotion.gd:79`, `scripts/player/locomotion.gd:165`, `scripts/player/locomotion.gd:192` |
| `balance` | Equilibrio | campo | `scripts/assistance/kick_model.gd:85`, `scripts/player/ball_handler.gd:3210`, `scripts/player/player_actions.gd:494`, `scripts/player/player_actions.gd:495` |
| `agility` | Agilidad | campo | `scripts/player/ball_handler.gd:654`, `scripts/player/ball_handler.gd:2118`, `scripts/player/ball_turn.gd:191`, `scripts/player/ball_turn.gd:218`, `scripts/player/drag_back.gd:198`, `scripts/player/drag_back.gd:292`, `scripts/player/locomotion.gd:74`, `scripts/player/locomotion.gd:190` |
| `ball_control` | Control de balón | campo | `scripts/player/ball_handler.gd:1656`, `scripts/player/ball_handler.gd:3166`, `scripts/player/ball_handler.gd:3170`, `scripts/player/ball_handler.gd:3184`, `scripts/player/json_receive.gd:687` |
| `ball_carrying` | Conducción | campo | `scripts/player/ball_handler.gd:369`, `scripts/player/ball_handler.gd:1656` |
| `dribbling` | Regate | campo | **sin uso todavía** |
| `short_pass` | Pase corto | campo | `scripts/assistance/pass_assist.gd:100`, `scripts/assistance/pass_assist.gd:228` |
| `long_pass` | Pase largo | campo | `scripts/assistance/cross_assist.gd:93`, `scripts/assistance/cross_assist.gd:103`, `scripts/assistance/pass_assist.gd:100`, `scripts/assistance/pass_assist.gd:228` |
| `pass_accuracy` | Precisión de pase | campo | `scripts/assistance/pass_assist.gd:121`, `scripts/assistance/pass_assist.gd:262`, `scripts/gameplay/set_piece.gd:515` |
| `shot_power` | Potencia de tiro | campo | `scripts/assistance/shot_assist.gd:116` |
| `shot_accuracy` | Precisión de tiro | campo | `scripts/assistance/shot_assist.gd:127`, `scripts/assistance/shot_assist.gd:155`, `scripts/assistance/shot_assist.gd:234` |
| `finishing` | Finalización | campo | `scripts/assistance/shot_assist.gd:128`, `scripts/assistance/shot_assist.gd:155`, `scripts/assistance/shot_assist.gd:234` |
| `weak_foot` | Pierna débil | campo | `scripts/assistance/kick_model.gd:106`, `scripts/assistance/kick_model.gd:109` |
| `reaction` | Reacción | campo | **sin uso todavía** |
| `marking` | Marcaje | campo | `scripts/player/ball_handler.gd:3202` |
| `interception` | Intercepción | campo | **sin uso todavía** |
| `strength` | Fuerza física | campo | `scripts/player/ball_handler.gd:3210`, `scripts/player/player_actions.gd:494`, `scripts/player/player_actions.gd:495` |
| `jumping` | Salto | campo | **sin uso todavía** |
| `heading` | Cabeceo | campo | **sin uso todavía** |
| `composure` | Compostura | campo | `scripts/assistance/pass_assist.gd:131`, `scripts/assistance/pass_assist.gd:270`, `scripts/assistance/shot_assist.gd:139` |
| `decision` | Capacidad de decisión | campo | **sin uso todavía** |
| `reflexes` | Reflejos | arquero | **sin uso todavía** |
| `positioning` | Posicionamiento | arquero | **sin uso todavía** |
| `catching` | Blocaje | arquero | `scripts/goalkeeper/goalkeeper.gd:798` |
| `diving` | Estirada | arquero | `scripts/goalkeeper/goalkeeper.gd:809` |
| `aerial` | Juego aéreo | arquero | **sin uso todavía** |
| `throwing` | Saque con la mano | arquero | **sin uso todavía** |
| `kicking` | Juego con los pies | arquero | **sin uso todavía** |
| `rebound_control` | Reacción a rebotes | arquero | **sin uso todavía** |
<!-- /AUTO -->

Constantes: `MIN_VALUE = 1`, `MAX_VALUE = 100`, `DEFAULT_ROOKIE = 40` (valor inicial de `PlayerAttributes.new()`); en el partido real se usa 55 (`MatchScene._make_footballer`), en las pruebas 50 por defecto (neutro).

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `spread` en cada `factor(clave, spread)` | Es el rango de influencia de cada atributo en su sitio de uso (en `Locomotion`, `BallHandler`, `PassAssist`…). Subirlo hace que los atributos dominen la física. |
| `DEFAULT_ROOKIE` / `reset_to(55)` | Cambia el comportamiento base de **todos** los jugadores del partido; varias pruebas fijan atributos explícitos (10, 50, 100) y no se ven afectadas, otras usan 50. |
| Claves de atributos | Se usan como cadenas en el código (`attributes.factor("speed", …)`): renombrar una exige actualizar todos los usos (la tabla anterior los enumera) y `from_dict`. |

## Progresión del jugador (penales, tiros libres, desafíos y online; 2026-11-13)

Pedido del usuario: «nivel, experiencia, puntos de mejora, atributos con efecto real, medible y comprobable… no permitir
que una estadística alta haga ganar automáticamente… límites… especialización… arquero que nunca ataje lo imposible…
pantalla MI JUGADOR — PROGRESIÓN».

**Reglas** (`scripts/progression/progression_rules.gd`, iguales en `LocalBackend` y en el SQL):

| Regla | Valor |
|---|---|
| Nivel | `PlayerProgress.level_for`: cada nivel pide 150 XP más que el anterior (nivel n: 75·n·(n−1) XP en total) |
| Puntos de mejora | 2 por nivel hasta el nivel 30 (`POINT_LEVEL_CAP`): 58 en total; después se sigue subiendo de nivel sin más puntos |
| Atributos | `power`, `accuracy`, `curve`, `height`, `technique`, `control` (tirador); `keeper_reach`, `keeper_reflex`, `keeper_catch` (arquero); de 1 a 10 |
| Costo (`cost_to`) | 1 punto hasta el 5, 2 del 6 al 8, 3 el 9 y el 10: 16 puntos para llevar uno al máximo, 144 para todos |
| Estilo (`specialization`) | Sale de la distribución (especialista en X si le lleva 2 al segundo; completo si son parejos; mixto; arquero si la mayoría de los puntos están en el arco). No es una clase fija |
| Redistribuir (`respec_state`) | Todo vuelve a 1 y se recuperan los puntos; la primera gratis, después una cada 7 días por 300 monedas; nunca durante una partida online; idempotente |

**Efecto de cada atributo** (`scripts/progression/attribute_effects.gd`). Con todo en 1 el juego es exactamente el de
antes (`tuning_for` devuelve el mismo `GestureTuning`); el efecto crece en línea hasta el 10:

| Atributo | Parámetro real | En 10 |
|---|---|---|
| Potencia | velocidad máxima de salida (`speed_range`; la mínima no cambia) | +6 % (tiro libre 33,0 → 35,0 m/s; penal 29,0 → 30,7) |
| Precisión | `error_base` y `error_power` del gesto | −25 % (1,85° → 1,39° a potencia máxima) |
| Efecto | `spin_max` y `spin_gain` | +15 % y +10 % |
| Altura | parte vertical del error (`ShotSolver.perturb`, `pitch_ratio`) y `ascend_lift` | 0,70 → 0,45 del lateral; +40 % |
| Técnica de disparo | `error_rough` y el error de los tiros técnicos (con efecto, globo, rápido y corto, elevado) | −35 % y −15 % |
| Control | `error_short` y `length_full` (control total con un trazo más corto) | −35 % y −15 % |
| Alcance (arquero) | `KeeperReach.reach` scale | +6 % (3,50 → 3,71 m), límite `SCALE_LIMITS` |
| Reflejos (arquero) | `KeeperReach.time_factor` react (reflejos y velocidad de reacción son el mismo parámetro) | arranca 0,04 s antes, límite `REACT_LIMITS` |
| Atrapada (arquero) | `SpKeeper.catch_scale` sobre `SpSettings.keeper_catch_speed` | +15 % |

- Dónde se aplican: `SetPieceGame.user_attrs` (perfil del autoload `Online`), `_user_tuning`, `shot_context(attrs)`,
  `_take_shot` (error por tipo y parte vertical) y `AttributeEffects.apply_keeper` sobre `user_keeper`. La CPU y el
  **duelo local** (dos personas en un teléfono) juegan con atributos neutros (`_shooter_attrs`).
- Online: el servidor calcula el alcance con los atributos del **perfil del que ataja** (`keeper_reachable_attr` en
  `submit_turn`; `LocalBackend.keeper_rule(..., keeper_attrs)`), nunca con valores que mande el cliente.
- Lo que no hacen: no cambian el gesto, no fijan la dirección ni la potencia, no cambian la física de la pelota (el
  efecto lo sigue aplicando Magnus), no hacen atajar fuera del alcance (ni al máximo se llega al ángulo).

**Experiencia** (fuentes y freno al abuso; `claim_reward` del SQL y de `LocalBackend`):

- Fuentes: penales y tiros libres contra la CPU (`offline_match`: 30 + 20 si gana + 4 por gol + 6 por atajada, goles y
  atajadas hasta 5), minijuegos arcade, academia, desafíos diarios y semanales, logros, partidas online (`_settle`),
  eventos y temporada.
- Rendimiento decreciente por repetir la misma fuente en el día: 8 enteras, hasta la 16 a la mitad, después un cuarto.
- Tope diario fuera de las partidas online (1500 XP, 800 monedas); el doble de XP tampoco lo pasa.
- El duelo local y la práctica libre no dan experiencia.

**Tabla de progresión** (`test_progression_table`: un día de cada tipo de jugador con las reglas reales del servidor
local, extrapolado; sin contar partidas online):

| Jugador (por día) | XP | Nivel 5 | Nivel 10 | Nivel 20 | Nivel 30 (tope de puntos) |
|---|---|---|---|---|---|
| Casual (2 partidas, 2 arcade, 1 desafío) | 273 | 6 días | 25 días | 105 días | 240 días |
| Regular (6 partidas, 6 arcade, 2 desafíos) | 884 | 2 días | 8 días | 33 días | 74 días |
| Intenso (tope diario) | 1500 | 1 día | 5 días | 19 días | 44 días |

**Balance** (`test_balance_new_players_can_compete`, Monte Carlo de 6000 penales con el modelo del juego: error del
gesto, alcance del arquero y una CPU que lee bien el 30 %):

| Perfil | Gol | Atajado | Afuera |
|---|---|---|---|
| Nuevo (todo 1) | 66,3 % | 28,2 % | 5,5 % |
| Intermedio (22 puntos parejos) | 67,8 % | 28,8 % | 3,4 % |
| Especialista en precisión (nivel 30) | 68,8 % | 28,8 % | 2,4 % |
| Todo al máximo (imposible con los puntos) | 70,9 % | 27,7 % | 1,4 % |

- Un trazo descuidado con todo al máximo convierte menos (61,1 %) que un trazo prolijo sin atributos (69,4 %): manda el
  gesto.
- El arquero del usuario con todo al máximo ataja 31,3 % contra 28,9 % sin atributos.

**Pantalla «MI JUGADOR — PROGRESIÓN»** (`MenuScreens.open_progression`; el mosaico MI JUGADOR del menú principal
reemplaza al de PERFIL, que sigue en el botón «Perfil y ranking»):

- el jugador 3D haciendo dominadas a la izquierda (el mismo de Personalizar);
- nivel, barra de experiencia y puntos;
- pestañas Tirador, Arquero, Historial (mejoras y experiencia reciente) y Estadísticas (logros acumulados);
- cada atributo: icono (`MenuIcon`), valor y barra de 10, descripción, efecto actual y costo;
- MEJORAR abre una confirmación con el antes y el después en números (`AttributeEffects.effect`) y no se puede sin
  puntos;
- redistribución con sus reglas y confirmación.

**Servidor** (`supabase/migrations/20261113000009_progression.sql`): `attribute_log` (historial, RLS), columnas
`respecs` y `respec_at`, `attr_value`, `attr_cost`, `attr_spent`, `attr_earned`, `spend_attribute_point` (costo
creciente), `respec_attributes`, `get_my_state` con el bloque `progression`, `claim_reward` (rendimiento y repetición),
`keeper_reachable_attr` y `submit_turn` con el alcance del perfil del arquero.

## Personalización avanzada (2026-11-13)

Pedido del usuario (EXPANSIÓN, secciones 5 a 10): peinados, barbas y bigotes, altura y complexión sin romper las
animaciones ni dar ventajas, botines con color secundario, suela y cordones, número y nombre en la camiseta validados,
desbloqueos por nivel, logros, monedas y temporada, guardado sin conexión.

- **Peinados y barbas** (`scripts/progression/hair_catalog.gd`, `SpActor.set_look`):
  - son objetos del catálogo (`haircut`, `beard`): 9 peinados y 6 barbas;
  - las piezas son elipsoides colgados del hueso de la cabeza con `BoneAttachment3D`: siguen la animación sin tocar el
    esqueleto (la prueba lo verifica con render);
  - el pelo del modelo de Tripo está en la textura y tiene volumen (un jopo), así que cada peinado lleva un casco que lo
    envuelve; el rapado mezcla además el pelo con la piel (`hair_buzz` del shader);
  - las medidas salen del perfil de la cara en reposo.
- **Altura y complexión** (`HairCatalog.HEIGHTS`, `BUILDS`; `SpActor.set_body_shape`):
  - escala del modelo, 0,97–1,03 de alto y 0,94–1,08 de ancho;
  - solo visual: el alcance, la barrera y el tiro no la usan;
  - el arquero del usuario no la lleva, porque sus manos tienen que coincidir con las atajadas planificadas.
- **Botines**: secundario, suela y cordones elegibles (`HairCatalog.BOOT_DETAILS`; −1 = los del par), sobre el diseño
  de `BootsCatalog`.
- **Nombre y número**:
  - el nombre se imprime arriba del número, en la tela (`name_atlas.png` generado por `tools/ui/make_number_atlas.gd`,
    `name_ink` del shader);
  - un nombre largo achica las letras;
  - `ShirtName` valida hasta 12 letras y filtra insultos, y el servidor lo valida igual;
  - el 7 y el 10 son botones destacados, y cualquier número de 1 a 99 va por la caja numérica (`update_identity`).
- **Un solo lugar para vestir al jugador**: `PlayerCustom.dress(actor, keeper)`. Lo usan el menú, la tanda, el
  arquero, los minijuegos y la vista previa de la tienda.
- **Desbloqueos**:
  - gratis (casco natural, rapado, rulos, sin barba, bigote, barba corta);
  - por nivel (jopo 3, candado 4): el servidor los acepta desde ese nivel. Antes ningún objeto de progresión llegaba al
    inventario: estaba roto desde la tienda visual;
  - con monedas (rodete, melena, afro, barba completa);
  - por logro (`achievement`: la cresta con Goleador, la barba vikinga con Guantes firmes; se entregan al cobrar el
    logro, una vez);
  - premium solo estético y sin venta (cresta dorada).
- **Sin conexión**: `Online.queue_appearance` deja **una** operación `update_appearance` en la cola (la última elección
  de cada campo) y se manda al volver.
- **Arreglo de paso**: al cargar la personalización guardada, los diseños de camiseta 7–11 y de short y medias 3–4 se
  recortaban a los viejos.
- **Limitación**: la máscara de pelo del cuerpo de Tripo es parcial. Con el peinado natural se ve algo del rubio
  original de la textura; los otros peinados lo tapan con el casco.

## Personalización y logros (2026-11-10)

- `PlayerCustom` (`scripts/progression/player_custom.gd`): paletas de uniforme/piel/pelo (shader del kit), número en la
  espalda (`SpActor.set_back_number`), estilo de golpeo y carrera (pesos sobre `ShotCatalog`, sin tocar la física),
  seguimiento tras el tiro, festejo elegido; cosméticos bloqueados hasta ganarlos. `user://custom.cfg`.
  - Número de la espalda (2026-11-12, «estaba separado de la camiseta»). Con el cuerpo de Tripo va **impreso en la
    tela**:
    - `player_kit.gdshader` proyecta las cifras de `assets/characters/player/number_atlas.png`
      (`tools/ui/make_number_atlas.gd`) sobre la espalda;
    - usa la posición de reposo que `build_tripo_body` guarda en CUSTOM0;
    - contraste automático con la camiseta;
    - se mantiene al cambiar el uniforme.
  - El humanoide, que lo llevaba en un `Label3D`, se eliminó el mismo día: queda un solo cuerpo.
  - Prueba: `test_back_number`; captura: `tools/ui/number_capture.gd`.
- `Achievements` (`scripts/progression/achievements.gd`): logros permanentes + 3 diarios y 2 semanales (rotación por
  fecha, progreso por período, premio único por período, historial). Avisos: autoload `Toasts`. `user://achievements.cfg`.
- Pestaña LOGROS en `ChallengeMenu`; panel «Jugador» en el menú principal.

## Mapa de funciones

<!-- AUTO:funcs:scripts/progression/progression_rules.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ProgressionRules.all()` | 24 |  |
| `ProgressionRules.is_attribute(k: String)` | 27 |  |
| `ProgressionRules.value(attrs: Dictionary, k: String)` | 30 |  |
| `ProgressionRules.cost_to(v: int)` | 34 | Costo (puntos) de pasar del valor v - 1 al valor v. |
| `ProgressionRules.cost_next(cur: int)` | 42 | Costo de la proxima mejora desde el valor actual (0 si ya esta al maximo). |
| `ProgressionRules.cost_of(v: int)` | 46 | Puntos que vale tener el atributo en v (desde 1). |
| `ProgressionRules.spent(attrs: Dictionary)` | 52 |  |
| `ProgressionRules.earned(level: int)` | 59 |  |
| `ProgressionRules.available(level: int, attrs: Dictionary)` | 62 |  |
| `ProgressionRules.can_raise(level: int, attrs: Dictionary, k: String)` | 66 | "" si se puede subir k; si no, el motivo (lo mismo que contesta el servidor). |
| `ProgressionRules.xp_in_level(total_xp: int)` | 77 | Experiencia dentro del nivel actual: [ganada en el nivel, la que pide el nivel]. |
| `ProgressionRules.respec_state(respecs: int, last_at: float, now_s: float)` | 86 | Estado de la redistribucion: {"free": la primera, "cost": monedas, "wait": segundos que faltan (0 = ya se puede)}. |
| `ProgressionRules.specialization(attrs: Dictionary)` | 99 | Estilo de juego que sale de la distribucion (no es una clase fija: cambia con los puntos). |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/progression/attribute_effects.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `AttributeEffects.n(attrs: Dictionary, k: String)` | 43 | 0 (valor 1) .. 1 (valor 10). |
| `AttributeEffects.neutral(attrs: Dictionary)` | 46 |  |
| `AttributeEffects.tuning_for(base: GestureTuning, attrs: Dictionary)` | 53 | Coeficientes del gesto con los atributos del tirador (una copia; con atributos neutros, la misma base). |
| `AttributeEffects.speed_range(base: Vector2, attrs: Dictionary)` | 71 | Velocidades de salida del modo (minima, maxima) con la potencia del tirador. |
| `AttributeEffects.pitch_ratio(attrs: Dictionary)` | 75 | Parte vertical del error (ShotSolver.perturb) con la altura del tirador. |
| `AttributeEffects.type_error_factor(attrs: Dictionary, gesture_type: String)` | 79 | Factor del error de un tiro del tipo gesture_type (la tecnica solo cuenta en los tiros tecnicos). |
| `AttributeEffects.keeper_reach_scale(attrs: Dictionary)` | 84 |  |
| `AttributeEffects.keeper_react_bias(attrs: Dictionary)` | 87 |  |
| `AttributeEffects.keeper_catch_scale(attrs: Dictionary)` | 90 |  |
| `AttributeEffects.apply_keeper(k: SpKeeper, attrs: Dictionary)` | 94 | Aplica los atributos de arquero a un SpKeeper. |
| `AttributeEffects.user_attrs()` | 102 | Atributos del usuario (perfil del servidor o del servidor local); sin perfil, neutros. |
| `AttributeEffects.effect(k: String, v: int)` | 115 | Efecto en numeros del atributo k con el valor v (para la pantalla de mejoras: antes / despues). |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/progression/player_attributes.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PlayerAttributes._init()` | 52 |  |
| `PlayerAttributes.reset_to(base: int)` | 55 |  |
| `PlayerAttributes.is_known(key: String)` | 62 |  |
| `PlayerAttributes.display_name(key: String)` | 65 |  |
| `PlayerAttributes.get_value(key: String)` | 72 |  |
| `PlayerAttributes.set_value(key: String, v: int)` | 76 | Asigna un valor respetando el maximo. Devuelve el valor realmente asignado (o -1 si la clave no existe). |
| `PlayerAttributes.factor(key: String, spread: float)` | 83 | Factor multiplicador: 1.0 con valor 50; +-spread en los extremos. |
| `PlayerAttributes.norm(key: String)` | 87 | Valor 0..1 (1 = maximo), util para probabilidades y errores. |
| `PlayerAttributes.total_field()` | 90 |  |
| `PlayerAttributes.overall()` | 96 |  |
| `PlayerAttributes.to_dict()` | 99 |  |
| `PlayerAttributes.from_dict(d: Dictionary)` | 103 | Carga con validacion: ignora claves desconocidas, recorta rangos y rellena las faltantes. |
| `PlayerAttributes.duplicate_attributes()` | 112 |  |
<!-- /AUTO -->

## Pruebas

- **Progresión:** `tools/run_tests.sh progression` (`tests/test_progression.gd`: reglas; servidor local con mejoras,
  historial y redistribución; experiencia sin abuso; cada atributo en 1, 5 y 10; la velocidad real de la pelota con
  potencia 1 y 10; desvío, altura, técnica y efecto con el camino del tiro del juego; arquero sin atajadas imposibles;
  balance; tabla de progresión; pantalla). Servidor: `PGHOST=/var/tmp/fks_pg PGPORT=54329 supabase/tests/run_local.sh`.
- **`PlayerAttributes`:** no hay un archivo propio; se ejercita indirectamente: `tools/run_tests.sh passing` (precisión de pase con atributos 10 vs 100), `locomotion` y `dribbling`.
- **Última ejecución (2026-10-26):** suite completa 57 pruebas / 212 comprobaciones sin fallos.
- **Alcance real:** **`PlayerAttributes.from_dict`/`to_dict`/`overall`/`set_value` no tienen prueba directa.**

## Limitaciones conocidas (pendientes)

- Atributos sin uso en el código (aparecen con «sin uso» en la tabla de arriba), entre ellos `dribbling`, y todos los de arquero.
- No hay mapeo de atributos → apariencia/ficha, ni persistencia de jugadores (`user://` solo guarda asistencias, diagnóstico y gráficos).
- Partido de fútbol 5 (`PlayerAttributes`): sin progresión ni estadísticas; los `GameEvent` se emiten pero nadie los
  acumula. La progresión de 2026-11-13 es la del jugador de penales y tiros libres.
- Progresión: el control (`control`) solo actúa en el gesto del tiro (los minijuegos arcade no usan los atributos, para
  no cambiar sus récords); la recuperación después de la estirada no es un atributo (en penales y tiros libres la
  jugada termina con la atajada). Sin medición en un teléfono.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido» (los atributos escalan locomoción, conducción y asistencias).
