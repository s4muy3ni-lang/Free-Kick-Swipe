class_name ChatFilter
extends RefCounted
## Chat de partida: frases rapidas, emojis, filtro de palabras (el servidor vuelve a filtrar y limita la frecuencia) y
## las reacciones de los bots segun personalidad y contexto: bromas amistosas, sorpresa, felicitaciones. Nunca insultos.

const QUICK := {"buen_tiro": "¡Buen tiro!", "que_atajada": "¡Qué atajada!", "suerte": "¡Suerte!", "casi": "¡Casi!",
	"revancha": "¿Revancha?", "bien_jugado": "Bien jugado", "uy": "¡Uyyy!", "vamos": "¡Vamos!"}
const EMOTES := ["😀", "😂", "😮", "😎", "🔥", "👏", "😅", "😤", "🙌", "⚽", "🧤", "💪"]
const BAD := ["puto", "puta", "pelotudo", "boludo", "forro", "mierda", "concha", "idiota", "imbecil", "tarado"]

static func clean(text: String) -> String:
	var t: String = text.strip_edges().substr(0, 60)
	for w in BAD:
		var re := RegEx.create_from_string("(?i)" + w)
		t = re.sub(t, "*".repeat(w.length()), true)
	return t

## Reacciones del bot. Contexto: user_miss, user_near_miss, user_goal, user_great, bot_goal, bot_saved, user_saved,
## user_lost, user_won.
const LINES := {
	"user_miss": {"default": ["Esa se fue a la tribuna 😅", "¡Uy! Calibrá la mira", "Tranqui, le pasa a cualquiera"],
		"agresivo": ["¡Afuera! 😂", "Así no me ganás"], "tecnico": ["Te faltó perfil", "Abriste mucho el pie"],
		"principiante": ["Uh, yo también erro así 😅"]},
	"user_near_miss": {"default": ["¡Por un pelito! 😮", "La besó el palo", "Casi casi..."],
		"impredecible": ["Si entraba era golazo 🔥"]},
	"user_goal": {"default": ["Bien ahí", "No la vi venir 😮", "Buen tiro"], "competitivo": ["Ahora me toca a mí 😤"],
		"tranquilo": ["Bien pateado"]},
	"user_great": {"default": ["¡GOLAZO! 👏", "Eso fue de otro planeta 🔥", "Ángulo perfecto, felicitaciones"]},
	"user_saved": {"default": ["¡Qué atajada! 🧤", "Me la sacaste, crack"], "agresivo": ["Tuviste suerte 😤"]},
	"bot_goal": {"default": ["¡Adentro! ⚽", "Esa no la sacabas", "😎"], "agresivo": ["¡Tomá! 💪"],
		"principiante": ["¡Entró! No lo puedo creer 😂"]},
	"bot_saved": {"default": ["La saqué 🧤", "Hoy estoy inspirado"], "experto": ["Te leí el tiro"]},
	"user_lost": {"default": ["Buen partido, la próxima es tuya", "GG 👏", "¿Revancha?"], "agresivo": ["Hoy no era tu día 😎"]},
	"user_won": {"default": ["Bien jugado, me ganaste", "GG, merecido 👏"], "competitivo": ["La revancha va a ser distinta 😤"]},
}

static func bot_line(context: String, personality: String, rng: RandomNumberGenerator) -> String:
	var bank: Dictionary = LINES.get(context, {})
	if bank.is_empty():
		return ""
	var pool: Array = (bank.get("default", []) as Array).duplicate()
	pool.append_array(bank.get(personality, []))
	return String(pool[rng.randi() % pool.size()])
