extends CharacterBody2D
## "Grognon" : petit scarabée ronchon qui fait des allers-retours.
## Il fait demi-tour contre un mur ou au bord du vide. On l'écrase en lui sautant dessus.

const SPEED := 60.0
const GRAVITY := 1800.0

var main
var dir := -1.0
var dead := false
var t := 0.0

# Photo du visage (optionnelle) : place une image "tete.png" (ou .jpg / .webp)
# recadrée sur ton visage dans le dossier du jeu, elle remplacera la tête dessinée.
static var face_tex: Texture2D = null
static var face_checked := false


func _ready() -> void:
	if not face_checked:
		face_checked = true
		for ext in ["png", "jpg", "jpeg", "webp"]:
			var path: String = "res://tete." + ext
			if ResourceLoader.exists(path):
				face_tex = load(path)
				break
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(26, 24)
	cs.shape = rs
	add_child(cs)


func _physics_process(delta: float) -> void:
	t += delta
	if dead:
		return
	# Il ne bouge que lorsque le joueur est assez proche
	if main.player != null and absf(main.player.global_position.x - global_position.x) > 900.0:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	velocity.x = dir * SPEED
	move_and_slide()
	if is_on_wall():
		dir = -dir
	elif is_on_floor() and not main.is_solid_at(global_position + Vector2(dir * 16.0, 22.0)):
		dir = -dir
	queue_redraw()


func squash_kill() -> void:
	dead = true
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var bob := 0.0
	if dead:
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.3, 0.35))
	else:
		bob = absf(sin(t * 8.0)) * 2.0
	var dark := Color(0.12, 0.12, 0.15)
	# jambes
	draw_circle(Vector2(-6, 10), 4.0, dark)
	draw_circle(Vector2(6, 10), 4.0, dark)
	# veste polaire bleu marine
	draw_circle(Vector2(0, 5 - bob * 0.5), 10.0, Color(0.1, 0.15, 0.3))
	draw_line(Vector2(0, -1 - bob), Vector2(0, 12 - bob), Color(0.05, 0.08, 0.18), 1.5)

	var c := Vector2(dir * 1.0, -9 - bob)   # centre de la tête
	if face_tex != null:
		_draw_photo_head(c, 13.0)
		return

	var o := dir * 1.5
	var skin := Color(0.96, 0.78, 0.66)
	var beard := Color(0.28, 0.22, 0.18)
	# barbe (en dessous), puis le haut du visage par-dessus
	draw_circle(c + Vector2(0, 3), 11.5, beard)
	draw_circle(c + Vector2(0, -2), 11.0, skin)
	draw_circle(c + Vector2(o, 4), 5.5, beard)          # moustache / menton
	# crâne dégarni qui brille + cheveux courts sur les côtés
	draw_circle(c + Vector2(-3, -9), 2.5, Color(1, 1, 1, 0.45))
	draw_arc(c + Vector2(0, -2), 11.0, PI * 1.02, PI * 1.32, 8, Color(0.4, 0.3, 0.22), 2.5)
	draw_arc(c + Vector2(0, -2), 11.0, PI * 1.68, PI * 1.98, 8, Color(0.4, 0.3, 0.22), 2.5)
	# lunettes rectangulaires
	var metal := Color(0.35, 0.3, 0.3)
	draw_rect(Rect2(c + Vector2(-8.5 + o, -4), Vector2(7, 5)), Color(0.85, 0.9, 1.0, 0.35))
	draw_rect(Rect2(c + Vector2(1.5 + o, -4), Vector2(7, 5)), Color(0.85, 0.9, 1.0, 0.35))
	draw_rect(Rect2(c + Vector2(-8.5 + o, -4), Vector2(7, 5)), metal, false, 1.2)
	draw_rect(Rect2(c + Vector2(1.5 + o, -4), Vector2(7, 5)), metal, false, 1.2)
	draw_line(c + Vector2(-1.5 + o, -2), c + Vector2(1.5 + o, -2), metal, 1.2)
	# yeux mi-clos et sourcils froncés (il est ronchon !)
	draw_circle(c + Vector2(-5 + o * 1.3, -1.5), 1.3, dark)
	draw_circle(c + Vector2(5 + o * 1.3, -1.5), 1.3, dark)
	draw_line(c + Vector2(-8 + o, -7), c + Vector2(-2 + o, -5), beard, 1.8)
	draw_line(c + Vector2(8 + o, -7), c + Vector2(2 + o, -5), beard, 1.8)
	# nez et lèvres en moue
	draw_circle(c + Vector2(o * 1.2, 1.5), 2.0, Color(0.9, 0.68, 0.58))
	draw_circle(c + Vector2(o, 5.5), 2.6, Color(0.85, 0.45, 0.45))


func _draw_photo_head(c: Vector2, r: float) -> void:
	# Découpe la photo en disque
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5)
	draw_polygon(pts, PackedColorArray([Color(1, 1, 1)]), uvs, face_tex)
	draw_arc(c, r, 0.0, TAU, 32, Color(0.1, 0.1, 0.1), 1.5)
