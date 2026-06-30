extends Node2D
## Vertical slice with the real art: character select (Emmy / Isla) -> walk the
## island collecting presents. Gamepad-first (Steam Deck). Sprites are sized by
## target on-screen height so any art drops in cleanly. Idle-bob + walk-squash
## give the characters life from a single static drawing.

const HEROES: Array[String] = ["isla", "emmy"]
const SCREEN := Vector2(1280, 800)

# play-area clamp (keep the kids on the island grass, below the HUD)
const AREA_MIN := Vector2(150, 230)
const AREA_MAX := Vector2(1130, 700)

var state: String = "select"
var sel: int = 0
var ui: CanvasLayer
var player: Node2D
var player_base_scale: Vector2 = Vector2.ONE
var presents: Array[Sprite2D] = []
var score: int = 0
var score_label: Label
var anim_t: float = 0.0


func _ready() -> void:
	show_select()


# ---------------------------------------------------------------- select
func show_select() -> void:
	state = "select"
	sel = 0
	ui = CanvasLayer.new()
	add_child(ui)

	var bg := ColorRect.new()
	bg.color = Color(0.66, 0.85, 0.95)
	bg.size = SCREEN
	ui.add_child(bg)

	ui.add_child(_label("ISLA & EMMY: FUNKY ISLANDS", 56, Vector2(0, 56), true))
	ui.add_child(_label("Tap a hero  —  or  <  Left / Right  >  then  A", 28, Vector2(0, 156), true))

	for i in HEROES.size():
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/%s.png" % HEROES[i])
		spr.position = Vector2(440 + i * 400, 470)
		spr.name = "portrait_%d" % i
		ui.add_child(spr)
		var nm := _label(HEROES[i].to_upper(), 40, Vector2(440 + i * 400 - 140, 650), false)
		nm.size = Vector2(280, 50)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.add_child(nm)

	_update_cursor()


func _update_cursor() -> void:
	for i in HEROES.size():
		var spr := ui.get_node("portrait_%d" % i) as Sprite2D
		var on := i == sel
		_fit_height(spr, 440.0 if on else 360.0)
		spr.modulate = Color(1, 1, 1) if on else Color(0.7, 0.7, 0.7, 0.85)


func _input(event: InputEvent) -> void:
	# Touch/click to pick a hero — robust against Steam Deck controller layouts
	# that send A as a mouse-click. Tap the side the hero is on.
	if state != "select":
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and event.pressed and \
			(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	if pos != Vector2.INF:
		sel = 0 if pos.x < SCREEN.x * 0.5 else 1
		_update_cursor()
		start_game(HEROES[sel])


# ---------------------------------------------------------------- world
func start_game(hero: String) -> void:
	state = "play"
	Globals.hero = hero
	ui.queue_free()

	var bg := Sprite2D.new()
	bg.texture = load("res://assets/island_bg.png")
	bg.position = SCREEN * 0.5
	bg.z_index = -10
	add_child(bg)

	var hud := CanvasLayer.new()
	add_child(hud)
	score_label = _label("Presents: 0", 30, Vector2(30, 18), false)
	hud.add_child(score_label)
	hud.add_child(_label("Playing as " + hero.to_upper() + "   (B = change hero)", 22, Vector2(30, 58), false))
	# heart HUD (cosmetic preview of the health bar)
	for h in 3:
		var heart := Sprite2D.new()
		heart.texture = load("res://assets/heart.png")
		_fit_height(heart, 46.0)
		heart.position = Vector2(1130 + h * 48, 40)
		hud.add_child(heart)

	player = Node2D.new()
	player.position = SCREEN * 0.5
	player.z_index = 10
	add_child(player)
	var spr := Sprite2D.new()
	spr.name = "spr"
	spr.texture = load("res://assets/%s.png" % hero)
	player_base_scale = _fit_height(spr, 185.0)
	player.add_child(spr)

	var spots := [
		Vector2(250, 300), Vector2(1000, 320), Vector2(360, 600),
		Vector2(930, 600), Vector2(640, 270), Vector2(640, 640),
	]
	for s in spots:
		var p := Sprite2D.new()
		p.texture = load("res://assets/present.png")
		_fit_height(p, 78.0)
		p.position = s
		add_child(p)
		presents.append(p)


func _process(delta: float) -> void:
	if state == "select":
		if Input.is_action_just_pressed("ui_left"):
			sel = (sel - 1 + HEROES.size()) % HEROES.size()
			_update_cursor()
		elif Input.is_action_just_pressed("ui_right"):
			sel = (sel + 1) % HEROES.size()
			_update_cursor()
		if Input.is_action_just_pressed("ui_accept"):
			start_game(HEROES[sel])
		return

	if state != "play":
		return

	if Input.is_action_just_pressed("ui_cancel"):
		_reset_to_select()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := dir.length() > 0.1
	player.position += dir * 330.0 * delta
	player.position.x = clampf(player.position.x, AREA_MIN.x, AREA_MAX.x)
	player.position.y = clampf(player.position.y, AREA_MIN.y, AREA_MAX.y)

	# --- juice: idle bob + walk squash on the single static sprite ---
	anim_t += delta * (10.0 if moving else 2.5)
	var s := sin(anim_t)
	var spr := player.get_node("spr") as Sprite2D
	if moving:
		spr.position.y = -absf(s) * 13.0
		spr.scale = player_base_scale * Vector2(1.0 - 0.05 * s, 1.0 + 0.05 * s)
		if dir.x != 0.0:
			spr.flip_h = dir.x < 0.0
	else:
		spr.position.y = -absf(s) * 3.0
		spr.scale = player_base_scale * Vector2(1.0 + 0.03 * s, 1.0 - 0.03 * s)

	# --- collect presents ---
	var any_left := false
	for p in presents:
		if p.visible and player.position.distance_to(p.position) < 70.0:
			p.visible = false
			score += 1
			score_label.text = "Presents: %d" % score
		any_left = any_left or p.visible
	if not any_left:
		for p in presents:
			p.visible = true


func _reset_to_select() -> void:
	for c in get_children():
		c.queue_free()
	player = null
	presents.clear()
	score = 0
	call_deferred("show_select")


# ---------------------------------------------------------------- helpers
func _fit_height(spr: Sprite2D, target_px: float) -> Vector2:
	var h := spr.texture.get_height()
	var s := target_px / float(h)
	spr.scale = Vector2(s, s)
	return spr.scale


func _label(text: String, size: int, pos: Vector2, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.12, 0.12, 0.2))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	if centered:
		l.size = Vector2(SCREEN.x, float(size) + 12.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
