class_name ScriptedInput
extends InputSource
## Entrada programable para pruebas y demostraciones. Los flancos (pressed/released) duran un solo poll.

var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var press_held: bool = false
var lob_held: bool = false
var _pass_held: bool = false
var _shoot_held: bool = false
var _pass_pressed: bool = false
var _pass_released: bool = false
var _shoot_pressed: bool = false
var _shoot_released: bool = false
var _switch: bool = false
var _skill: bool = false
var _through_held: bool = false
var _through_pressed: bool = false
var _through_released: bool = false
var _cross_held: bool = false
var _cross_pressed: bool = false
var _cross_released: bool = false
var _tackle: bool = false
var _tick: int = 0

func hold_through() -> void:
	_through_pressed = true
	_through_held = true

func release_through() -> void:
	_through_held = false
	_through_released = true

func hold_cross() -> void:
	_cross_pressed = true
	_cross_held = true

func release_cross() -> void:
	_cross_held = false
	_cross_released = true

func tackle() -> void:
	_tackle = true

func hold_pass() -> void:
	_pass_pressed = true
	_pass_held = true

func release_pass() -> void:
	_pass_held = false
	_pass_released = true

func hold_shoot() -> void:
	_shoot_pressed = true
	_shoot_held = true

func release_shoot() -> void:
	_shoot_held = false
	_shoot_released = true

func skill() -> void:
	_skill = true

func request_switch() -> void:
	_switch = true

func poll(_footballer: Footballer) -> InputFrame:
	var f := InputFrame.new()
	_tick += 1
	f.tick = _tick
	f.move = move
	f.sprint = sprint
	f.press_held = press_held
	f.lob_held = lob_held
	f.pass_pressed = _pass_pressed
	f.pass_held = _pass_held
	f.pass_released = _pass_released
	f.shoot_pressed = _shoot_pressed
	f.shoot_held = _shoot_held
	f.shoot_released = _shoot_released
	f.switch_pressed = _switch
	f.skill_pressed = _skill
	f.through_pressed = _through_pressed
	f.through_held = _through_held
	f.through_released = _through_released
	f.cross_pressed = _cross_pressed
	f.cross_held = _cross_held
	f.cross_released = _cross_released
	f.tackle_pressed = _tackle
	_through_pressed = false
	_through_released = false
	_cross_pressed = false
	_cross_released = false
	_tackle = false
	_pass_pressed = false
	_pass_released = false
	_shoot_pressed = false
	_shoot_released = false
	_switch = false
	_skill = false
	return f
