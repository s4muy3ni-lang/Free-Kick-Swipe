class_name HumanInput
extends InputSource
## Lee las acciones de InputMap (teclado, gamepad y HUD tactil, que inyecta acciones reales).

var _tick: int = 0

func poll(_footballer: Footballer) -> InputFrame:
	InputBindings.ensure()
	var f := InputFrame.new()
	_tick += 1
	f.tick = _tick
	f.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	f.sprint = Input.is_action_pressed("sprint")
	f.pass_pressed = Input.is_action_just_pressed("pass")
	f.pass_held = Input.is_action_pressed("pass")
	f.pass_released = Input.is_action_just_released("pass")
	f.shoot_pressed = Input.is_action_just_pressed("shoot")
	f.shoot_held = Input.is_action_pressed("shoot")
	f.shoot_released = Input.is_action_just_released("shoot")
	f.lob_held = Input.is_action_pressed("lob")
	f.press_held = Input.is_action_pressed("press")
	f.switch_pressed = Input.is_action_just_pressed("switch_player")
	f.skill_pressed = Input.is_action_just_pressed("skill")
	f.through_pressed = Input.is_action_just_pressed("through_pass")
	f.through_held = Input.is_action_pressed("through_pass")
	f.through_released = Input.is_action_just_released("through_pass")
	f.cross_pressed = Input.is_action_just_pressed("cross")
	f.cross_held = Input.is_action_pressed("cross")
	f.cross_released = Input.is_action_just_released("cross")
	f.tackle_pressed = Input.is_action_just_pressed("tackle")
	return f
