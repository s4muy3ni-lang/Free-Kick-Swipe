"""Genera docs/transferencia_integracion_completa/PARAMETROS_UCS.md (tabla de los parametros de juego de UCS) a partir de
PARAMETROS_UCS.csv (salida de tools/transfer/ucs_params_extract.py sobre libMPX.so).

Valor por defecto, origen del valor, campo y direccion: COMPROBADOS en el codigo ARM64 (salida del extractor).
Funcion posible y unidad: INFERIDAS del nombre (no se descompilo el codigo que los usa).
Sistema de Futbol5 y estado: COMPROBADOS en nuestro codigo (archivo:linea), salvo donde dice «candidato».

Uso: python3 tools/transfer/make_params_doc.py > docs/transferencia_integracion_completa/PARAMETROS_UCS.md
"""
import csv
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs", "transferencia_integracion_completa", "PARAMETROS_UCS.csv")
E4 = os.path.join(ROOT, "docs", "fases", "E4_parametros_ucs.csv")

UP = "scripts/ai/ucs_params.gd"
# Estado de los que tocan nuestro codigo (comprobado leyendo el codigo).
STATUS = {
    "MaxActivePresses": "IMPLEMENTADO: `UcsParams.MAX_ACTIVE_PRESSES` (%s:14) en `TeamBrain._defend` (scripts/ai/team_brain.gd:348): segundo presionador `press2`" % UP,
    "MaxActiveTackles": "IMPLEMENTADO (implicito): el segundo presionador lleva `press: false` y no entra (scripts/ai/team_brain.gd:349); la constante `UcsParams.MAX_ACTIVE_TACKLES` (%s:15) no se lee" % UP,
    "WidthOpenPlay": "IMPLEMENTADO: `UcsParams.WIDTH_OPEN_PLAY` (%s:36) en `TeamBrain._attack`, puesto `width` (scripts/ai/team_brain.gd:159)" % UP,
    "BotMinKickFrames": "IMPLEMENTADO: `UcsParams.BOT_MIN_KICK_S` (%s:23) en `AIInput._decide_with_ball` (scripts/ai/ai_input.gd:539)" % UP,
    "BotMaxKickFrames": "IMPLEMENTADO: `UcsParams.BOT_MAX_KICK_S` (%s:24) = `AIInput.CARRY_PATIENCE` (scripts/ai/ai_input.gd:31, usado en :541)" % UP,
    "PressureSpeedRate": "PROBADO Y DESCARTADO (E4): `UcsParams.PRESSURE_SPEED_RATE` (%s:17) definido y sin uso; aplicado como velocidad rompio `test_shot_keeper`" % UP,
    "ResponseGKSave0": "PROBADO Y DESCARTADO (E4): `UcsParams.RESPONSE_GK_SAVE_S` (%s:29) sin uso; ver comentario en `Goalkeeper._assess_shot` (scripts/goalkeeper/goalkeeper.gd:375-377)" % UP,
    "ResponseGKSave1": "PROBADO Y DESCARTADO (E4): idem ResponseGKSave0",
    "InterceptUrgency": "DEFINIDO SIN USO: `UcsParams.INTERCEPT_URGENCY` (%s:19)" % UP,
    "ResponsePlayerAction0": "DEFINIDO SIN USO: `UcsParams.RESPONSE_ACTION_S` (%s:27)" % UP,
    "ResponsePlayerAction1": "DEFINIDO SIN USO: idem",
    "RunAutoMaxRunners": "DEFINIDO SIN USO: `UcsParams.RUN_AUTO_MAX_RUNNERS` (%s:32)" % UP,
    "RunTimeout": "DEFINIDO SIN USO: `UcsParams.RUN_TIMEOUT_S` (%s:33)" % UP,
    "UrgencyLooseBallOppoFrames": "DEFINIDO SIN USO: `UcsParams.URGENCY_LOOSE_BALL_OPPO_S` (%s:39)" % UP,
}

