class_name AnimBank
extends RefCounted
## Cuerpo y animaciones de los jugadores de penales, tiros libres, minijuegos y laboratorio.
##
## - Animaciones: el banco JSON (json_clips.res, json_keeper.res, json_scenes.res; SpClips, PackLibrary, ShotCatalog). La
##   biblioteca de Mixamo que se sumo el 2026-11-12 se elimino ese mismo dia por pedido del usuario («son muy feas y
##   basicas»): ya no hay selector de biblioteca.
## - Cuerpo: el modelo de Tripo del usuario (assets/characters/player/player_base.glb adaptado por
##   tools/json_anim/build_tripo_body). Es el UNICO cuerpo del juego: el humanoide JSON se elimino (pedido del usuario
##   2026-11-12: «el humanoide no va mas, queda el jugador 3D; eliminalo de los archivos»).

const BODY_PATH := "res://assets/characters/json/tripo_body.scn"

static func body_path() -> String:
	return BODY_PATH
