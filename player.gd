extends CharacterBody2D
## Lumo, le héros : une petite créature verte avec une antenne lumineuse.
## Saut à hauteur variable (relâcher = saut plus court), course, "coyote time".

const GRAVITY := 1800.0
const MAX_FALL := 900.0
const WALK := 210.0
const RUN := 320.0
const ACCEL := 1600.0
const FRICTION := 1900.0
const JUMP := 640.0

var main
var controls := true
var facing := 1.0
var coyote := 0.0
var jump_buffer := 0.0
var prev_jump := false
var bounced := false
var invuln := 0.0
var squash := Vector2.ONE
var was_on_floor := true
var t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 28)
	cs.shape = rs
	add_child(cs)


func _physics_process(delta: float) -> void:
	t += delta
	var left := false
	var right := false
	var jump_held := false
	var run_held := false
	if controls:
		var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		left = Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) \
				or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) or ax < -0.3
		right = Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) \
				or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) or ax > 0.3
		jump_held = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) \
				or Input.is_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
		run_held = Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_X) \
				or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
		# Téléphone : boutons à l'écran
		if main != null and main.touch != null:
			var tc = main.touch
			left = left or tc.is_pressed("left")
			right = right or tc.is_pressed("right")
			jump_held = jump_held or tc.is_pressed("jump")
			run_held = run_held or tc.is_pressed("run")

	var dir := 0.0
	if left:
		dir -= 1.0
	if right:
		dir += 1.0
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * (RUN if run_held else WALK), ACCEL * delta)
		facing = dir
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if is_on_floor():
		coyote = 0.1
	else:
		coyote -= delta
	if jump_held and not prev_jump:
		jump_buffer = 0.12
	else:
		jump_buffer -= delta
	prev_jump = jump_held

	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = -JUMP
		jump_buffer = 0.0
		coyote = 0.0
		squash = Vector2(0.75, 1.25)

	if velocity.y >= 0.0:
		bounced = false
	if not jump_held and not bounced and velocity.y < -260.0:
		velocity.y = -260.0

	var vy_before := velocity.y
	move_and_slide()

	if is_on_ceiling() and vy_before < 0.0 and main != null:
		main.head_bump(global_position)
	if is_on_floor() and not was_on_floor:
		squash = Vector2(1.25, 0.75)
	was_on_floor = is_on_floor()

	if invuln > 0.0:
		invuln -= delta
	squash = squash.lerp(Vector2.ONE, clampf(12.0 * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if invuln > 0.0 and int(invuln * 12.0) % 2 == 0:
		return   # clignote après avoir été touché
	draw_set_transform(Vector2(0, 14.0 - 14.0 * squash.y), 0.0, Vector2(squash.x * facing, squash.y))
	var bob := sin(t * 14.0) if (absf(velocity.x) > 20.0 and is_on_floor()) else 0.0
	var dark := Color(0.12, 0.3, 0.3)
	# pieds
	draw_circle(Vector2(-6, 12), 4.5, dark)
	draw_circle(Vector2(6, 12), 4.5, dark)
	# corps et ventre
	draw_circle(Vector2(0, 1 + bob), 13.0, Color(0.25, 0.75, 0.6))
	draw_circle(Vector2(3, 5 + bob), 7.0, Color(0.75, 0.95, 0.85))
	# antenne lumineuse
	draw_line(Vector2(-2, -11 + bob), Vector2(-5, -19 + bob), dark, 2.0)
	draw_circle(Vector2(-5, -21 + bob), 4.0 + sin(t * 6.0) * 0.6, Color(1.0, 0.9, 0.3))
	# grand oeil
	draw_circle(Vector2(4, -3 + bob), 5.5, Color(1, 1, 1))
	draw_circle(Vector2(6, -3 + bob), 2.6, Color(0.05, 0.05, 0.1))
	draw_circle(Vector2(7, -4.5 + bob), 1.0, Color(1, 1, 1))
	# joue rose
	draw_circle(Vector2(-4, 4 + bob), 2.5, Color(1.0, 0.55, 0.6, 0.8))