# (patron del nombre, posible funcion segun el nombre, sistema de Futbol5 candidato)
RULES = [
    (r"^(Version|ScreenOrientation|ReSignInTime|PerformHousekeepingHours|ChatWaitSeconds|MatchSaveExtraHighlightsCount|NoActiveSeasonText|MatchesForLinkCode|LeaderboardJoin|MaxSquadSize|FriendLimit|BoostsValue|TokenValue|WildcardValue)$",
     "aplicacion / cuenta / tienda (no juego)", "ninguno (no hay equivalente)"),
    (r"^SpeedSprint", "velocidad de sprint por atributo (0 = minimo, 1 = maximo)", "Locomotion.max_sprint_speed (scripts/player/locomotion.gd:59): PlayerTuning.sprint_speed 6.8 x factor(speed, 0.12)"),
    (r"^StrengthJump", "salto por atributo de fuerza", "sin sistema de salto propio; golpeo aereo en BallHandler.plan_aerial_kick (scripts/player/ball_handler.gd:803)"),
    (r"^StrengthSlideTackleRange", "alcance de la barrida por fuerza", "PlayerActions.try_slide_tackle (scripts/player/player_actions.gd:211)"),
    (r"^StrengthPressureTackleRange", "alcance de la entrada al presionar", "BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), PlayerActions.tackle_request (scripts/player/player_actions.gd:294)"),
    (r"^StrengthPassiveTackleRange", "alcance de la entrada pasiva", "BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083)"),
    (r"^KickPowerWrongFoot", "potencia con el pie malo", "KickModel.weak_foot_power_mult (scripts/assistance/kick_model.gd:108)"),
    (r"^KickPower", "potencia de golpeo por atributo", "PassAssist.compute / ShotAssist.compute (scripts/assistance/pass_assist.gd:53, shot_assist.gd:54)"),
    (r"^TechniqueSpecialKick", "probabilidad de golpeo especial", "sin equivalente"),
    (r"^TechniqueSpecialControl", "probabilidad de control especial", "JsonReceive (scripts/player/json_receive.gd) sin probabilidad"),
    (r"^TechniqueDribbleSpeedScale", "escala de velocidad conduciendo", "BallHandler.dribble_speed_cap (scripts/player/ball_handler.gd:352)"),
    (r"^TechniqueCurl", "efecto (comba) por tecnica", "KickModel.curl_spin (scripts/assistance/kick_model.gd:61)"),
    (r"^TechniqueTackleJump", "probabilidad de saltar una entrada", "PlayerActions.avoid_tackle (scripts/player/player_actions.gd:456)"),
    (r"^TechniqueKickError", "error del golpeo (adelante / atras / altura)", "PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55)"),
    (r"^Technique(Rot|Height)PowerScale", "escala de potencia al girar / en altura", "ShotAssist.compute (scripts/assistance/shot_assist.gd:54)"),
    (r"^ResponsePlayer", "respuesta del jugador (posicion / fuera de posesion / golpeo)", "AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19)"),
    (r"^(TechniqueGK|GKPresence|ResponseGKSave|GKSafe|GKSweep|GKCharge|GKCloseDown)", "arquero: distancias de atajada, velocidad, presencia, achique, salidas", "Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd)"),
    (r"^Freeze", "ventana de conduccion congelada (distancias / altura de pelota)", "sin equivalente; posesion en MatchContext.update_possession (scripts/gameplay/match_context.gd:37)"),
    (r"^Intercept", "intercepcion / despeje (espacio, altura, urgencia)", "TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296)"),
    (r"^MaxActive", "maximo de jugadores que presionan / entran", "TeamBrain._defend (scripts/ai/team_brain.gd:317)"),
    (r"^Tackl", "entrada: circulo del rival, distancia minima, cuadros, velocidad", "BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), Footballer._ai_commits_tackle (footballer.gd)"),
    (r"^PressureSpeedRate", "velocidad del que presiona", "TeamBrain._defend (scripts/ai/team_brain.gd:317)"),
    (r"^KickError", "escala del error de trayectoria / potencia", "KickModel (scripts/assistance/kick_model.gd)"),
    (r"^(DribbleMinDist|LooseBallDribbleTolerance)", "conduccion / pelota suelta", "BallHandler (scripts/player/ball_handler.gd), MatchContext.update_possession (match_context.gd:37)"),
    (r"^Marking", "marcaje (umbral, linea de fondo, zona, distancia)", "AIInput._mark_spot (scripts/ai/ai_input.gd:673): MARK_GOAL_SIDE 2.6 m, MARK_RANGE 15 m"),
    (r"^Run", "desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro)", "AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371)"),
    (r"^ShotDist", "potencia del tiro segun la distancia", "ShotAssist.compute (scripts/assistance/shot_assist.gd:54)"),
    (r"^Ctrl", "radio en pantalla del control tactil (pelota / jugador)", "TouchControls (scripts/ui/touch_controls.gd)"),
    (r"^(PosChangeFrames|CentreXPercent|BackLine|MidLinePercent|Width|Focal)", "posicionamiento del equipo (lineas, ancho, punto focal en balon parado)", "TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11)"),
    (r"^UrgencyLooseBall", "urgencia ante pelota suelta con rival cerca", "TeamBrain._loose (scripts/ai/team_brain.gd:409)"),
    (r"^PossessionTimer", "temporizador de posesion", "sin equivalente"),
    (r"^Bot(Min|Max)KickFrames", "tiempo del bot con la pelota antes de golpear", "AIInput._decide_with_ball (scripts/ai/ai_input.gd:482)"),
    (r"^Bot(UserChat|Chat)Percent", "chat del bot (no juego)", "ninguno"),
    (r"^Bot", "dificultad y comportamiento del bot (tasa de presion, barrida, error, pase)", "AIInput (scripts/ai/ai_input.gd)"),
    (r"^AnalyticsPercent", "muestreo de analitica (no juego)", "ninguno"),
    (r"^(Goals|Shots|Passes|PassesComplete|Interceptions|StandTacklesSuccess|SlideTacklesSuccess|Kicks|Assists|Fouled|Fouls|Offsides|KeeperSaves)$", "puntos por estadistica del partido (inferido: lista de eventos)", "ninguno (sin valoracion por estadisticas)"),
    (r"^Dist(Default|Close)$", "distancia de camara (inferido)", "MatchCamera (scripts/camera/match_camera.gd)"),
    (r"^ReplayCameras$", "camaras de repeticion", "GoalReplay (scripts/gameplay/goal_replay.gd)"),
    (r"^(MaxReconnects|LateReconnectLimit|ReconnectWait)$", "reconexion en linea (no juego)", "ninguno"),
    (r"^Friend", "partidos amistosos (no juego)", "ninguno"),
    (r"^(ShowAfterWins|BaseContracts|BaseCards|CardsPer|ContractsPer|MatchesDownTime)", "progresion / economia (no juego)", "ninguno"),
]


