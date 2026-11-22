extends Node2D
## "Lumo et les Gemmes" - jeu de plateforme 2D original.
## Le niveau est une grille de cases construite en code et dessinée avec des formes simples.
##   #  sol        =  bloc de pierre     C  caisse (à frapper par-dessous)   U  caisse vide
##   o  gemme      ^  piques             S  ressort

const T := 32          # taille d'une case en pixels
const W := 150         # largeur du niveau (cases)
const H := 15          # hauteur du niveau (cases)
const CHECK_X := 72    # colonne du point de passage
const GOAL_X := 144    # colonne du drapeau d'arrivée
const PlayerScript := preload("res://player.gd")
const EnemyScript := preload("res://enemy.gd")
const TouchScript := preload("res://touch_controls.gd")

var touch   # commandes tactiles (visibles seulement sur téléphone)

var grid: Array = []
var enemy_spots: Array = []
var enemies: Array = []
var player
var camera: Camera2D
var gems := 0
var total_gems := 0
var lives := 3
var elapsed := 0.0
var state := "play"
var checkpoint_on := false
var msg_time := 0.0

var bg: Node2D
var gem_label: Label
var lives_label: Label
var time_label: Label
var msg_label: Label
var panel: ColorRect
var panel_label: Label


func _ready() -> void:
	_init_grid()
	_build_level()
	_build_collisions()
	_build_background()
	_build_touch()
	_spawn_player()
	_spawn_enemies()
	_build_ui()
	for y in H:
		for x in W:
			if grid[y][x] == "o" or grid[y][x] == "C":
				total_gems += 1
	_update_ui()
	_show_message("Ramasse les gemmes et atteins le drapeau !")


func _build_touch() -> void:
	# Téléphone : < > en bas à gauche, COURS et SAUT en bas à droite
	touch = TouchScript.new()
	add_child(touch)
	touch.add_button("left", "<", Vector2(0.07, 0.8), 66.0)
	touch.add_button("right", ">", Vector2(0.2, 0.8), 66.0)
	touch.add_button("run", "COURS", Vector2(0.76, 0.84), 62.0)
	touch.add_button("jump", "SAUT", Vector2(0.9, 0.73), 72.0)
	touch.add_button("restart", "R", Vector2(0.5, 0.07), 34.0)
	touch.button_pressed.connect(_on_touch_button)


func _on_touch_button(id: String) -> void:
	if id == "restart":
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- Grille

func _init_grid() -> void:
	for y in H:
		var row := []
		row.resize(W)
		row.fill(".")
		grid.append(row)


func cell(x: int, y: int) -> String:
	if x < 0 or x >= W or y < 0 or y >= H:
		return "."
	return grid[y][x]


func setc(x: int, y: int, c: String) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		grid[y][x] = c


