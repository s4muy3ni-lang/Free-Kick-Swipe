# ONLINE — Cuentas, servidor, economía, matchmaking, bots y menú

## Identificación

- **Responsabilidad exacta:** cuentas y sesión (Supabase Auth o `LocalBackend`), estado del jugador con autoridad del
  servidor (perfil, monedas, XP, inventario, consumibles, temporada, eventos, rankings), cola de sincronización
  idempotente para el juego offline, matchmaking (primero humanos, después un bot generado por el servidor), rivales IA
  (`BotFactory`, `BotBrain`, `BehaviorMirror`), penales online (`OnlineMatch` sobre `SetPieceGame`), chat y reacciones,
  menú principal con sus pantallas (`MenuScreens`), herramientas de desarrollo ocultas en la build pública (`DevFlags`).
- **Estado real:**
  - el servidor está escrito y probado contra PostgreSQL 16 local, pero **no hay proyecto Supabase conectado** (ver
    `docs/online/ARQUITECTURA_ONLINE.md`);
  - online jugable: penales contra bot (con `LocalBackend` sin servidor);
  - humano contra humano: protocolo del servidor probado en SQL, cliente implementado pero sin probar entre dos
    dispositivos;
  - tiros libres y minijuegos online: «en preparación».
- **Última verificación:** <!-- AUTO:verified -->
2026-11-12
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función |
|---|---|
| `supabase/migrations/*.sql` | Esquema (RLS en todas las tablas), funciones del servidor (`create_profile`, `claim_reward`, `buy_item`, `use_consumable`, `update_appearance`, `find_match`, `start_bot_match`, `submit_turn`, `claim_timeout`, `send_chat`, `get_leaderboard`, `claim_season_tier`, `grant_purchase`…), datos iniciales |
| `supabase/tests/` | Simulación mínima de Supabase + pruebas SQL (`run_local.sh`) |
| `scripts/online/online.gd` (autoload `Online`) | Sesión, estado, `call_fn`/`call_state_fn`, cola `queue_reward`/`flush`, latido |
| `scripts/online/supabase_api.gd` | HTTP a GoTrue (`/auth/v1`) y PostgREST (`/rest/v1`, RPC) con la clave pública |
| `scripts/online/local_backend.gd` | La misma API sin servidor (cuenta local con contraseña con sal y hash) |
| `scripts/online/backend_config.gd` | `res://config/backend.json` (lo genera CI desde los GitHub Secrets); rechaza claves de servicio |
| `scripts/online/welcome_screen.gd` | Entrada del juego: iniciar sesión, crear cuenta, recuperar contraseña, crear perfil |
| `scripts/online/online_match.gd` | Penales online: turnos y resultados del servidor, reloj de 20 s con tiro de penalización, bot, chat |
| `scripts/online/bot_factory.gd`, `bot_brain.gd`, `behavior_mirror.gd`, `chat_filter.gd` | Rivales IA, decisiones, tiempos espejo, chat y reacciones |
| `scripts/online/online_duel.gd` | Las demás modalidades online contra un bot difícil (por turnos en A la vista, Guante y Dardos; por puntaje en Basket, Diana y Tiros libres) |
| `scripts/ui/menu_screens.gd`, `menu_icon.gd`, `scripts/setpiece/main_menu.gd` | Menú con 10 entradas, pantallas, íconos dibujados. JUGAR ONLINE rediseñado (2026-11-12): pastillas de estado del lobby, modalidades como tarjetas con imagen (`_mode_tile`, la elegida con borde dorado), panel de la modalidad con entrada en botones y BUSCAR PARTIDA (`select_mode`, `_show_mode_detail`), pantalla de búsqueda con radar (`search_screen`, `SearchRadar`) y cara a cara al encontrar rival (`show_found`) |
| `scripts/ui/scroll_tap.gd` | `ScrollTap`: en las listas con scroll, las tarjetas y sus imágenes dejan pasar el arrastre y un toque que arrastró la lista no aprieta el botón (menú, arcade, desafíos, pausa) |
| `scripts/diagnostics/dev_flags.gd` | Build pública (característica `public`): sin «Diag.», sin línea de destino, sin banco de animaciones |

## Reglas de seguridad (implementadas en SQL)

- **Escrituras:** el cliente no escribe ninguna tabla; todo pasa por funciones del servidor que validan y recalculan.
- **Recompensas:** idempotentes por clave (`reward_ledger`, único por usuario y clave), con topes diarios para lo
  offline y lo jugado contra bots.