def unit_from_name(n):
    for pat, u in ((r"Frames", "cuadros (nombre)"), (r"Seconds", "segundos (nombre)"), (r"Hours", "horas (nombre)"),
                   (r"Percent", "por ciento (nombre)"), (r"Yards", "yardas (nombre)"), (r"Rate|Scale", "escala: lectura Q12 posible"),
                   (r"Time$", "tiempo (nombre; unidad no establecida)")):
        if re.search(pat, n):
            return u
    return "no establecida"


def main():
    rows = list(csv.DictReader(open(SRC, encoding="utf-8")))
    e4 = {r["parametro"]: r for r in csv.DictReader(open(E4, encoding="utf-8"))}
    print("| # | parametro | defecto | origen del valor | Q12 | campo | STR en | unidad / escala | posible funcion (nombre) | sistema de Futbol5 | estado | correccion respecto de E4 |")
    print("|---:|---|---:|---|---:|---|---|---|---|---|---|---|")
    for i, r in enumerate(rows, 1):
        n = r["parametro"]
        func, system = "", ""
        for pat, f, s in RULES:
            if re.search(pat, n):
                func, system = f, s
                break
        status = STATUS.get(n, "SIN CONECTAR")
        corr = ""
        if n not in e4:
            corr = "falta en E4_parametros_ucs.csv"
        else:
            ev = e4[n]["valor_entero"]
            if ev != r["valor_defecto"]:
                corr = "E4: %s" % (ev if ev else "vacio")
            if e4[n]["campo"] != r["campo"]:
                corr += ("; " if corr else "") + "campo en E4: %s" % e4[n]["campo"]
        print("| %d | `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            i, n, r["valor_defecto"] or "-", r["origen_valor"], r["q12"] or "-", r["campo"], r["direccion_str"],
            unit_from_name(n), func, system, status, corr))


if __name__ == "__main__":
    main()