func is_solid_cell(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c == "#" or c == "=" or c == "C" or c == "U"


func is_solid_at(p: Vector2) -> bool:
	return is_solid_cell(floori(p.x / T), floori(p.y / T))


func _row(c: String, x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		setc(x, y, c)


func _gap(x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		setc(x, 13, ".")
		setc(x, 14, ".")


func _pillar(x: int, h: int) -> void:
	for k in h:
		setc(x, 12 - k, "#")


# ---------------------------------------------------------------- Niveau

func _build_level() -> void:
	_row("#", 0, W - 1, 13)
	_row("#", 0, W - 1, 14)

	_row("o", 6, 9, 10)
	setc(12, 9, "=")
	setc(13, 9, "C")
	setc(14, 9, "=")
	setc(15, 9, "C")
	setc(16, 9, "=")
	_row("o", 13, 15, 7)
	enemy_spots.append(Vector2i(19, 12))

	_pillar(23, 2)
	_pillar(24, 2)
	_gap(28, 30)
	_row("o", 28, 30, 10)

	_row("=", 33, 37, 9)
	enemy_spots.append(Vector2i(35, 8))
	enemy_spots.append(Vector2i(41, 12))

	for k in 4:
		_pillar(44 + k, k + 1)
	_gap(48, 51)
	for k in 4:
		_pillar(52 + k, 4 - k)
	enemy_spots.append(Vector2i(58, 12))

	setc(61, 12, "S")              # ressort pour atteindre la plateforme haute
	_row("=", 63, 69, 5)
	_row("o", 64, 68, 4)
	_row("^", 64, 68, 12)

	_row("C", 75, 77, 9)
	enemy_spots.append(Vector2i(79, 12))
	enemy_spots.append(Vector2i(83, 12))

	_gap(87, 91)
	setc(89, 11, "=")
	_row("o", 88, 90, 8)

	_pillar(95, 3)
	enemy_spots.append(Vector2i(98, 12))
	_pillar(101, 3)

	_row("^", 105, 106, 12)
	_row("o", 104, 107, 9)

	_gap(111, 115)
	_row("=", 112, 114, 11)
	_row("o", 112, 114, 10)

	enemy_spots.append(Vector2i(119, 12))
	enemy_spots.append(Vector2i(124, 12))

	for k in 8:
		_pillar(130 + k, k + 1)   # grand escalier final


func _build_collisions() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for y in H:
		var x := 0
		while x < W:
			if is_solid_cell(x, y):
				var start := x
				while x < W and is_solid_cell(x, y):
					x += 1
				_add_rect(body, Rect2(start * T, y * T, (x - start) * T, T))
			else:
				x += 1
	# murs invisibles aux deux bouts du niveau
	_add_rect(body, Rect2(-T, -10 * T, T, (H + 20) * T))
	_add_rect(body, Rect2(W * T, -10 * T, T, (H + 20) * T))


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)


func _spawn_pos() -> Vector2:
	if checkpoint_on:
		return Vector2(CHECK_X * T + 16, 12 * T + 18)
	return Vector2(2 * T + 16, 12 * T + 18)


func _spawn_player() -> void:
	player = PlayerScript.new()
	player.main = self
	player.position = _spawn_pos()
	add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = W * T
	camera.limit_bottom = H * T
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()


func _spawn_enemies() -> void:
	for spot in enemy_spots:
		var e = EnemyScript.new()
		e.main = self
		e.position = Vector2(spot.x * T + 16, spot.y * T + 20)
		add_child(e)
		enemies.append(e)


# ---------------------------------------------------------------- Dessin

func _draw() -> void:
	for y in H:
		for x in W:
			var c: String = grid[y][x]
			if c == ".":
				continue
			var r := Rect2(x * T, y * T, T, T)
			var mid := r.position + Vector2(16, 16)
			match c:
				"#":
					draw_rect(r, Color(0.55, 0.36, 0.2))
					if not is_solid_cell(x, y - 1):
						draw_rect(Rect2(x * T, y * T, T, 9), Color(0.3, 0.75, 0.3))
						draw_rect(Rect2(x * T, y * T + 9, T, 3), Color(0.22, 0.55, 0.22))
					else:
						draw_circle(r.position + Vector2(9, 12), 3.0, Color(0.47, 0.3, 0.16))
						draw_circle(r.position + Vector2(22, 23), 2.5, Color(0.47, 0.3, 0.16))
				"=":
					draw_rect(r, Color(0.6, 0.6, 0.68))
					draw_rect(r.grow(-4), Color(0.7, 0.7, 0.78))
					draw_rect(r, Color(0.35, 0.35, 0.42), false, 2.0)
				"C":
					draw_rect(r, Color(0.75, 0.45, 0.18))
					draw_rect(r.grow(-4), Color(0.88, 0.58, 0.25))
					draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color(0.55, 0.32, 0.12), 2.0)
					draw_line(Vector2(r.end.x - 4, r.position.y + 4), Vector2(r.position.x + 4, r.end.y - 4), Color(0.55, 0.32, 0.12), 2.0)
					draw_rect(r, Color(0.45, 0.25, 0.1), false, 2.0)
					_draw_gem(mid, 0.6)
				"U":
					draw_rect(r, Color(0.45, 0.35, 0.3))
					draw_rect(r, Color(0.3, 0.22, 0.18), false, 2.0)
				"o":
					_draw_gem(mid, 1.0)
				"^":
					for k in 2:
						var bx := x * T + k * 16.0
						draw_colored_polygon(PackedVector2Array([Vector2(bx, y * T + 32), Vector2(bx + 8, y * T + 12), Vector2(bx + 16, y * T + 32)]), Color(0.7, 0.72, 0.78))
				"S":
					draw_rect(Rect2(x * T + 4, y * T + 26, 24, 6), Color(0.5, 0.1, 0.1))
					for k in 3:
						var yy := y * T + 24 - k * 3.5
						draw_line(Vector2(x * T + 8, yy), Vector2(x * T + 24, yy - 2), Color(0.6, 0.6, 0.65), 2.0)
					draw_rect(Rect2(x * T + 2, y * T + 13, 28, 5), Color(0.9, 0.2, 0.2))

	# Point de passage (rouge, devient vert une fois atteint)
	var cxp := CHECK_X * T + 16.0
	draw_line(Vector2(cxp, 9 * T), Vector2(cxp, 13 * T), Color(0.3, 0.3, 0.3), 3.0)
	var fc := Color(0.3, 0.85, 0.3) if checkpoint_on else Color(0.9, 0.3, 0.3)
	draw_colored_polygon(PackedVector2Array([Vector2(cxp, 9 * T), Vector2(cxp + 26, 9 * T + 9), Vector2(cxp, 9 * T + 18)]), fc)

	# Drapeau d'arrivée et petit temple
	var gx := GOAL_X * T + 16.0
	draw_line(Vector2(gx, 3 * T), Vector2(gx, 13 * T), Color(0.95, 0.95, 0.95), 5.0)
	draw_circle(Vector2(gx, 3 * T), 7.0, Color(1.0, 0.85, 0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(gx, 3 * T + 6), Vector2(gx + 56, 3 * T + 24), Vector2(gx, 3 * T + 42)]), Color(0.2, 0.7, 0.75))
	_draw_gem(Vector2(gx + 18, 3 * T + 24), 0.8)
	var temple := Rect2(146 * T, 9 * T, 3 * T, 4 * T)
	draw_rect(temple, Color(0.75, 0.7, 0.6))
	draw_colored_polygon(PackedVector2Array([Vector2(temple.position.x - 10, temple.position.y), Vector2(temple.position.x + temple.size.x * 0.5, temple.position.y - 40), Vector2(temple.end.x + 10, temple.position.y)]), Color(0.6, 0.3, 0.25))
	draw_rect(Rect2(temple.position.x + 32, temple.position.y + 64, 32, 64), Color(0.25, 0.18, 0.15))


