extends Node2D
## Vertical slice: character select (Emmy / Isla) -> walk around, collect presents.
## Built entirely in code so it stays robust and easy to extend. Gamepad-first
## (Steam Deck): left stick / d-pad move, A confirms.

const HEROES: Array[String] = ["isla", "emmy"]

var state: String = "select"
var sel: int = 0
var ui: CanvasLayer
var player: Node2D
var presents: Array[Sprite2D] = []
var score: int = 0
var score_label: Label

const SCREEN := Vector2(1280, 800)


func _ready() -> void:
	show_select()


# ---------------------------------------------------------------- select
func show_select() -> void:
	state = "select"
	sel = 0
	ui = CanvasLayer.new()
	add_child(ui)

	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.78, 0.95)
	bg.size = SCREEN
	ui.add_child(bg)

	var title := _label("ISLA & EMMY: FUNKY ISLANDS", 56, Vector2(0, 70), true)
	ui.add_child(title)
	ui.add_child(_label("Pick your hero   <  Left / Right  >   then  A", 28, Vector2(0, 180), true))
	var ver := _label("auto-update test - build 2", 20, Vector2(0, 760), true)
	ver.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(ver)

	for i in HEROES.size():
		var h: String = HEROES[i]
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/%s.png" % h)
		spr.scale = Vector2(2.6, 2.6)
		spr.position = Vector2(440 + i * 400, 440)
		spr.name = "portrait_%d" % i
		ui.add_child(spr)
		var nm := _label(h.to_upper(), 40, Vector2(440 + i * 400 - 120, 560), false)
		nm.size = Vector2(240, 50)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.add_child(nm)

	_update_cursor()


func _update_cursor() -> void:
	for i in HEROES.size():
		var spr := ui.get_node("portrait_%d" % i) as Sprite2D
		var on := i == sel
		spr.modulate = Color(1, 1, 1) if on else Color(0.5, 0.5, 0.5, 0.85)
		spr.scale = Vector2(3.1, 3.1) if on else Vector2(2.4, 2.4)


func _unhandled_input(event: InputEvent) -> void:
	if state != "select":
		return
	if event.is_action_pressed("ui_left"):
		sel = (sel - 1 + HEROES.size()) % HEROES.size()
		_update_cursor()
	elif event.is_action_pressed("ui_right"):
		sel = (sel + 1) % HEROES.size()
		_update_cursor()
	elif event.is_action_pressed("ui_accept"):
		start_game(HEROES[sel])


# ---------------------------------------------------------------- world
func start_game(hero: String) -> void:
	state = "play"
	Globals.hero = hero
	ui.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.72, 0.45)
	bg.size = SCREEN
	bg.z_index = -10
	add_child(bg)

	var hud := CanvasLayer.new()
	add_child(hud)
	score_label = _label("Presents: 0", 32, Vector2(30, 20), false)
	hud.add_child(score_label)
	hud.add_child(_label("Playing as " + hero.to_upper() + "   (B = change hero)", 24, Vector2(30, 62), false))

	player = Node2D.new()
	player.position = SCREEN * 0.5
	player.z_index = 10
	add_child(player)
	var spr := Sprite2D.new()
	spr.name = "spr"
	spr.texture = load("res://assets/%s.png" % hero)
	spr.scale = Vector2(1.6, 1.6)
	player.add_child(spr)

	var spots := [
		Vector2(180, 170), Vector2(1090, 200), Vector2(300, 640),
		Vector2(980, 630), Vector2(640, 150), Vector2(150, 430),
		Vector2(1120, 470), Vector2(640, 670),
	]
	for s in spots:
		var p := Sprite2D.new()
		p.texture = load("res://assets/present.png")
		p.position = s
		add_child(p)
		presents.append(p)


func _process(delta: float) -> void:
	if state != "play":
		return

	# back to character select
	if Input.is_action_just_pressed("ui_cancel"):
		_reset_to_select()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.position += dir * 340.0 * delta
	player.position.x = clampf(player.position.x, 40, SCREEN.x - 40)
	player.position.y = clampf(player.position.y, 40, SCREEN.y - 40)
	if dir.x != 0.0:
		(player.get_node("spr") as Sprite2D).flip_h = dir.x < 0.0

	var any_left := false
	for p in presents:
		if p.visible and player.position.distance_to(p.position) < 64.0:
			p.visible = false
			score += 1
			score_label.text = "Presents: %d" % score
		any_left = any_left or p.visible
	if not any_left:
		for p in presents:
			p.visible = true   # endless, no-lose: they just keep coming back


func _reset_to_select() -> void:
	for c in get_children():
		c.queue_free()
	player = null
	presents.clear()
	score = 0
	call_deferred("show_select")


# ---------------------------------------------------------------- helpers
func _label(text: String, size: int, pos: Vector2, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.12, 0.12, 0.2))
	l.position = pos
	if centered:
		l.size = Vector2(SCREEN.x, float(size) + 12.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