- **Partidas:**
  - la zona del arquero queda oculta hasta que llega el tiro;
  - un tiro informado como gol en la zona elegida se cuenta atajada, y uno fuera del arco nunca es gol;
  - turno vencido = tiro errado, y tres seguidos = abandono.
- **Bots:** sin fila de usuario, estadísticas en `vs_bots = true` y fuera de los rankings.
- **Claves:** la service key solo la usaría el webhook de pagos; el cliente la rechaza.

## Pruebas

- `PGHOST=… PGPORT=… supabase/tests/run_local.sh` — 66 comprobaciones del servidor (RLS, idempotencia, topes,
  tienda, consumibles, matchmaking, zona oculta, regla de zonas, liquidación, Elo, ranking sin bots, chat, turnos
  vencidos, temporada).
- `tools/run_tests.sh online_client` — cuentas, sesión cifrada, contraseñas con hash, cola offline idempotente, tienda,
  apariencia, consumibles, partida contra bot, bots adaptativos, espejo, chat, pantalla de bienvenida.
- `tools/run_tests.sh online_match` — tanda online contra bot con el juego real (marcador local = servidor), reloj de
  20 s con tiro de penalización.

## Riesgos y límites

- Sin proyecto Supabase nada de esto es online real: la APK sin `SUPABASE_URL` / `SUPABASE_ANON_KEY` usa la cuenta
  local.
- La física (Jolt) no es determinista entre dispositivos: el servidor valida la coherencia del resultado (zonas,
  rangos), no re-simula. En partidas contra bots, el cliente informa los turnos del bot; por eso esos premios son
  reducidos y tienen tope diario.
- Nada se probó en el teléfono.

## Funciones

<!-- AUTO:funcs:scripts/online/online.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Online._ready()` | 34 |  |
| `Online.use_local(dir: String)` | 46 | Para las pruebas: backend local aislado en otra carpeta, sin sesion ni cola previas. |
| `Online.has_server()` | 63 |  |
| `Online.backend_label()` | 66 |  |
| `Online.signed_in()` | 71 |  |
| `Online.has_profile()` | 74 |  |
| `Online.profile()` | 77 |  |
| `Online.coins()` | 80 |  |
| `Online.level()` | 83 |  |
| `Online.inventory()` | 86 |  |
| `Online.owns(item_id: String)` | 89 |  |
| `Online._auth_call(fn: String, a: String, b: String = "")` | 94 |  |
| `Online.sign_up(email: String, password: String, keep: bool = true)` | 110 | Registro. Con verificacion de correo activa en Supabase no hay sesion hasta confirmar: needs_verification = true. |
| `Online.sign_in(email: String, password: String, keep: bool = true)` | 123 |  |
| `Online.recover(email: String)` | 132 |  |
| `Online.sign_out()` | 135 |  |
| `Online.restore_session()` | 147 | Al abrir el juego: renueva la sesion guardada. Sin conexion entra igual (offline) con el estado guardado. |
| `Online._take_session(d: Dictionary, keep: bool)` | 167 |  |
| `Online.call_fn(fn: String, args: Dictionary = {})` | 180 | Llama a una funcion del servidor (o del backend local). Devuelve {ok, data, error, network}. |
| `Online.call_state_fn(fn: String, args: Dictionary = {})` | 196 | Las funciones que devuelven el estado del jugador lo actualizan aqui. |
| `Online.refresh_state()` | 202 |  |
| `Online._set_state(s: Dictionary)` | 205 |  |
| `Online.catalog(table: String)` | 213 | Datos publicos (catalogo, modos, temporada, eventos). Sin servidor o sin conexion: los del juego (seed.json). |
| `Online.queue_reward(source: String, payload: Dictionary)` | 224 | Encola un premio de juego local; el servidor decide el monto. Devuelve la clave de idempotencia. |
| `Online.flush()` | 234 | Envia la cola. Un error de red la deja para despues; un rechazo del servidor (regla, tope, duplicado) la descarta. |
| `Online._process(delta: float)` | 250 |  |
| `Online._key()` | 262 |  |
| `Online._save_session()` | 265 |  |
| `Online._save_queue()` | 274 |  |
| `Online._load_files()` | 279 |  |
<!-- /AUTO -->