func _draw_gem(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(8, 0) * s, c + Vector2(0, 10) * s, c + Vector2(-8, 0) * s]), Color(0.3, 0.9, 1.0))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7) * s, c + Vector2(3, -1) * s, c + Vector2(-3, -1) * s]), Color(0.85, 1.0, 1.0))


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.8, 0.98)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = Node2D.new()
	layer.add_child(bg)
	bg.draw.connect(_draw_bg)


func _draw_bg() -> void:
	var size := get_viewport_rect().size
	var off := 0.0
	if camera != null:
		off = camera.get_screen_center_position().x
	# nuages (défilent lentement)
	for k in range(-1, 8):
		var x := k * 260.0 - fmod(off * 0.15, 260.0)
		var y := 90.0 + posmod(k, 3) * 45.0
		bg.draw_circle(Vector2(x, y), 26.0, Color(1, 1, 1, 0.9))
		bg.draw_circle(Vector2(x + 28, y + 6), 22.0, Color(1, 1, 1, 0.9))
		bg.draw_circle(Vector2(x - 26, y + 8), 20.0, Color(1, 1, 1, 0.9))
	# collines lointaines puis proches (effet de profondeur)
	for k in range(-1, 10):
		var x := k * 220.0 - fmod(off * 0.3, 220.0)
		bg.draw_circle(Vector2(x, size.y + 60.0), 200.0, Color(0.5, 0.78, 0.55))
	for k in range(-1, 10):
		var x := k * 300.0 + 120.0 - fmod(off * 0.5, 300.0)
		bg.draw_circle(Vector2(x, size.y + 130.0), 210.0, Color(0.38, 0.66, 0.42))


# ---------------------------------------------------------------- Jeu

func _physics_process(delta: float) -> void:
	if state != "play":
		return
	elapsed += delta
	var pp: Vector2 = player.global_position

	# Cases touchées par le joueur
	var x0 := floori((pp.x - 10.0) / T)
	var x1 := floori((pp.x + 9.0) / T)
	var y0 := floori((pp.y - 14.0) / T)
	var y1 := floori((pp.y + 13.0) / T)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cell(cx, cy)
			if c == "o":
				setc(cx, cy, ".")
				gems += 1
				_pop_gem(Vector2(cx * T + 16, cy * T + 16))
				queue_redraw()
				_update_ui()
			elif c == "^" and pp.y + 14.0 > cy * T + 14:
				_hurt()
				return
			elif c == "S" and player.velocity.y >= 0.0:
				player.velocity.y = -1050.0
				player.bounced = true
				player.squash = Vector2(0.7, 1.3)

	# Ennemis : on les écrase en tombant dessus, sinon on est touché
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var ep: Vector2 = e.global_position
		if absf(ep.x - pp.x) < 23.0 and absf(ep.y - pp.y) < 26.0:
			if player.velocity.y > 0.0 and pp.y < ep.y - 4.0:
				e.squash_kill()
				player.velocity.y = -620.0 if player.prev_jump else -420.0
				player.bounced = true
			else:
				_hurt()
				return

	if pp.y > H * T + 80:
		_hurt(true)
		return
	if not checkpoint_on and pp.x > CHECK_X * T:
		checkpoint_on = true
		queue_redraw()
		_show_message("Point de passage atteint !")
	if pp.x > GOAL_X * T + 8:
		_win()


func head_bump(p: Vector2) -> void:
	# Le joueur se cogne la tête : s'il y a une caisse au-dessus, elle libère une gemme
	for dx in [0.0, -9.0, 9.0]:
		var cx := floori((p.x + dx) / T)
		var cy := floori((p.y - 16.0) / T)
		if cell(cx, cy) == "C":
			setc(cx, cy, "U")
			gems += 1
			_pop_gem(Vector2(cx * T + 16, cy * T - 8))
			queue_redraw()
			_update_ui()
			return


func _pop_gem(pos: Vector2) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, -10), Vector2(8, 0), Vector2(0, 10), Vector2(-8, 0)])
	poly.color = Color(0.3, 0.9, 1.0)
	poly.position = pos
	add_child(poly)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(poly, "position:y", pos.y - 40.0, 0.4)
	tw.tween_property(poly, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(poly.queue_free)


func _hurt(fall := false) -> void:
	if not fall and player.invuln > 0.0:
		return
	lives -= 1
	_update_ui()
	if lives <= 0:
		state = "gameover"
		player.controls = false
		player.visible = false
		_show_panel("PERDU !\n\nAppuie sur R (ou Start) pour réessayer", Color(1.0, 0.55, 0.55))
		return
	player.global_position = _spawn_pos()
	player.velocity = Vector2.ZERO
	player.invuln = 1.5
	camera.reset_smoothing()
	_show_message("Aïe ! Il te reste %d vie%s" % [lives, "s" if lives > 1 else ""])


func _win() -> void:
	state = "win"
	player.controls = false
	_show_panel("BRAVO !\n\nNiveau terminé en %.1f s\nGemmes : %d / %d\n\nR (ou Start) pour rejouer" % [elapsed, gems, total_gems], Color(1.0, 0.9, 0.4))


func _process(delta: float) -> void:
	time_label.text = "Temps : %.1f s" % elapsed
	if msg_time > 0.0:
		msg_time -= delta
		msg_label.modulate.a = clampf(msg_time, 0.0, 1.0)
	bg.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := event as InputEventKey
		if k.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif k.physical_keycode == KEY_ESCAPE and not OS.has_feature("web"):
			get_tree().quit()
	elif event is InputEventJoypadButton and event.is_pressed():
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_START:
			get_tree().reload_current_scene()


# ---------------------------------------------------------------- Interface

func _make_label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	gem_label = _make_label(layer, 28)
	gem_label.position = Vector2(24, 14)
	gem_label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	lives_label = _make_label(layer, 28)
	lives_label.position = Vector2(300, 14)
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	time_label = _make_label(layer, 28)
	time_label.anchor_left = 1.0
	time_label.anchor_right = 1.0
	time_label.offset_left = -320.0
	time_label.offset_right = -24.0
	time_label.offset_top = 14.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var help := _make_label(layer, 17)
	help.text = "Q/D ou flèches : bouger    Espace / Z / A (manette) : sauter    Maj / X (manette) : courir    R / Start : recommencer    Échap : quitter"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.anchor_right = 1.0
	help.offset_top = -34.0
	help.offset_bottom = -8.0
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if touch.enabled:
		help.visible = false   # sur téléphone, les boutons à l'écran suffisent

	msg_label = _make_label(layer, 32)
	msg_label.anchor_right = 1.0
	msg_label.offset_top = 80.0
	msg_label.offset_bottom = 130.0
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.65)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel_label = _make_label(panel, 48)
	panel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _update_ui() -> void:
	gem_label.text = "Gemmes : %d / %d" % [gems, total_gems]
	lives_label.text = "Vies : %d" % lives


func _show_message(text: String) -> void:
	msg_label.text = text
	msg_time = 2.5
	msg_label.modulate.a = 1.0


func _show_panel(text: String, color: Color) -> void:
	panel_label.text = text
	panel_label.add_theme_color_override("font_color", color)
	panel.visible = true
	msg_label.text = ""
